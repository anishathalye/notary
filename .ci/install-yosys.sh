#!/usr/bin/env bash

cd ~
git clone https://github.com/YosysHQ/yosys
cd yosys
cat >Makefile.conf <<EOF
ENABLE_TCL := 0
ENABLE_ABC := 0
ENABLE_GLOB := 0
ENABLE_PLUGINS := 0
ENABLE_READLINE := 0
ENABLE_COVER := 0
ENABLE_ZLIB := 0
EOF
make -j$(nproc)
