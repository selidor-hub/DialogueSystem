all:

include ../kaldi.mk

LDFLAGS += $(CUDA_LDFLAGS)
LDLIBS += $(CUDA_LDLIBS)

OBJFILES =  VADNnet.o  VADEventObserver.o

LIBNAME = VADNnet

ADDLIBS = ../nnet3/kaldi-nnet3.a ../chain/kaldi-chain.a ../nnet2/kaldi-nnet2.a \
          ../cudamatrix/kaldi-cudamatrix.a ../decoder/kaldi-decoder.a \
          ../fstext/kaldi-fstext.a \
          ../feat/kaldi-feat.a ../transform/kaldi-transform.a \
          ../util/kaldi-util.a \
          ../matrix/kaldi-matrix.a ../base/kaldi-base.a 
          
include ../makefiles/default_rules.mk