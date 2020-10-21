namespace Ghost {
    public const string API_ENDPOINT = "api/v3/admin/";
    public const string POST = "posts";
    public const string IMAGE = "images";

    public class Client {
        public string endpoint;
        string username;
        private string? authenticated_user;

        public Client (string url, string user, string token) {
            if (url.has_suffix ("/")) {
                endpoint = url;
            } else {
                endpoint = url + "/";
            }

            username = user;
            authenticated_user = token;
        }

        private string generate_token () {
            string secret = authenticated_user.substring (authenticated_user.index_of (":") + 1);
            string id = authenticated_user.substring (0, authenticated_user.index_of (":"));
            string header = "{\"alg\": \"HS256\",\"typ\": \"JWT\", \"kid\": \"%s\"}".printf (id);
            DateTime now = new DateTime.now_utc ();
            DateTime in_5 = now.add_minutes (5);
            string payload = "{\"iat\":" + now.to_unix ().to_string () + ",\"exp\":" + in_5.to_unix ().to_string () + "\"aud\": \"/v3/admin/\"}";
            return JWT.Jwt.encode (header, payload, secret);
        }
    }

    private class WebCall {
        private Soup.Session session;
        private Soup.Message message;
        private string url;
        private string body;

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

        public bool perform_call () {
            bool success = false;
            debug ("Calling %s", url);

            if (body != "") {
                message.set_request ("application/json", Soup.MemoryUse.COPY, body.data);
            } else {
                add_header ("Content-Type", "application/json");
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