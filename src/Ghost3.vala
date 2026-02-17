namespace Ghost {
    public const string API_ENDPOINT = "ghost/api/admin/";
    public const string API_VERSION = "v5.0";
    public const string POST = "posts";
    public const string IMAGE = "images";

    public const string COOKIE = "ghost-admin-api-session";
    public const string ORIGIN = "https://thiefmd.com/";

    public class Client {
        public string endpoint;
        string username;
        private string? authenticated_user;
        public string origin_dat;
        public SList<Soup.Cookie> cookies;
        public bool requires_2fa { get; private set; default = false; }
        private bool is_cookie_auth = false;

        public Client (string url, string user, string token) {
            if (url.has_suffix ("/")) {
                endpoint = url;
            } else {
                endpoint = url + "/";
            }

            if (!endpoint.has_prefix ("http")) {
                endpoint = "https://" + endpoint;
            }

            username = user;
            cookies = new SList<Soup.Cookie> ();
            origin_dat = ORIGIN + user;

            // Check if token is a stored session cookie
            if (token != null && token.has_prefix ("cookie:")) {
                // Extract the actual cookie value
                authenticated_user = token.substring (7); // Remove "cookie:" prefix
                is_cookie_auth = true;
                // Note: cookies will be populated by authenticate() or when making requests
                // The actual cookie object will be created when needed
            } else {
                // Use token as password for authentication
                authenticated_user = token;
                is_cookie_auth = false;
            }
        }

        public bool authenticate () {
            // If we're using a stored cookie, reconstruct the cookie from the value
            if (is_cookie_auth && authenticated_user != null && authenticated_user != "") {
                debug ("Using stored session cookie for authentication");
                // The cookie value is already in authenticated_user
                // We'll add it to the cookies list for use in API requests
                // Note: The actual cookie object will be used by the WebCall class
                return true;
            }

            // Otherwise, perform password-based authentication
            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("POST", endpoint + API_ENDPOINT + "session/");
            msg.request_headers.append ("Origin", origin_dat);
            msg.request_headers.append ("Accept-Version", API_VERSION);
            string login = "username=" + username + "&password=" + authenticated_user;
            Bytes login_data = new Bytes.take (login.data);
            msg.set_request_body_from_bytes ("application/x-www-form-urlencoded", login_data);
            cookies = new SList<Soup.Cookie> ();
            requires_2fa = false;
            MainLoop loop = new MainLoop ();

            session.send_and_read_async.begin (msg, 0, null, (obj, res) => {
                try {
                    var response = session.send_and_read_async.end (res);

                    // Store cookies for both success and 2FA responses
                    if (msg.status_code >= 200 && msg.status_code < 300) {

                        GLib.SList<Soup.Cookie> rec_cookies = Soup.cookies_from_response (msg);
                        debug ("Got success from server");
                        foreach (var cookie in rec_cookies) {
                            if (cookie.get_name() == COOKIE) {
                                cookies.append (cookie);
                            }
                        }
                        debug ("Found : %u expected cookies", cookies.length ());
                    } else if (msg.status_code == 403) {
                        // Check if this is a 2FA requirement
                        string response_str = response != null ? (string)response.get_data () : "";
                        if (response_str != null && response_str.contains ("User must verify session to login")) {
                            requires_2fa = true;
                            // Save cookies for 2FA verification
                            GLib.SList<Soup.Cookie> rec_cookies = Soup.cookies_from_response (msg);
                            debug ("2FA required - got session cookie");
                            foreach (var cookie in rec_cookies) {
                                if (cookie.get_name() == COOKIE) {
                                    cookies.append (cookie);
                                }
                            }
                            debug ("Found : %u expected cookies for 2FA", cookies.length ());
                        }
                    }
                } catch (Error e) {
                    warning ("Error sending request: %s", e.message);
                }
                loop.quit ();
            });

            loop.run ();

            // Incase URL is valid but has ghost install path at the end
            if (cookies.length () == 0 && endpoint.has_suffix ("ghost/")) {
                endpoint = endpoint.substring (0, endpoint.length - 6);
                return authenticate ();
            }

            return (cookies.length () != 0);
        }

        public bool verify_session (string auth_code) {
            if (cookies.length () == 0) {
                warning ("No session cookie available for verification");
                return false;
            }

            Json.Builder builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("token");
            builder.add_string_value (auth_code);
            builder.end_object ();

            Json.Generator generate = new Json.Generator ();
            Json.Node root = builder.get_root ();
            generate.set_root (root);
            string request_body = generate.to_data (null);

            WebCall call = new WebCall (endpoint, API_ENDPOINT + "session/verify");
            call.set_put ();
            call.add_header ("Origin", origin_dat);
            call.add_cookies (cookies);
            string? cookie_header = get_stored_cookie_header ();
            if (cookie_header != null) {
                call.add_header ("Cookie", cookie_header);
            }
            call.set_body (request_body);
            call.perform_call ();

            if (call.response_code >= 200 && call.response_code < 300) {
                requires_2fa = false;
                debug ("2FA verification successful");
                return true;
            }

            warning ("2FA verification failed with status: %u", call.response_code);
            return false;
        }

        public bool resend_verification () {
            if (cookies.length () == 0) {
                warning ("No session cookie available for resend");
                return false;
            }

            Json.Builder builder = new Json.Builder ();
            builder.begin_object ();
            builder.end_object ();

            Json.Generator generate = new Json.Generator ();
            Json.Node root = builder.get_root ();
            generate.set_root (root);
            string request_body = generate.to_data (null);

            WebCall call = new WebCall (endpoint, API_ENDPOINT + "session/verify");
            call.set_post ();
            call.add_header ("Origin", origin_dat);
            prepare_cookies ();
            call.add_cookies (cookies);
            string? cookie_header = get_stored_cookie_header ();
            if (cookie_header != null) {
                call.add_header ("Cookie", cookie_header);
            }
            call.set_body (request_body);
            call.perform_call ();

            if (call.response_code >= 200 && call.response_code < 300) {
                debug ("2FA code resent successfully");
                return true;
            }

            warning ("2FA resend failed with status: %u", call.response_code);
            return false;
        }

        private void prepare_cookies () {
            // If using cookie auth and cookies list is empty, add the stored cookie
            if (is_cookie_auth && cookies.length () == 0 && authenticated_user != null && authenticated_user != "") {
                // Create a header-based cookie representation for the stored session
                // This will be added as a Cookie header instead of using Soup.Cookie objects
                debug ("Preparing stored session cookie for API request");
                // We'll handle this in the WebCall class by adding it as a header
            }
        }

        public string? get_stored_cookie_header () {
            // If using cookie auth, return the Cookie header value
            if (is_cookie_auth && authenticated_user != null && authenticated_user != "") {
                return Ghost.COOKIE + "=" + authenticated_user;
            }
            return null;
        }

        public string? get_session_cookie () {
            if (cookies.length () > 0 && cookies.data != null) {
                var cookie = (Soup.Cookie)cookies.data;
                if (cookie != null && cookie.get_value () != null) {
                    return cookie.get_value ();
                }
            }
            return null;
        }

        public bool upload_image_simple (
            out string file_url,
            string local_file_path
        )
        {
            bool success = false;
            file_url = "";
            File upload_file = File.new_for_path (local_file_path);
            string file_mimetype = "application/octet-stream";

            if (!upload_file.query_exists ()) {
                warning ("Invalid file provided");
                return false;
            }

            uint8[] file_data;
            try {
                GLib.FileUtils.get_data(local_file_path, out file_data);
            } catch (GLib.FileError e) {
                warning(e.message);
                return false;
            }

            bool uncertain = false;
            string? st = ContentType.guess (upload_file.get_basename (), file_data, out uncertain);
            if (!uncertain || st != null) {
                file_mimetype = ContentType.get_mime_type (st);
            }

            debug ("Will upload %s : %s", file_mimetype, local_file_path);

            Bytes buffer = new Bytes.take(file_data);
            Soup.Multipart multipart = new Soup.Multipart("multipart/form-data");
            multipart.append_form_file ("file", upload_file.get_path (), file_mimetype, buffer);
            // multipart.append_form_string ("ref", Soup.URI.encode(upload_file.get_basename ()), file_mimetype, buffer);

            WebCall call = new WebCall (endpoint, API_ENDPOINT + IMAGE + "/upload");
            call.set_multipart (multipart);
            call.add_header ("Origin", origin_dat);
            call.add_cookies (cookies);
            // Add stored cookie as header if using cookie auth
            string? cookie_header = get_stored_cookie_header ();
            if (cookie_header != null) {
                call.add_header ("Cookie", cookie_header);
            }
            call.perform_call ();

            if (call.response_code >= 200 && call.response_code < 300) {
                success = true;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data (call.response_str);
                var json_obj = parser.get_root ().get_object ();
                if (json_obj.has_member ("images")) {
                    var image_data = json_obj.get_array_member ("images");
                    foreach (var p in image_data.get_elements ()) {
                        var ip = p.get_object ();
                        if (ip.has_member ("url")) {
                            success = true;
                            file_url = ip.get_string_member ("url");
                        }
                    }
                }
            } catch (Error e) {
                warning ("Error parsing response: %s", e.message);
            }

            return success;
        }

        public bool create_post_simple (
            out string slug,
            out string id,
            string title,
            string html_body,
            bool publish = true,
            string cover_image_url = "",
            string[]? tags = null)
        {
            bool success = false;
            slug = "";
            id = "";

            // One day I'll learn how JSON serialization in vala works
            Json.Builder builder = new Json.Builder ();
            builder.begin_object ();
            builder.set_member_name ("posts");
            builder.begin_array ();
            builder.begin_object ();
            builder.set_member_name ("title");
            builder.add_string_value (title);
            builder.set_member_name ("html");
            builder.add_string_value (html_body);
            if (cover_image_url != "") {
                builder.set_member_name ("feature_image");
                builder.add_string_value (cover_image_url);
            }
            builder.set_member_name ("status");
            if (publish) {
                builder.add_string_value ("published");
            } else {
                builder.add_string_value ("draft");
            }
            if (tags != null && tags.length > 0) {
                builder.set_member_name ("tags");
                builder.begin_array ();
                foreach (var tag in tags) {
                    builder.add_string_value (tag);
                }
                builder.end_array ();

            }
            builder.end_object ();
            builder.end_array ();
            builder.end_object ();

            Json.Generator generate = new Json.Generator ();
            generate.pretty = true;
            Json.Node root = builder.get_root ();
            generate.set_root (root);
            string request_body = generate.to_data (null);

            WebCall call = new WebCall (endpoint, API_ENDPOINT + POST + "/?source=html");
            call.set_post ();
            call.add_header ("Origin", origin_dat);
            call.add_cookies (cookies);
            string? cookie_header = get_stored_cookie_header ();
            if (cookie_header != null) {
                call.add_header ("Cookie", cookie_header);
            }
            call.set_body (request_body);
            call.perform_call ();

            if (call.response_code >= 200 && call.response_code < 300) {
                success = true;
            }

            try {
                var parser = new Json.Parser ();
                parser.load_from_data (call.response_str);
                var json_obj = parser.get_root ().get_object ();
                if (json_obj.has_member ("posts")) {
                    var posts_data = json_obj.get_array_member ("posts");
                    foreach (var p in posts_data.get_elements ()) {
                        success = true;
                        var ip = p.get_object ();
                        if (ip.has_member ("slug")) {
                            slug = ip.get_string_member ("slug");
                        }

                        if (ip.has_member ("id")) {
                            id = ip.get_string_member ("id");
                        }
                    }
                }
            } catch (Error e) {
                warning ("Error parsing response: %s", e.message);
            }

            return success;
        }
    }

    private class WebCall {
        private Soup.Session session;
        private Soup.Message message;
        private string url;
        private string body;
        private bool is_mime = false;

        public string response_str;
        public uint response_code;

        public WebCall (string endpoint, string api) {
            url = endpoint + api;
            session = new Soup.Session ();
            body = "";
        }

        public void set_body (string data) {
            body = data;
        }

        public void set_multipart (Soup.Multipart multipart) {
            message = new Soup.Message.from_multipart (url, multipart);
            is_mime = true;
        }

        public void set_get () {
            message = new Soup.Message ("GET", url);
        }
        
        public void set_put () {
            message = new Soup.Message ("PUT", url);
        }

        public void set_delete () {
            message = new Soup.Message ("DELETE", url);
        }

        public void set_post () {
            message = new Soup.Message ("POST", url);
        }

        public void add_header (string key, string value) {
            message.request_headers.append (key, value);
        }

        private void add_default_headers () {
            add_header ("Accept-Version", API_VERSION);
        }

        public void add_cookies (SList<Soup.Cookie> cookies) {
            Soup.cookies_to_request (cookies, message);
        }

        public bool perform_call () {
            bool success = false;

            if (message == null) {
                return false;
            }

            add_default_headers ();

            if (body != "") {
                Bytes body_bytes = new Bytes.static (body.data);
                message.set_request_body_from_bytes ("application/json", body_bytes);
            } else {
                if (!is_mime) {
                    add_header ("Content-Type", "application/json");
                } else {
                    add_header ("Content-Type", Soup.FORM_MIME_TYPE_MULTIPART);
                }
            }

            MainLoop loop = new MainLoop ();

            session.send_and_read_async.begin (message, 0, null, (obj, res) => {
                try {
                    var response = session.send_and_read_async.end (res);
                    response_str = response != null ? (string)response.get_data () : "";
                    response_code = message.status_code;

                    if (response_str != null && response_str != "") {
                        debug ("Non-empty body");
                    }

                    if (response_code >= 200 && response_code <= 250) {
                        success = true;
                        debug ("Success HTTP code");
                    }
                } catch (Error e) {
                    warning ("Error sending request: %s", e.message);
                }
                loop.quit ();
            });

            loop.run ();
            return success;
        }
    }
}