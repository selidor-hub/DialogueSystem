OCAMLC=ocamlc
OCAMLOPT=ocamlopt
OCAMLDEP=ocamldep
INCLUDES=-I +xml-light -I +xlib -I +zip -I +bz2 -I +eniam -I +qlib
OCAMLFLAGS=$(INCLUDES) -g
OCAMLOPTFLAGS=$(INCLUDES) unix.cmxa xml-light.cmxa str.cmxa nums.cmxa zip.cmxa bz2.cmxa xlib.cmxa eniam-fuzzyAnalyzer.cmxa eniam-morphology.cmxa eniam-subsyntax.cmxa eniam-lcg-parser.cmxa \
	eniam-lcg-lexicon.cmxa \
	eniam-valence.cmxa eniam-semantics.cmxa eniam-exec.cmxa #qlib.cmxa
INSTALLDIR=`ocamlc -where`/eniam

SOURCES= latTypes.ml latLoader.ml latStats.ml latSubsyntax.ml kratoczyt.ml
SOURCES2= testAnalyzer.ml

all: $(SOURCES)
	$(OCAMLOPT) -o kratoczyt $(OCAMLOPTFLAGS) $(SOURCES)

test_analyzer: $(SOURCES2)
	$(OCAMLOPT) -o test_analyzer $(OCAMLOPTFLAGS) $(SOURCES2)

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
	rm -f *~ *.cm[aoix] *.o *.so *.cmxa *.a kratoczyt test_analyzer
