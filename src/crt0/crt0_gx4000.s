;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;
; NB: It's called GX4000 but it's for the whole plus range.
;
; crt0_gx4000.s
; CRT0 for CPC+ / GX4000 cartridge
;
; CPR layout (handled by sjasmplus packer, not SDCC):
;   ROM bank 0 $0000-$3FFF : this CRT0 stub (just hardware init + jump to $A000)
;   ROM bank 0 $A000+      : SDCC-linked game code + library (incbin of .bin)
;
; RAM layout at runtime:
;   $A000-$BFFF : game code + library data (copied from ROM by sjasmplus ldir stub)
;   $C000-$FFFF : screen RAM
;   $4000-$7FFF : ASIC register window (paged in/out as needed)
;
; SDCC link target: --code-loc 0xA000 --data-loc 0xA000
; The SDCC binary is a flat image starting at $A000.
; sjasmplus packs it into the CPR and adds the copy stub.
;
; This CRT0 is assembled by sdasz80 and linked into the SDCC binary.
; At link time SDCC places _HEADER at --code-loc (0xA000), so the
; entire output starts with this CRT0 code at $A000.
; The sjasmplus packer copies the entire bank0 image to RAM $A000 then
; falls through to this code.
;

    .module crt0_gx4000
    .globl  _main
    .globl  _cpc_runtime_init
    .globl  s__INITIALIZED
    .globl  s__INITIALIZER
    .globl  l__INITIALIZED
    .globl  s__DATA
    .globl  l__DATA

    .area   _CODE

;==============================================================================
; Entry point at $A000. crt0.rel is linked first so these bytes appear at
; the very start of _CODE = $A000. _main follows in _CODE after this stub.
;==============================================================================
crt0_entry::
    di
    im      1
    ld      sp, #0xBFFE

    ; Zero _DATA (uninitialised statics - SDCC puts them here on Z80, not _BSS)
    ld      bc, #l__DATA
    ld      a, b
    or      c
    jr      z, 00003$
    ld      hl, #s__DATA
    ld      (hl), #0
    dec     bc
    ld      a, b
    or      c
    jr      z, 00003$
    ld      de, #s__DATA + 1
    ldir
00003$:

    ; Copy initialised data from ROM (_INITIALIZER) to RAM (_INITIALIZED)
    ld      bc, #l__INITIALIZED
    ld      a, b
    or      c
    jr      z, 00001$
    ld      hl, #s__INITIALIZER
    ld      de, #s__INITIALIZED
    ldir
00001$:

    ; Zero BSS
    ld      bc, #l__BSS
    ld      a, b
    or      c
    jr      z, 00002$
    ld      hl, #s__BSS
    ld      (hl), #0
    dec     bc
    ld      a, b
    or      c
    jr      z, 00002$
    ld      de, #s__BSS + 1
    ldir
00002$:

    call    _cpc_runtime_init
    jp      _main

; Fallback BSS symbols - used only if no _BSS section exists in the program.
; When a real _BSS section is present the linker uses those symbols instead.
    .area   _BSS
s__BSS_fallback::
    .ds     0

    .area   _GSINIT
__sdcc_gsinit_startup::
    ret

    .area   _GSFINAL
    ret
