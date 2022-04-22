OCAMLC=ocamlc
OCAMLOPT=ocamlopt
OCAMLDEP=ocamldep
INCLUDES=-I +xml-light -I +xlib -I +zip -I +bz2 -I +eniam
OCAMLFLAGS=$(INCLUDES) -g
OCAMLOPTFLAGS=$(INCLUDES) unix.cmxa xml-light.cmxa str.cmxa nums.cmxa zip.cmxa bz2.cmxa xlib.cmxa  eniam-morphology.cmxa eniam-subsyntax.cmxa
INSTALLDIR=`ocamlc -where`/eniam

SOURCES= czytacz.ml
SOURCES2= czytacz2.ml
SOURCES3= czytacz3.ml

all: czytacz czytacz2 czytacz3

czytacz: $(SOURCES)
	$(OCAMLOPT) -o czytacz $(OCAMLOPTFLAGS) $(SOURCES)

czytacz2: $(SOURCES2)
	$(OCAMLOPT) -o czytacz2 $(OCAMLOPTFLAGS) $(SOURCES2)

czytacz3: $(SOURCES3)
	$(OCAMLOPT) -o czytacz3 $(OCAMLOPTFLAGS) $(SOURCES3)

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
	rm -f *~ *.cm[aoix] *.o *.so *.cmxa *.a czytacz czytacz2 czytacz3
