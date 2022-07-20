FROM ubuntu:22.04 AS base

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    gcc-riscv64-linux-gnu \
    libboost-filesystem1.74.0 \
    libboost-iostreams1.74.0 \
    libboost-program-options1.74.0 \
    libboost-thread1.74.0 \
    libftdi1 \
    libpython3.10 \
    libssl-dev \
    make \
    python3-pip \
    python3.10 \
    wget \
    && rm -rf /var/lib/apt/lists/*

FROM base AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    bison \
    build-essential \
    clang \
    cmake \
    flex \
    git \
    libboost-filesystem1.74-dev \
    libboost-iostreams1.74-dev \
    libboost-program-options1.74-dev \
    libboost-thread1.74-dev \
    libeigen3-dev \
    libftdi-dev \
    pkg-config \
    python3.10-dev

RUN git clone https://github.com/YosysHQ/yosys.git \
    && cd yosys \
    && echo >>Makefile.conf "ENABLE_TCL := 0" \
    && echo >>Makefile.conf "ENABLE_GLOB := 0" \
    && echo >>Makefile.conf "ENABLE_PLUGINS := 0" \
    && echo >>Makefile.conf "ENABLE_READLINE := 0" \
    && echo >>Makefile.conf "ENABLE_COVER := 0" \
    && echo >>Makefile.conf "ENABLE_ZLIB := 0" \
    && make -j$(nproc) \
    && make install

FROM base

RUN wget https://download.racket-lang.org/installers/8.5/racket-8.5-x86_64-linux-cs.sh \
    && sh racket-8.5-x86_64-linux-cs.sh --create-dir --unix-style --dest /usr/ \
    && rm racket-8.5-x86_64-linux-cs.sh

RUN raco pkg install --no-docs --batch --auto https://github.com/anishathalye/rtlv.git

RUN pip3 install bin2coe

COPY --from=build /usr/local/bin/* /usr/local/bin/
COPY --from=build /usr/local/share/yosys/ /usr/local/share/yosys/

WORKDIR /
