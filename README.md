# ghost-vala

Unofficial [Ghost](https://ghost.org/) API client library for Vala. Still a work in progress.

This is a simple API for publishing from [ThiefMD](https://thiefmd.com), and will hopefully become fully compatible with time.

**Now with 2FA support!** The library automatically detects when two-factor authentication is required and provides methods to complete the verification process.

**Current API Version:** Ghost Admin API v5.0

## Compilation

I recommend including `ghost-vala` as a git submodule and adding `ghost-vala/src/Ghost.vala` to your sources list. This will avoid packaging conflicts and remote build system issues until I learn a better way to suggest this.

For libsoup3, use `ghost-vala/src/Ghost3.vala`.

### Requirements

```
meson
ninja-build
valac
libgtk-3-dev
```

### Building

```bash
meson build
cd build
meson configure -Denable_examples=true
ninja
./examples/hello-ghost
```

Examples require update to username and password, don't check this in

```
string user = "username";
string password = "password";
```

# Quick Start

## Authentication

```vala
Ghost.Client client = Client (url, username, password);
if (client.authenticate ()) {
    print ("You logged in!");
}
```

## Two-Factor Authentication (2FA)

If your Ghost site has 2FA enabled, the library automatically detects it and provides the verification flow:

```vala
Ghost.Client client = Client (url, username, password);
client.authenticate ();

if (client.requires_2fa) {
    print ("2FA required! Check your email for the code.\n");
    
    // Get the verification code from user input
    string auth_code = get_verification_code_from_user ();
    
    if (client.verify_session (auth_code)) {
        print ("Successfully verified! You're now logged in.\n");
    } else {
        print ("Verification failed.\n");
    }
}
```

You can also resend the verification code if needed:

```vala
if (client.requires_2fa) {
    if (client.resend_verification ()) {
        print ("Verification code resent to your email.\n");
    }
}
```

See `examples/hello-ghost-2fa.vala` for a complete interactive example.

## Simple Post

```vala
Ghost.Client client = Client (url, username, password);

string id;
string slug;
if (client.create_post_simple (out slug,
    out id,
    "Hello world",
    "<p>Hello ghost</p>"))
{
    print ("New post at %s/%s", url, slug);
}
```

## Simple Image Upload

```vala
Ghost.Client client = Client (url, username, password);

string id;
string slug;
if (client.upload_image_simple (
    out file_url,
    "/home/user/Pictures/photo.jpeg"))
{
    print ("New image at %s", file_url);
}
```