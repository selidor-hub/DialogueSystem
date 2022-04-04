
all:

EXTRA_CXXFLAGS = -Wno-sign-compare
include ../kaldi.mk

LDFLAGS += $(CUDA_LDFLAGS)
LDLIBS += $(CUDA_LDLIBS)

BINFILES = testLatticeConsummerTxtFst

OBJFILES =

TESTFILES = 

ADDLIBS = /usr/src/googletest/googletest/gtest.a LatticeOutputLayer.so \
			../fstext/kaldi-fstext.a ../lat/kaldi-lat.a \
          ../util/kaldi-util.a ../base/kaldi-base.a /usr/lib/x86_64-linux-gnu/boost_system.so \
          /usr/lib/x86_64-linux-gnu/boost_filesystem.so

include ../makefiles/default_rules.mk
