;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_gfx.s
; Palette, border, screen clear
;

    .module cpc_gfx
    .globl  _cpc_border_set
    .globl  _cpc_palette_set_ink
    .globl  _cpc_palette_set
    .globl  _cpc_palette_set_plus
    .globl  _cpc_screen_clear
    .globl  _cpc_screen_load
    .globl  __cpc_palette_set_hl
    .globl  __cpc_pagein_asic
    .globl  __cpc_pageout_asic
    .globl  __cpc_asic_unlock

    .area   _CODE

;------------------------------------------------------------------------------
; Firmware ink -> hardware colour byte lookup
; The CPC GA encodes ink as a hardware value that is NOT the same as the
; firmware ink index. The formula is in the table below (from hardware docs).
; Input:  A = firmware ink (0..26)
; Output: A = hardware colour byte (to be OR'd with $40 for GA write)
;------------------------------------------------------------------------------
__cpc_fw_to_hw::
    ld      hl, #_fw_to_hw_table
    add     a, l
    ld      l, a
    adc     a, h
    sub     l
    ld      h, a
    ld      a, (hl)
    ret

;------------------------------------------------------------------------------
; __cpc_palette_set_hl
; Set all 16 screen pens from array at HL (16 firmware ink bytes).
; Used internally by _cpc_palette_set and _cpc_runtime_init.
;------------------------------------------------------------------------------
__cpc_palette_set_hl::
    ld      e, #0               ; E = pen index
00001$:
    ld      a, e
    ld      bc, #0x7F00
    ld      c, a
    out     (c), c              ; select pen
    ld      a, (hl)
    call    __cpc_fw_to_hw
    or      #0x40
    ld      c, a
    out     (c), c              ; write colour
    inc     hl
    inc     e
    ld      a, e
    cp      #16
    jr      NZ, 00001$
    ret

;------------------------------------------------------------------------------
; _cpc_border_set(ink) - sdcccall(1): ink in L
;------------------------------------------------------------------------------
_cpc_border_set::
    ld      a, l
    call    __cpc_fw_to_hw
    or      #0x40
    ld      bc, #0x7F10         ; pen $10 = border
    out     (c), c
    ld      c, a
    out     (c), c
    ret

;------------------------------------------------------------------------------
; _cpc_palette_set_ink(pen, ink) - sdcccall(1): ink in L, pen on stack
;------------------------------------------------------------------------------
_cpc_palette_set_ink::
    ld      a, l                ; A = ink (last arg, in HL)
    ex      af, af'
    pop     af                  ; return address
    pop     bc                  ; C = pen
    push    af
    ex      af, af'             ; A = ink
    call    __cpc_fw_to_hw
    or      #0x40
    ld      d, a                ; D = hardware colour | $40
    ld      a, c
    and     #0x0F               ; A = pen (0..15)
    ld      bc, #0x7F00
    ld      c, a
    out     (c), c              ; select pen
    ld      a, d
    ld      c, a
    out     (c), c              ; write colour
    ret

;------------------------------------------------------------------------------
; _cpc_palette_set(inks) - sdcccall(1): inks ptr in HL
;------------------------------------------------------------------------------
_cpc_palette_set::
    call    __cpc_palette_set_hl
    ret

;------------------------------------------------------------------------------
; _cpc_palette_set_plus(colours) - sdcccall(1): colours ptr in HL
; Writes 16 x 16-bit ASIC colours to ASIC palette RAM at $6400.
;------------------------------------------------------------------------------
_cpc_palette_set_plus::
    push    bc
    push    de
    ; HL = colours ptr. Copy to $B7CE scratch first (src may be in $4000-$7FFF
    ; which becomes inaccessible when ASIC is paged in).
    ; $B7CE is safely above all SDK state and game data segments.
    ld      de, #0xB7D0
    ld      bc, #32
    ldir
    ; Now write from scratch to ASIC $6400
    di
    ld      bc, #0x7FB8
    out     (c), c              ; ASIC page in
    ld      hl, #0xB7D0
    ld      de, #0x6400
    ld      bc, #32
    ldir
    ld      bc, #0x7FA0
    out     (c), c              ; ASIC page out
    ei
    pop     de
    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_screen_clear(fill) - sdcccall(1): fill byte in A
;------------------------------------------------------------------------------
_cpc_screen_clear::
                                ; A = fill byte (sdcccall(1) uint8_t arg)
    push    hl
    push    de
    push    bc
    ld      hl, #0xC000
    ld      (hl), a
    ld      de, #0xC001
    ld      bc, #0x3FFF
    di
    ldir
    ei
    pop     bc
    pop     de
    pop     hl
    ret

;------------------------------------------------------------------------------
; _cpc_screen_load(addr) - sdcccall(1): pointer to image data in HL
; Load a full-screen image from a binary blob already in RAM.
;
; The boot stub copies asset bank cb01 to RAM $4000 before jumping to $8000.
; Call as: cpc_screen_load((uint8_t*)0x4000)
;
; Data layout (produced by img_to_scr.py):
;   Bytes  0-31  : ASIC palette (16 x uint16_t LE, format 0x0GRB)
;   Bytes 32-    : Screen pixel data (16000 bytes)
;
; Method:
;   1. Save palette (32 bytes from HL) to $B700 scratch
;   2. Copy pixel data (16000 bytes from HL+32) to VRAM $C000
;   3. Write palette from $B700 to ASIC $6400 via pagein_asic
;
; $B700 is a 32-byte scratch area safely above SDK state + SDCC DATA.
; $4000-$7FFF must NOT be used for other data when this is called.
;------------------------------------------------------------------------------
_cpc_screen_load::
    push    bc
    push    de

    ; Save 32-byte palette from data ptr (HL) to $B7D0 scratch
    ld      de, #0xB7D0
    ld      bc, #32
    push    hl
    ldir                            ; HL now = data + 32 (pixel start)

    ; Copy 16352 pixel bytes to VRAM $C000 (0x4000-32 = fits in one 16KB bank with palette)
    ld      de, #0xC000
    ld      bc, #0x3FE0
    ldir

    ; Write palette from $B7D0 to ASIC $6400
    di
    call    __cpc_pagein_asic
    ld      hl, #0xB7D0
    ld      de, #0x6400
    ld      bc, #32
    ldir
    call    __cpc_pageout_asic
    ei

    pop     hl
    pop     de
    pop     bc
    ret

;==============================================================================
; Firmware-ink to hardware-colour lookup table
; Source: CPC hardware documentation, confirmed against gx4000_api.asm
; Index = firmware ink (0..26), value = raw hardware colour byte
;==============================================================================
_fw_to_hw_table:
    .db     0x54    ; 0  black
    .db     0x44    ; 1  blue
    .db     0x55    ; 2  bright blue
    .db     0x5C    ; 3  red
    .db     0x58    ; 4  magenta
    .db     0x5D    ; 5  mauve
    .db     0x4C    ; 6  bright red
    .db     0x45    ; 7  purple
    .db     0x4D    ; 8  bright magenta
    .db     0x56    ; 9  green
    .db     0x46    ; 10 cyan
    .db     0x57    ; 11 sky blue
    .db     0x5E    ; 12 yellow
    .db     0x40    ; 13 white
    .db     0x5F    ; 14 pastel blue
    .db     0x4E    ; 15 orange
    .db     0x47    ; 16 pink
    .db     0x4F    ; 17 pastel magenta
    .db     0x52    ; 18 bright green
    .db     0x42    ; 19 sea green
    .db     0x53    ; 20 bright cyan
    .db     0x5A    ; 21 lime
    .db     0x4A    ; 22 pastel green
    .db     0x5B    ; 23 ice
    .db     0x4B    ; 24 bright yellow  (actually: pastel yellow)
    .db     0x43    ; 25 pastel yellow
    .db     0x4B    ; 26 bright white
