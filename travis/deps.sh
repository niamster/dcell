#!/bin/sh

wd=$PWD
tmp=$wd/tmp

for dep in $wd/travis/deps/*.sh; do
    mkdir -p $tmp
    cd $tmp
    sh $dep
    rm -rf $tmp
done
