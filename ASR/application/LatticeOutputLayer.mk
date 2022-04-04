
all:

include ../kaldi.mk

LDFLAGS += $(CUDA_LDFLAGS)
LDLIBS += $(CUDA_LDLIBS)

OBJFILES = LatticeConsummerTxtFST.o OutputDataCreator.o LatticeConsummerDecorator.o HTTPSOutputLayer.o HTTPOutputLayer.o LatticeConverter.o

LIBNAME = LatticeOutputLayer

TESTFILES =

ADDLIBS = ../fstext/kaldi-fstext.a ../util/kaldi-util.a \
          ../matrix/kaldi-matrix.a ../util/kaldi-util.a \
           ../base/kaldi-base.a /usr/lib/x86_64-linux-gnu/boost_system.so /usr/lib/x86_64-linux-gnu/boost_thread.so
          
include ../makefiles/default_rules.mk