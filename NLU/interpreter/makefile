OCAMLC=ocamlc
OCAMLOPT=ocamlopt
OCAMLDEP=ocamldep
INCLUDES=-I +xml-light -I +xlib -I +zip -I +bz2 -I +eniam -I +qlib -I +roke
OCAMLFLAGS=$(INCLUDES) -g
OCAMLOPTFLAGS=$(INCLUDES) unix.cmxa xml-light.cmxa str.cmxa nums.cmxa zip.cmxa bz2.cmxa xlib.cmxa eniam-morphology.cmxa eniam-subsyntax.cmxa eniam-lcg-parser.cmxa eniam-lcg-lexicon.cmxa eniam-valence.cmxa eniam-semantics.cmxa #qlib.cmxa
INSTALLDIR=`ocamlc -where`/roke

SOURCES= interpreter.ml

all: interpreter.cma interpreter.cmxa

install: all
	mkdir -p $(INSTALLDIR)
	cp interpreter.cmxa interpreter.a interpreter.cma $(INSTALLDIR)
	cp interpreter.cmi $(INSTALLDIR)
	cp interpreter.cmx $(INSTALLDIR)

interpreter.cma: $(SOURCES)
	ocamlc -linkall -a -o interpreter.cma $(OCAMLFLAGS) $^

interpreter.cmxa: $(SOURCES)
	ocamlopt -linkall -a -o interpreter.cmxa $(INCLUDES) $^

test: $(SOURCES) test.ml
	$(OCAMLOPT) -o test $(OCAMLOPTFLAGS) $(SOURCES) test.ml

.SUFFIXES: .mll .mly .ml .mli .cmo .cmi .cmx

.mll.ml:
	ocamllex $<

.mly.mli:
	ocamlyacc $<

.mly.ml:
	ocamlyacc $<

.ml.cmo:
	$(OCAMLC) $(OCAMLFLAGS) -c $<

.mli.cmi:
	$(OCAMLC) $(OCAMLFALGS) -c $<

.ml.cmx:
	$(OCAMLOPT) $(OCAMLOPTFLAGS) -c $<

clean:
	rm -f *~ *.cm[aoix] *.o *.so *.cmxa *.a test
