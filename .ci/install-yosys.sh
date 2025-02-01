#!/usr/bin/env bash

cd ~
git clone -b yosys-0.21 https://github.com/YosysHQ/yosys.git
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
