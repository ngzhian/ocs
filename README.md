# OCS

Simple static blog generator

## Features

- Generates static HTML pages from markdown
- Fast
- OCaml code that's easy to read for learning

## Usage

```
$ ocaml setup.ml -configure
$ ocaml setup.ml -build
$ ocaml setup.ml -install
```

Your markdown files should be in a directory.
Template files are in a folder called `template`.
There are two template files right now:

- `index.html`
- `post.html`

In the directory, run ocs:

```
$ ocs
```

By default all the html files will be generated in the same directory.
This entire directory can then be uploaded GitHub pages.
