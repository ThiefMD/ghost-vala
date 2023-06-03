# ghost-vala

Unofficial [Ghost](https://ghost.org/) API client library for Vala. Still a work in progress.

This is a simple API for publishing from [ThiefMD](https://thiefmd.com), and will hopefully become fully compatible with time.

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