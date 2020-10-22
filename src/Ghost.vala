namespace Ghost {
    public const string API_ENDPOINT = "ghost/api/v3/admin/";
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

        public Client (string url, string user, string token) {
            if (url.has_suffix ("/")) {
                endpoint = url;
            } else {
                endpoint = url + "/";
            }

            username = user;
            authenticated_user = token;
            origin_dat = ORIGIN + user;
            cookies = new SList<Soup.Cookie> ();
        }

        public bool authenticate () {
            Soup.Session session = new Soup.Session ();
            Soup.Message msg = new Soup.Message ("POST", endpoint + API_ENDPOINT + "session/");
            msg.request_headers.append ("Origin", origin_dat);
            string login = "username=" + username + "&password=" + authenticated_user;
            msg.set_request ("application/x-www-form-urlencoded", Soup.MemoryUse.STATIC, login.data);
            session.send_message (msg);
            cookies = new SList<Soup.Cookie> ();

            if (msg.status_code >= 200 && msg.status_code < 300) {

                GLib.SList<Soup.Cookie> rec_cookies = Soup.cookies_from_response (msg);
                debug ("Got success from server");
                foreach (var cookie in rec_cookies) {
                    if (cookie.name == COOKIE) {
                        cookies.append (cookie);
                    }
                }
                debug ("Found : %u expected cookies", cookies.length ());
            }

            return (cookies.length () != 0);
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

            Soup.Buffer buffer = new Soup.Buffer.take(file_data);
            Soup.Multipart multipart = new Soup.Multipart("multipart/form-data");
            multipart.append_form_file ("file", upload_file.get_path (), file_mimetype, buffer);
            // multipart.append_form_string ("ref", Soup.URI.encode(upload_file.get_basename ()), file_mimetype, buffer);

            WebCall call = new WebCall (endpoint, API_ENDPOINT + IMAGE + "/upload");
            call.set_multipart (multipart);
            call.add_header ("Origin", origin_dat);
            call.add_cookies (cookies);
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
            string cover_image_url = "")
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

        public class WebCall (string endpoint, string api) {
            url = endpoint + api;
            session = new Soup.Session ();
            body = "";
        }

        public void set_body (string data) {
            body = data;
        }

        public void set_multipart (Soup.Multipart multipart) {
            message = Soup.Form.request_new_from_multipart (url, multipart);
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

        public void add_cookies (SList<Soup.Cookie> cookies) {
            Soup.cookies_to_request (cookies, message);
        }

        public bool perform_call () {
            bool success = false;

            if (body != "") {
                message.set_request ("application/json", Soup.MemoryUse.STATIC, body.data);
            } else {
                if (!is_mime) {
                    add_header ("Content-Type", "application/json");
                } else {
                    add_header ("Content-Type", Soup.FORM_MIME_TYPE_MULTIPART);
                }
            }

            session.send_message (message);
            response_str = (string) message.response_body.flatten ().data;
            response_code = message.status_code;

            if (response_str != null && response_str != "") {
                success = true;
                debug ("Non-empty body");
            }

            if (response_code >= 200 && response_code <= 250) {
                success = true;
                debug ("Success HTTP code");
            }

            return success;
        }
    }
}