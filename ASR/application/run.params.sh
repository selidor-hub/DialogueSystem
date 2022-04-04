#!/bin/bash

if [ $# -lt 1 ]
then
   echo "Too few arguments"
   echo "Usage:"
   echo "./run.sh [optional: --output-files-prefix=] [parameter] ..."
   echo ""
   echo "--output-files-prefix= (default=\"\") Prefix of optional output files (best path, lattice, response from client). It can by dir path and file name prefix. Define it to get files."
   exit 1
fi

cd /opt/kaldi/src/asr/
model=/data/default/


if [ $# -gt 0 ]
then
   echo "Running app with optios " $* 
   ./online2-tcp-nnet3-decode-faster-lat --read-timeout=-1 --samp-freq=16000 --frames-per-chunk=20 --extra-left-context-initial=0 --frame-subsampling-factor=3 --config=$model/conf/online.conf --min-active=200 --max-active=7000 --beam=15 --lattice-beam=8 --acoustic-scale=1.00 $* $model/final.mdl $model/HCLG.fst $model/words.txt $model/word_boundary.int
fi
cd -
