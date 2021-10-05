#!/bin/bash

cb=$1

if [[ -z $2 ]]; then
    f_=$(egrep -l PATCHED $cb/src/$cb/src/*.c | perl -p -e's/.*\///g')
else
    f_=( $2 )
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


mkdir -p xform
if (( $(egrep -c 'fix_repair' $cb/src/$cb/src/$f)>0 )); then
    cp $CGC_CB_DIR/challenges/$cb/src/$f $cb/src/$cb/src/$f
fi

cp $cb/src/$cb/src/$f xform/$f
$CODE_EXPAND -n xform/$f -f xform/t_$f -p $cb.json
res=$?

if [[ $res != 0 ]]; then
    echo "$CODE_EXPAND FAILED!"
    echo "[command] $CODE_EXPAND -n xform/$f -f xform/t_$f -p $cb.json"
    echo "Exiting."
    exit -1
fi

cp xform/t_$f $cb/src/$cb/src/$f
pushd $cb/build
make
popd

cp $cb/build/$cb/$x.i preprocessed/src/$cb/src/$f
}


for f in ${f_[*]}; do
    expand $f
done
