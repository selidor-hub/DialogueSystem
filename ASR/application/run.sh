#!/bin/bash

if [ $# -lt 1 ]
then
   echo "Too few arguments"
   echo "Usage:"
   echo "./run.sh MODEL_PATH [optional: --output-files-prefix=]"
   echo ""
   echo "--output-files-prefix= (default=\"\") Prefix of optional output files (best path, lattice, response from client). Define to get files."
   exit 1
fi

if [ ! -d "$1" ]; then
   echo "$1 does not exist."
   exit 1
fi

cd /opt/kaldi/src/asr/
model=$1


if [ $# -eq 2 ]
then
   echo "Running app with model " $model " and option " $2 
   ./online2-tcp-nnet3-decode-faster-lat --read-timeout=-1 --samp-freq=16000 --frames-per-chunk=20 --extra-left-context-initial=0 --frame-subsampling-factor=3 --config=$model/conf/online.conf --min-active=200 --max-active=7000 --beam=15 --lattice-beam=8 --acoustic-scale=1.0 $2 $model/final.mdl $model/HCLG.fst $model/words.txt $model/word_boundary.int
else
   echo "Running app with model " $model 
   ./online2-tcp-nnet3-decode-faster-lat --read-timeout=-1 --samp-freq=16000 --frames-per-chunk=20 --extra-left-context-initial=0 --frame-subsampling-factor=3 --config=$model/conf/online.conf --min-active=200 --max-active=7000 --beam=15 --lattice-beam=8 --acoustic-scale=1.0 $model/final.mdl $model/HCLG.fst $model/words.txt $model/word_boundary.int
fi
cd -
