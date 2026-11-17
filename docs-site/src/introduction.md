# Radius Based Network Authentication Simulator Handbook

Welcome to the handbook for the **Radius Based Network Authentication Simulator**,
a RADIUS server and NAS client simulator built on the open-source
[ToughRADIUS](https://github.com/talkincode/toughradius) project. It is built with
[mdBook](https://rust-lang.github.io/mdBook/) and lives in the repository under
`docs-site/`, so the documentation is versioned together with the code it describes.

Start with the [Overview](./en/overview.md).

## Build it locally

```bash
# Install mdBook (https://rust-lang.github.io/mdBook/guide/installation.html)
cargo install mdbook            # or: brew install mdbook

# Build the static site into docs-site/book/
mdbook build docs-site

# Or serve with live reload at http://localhost:3000
mdbook serve docs-site
```
