public class HelloGhost {
    public static int main (string[] args) {
        string user = "user@domain.com";
        string password = "password";
        string endpoint = "https://my-blog.ghost";

        Ghost.Client client = new Ghost.Client (endpoint, user, password);
        string id;
        string slug;
        client.authenticate ();

        if (client.create_post_simple(
            out slug,
            out id,
            "Hello world",
            "<p>Hello ghost</p>"))
        {
            print ("\n\n** New post at %s/%s\n\n", endpoint, slug);
        }


        return 0;
    }
}