#!/bin/sh

sudo apt-get install uuid-dev

GITV="git://github.com/jedisct1/libsodium.git -b 0.4.5"

git clone --depth 1 $GITV libsodium && cd libsodium

./autogen.sh
./configure
make

sudo make install
sudo /sbin/ldconfig
