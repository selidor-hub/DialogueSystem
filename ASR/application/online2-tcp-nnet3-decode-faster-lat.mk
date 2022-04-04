all:

include ../kaldi.mk

LDFLAGS += $(CUDA_LDFLAGS)
LDLIBS += $(CUDA_LDLIBS)

OBJFILES = 

BINFILES = online2-tcp-nnet3-decode-faster-lat

TESTFILES =

ADDLIBS = VADNnet.so TcpServer.so LatticeOutputLayer.so QuestionFinder.so \
		  ../online2/kaldi-online2.a ../ivector/kaldi-ivector.a \
          ../nnet3/kaldi-nnet3.a ../chain/kaldi-chain.a ../nnet2/kaldi-nnet2.a \
          ../cudamatrix/kaldi-cudamatrix.a ../decoder/kaldi-decoder.a \
          ../lat/kaldi-lat.a ../fstext/kaldi-fstext.a ../hmm/kaldi-hmm.a \
          ../feat/kaldi-feat.a ../transform/kaldi-transform.a \
          ../gmm/kaldi-gmm.a ../tree/kaldi-tree.a ../util/kaldi-util.a \
          ../matrix/kaldi-matrix.a ../base/kaldi-base.a /usr/lib/x86_64-linux-gnu/boost_system.so \
          /usr/lib/x86_64-linux-gnu/boost_filesystem.so /usr/lib/x86_64-linux-gnu/boost_thread.so \
           /usr/lib/x86_64-linux-gnu/ssl.so /usr/lib/x86_64-linux-gnu/crypto.so
          
include ../makefiles/default_rules.mk