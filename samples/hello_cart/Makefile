# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

# CeePCee V2 - hello_cart sample Makefile
#
# Pipeline (V1-style, copy to RAM):
#   1. sdcc:      crt0.rel + main.rel + ceepcee.lib -> game.ihx  (linked at $8000)
#   2. ihx_to_bin: game.ihx                        -> game.bin  (flat at $8000)
#   3. sjasmplus: boot_stub + game.bin             -> cart.bin  (16KB ROM image)
#   4. rom_packer: cart.bin                        -> hello_cart.cpr

SDCC      := sdcc
SJASMPLUS := sjasmplus
PYTHON    := python3

ROOT      := ../..
TOOLS     := $(ROOT)/tools
SCRIPTS   := $(ROOT)/tools
INCLUDE   := $(ROOT)/include
LIB_DIR   := $(ROOT)/lib
CRT0      := $(LIB_DIR)/crt0.rel
LIBRARY   := $(LIB_DIR)/ceepcee.lib

NAME      := hello_cart
BUILD     := build

# Link at $8000 - boot stub copies binary to RAM $8000, runs from there.
# State variables at $B000 (RAM, after code).
CFLAGS    := -mz80 --no-std-crt0 --sdcccall 1 \
             --code-loc 0x8000 --data-loc 0xB000 \
             -I $(INCLUDE)

.PHONY: all clean

all: $(BUILD) $(NAME).cpr
	@echo ""
	@echo "Built $(NAME).cpr - load in WinAPE, JavaCPC or real hardware"

$(BUILD):
	mkdir -p $@

# Step 1a: Compile main.c to a .rel (no link yet)
$(BUILD)/main.rel: main.c | $(BUILD)
	$(SDCC) $(CFLAGS) -c main.c -o $@

# Step 1b: Link: CRT0 first (its _CODE goes to $0000), then main, then library
$(BUILD)/game.ihx: $(BUILD)/main.rel $(CRT0) $(LIBRARY)
	$(SDCC) $(CFLAGS) $(CRT0) $(BUILD)/main.rel $(LIBRARY) -o $@

# Step 2: Flatten IHX to raw binary at $8000
$(BUILD)/game.bin: $(BUILD)/game.ihx
	$(PYTHON) $(TOOLS)/ihx_to_bin.py $< $@ 0x8000

# Step 3: Assemble ROM image (boot stub copies game.bin to RAM $8000)
$(BUILD)/cart_wrap.asm: $(BUILD)/game.bin $(TOOLS)/boot_stub.asm
	@echo "    DEFINE __SDCC_BIN__ \"$(abspath $(BUILD)/game.bin)\"" > $@
	@echo "    include \"$(abspath $(TOOLS)/boot_stub.asm)\"" >> $@

$(BUILD)/cart.bin: $(BUILD)/cart_wrap.asm
	$(SJASMPLUS) --raw=$@ $(BUILD)/cart_wrap.asm

# Step 4: Wrap into CPR
$(NAME).cpr: $(BUILD)/cart.bin
	bash $(SCRIPTS)/rom_packer.sh $< $@

clean:
	rm -rf $(BUILD) $(NAME).cpr
