#!/bin/bash

cb=$1

trnsrc=$2

json_file=$3

file=$4

SRC_DIR=$CGC_CB_DIR/challenges/$cb

if [[ -z $file ]]; then
    f_=$(egrep -l PATCHED $SRC_DIR/src/*.c | perl -p -e's/.*\///g')
else
    f_=( $file )
fi

[[ ! -d $trnsrc ]] && mkdir -p $trnsrc
if [[ ! -d $trnsrc/$cb ]]; then 
    echo "Initializing: cp -r $CGC_CB_DIR/challenges/$cb $trnsrc/i.$cb"; 
    cp -r $CGC_CB_DIR/challenges/$cb $trnsrc/i.$cb
fi

expand() {
local f=$1

x=$(echo $f | perl -p -e's/\..*//')
echo "$x - $f"

CODE_EXPAND=/mnt/Data/tools/code_rewrite/code_expand.py
#CODE_EXPAND=/mnt/Data/tools/code_rewrite.stable/code_expand.py

if [[ ! -d $cb ]]; then
    echo "ERROR: It does not look like you're in a GenProg run directory for $cb"
    echo "Check cb name and try again."
    echo "Exiting."
    exit -1
fi

if [[ ! -e $cb/src/$cb/src/$f ]]; then 
    echo "ERROR: It does not look like $f exists in $cb/src/$cb/src/"
    echo "Check file name and try again."
    echo "Exiting."
    exit -1
fi

if [[ ! -e $CODE_EXPAND ]]; then 
    echo "ERROR: It does not look like $CODE_EXPAND exists!"
    echo "Check and try again."
    echo "Exiting."
    exit -1
fi


#mkdir -p xform
#if (( $(egrep -c 'fix_repair' $cb/src/$cb/src/$f)>0 )); then
#    cp $SRC_DIR/src/$f $cb/src/$cb/src/$f
#fi
#cp $cb/src/$cb/src/$f xform/$f
(time $CODE_EXPAND -n xform/$f -f xform/t_$f -p $json_file) &> xform.$x.log
res=$?

if [[ $res != 0 ]]; then
    echo "$CODE_EXPAND FAILED!"
    echo "[command] $CODE_EXPAND -n xform/$f -f xform/t_$f -p $json_file"
    echo "Exiting."
    exit -1
fi

cp xform/t_$f $cb/src/$cb/src/$f
pushd $cb/build
make &> ../make.transform.$x.log
ret=$?
popd

if (( $ret==0 )); then
echo "[$cb] $f transform | PASSED recompilation"
cp xform/t_$f $trnsrc/i.$cb/src/$f
else
echo "[$cb] $f transform | FAILED recompilation"
cp xform/t_$f $trnsrc/i.$cb/src/$f.failed
cp $SRC_DIR/src/$f $cb/src/$cb/src/$f
fi
cp $cb/build/$cb/$x.i preprocessed/src/$cb/src/$f
cp $cb/build/$cb/$x.i $trnsrc/i.$cb/src/$x.i
}


for f in ${f_[*]}; do
  mkdir -p xform
  cp $SRC_DIR/src/$f xform/$f
  #if (( $TRANSFORMED==0 )); then 
  if [[ ! -d $trnsrc/$cb ]]; then 
    echo "Expanding $f [$x]"
    expand $f
  else
    x=$(echo $f | perl -p -e's/\..*//')
    if [[ -e $trnsrc/$cb/src/$f.failed ]]; then 
       echo "[$cb] $f transform | FAILED recompilation (existing)";
       cp $trnsrc/$cb/src/$f.failed xform/t_$f
    else
       echo "[$cb] $f transform | PASSED recompilation (existing)";
       cp $trnsrc/$cb/src/$f xform/t_$f
       cp $trnsrc/$cb/src/$f $cb/src/$cb/src/$f
    fi
    [[ -e $trnsrc/$cb/src/$x.i ]] && cp $trnsrc/$cb/src/$x.i preprocessed/src/$cb/src/$f
  fi
done
[[ -d $trnsrc/i.$cb ]] && mv $trnsrc/i.$cb $trnsrc/$cb
