public class HelloGhost {
    public static int main (string[] args) {
        string user = "user@domain.com";
        string password = "password";
        string endpoint = "https://my-blog.ghost";

        Ghost.Client client = new Ghost.Client (endpoint, user, password);
        string id;
        string slug;
        client.authenticate ();

        // Check if 2FA is needed (basic check - see hello-ghost-2fa.vala for full example)
        if (client.requires_2fa) {
            print ("2FA required! Please check your email and run the 2FA example.\n");
            return 1;
        }

        string file_url;
        if (client.upload_image_simple (
            out file_url,
            "/home/kmwallio/Pictures/bread.jpeg"))
        {
            print ("\n\n** New image at %s\n\n", file_url);
        }

        if (client.create_post_simple(
            out slug,
            out id,
            "Hello world",
            "<p>Hello ghost</p><img src='%s' />".printf (file_url),
            false,
            file_url,
            {"Sample", "Post"}))
        {
            print ("\n\n** New post at %s/%s\n\n", endpoint, slug);
        }


        return 0;
    }
}