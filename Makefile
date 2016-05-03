default: all

configure:
	oasis setup
	ocaml setup.ml -configure

build:
	ocaml setup.ml -build

all:
	ocaml setup.ml -all

clean:
	ocaml setup.ml -clean

install:
	ocaml setup.ml -install

uninstall:
	ocaml setup.ml -uninstall

reinstall:
	ocaml setup.ml -reinstall

.PHONY: build all build default install uninstall
