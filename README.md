# Notary: A Device for Secure Transaction Approval [[![Build Status](https://travis-ci.com/anishathalye/notary.svg?branch=master)](https://travis-ci.com/anishathalye/notary)]

This repository contains the code for verifying deterministic start for
Notary's agent SoC. For more details, see our [SOSP paper][sosp] or
[talk][sosp-talk], or our [;login: article][login]. See the
[overview](#overview) below for a high-level description of deterministic start
and its application to reset-based switching.

Notary's agent SoC, for which we verify deterministic start, is made up of
mostly off-the-shelf Verilog, without modifications to simplify verification.
The Verilog, located in [`hw/`](hw/), uses the following third-party
open-source modules:

- [PicoRV32] CPU
- [simpleuart] from the [PicoSoC]
- [SPI Master]

## Use

To run the verification, run `make verify`. This will build the firmware,
transform the Verilog code describing the SoC into a format suitable for
symbolic simulation, and run the verification code. The output looks like this:

```console
$ make verify
...
cycle 0
  stepped in 117.4ms
cycle 1
  stepped in 3.4ms
cycle 2
  stepped in 39.9ms
cycle 3
  stepped in 2.8ms
...
cycle 180343
  smt query returned in 135ms
  -> sat!
    soc_m ram.ram
  stepped in 21.3ms
cycle 180344
  smt query returned in 112.7ms
  -> sat!
    soc_n cpu.mem_rdata_q
  stepped in 2.4ms
cycle 180345
  smt query returned in 120ms
  -> sat!
    soc_n cpu.mem_rdata_q
  stepped in 2.1ms
cycle 180346
  smt query returned in 115.2ms
  -> sat!
    soc_n cpu.mem_rdata_q
  stepped in 2.2ms
cycle 180347
  smt query returned in 108.1ms
  -> unsat!
finished in 509.1s
```

The verification script doesn't bother to check to see if the deterministic
start property has been satisfied in the earlier cycles --- it starts checking
from cycle 180340. When it finds components of state that have not been
provably reset, it points them out. When it has proven that all internal state
has been cleared no matter what the starting state was, it prints out "unsat"
and terminates.

If you're looking to experiment with the code, it's convenient to reduce the
size of the RAM (edit the parameter `RAM_ADDR_BITS` in [`hw/soc.v`](hw/soc.v)
to something like `8`), and then change the `#:try-verify-after` keyword
argument in [`verify.rkt`](verify.rkt) to `0`, so you can see the SMT output
from cycle 0. A neat thing to try is to break the deterministic start code by
editing [`fw/firmware.s`](fw/firmware.s), or try alternative strategies to
clear the state (e.g. xor a register with itself to clear it, instead of
loading a constant 0).

## Setup

If you don't want to install dependencies manually, you can use the provided
[Vagrant] configuration. Run `vagrant up` to provision a VM with all the
dependencies installed. Once you've done that, you can `vagrant ssh` into the
VM.

To run the verification script, run the following in the VM:

```console
$ cd /notary
$ make verify
````

### Dependencies

If you're running this on your own machine, you can install the following
dependencies manually:

- [RISC-V compiler toolchain]
- [Yosys]
- [Racket]
- [Rosette]
- [bin2coe]
- [rtl] --- our Yosys to Rosette compiler, and the core deterministic start verification implementation

## Overview

### Motivation

At a high level, our goal is to run process A and then run process B on a
single CPU without processes interfering with each other: process B should not
be able to steal process A's private data, and process A should not be able to
corrupt process B's execution. This is the classic non-interference property.
Achieving (and proving correct) non-interference is hard, so instead, let's use
a simple (but heavyweight) mechanism to achieve it that will make the mechanism
easy to implement and reason about.

We fully reset the system between task switches, ensuring that we reach a
"clean state" after executing process A, so that process B cannot steal A's
data and cannot be adversely affected by whatever A did on the system. If
resetting a system always restores it to a deterministic state (i.e.
independent of the state it was in beforehand), this implies our desired
non-interference property. And because we're considering the complete internal
state of the processor (not only architectural state but also
micro-architectural state), this also implies the absence of architectural and
micro-architectural side channels.

For more details on how deterministic start can be used as a component in
building secure systems, as applied to transaction authorization devices, see
[our paper][sosp].

### Reset

How do we know that reset actually resets? Reset is a non-trivial operation,
and asserting a processor's reset line does not necessarily clear all internal
state. The ISA specification is usually nondeterministic, and it says that that
certain (often much) architectural state is undefined after reset. The ISA's
reset specification does not talk about micro-architectural state at all,
because it does not exist at the architectural level, it's an implementation
detail.

Looking at the [RISC-V ISA] for example, Section 3.3 says:

> Upon reset, a hart’s privilege mode is set to M. The mstatus fields MIE and
> MPRV are reset to 0, and the VM field is reset to Mbare. The pc is set to an
> implementation-defined reset vector. The mcause register is set to a value
> indicating the cause of the reset. All other hart state is undefined.

### Approach

Even if the ISA specification is nondeterministic, at the RTL level, the
processor is deterministic, so we can prove that a _specific processor_ (or
peripheral or entire SoC) can be reliably reset. In general, processors will
not clear all internal state after asserting the reset line, so for that
reason, we do a "software-assisted deterministic start": we assert the reset
line, and we have state-clearing software in a read-only region of memory where
the processor begins execution upon reset.

### Verification

Reasoning about architectural state of a processor is hard enough, but trying
to reason about internal state (and clearing this state through software
instructions) seems especially error-prone if done manually (missing a single
register internal to the processor invalidates the noninterference proof). For
this reason, we use formal verification to prove correct our software-assisted
state-clearing operation.

At a high level, we want to prove the theorem that "the system can be reliably
reset". We can show this by considering two worlds (that are allowed to have
arbitrary state) and showing that executing the start sequence (asserting the
reset line, and then allowing the SoC to execute for some number of cycles) on
the worlds makes them indistinguishable. This is equivalent to the property
that there must exist a single possible state that the SoC could be in after
running for some number of cycles after reset.

We perform this proof by converting the SoC to a format suitable for symbolic
simulation and using [Rosette] to reason about its execution.

### Workflow

The general workflow is:

1. Write some initialization code (or start with a `nop`).
2. Run the verifier. If it succeeds, you are done. Otherwise, see what
   processor-internal state is not reset (the verifier will point out at least
   one state sub-component that is not reset).
3. Think about why that state isn't reset (maybe consulting the CPU design to
   help with this process) and update the code to reset that state component.
4. GOTO 1

## Citation

```
@inproceedings{notary:sosp19,
    author = {Athalye, Anish and Belay, Adam and Kaashoek, M. Frans and Morris, Robert and Zeldovich, Nickolai},
    title = {Notary: A Device for Secure Transaction Approval},
    year = {2019},
    publisher = {Association for Computing Machinery},
    address = {New York, NY, USA},
    doi = {10.1145/3341301.3359661},
    booktitle = {Proceedings of the 27th ACM Symposium on Operating Systems Principles},
    pages = {97–113},
    numpages = {17},
    location = {Huntsville, Ontario, Canada},
}
```

[sosp]: https://pdos.csail.mit.edu/papers/notary:sosp19.pdf
[sosp-talk]: https://sosp19.rcs.uwaterloo.ca/videos/D1-S2-P3.mp4
[login]: https://pdos.csail.mit.edu/papers/notary:login20.pdf
[PicoRV32]: https://github.com/cliffordwolf/picorv32
[simpleuart]: https://github.com/cliffordwolf/picorv32/blob/master/picosoc/simpleuart.v
[PicoSoC]: https://github.com/cliffordwolf/picorv32/tree/master/picosoc
[SPI Master]: https://github.com/nandland/spi-master
[RISC-V ISA]: https://people.eecs.berkeley.edu/~krste/papers/riscv-privileged-v1.9.pdf
[Rosette]: https://github.com/emina/rosette
[bin2coe]: https://github.com/anishathalye/bin2coe
[rtl]: https://github.com/anishathalye/rtl
[RISC-V compiler toolchain]: https://github.com/riscv/riscv-gnu-toolchain
[Yosys]: https://github.com/YosysHQ/yosys
[Racket]: https://racket-lang.org/
[Vagrant]: https://www.vagrantup.com/
