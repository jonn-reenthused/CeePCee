# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

# CeePCee V2 - image_demo sample Makefile

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

NAME      := image_demo
BUILD     := build
ASSETS    := assets
MODE      ?= 0

CFLAGS    := -mz80 --no-std-crt0 --sdcccall 1 \
             --code-loc 0x8000 --data-loc 0xB600 \
             -I $(INCLUDE) -DSCREEN_MODE=$(MODE)

.PHONY: all clean

all: $(BUILD) $(NAME).cpr
	@echo ""
	@echo "Built $(NAME).cpr - load in WinAPE, JavaCPC or real hardware"

$(BUILD):
	mkdir -p $@

# Convert PNG asset to CPC+ screen binary (palette header + pixels)
$(BUILD)/image.bin: $(ASSETS)/image.png | $(BUILD)
	$(PYTHON) $(TOOLS)/img_to_scr.py $< $@ --mode $(MODE)

$(BUILD)/main.rel: main.c | $(BUILD)
	$(SDCC) $(CFLAGS) -c main.c -o $@

$(BUILD)/game.ihx: $(BUILD)/main.rel $(CRT0) $(LIBRARY)
	$(SDCC) $(CFLAGS) $(CRT0) $(BUILD)/main.rel $(LIBRARY) -o $@

$(BUILD)/game.bin: $(BUILD)/game.ihx
	$(PYTHON) $(TOOLS)/ihx_to_bin.py $< $@ 0x8000

$(BUILD)/cart_wrap.asm: $(BUILD)/game.bin $(BUILD)/image.bin $(TOOLS)/boot_stub.asm
	@echo "    DEFINE __SDCC_BIN__ \"$(abspath $(BUILD)/game.bin)\"" > $@
	@echo "    DEFINE __ASSET_BIN__ \"$(abspath $(BUILD)/image.bin)\"" >> $@
	@echo "    include \"$(abspath $(TOOLS)/boot_stub.asm)\"" >> $@

$(BUILD)/cart.bin: $(BUILD)/cart_wrap.asm
	$(SJASMPLUS) --raw=$@ $(BUILD)/cart_wrap.asm

$(NAME).cpr: $(BUILD)/cart.bin
	bash $(SCRIPTS)/rom_packer.sh $< $@

clean:
	rm -rf $(BUILD) $(NAME).cpr
