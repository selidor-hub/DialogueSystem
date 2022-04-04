all:

include ../kaldi.mk

LDFLAGS += $(CUDA_LDFLAGS)
LDLIBS += $(CUDA_LDLIBS)

OBJFILES = QuestionFinder.o

#BINFILES = online2-tcp-nnet3-decode-faster-lat
LIBNAME = QuestionFinder

TESTFILES =

ADDLIBS =  ../cudamatrix/kaldi-cudamatrix.a \
          ../lat/kaldi-lat.a ../fstext/kaldi-fstext.a \
          ../transform/kaldi-transform.a \
           ../util/kaldi-util.a \
          ../base/kaldi-base.a /usr/lib/x86_64-linux-gnu/boost_system.so \
          /usr/lib/x86_64-linux-gnu/boost_filesystem.so /usr/lib/x86_64-linux-gnu/boost_thread.so
          
include ../makefiles/default_rules.mk