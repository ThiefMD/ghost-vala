# ghost-vala

Unofficial [Ghost](https://ghost.org/) API client library for Vala. Still a work in progress.

## Compilation

I recommend including `ghost-vala` as a git submodule and adding `ghost-vala/src/Ghost.vala` to your sources list. This will avoid packaging conflicts and remote build system issues until I learn a better way to suggest this.

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

