#!/bin/sh

GITV="git://github.com/zeromq/zeromq4-x.git -b v4.0.5"

git clone --depth 1 $GITV zmqlib && cd zmqlib

./autogen.sh
./configure
make

sudo make install
sudo /sbin/ldconfig
