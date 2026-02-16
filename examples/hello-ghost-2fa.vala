public class HelloGhost2FA {
    public static int main (string[] args) {
        string user = "user@domain.com";
        string password = "password";
        string endpoint = "https://my-blog.ghost";

        Ghost.Client client = new Ghost.Client (endpoint, user, password);
        
        // Try to authenticate - might require 2FA
        client.authenticate ();

        // Check if 2FA is required
        if (client.requires_2fa) {
            print ("2FA is required! Please check your email for the verification code.\n");
            
            // In a real app, you'd get this from user input
            print ("Enter verification code: ");
            string? auth_code = stdin.read_line ();
            
            if (auth_code != null && auth_code.length > 0) {
                if (client.verify_session (auth_code)) {
                    print ("Successfully verified! You're now logged in.\n");
                } else {
                    print ("Verification failed. Try again or resend the code.\n");
                    
                    // Example: resend the code
                    // if (client.resend_verification ()) {
                    //     print ("Verification code resent!\n");
                    // }
                    return 1;
                }
            } else {
                print ("No verification code provided.\n");
                return 1;
            }
        }

        // Now we're authenticated, we can use the API
        string id;
        string slug;
        
        // Create a simple post
        if (client.create_post_simple(
            out slug,
            out id,
            "Hello from 2FA example",
            "<p>Successfully logged in with 2FA!</p>",
            false,
            "",
            {"2FA", "Example"}))
        {
            print ("\n** New post created at %s/%s\n", endpoint, slug);
        } else {
            print ("Failed to create post\n");
        }

        return 0;
    }
}
