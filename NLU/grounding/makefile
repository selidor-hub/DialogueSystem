OCAMLC=ocamlc
OCAMLOPT=ocamlopt
OCAMLDEP=ocamldep
INCLUDES=-I +xml-light -I +xlib -I +zip -I +bz2 -I +eniam
OCAMLFLAGS=$(INCLUDES) -g
OCAMLOPTFLAGS=$(INCLUDES) unix.cmxa xml-light.cmxa str.cmxa nums.cmxa zip.cmxa bz2.cmxa xlib.cmxa eniam-morphology.cmxa eniam-subsyntax.cmxa eniam-lcg-parser.cmxa \
	eniam-lcg-lexicon.cmxa \
	eniam-valence.cmxa eniam-semantics.cmxa eniam-exec.cmxa
INSTALLDIR=`ocamlc -where`/eniam

SOURCES= beautyLoader.ml
SOURCES2= serviceGrounder.ml
SOURCES3= corpusAnalyzer.ml
SOURCES4= categoryGrounder.ml
SOURCES5= interval.mli interval.ml timeGrounderTypes.ml timePreprocessing.ml dateGrounder.ml hourGrounder.ml preferenceGrounder.ml timeGrounder.ml

all: $(SOURCES) $(SOURCES2) $(SOURCES3) $(SOURCES4) time_grounder
	$(OCAMLOPT) -o beauty_loader $(OCAMLOPTFLAGS) $(SOURCES)
	$(OCAMLOPT) -o service_grounder $(OCAMLOPTFLAGS) $(SOURCES2)
	$(OCAMLOPT) -o corpus_analyzer $(OCAMLOPTFLAGS) $(SOURCES3)
	$(OCAMLOPT) -o category_grounder $(OCAMLOPTFLAGS) $(SOURCES4)
	
time_grounder: $(SOURCES5)
	$(OCAMLOPT) -o time_grounder $(OCAMLOPTFLAGS) $(SOURCES5)

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
	rm -f *~ *.cm[aoix] *.o *.so *.cmxa *.a beauty_loader service_grounder corpus_analyzer time_grounder
