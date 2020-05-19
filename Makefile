MAKEFLAGS += -r
MAKEFLAGS += -R

ROM_DEPTH := 256

ifndef PREFIX
PREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'make PREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

CC := $(PREFIX)gcc
AS := $(PREFIX)as
LD := $(PREFIX)ld
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump

CFLAGS := -O2 -march=rv32i -mabi=ilp32 -fdata-sections -ffunction-sections -ffreestanding
ASFLAGS := -march=rv32i -mabi=ilp32
OBJDUMPFLAGS := --disassemble-all --source --section-headers --demangle
LDFLAGS := -melf32lriscv -nostdlib
BIN2COEFLAGS := --width 32 --depth $(ROM_DEPTH) --fill 0

.PHONY: all
all: soc.rkt verify

.PHONY: clean
clean:
	rm -rf \
		fw/*.o fw/*.bin fw/*.lst fw/*.elf \
		hw/*.mem hw/*.smt2 \
		soc.rkt \
		compiled

# firmware

%.bin: %.elf
	$(OBJCOPY) $< -O binary $@

%.o: %.s
	$(AS) $(ASFLAGS) -c $< -o $@

%.lst: %.elf
	$(OBJDUMP) $(OBJDUMPFLAGS) $< > $@

fw/firmware.elf: fw/rom.ld fw/firmware.o
	$(LD) $(LDFLAGS) -T $^ -o $@

# soc

hw/firmware.mem: fw/firmware.bin
	bin2coe $(BIN2COEFLAGS) --mem -i $< -o $@

hw/soc.smt2: $(shell find hw -name '*.v') hw/firmware.mem
	cd hw; yosys \
		-p 'read_verilog -defer $(shell cd hw; find . -name '*.v')' \
		-p 'prep -flatten -top soc -nordff' \
		-p 'write_smt2 -stdt soc.smt2'

soc.rkt: hw/soc.smt2
	echo '#lang yosys' > $@
	cat $< >> $@

# run verification script
.PHONY: verify
verify: soc.rkt verify.rkt
	raco make verify.rkt
