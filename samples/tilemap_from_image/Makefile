# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

# CeePCee V2 - tilemap_from_image sample Makefile
#
# Pipeline:
#   assets/map.png  -->  map_from_image.py  -->  build/asset.bin
#                                            -->  build/asset_info.h
#   main.c + asset_info.h  -->  SDCC  -->  build/game.bin
#   game.bin + asset.bin  -->  sjasmplus + rom_packer  -->  tilemap_from_image.cpr

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

NAME      := tilemap_from_image
BUILD     := build
ASSETS    := assets

CFLAGS    := -mz80 --no-std-crt0 --sdcccall 1 \
             --code-loc 0x8000 --data-loc 0xB600 \
             -I $(INCLUDE) -I $(BUILD)

.PHONY: all clean

all: $(BUILD) $(NAME).cpr
	@echo ""
	@echo "Built $(NAME).cpr - load in WinAPE, JavaCPC or real hardware"

$(BUILD):
	mkdir -p $@

# Convert map image -> asset binary + C header (one step, no separate tileset needed)
$(BUILD)/asset.bin $(BUILD)/asset_info.h: $(ASSETS)/map.png | $(BUILD)
	$(PYTHON) $(TOOLS)/map_from_image.py $< \
	    --out     $(BUILD)/asset.bin \
	    --out-png $(BUILD)/tileset_preview.png \
	    --out-csv $(BUILD)/map.csv \
	    --out-header $(BUILD)/asset_info.h

# main.c depends on asset_info.h (generated above)
$(BUILD)/main.rel: main.c $(BUILD)/asset_info.h | $(BUILD)
	$(SDCC) $(CFLAGS) -c main.c -o $@

$(BUILD)/game.ihx: $(BUILD)/main.rel $(CRT0) $(LIBRARY)
	$(SDCC) $(CFLAGS) $(CRT0) $(BUILD)/main.rel $(LIBRARY) -o $@

$(BUILD)/game.bin: $(BUILD)/game.ihx
	$(PYTHON) $(TOOLS)/ihx_to_bin.py $< $@ 0x8000

$(BUILD)/cart_wrap.asm: $(BUILD)/game.bin $(BUILD)/asset.bin $(TOOLS)/boot_stub.asm
	@echo "    DEFINE __SDCC_BIN__ \"$(abspath $(BUILD)/game.bin)\"" > $@
	@echo "    DEFINE __ASSET_BIN__ \"$(abspath $(BUILD)/asset.bin)\"" >> $@
	@echo "    include \"$(abspath $(TOOLS)/boot_stub.asm)\"" >> $@

$(BUILD)/cart.bin: $(BUILD)/cart_wrap.asm
	$(SJASMPLUS) --raw=$@ $(BUILD)/cart_wrap.asm

$(NAME).cpr: $(BUILD)/cart.bin
	bash $(SCRIPTS)/rom_packer.sh $< $@

clean:
	rm -rf $(BUILD) $(NAME).cpr
