#!/usr/bin/env bash

cd ~
git clone https://github.com/greghendershott/travis-racket.git
export RACKET_DIR=~/racket
export RACKET_VERSION=RELEASE
bash travis-racket/install-racket.sh
