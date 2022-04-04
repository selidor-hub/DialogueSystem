
all:

include ../kaldi.mk

LDFLAGS += $(CUDA_LDFLAGS)
LDLIBS += $(CUDA_LDLIBS)

OBJFILES = TcpServer.o

#BINFILES = online2-tcp-nnet3-decode-faster-lat
LIBNAME = TcpServer

TESTFILES =

ADDLIBS =  ../feat/kaldi-feat.a ../transform/kaldi-transform.a \
          ../gmm/kaldi-gmm.a ../tree/kaldi-tree.a ../util/kaldi-util.a \
          ../matrix/kaldi-matrix.a ../util/kaldi-util.a \
           ../base/kaldi-base.a 
          
include ../makefiles/default_rules.mk