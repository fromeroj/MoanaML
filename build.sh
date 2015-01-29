#!/bin/bash

eval `opam config env`

#note: currently this only works with Irmin 0.8.3
ocamlbuild -r -use-ocamlfind -use-menhir -classic-display -package lwt,yojson,irmin,irmin.unix,oUnit -tag thread  tests.byte contacts.byte


./tests.byte
./contacts.byte
