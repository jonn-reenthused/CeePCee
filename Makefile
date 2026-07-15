# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

# Library Makefile
#
# Builds:
#   lib/crt0.rel      - CRT0 object (linked into every game)
#   lib/ceepcee.lib   - library archive (all SDK modules)
#
# Usage:
#   make              - build library
#   make clean        - remove build artefacts
#   make samples      - build all samples

SDCC    := sdcc
SDAS    := sdasz80
SDAR    := sdar

CFLAGS  := -mz80 --no-std-crt0 --sdcccall 1 -I include
ASFLAGS := -plosgff

LIB_DIR := lib
SRC_DIR := src
BUILD   := build

# Source files (assembly modules)
ASM_SRCS := \
    $(SRC_DIR)/cpc_init.s \
    $(SRC_DIR)/cpc_gfx.s \
    $(SRC_DIR)/cpc_input.s \
    $(SRC_DIR)/cpc_sprite.s \
    $(SRC_DIR)/cpc_sound.s \
    $(SRC_DIR)/cpc_text.s \
    $(SRC_DIR)/cpc_font_data.s \
    $(SRC_DIR)/cpc_tilemap.s \
    $(SRC_DIR)/cpc_scroll.s \
    $(SRC_DIR)/cpc_raster.s

# Object files
ASM_RELS := $(patsubst $(SRC_DIR)/%.s, $(BUILD)/%.rel, $(ASM_SRCS))

CRT0_REL := $(LIB_DIR)/crt0.rel
LIBRARY  := $(LIB_DIR)/ceepcee.lib

.PHONY: all clean samples

all: $(LIB_DIR) $(BUILD) $(CRT0_REL) $(LIBRARY)
	@echo ""
	@echo "========================================="
	@echo "CeePCee V2 library built successfully"
	@echo "  CRT0:    $(CRT0_REL)"
	@echo "  Library: $(LIBRARY)"
	@echo "========================================="

$(LIB_DIR):
	mkdir -p $@

$(BUILD):
	mkdir -p $@

# Assemble CRT0
$(CRT0_REL): $(SRC_DIR)/crt0/crt0_gx4000.s | $(LIB_DIR)
	$(SDAS) $(ASFLAGS) -o $@ $<

# Assemble library modules
$(BUILD)/%.rel: $(SRC_DIR)/%.s | $(BUILD)
	$(SDAS) $(ASFLAGS) -o $@ $<

# Archive into library
$(LIBRARY): $(ASM_RELS) | $(LIB_DIR)
	$(SDAR) -rc $@ $^

clean:
	rm -rf $(BUILD) $(LIB_DIR)
	$(MAKE) -C samples/hello_cart clean 2>/dev/null || true

samples: all
	$(MAKE) -C samples/hello_cart

# Quick syntax check: assemble all sources and report errors
check: $(BUILD)
	@echo "Checking assembly syntax..."
	@for f in $(ASM_SRCS) $(SRC_DIR)/crt0/crt0_gx4000.s; do \
	    echo -n "  $$f ... "; \
	    $(SDAS) $(ASFLAGS) -o /dev/null $$f 2>&1 && echo "OK" || echo "FAILED"; \
	done
