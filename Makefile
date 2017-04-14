#############################################################
# Configuration
#############################################################

# Allows users to create Makefile.local or ../Makefile.project with
# configuration variables, so they don't have to be set on the command-line
# every time.
extra_configs := $(wildcard Makefile.local ../Makefile.project)
ifneq ($(extra_configs),)
$(info Obtaining additional make variables from $(extra_configs))
include $(extra_configs)
endif

# Default target
BOARD ?= freedom-e510-arty
PROGRAM ?= baremetal

# Variables the user probably shouldn't override.
builddir := work/build
installdir := work/install
toolchain_srcdir := riscv-gnu-toolchain
openocd_srcdir := openocd

#############################################################
# BSP Loading
#############################################################

# Finds the directory in which this BSP is located, ensuring that there is
# exactly one.
board_dir := $(wildcard bsp/env/$(BOARD))
ifeq ($(words $(board_dir)),0)
$(error Unable to find BSP for $(BOARD), expected to find either "bsp/$(BOARD)" or "bsp-addons/$(BOARD)")
endif
ifneq ($(words $(board_dir)),1)
$(error Found multiple BSPs for $(BOARD): "$(board_dir)")
endif

# There must be a settings makefile fragment in the BSP's board directory.
ifeq ($(wildcard $(board_dir)/settings.mk),)
$(error Unable to find BSP for $(BOARD), expected to find $(board_dir)/settings.mk)
endif
include $(board_dir)/settings.mk

ifeq ($(RISCV_ARCH),)
$(error $(board_dir)/board.mk must set RISCV_ARCH, the RISC-V ISA string to target)
endif

ifeq ($(RISCV_ABI),)
$(error $(board_dir)/board.mk must set RISCV_ABI, the ABI to target)
endif

# Determines the XLEN from the toolchain tuple
ifeq ($(patsubst rv32%,rv32,$(RISCV_ARCH)),rv32)
RISCV_XLEN := 32
else ifeq ($(patsubst rv64%,rv64,$(RISCV_ARCH)),rv64)
RISCV_XLEN := 64
else
$(error Unable to determine XLEN from $(RISCV_ARCH))
endif

#############################################################
# Prints help message
#############################################################
.PHONY: help
help:
	@echo "  SiFive Freedom E Software Development Kit "
	@echo "  Makefile targets:"
	@echo ""
	@echo " tools:"
	@echo "    Install compilation & debugging tools."
	@echo ""
	@echo " uninstall:"
	@echo "    Uninstall the compilation & debugging tools."
	@echo ""
	@echo " software [PROGRAM=$(PROGRAM) BOARD=$(BOARD)]:"
	@echo "    Build a software program to load with the"
	@echo "    debugger."
	@echo ""
	@echo " upload [PROGRAM=$(PROGRAM) BOARD=$(BOARD)]:"
	@echo "    Launch OpenOCD to flash your program to the"
	@echo "    on-board Flash."
	@echo ""
	@echo " run_debug [PROGRAM=$(PROGRAM) BOARD=$(BOARD)]:"
	@echo "    Launch OpenOCD & GDB to load or debug "
	@echo "    running programs. Does not allow Ctrl-C to halt running programs."
	@echo ""
	@echo " run_openocd [BOARD=$(BOARD)]:"
	@echo " run_gdb     [PROGRAM=$(PROGRAM) BOARD=$(BOARD)]:"
	@echo "     Launch OpenOCD or GDB seperately. Allows Ctrl-C to halt running"
	@echo "     programs."
	@echo ""
	@echo " dasm [PROGRAM=$(BOARD)]:"
	@echo "     Generates the dissassembly output of 'objdump -D' to stdout."
	@echo ""
	@echo " For more information, visit dev.sifive.com"

.PHONY: clean
clean:

#############################################################
# This section is for tool installation
#############################################################
.PHONY: tools
tools: riscv-gnu-toolchain openocd

# Pointers to various important tools in the toolchain.
toolchain_builddir := $(builddir)/riscv-gnu-toolchain/$(RISCV_ARCH)-$(RISCV_ABI)-elf
toolchain_prefix := $(toolchain_builddir)/prefix

RISCV_GCC     := $(abspath $(toolchain_prefix)/bin/riscv$(RISCV_XLEN)-unknown-elf-gcc)
RISCV_GXX     := $(abspath $(toolchain_prefix)/bin/riscv$(RISCV_XLEN)-unknown-elf-g++)
RISCV_OBJDUMP := $(abspath $(toolchain_prefix)/bin/riscv$(RISCV_XLEN)-unknown-elf-objdump)
RISCV_GDB     := $(abspath $(toolchain_prefix)/bin/riscv$(RISCV_XLEN)-unknown-elf-gdb)
RISCV_AR      := $(abspath $(toolchain_prefix)/bin/riscv$(RISCV_XLEN)-unknown-elf-ar)

PATH := $(abspath $(toolchain_prefix)/bin):$(PATH)

$(RISCV_GCC) $(RISCV_GXX) $(RISCV_OBJDUMP) $(RISCV_GDB) $(RISCV_AR): $(toolchain_builddir)/install.stamp
	touch -c $@

# Builds riscv-gnu-toolchain, which contains GCC and all the supporting
# software for C code.
.PHONY: riscv-gnu-toolchain
riscv-gnu-toolchain: $(RISCV_GCC) $(RISCV_GXX) $(RISCV_OBJDUMP) $(RISCV_GDB) $(RISCV_AR)

$(builddir)/riscv-gnu-toolchain/%/install.stamp: $(builddir)/riscv-gnu-toolchain/%/build.stamp
	$(MAKE) -C $(dir $@) install
	date > $@

$(builddir)/riscv-gnu-toolchain/%/build.stamp: $(builddir)/riscv-gnu-toolchain/%/configure.stamp
	$(MAKE) -C $(dir $@)
	date > $@

$(builddir)/riscv-gnu-toolchain/%-elf/configure.stamp:
	$(eval $@_TUPLE := $(patsubst $(builddir)/riscv-gnu-toolchain/%-elf/configure.stamp,%,$@))
	$(eval $@_ARCH := $(word 1,$(subst -, ,$($@_TUPLE))))
	$(eval $@_ABI := $(word 2,$(subst -, ,$($@_TUPLE))))
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	cd $(dir $@); $(abspath $(toolchain_srcdir)/configure) \
		--prefix=$(abspath $(dir $@)/prefix) \
		--disable-linux \
		--with-arch=$($@_ARCH) \
		--with-abi=$($@_ABI) \
		--disable-multilib
	date > $@

.PHONY: toolchain-clean
clean: toolchain-clean
toolchain-clean:
	rm -rf $(toolchain_builddir)

# Builds and installs OpenOCD, which translates GDB into JTAG for debugging and
# initializing the target.
openocd_builddir := $(builddir)/openocd
openocd_prefix := $(openocd_builddir)/prefix
RISCV_OPENOCD := $(openocd_prefix)/bin/openocd

.PHONY: openocd
openocd: $(RISCV_OPENOCD)

$(RISCV_OPENOCD): $(openocd_builddir)/install.stamp
	touch -c $@

$(openocd_builddir)/install.stamp: $(openocd_builddir)/build.stamp
	$(MAKE) -C $(dir $@) install
	date > $@

$(openocd_builddir)/build.stamp: $(openocd_builddir)/configure.stamp
	$(MAKE) -C $(dir $@)
	date > $@

$(openocd_builddir)/configure.stamp:
	rm -rf $(dir $@)
	mkdir -p $(dir $@)
	cd $(abspath $(openocd_srcdir)); autoreconf -i
	cd $(dir $@); $(abspath $(openocd_srcdir)/configure) \
		--prefix=$(abspath $(dir $@)/prefix) \
		--disable-werror
	date > $@

.PHONY: openocd-clean
clean: openocd-clean
openocd-clean:
	rm -rf $(openocd_builddir)

#############################################################
# This Section is for Software Compilation
#############################################################
PROGRAM_DIR = software/$(PROGRAM)
PROGRAM_ELF = software/$(PROGRAM)/$(PROGRAM)

.PHONY: software_clean
software_clean:
	$(MAKE) -C $(PROGRAM_DIR) clean

.PHONY: software
software: software_clean
	$(MAKE) -C $(PROGRAM_DIR) CC=$(RISCV_GCC) AR=$(RISCV_AR) BSP_BASE=$(abspath bsp) BOARD=$(BOARD)

dasm: software $(RISCV_OBJDUMP)
	$(RISCV_OBJDUMP) -D $(PROGRAM_ELF)

#############################################################
# This Section is for uploading a program to SPI Flash
#############################################################
OPENOCD_UPLOAD = bsp/tools/openocd_upload.sh
OPENOCDCFG ?= bsp/env/$(BOARD)/openocd.cfg

upload:
	$(OPENOCD_UPLOAD) --openocd $(abspath $(RISCV_OPENOCD)) $(PROGRAM_ELF) $(OPENOCDCFG)

#############################################################
# This Section is for launching the debugger
#############################################################
OPENOCDARGS += -f $(OPENOCDCFG)

GDBCMDS += -ex "target extended-remote localhost:3333"
GDBARGS =

run_openocd:
	$(RISCV_OPENOCD) $(OPENOCDARGS)

run_gdb:
	$(RISCV_GDB) $(PROGRAM_DIR)/$(PROGRAM) $(GDBARGS)

run_debug:
	$(RISCV_OPENOCD) $(OPENOCDARGS) &
	$(RISCV_GDB) $(PROGRAM_DIR)/$(PROGRAM) $(GDBARGS) $(GDBCMDS)
