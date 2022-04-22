OCAMLC=ocamlc
OCAMLOPT=ocamlopt
OCAMLDEP=ocamldep
INCLUDES=-I +xml-light -I +xlib -I +zip -I +bz2 -I +eniam
OCAMLFLAGS=$(INCLUDES) -g
OCAMLOPTFLAGS=$(INCLUDES) unix.cmxa xml-light.cmxa str.cmxa nums.cmxa zip.cmxa bz2.cmxa xlib.cmxa eniam-morphology.cmxa eniam-subsyntax.cmxa #eniam-lcg-parser.cmxa \
	eniam-lcg-lexicon.cmxa \
	eniam-valence.cmxa eniam-semantics.cmxa eniam-exec.cmxa
INSTALLDIR=`ocamlc -where`/eniam

SOURCES= import.ml
SOURCES2= nameParser.ml

all: $(SOURCES) $(SOURCES2) 
	$(OCAMLOPT) -o import $(OCAMLOPTFLAGS) $(SOURCES)
	$(OCAMLOPT) -o name_parser $(OCAMLOPTFLAGS) $(SOURCES2)
	

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
	rm -f *~ *.cm[aoix] *.o *.so *.cmxa *.a import name_parser
