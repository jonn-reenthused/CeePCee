;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;
; boot_stub.asm
; cartridge boot stub
;
; This file is assembled by sjasmplus to produce cart.bin.
; It is NOT part of the SDCC-linked output.
;
; cart.bin layout:
;   $0000-$01FF : boot stub (runs from ROM at $0000, vectors, ASIC unlock, CRTC)
;   $0200-$3FFF : game code binary (incbin of game.bin, up to 15.5KB)
;                 Copied to RAM $8000 at boot. SDCC --code-loc 0x8000.
;   $4000-$7FFF : asset bank 0 (up to 16KB, optional)
;                 Copied to RAM $4000 at boot if __ASSET_BIN__ is defined.
;                 Use for image data, tilemaps, etc. accessed as normal RAM pointers.
;   $8000+      : additional asset banks (future use via $DFxx banking)
;
; The GX4000 maps ROM bank cb00 ($0000-$3FFF) at $0000 on boot.
; Boot stub copies game code to RAM $8000 and optionally asset data to RAM $4000.
;
; Asset data format (at RAM $4000 after copy):
;   Structured per-resource, defined by the application.
;   For cpc_screen_load: 32-byte palette header + 16000 bytes pixel data.
;
; Constraints:
;   Game code:  <= 15.5KB ($0200-$3FFF)
;   Asset bank: <= 16KB   ($4000-$7FFF)
;

    DEVICE NOSLOT64K

    ORG $0000

;==============================================================================
; $0000: Boot entry
; Run from ROM. Minimal PPI/GA init, copy game code to RAM $8000,
; optionally copy asset bank to RAM $4000, then continue to after_vectors.
;==============================================================================
boot_entry:
    di
    im      1
    ld      sp, $BFFE
    djnz    $+0
    djnz    $+0
    ld      bc, $F782 : out (c), c  ; PPI port C = $82 (CAS motor off, etc.)
    ld      bc, $F400 : out (c), c  ; PPI port A
    ld      bc, $F600 : out (c), c  ; PPI port B
    ld      bc, $EF7F : out (c), c  ; Select AY reg 7
    ld      bc, $DF00 : out (c), c  ; Map ROM bank 0 at $C000 (default, no-op on GX4000)
    ld      bc, $7F88 : out (c), c  ; GA: Mode 0 (overridden later), upper ROM off

    ; Copy game code from ROM $0200 to RAM $8000
    ld      hl, $0200
    ld      de, $8000
    ld      bc, game_bin_size
    ldir

    jp      after_vectors

;==============================================================================
; $0038: IM1 interrupt vector
;==============================================================================
    defs    $0038 - $, $FF
im1_vector:
    push    af
    push    hl
    ld      hl, $B1AF               ; __cpc_irq_count
    inc     (hl)
    ld      a, (hl)
    cp      6
    jr      nz, .im1_done
    ld      (hl), 0
    ld      hl, ($B1B0)             ; __cpc_frame_count
    inc     hl
    ld      ($B1B0), hl
.im1_done:
    pop     hl
    pop     af
    ei
    reti

;==============================================================================
; $0066: NMI vector
;==============================================================================
    defs    $0066 - $, $FF
nmi_vector:
    retn

;==============================================================================
; $0080: after_vectors - ASIC unlock + CRTC init, then JP $8000
;==============================================================================
    defs    $0080 - $, $FF
after_vectors:
    ; ASIC unlock pass 1: raw bytes to port $BC
    ld      b, $BC
    ld      c, $00
    ld      hl, asic_unlock_seq
    ld      e, 17
.unlock1:
    ld      a, (hl)
    out     (c), a
    inc     hl
    dec     e
    jr      nz, .unlock1

    ; Clear screen at $C000
    ld      hl, $C000
    ld      de, $C001
    ld      (hl), 0
    ld      bc, $3FFF
    ldir

    ; ASIC unlock pass 2: OR $40 bytes to port $7F
    ld      b, $7F
    ld      c, $00
    ld      hl, asic_unlock_seq
    ld      e, 17
.unlock2:
    ld      a, (hl)
    or      $40
    out     (c), a
    inc     hl
    dec     e
    jr      nz, .unlock2

    ; Mark ASIC unlocked in SDK state so SDK functions skip re-unlock
    ld      a, 1
    ld      ($B000), a

    ; GA: Mode 1 (default - cpc_init() overrides this)
    ld      bc, $7F89 : out (c), c

    ; CRTC R0-R13: screen base $C000 (R12=$30, R13=$00)
    ld      hl, crtc_vals
    ld      bc, $BC00
.crtc_loop:
    out     (c), c
    inc     b
    ld      a, (hl)
    out     (c), a
    dec     b
    inc     hl
    inc     c
    ld      a, c
    cp      14
    jr      nz, .crtc_loop

    ; Load title image (cb01) at boot (__TITLE_BIN__):
    ;   - palette (32 bytes) -> $B7B0 scratch (persists for draw_title to use)
    ;   - pixels (16352 bytes) -> VRAM $C000 (visible immediately)
    ; draw_title() in C just sets ASIC palette from $B7B0 and prints text over VRAM.
    IFDEF __TITLE_BIN__
    ld      bc, $7F80       ; GA: upper ROM on, mode 0
    out     (c), c
    ld      bc, $DF81       ; select CPR bank 1 (title) at $C000
    out     (c), c
    ld      hl, $C000       ; start of title data in ROM
    ld      de, $B7B0       ; save palette (32 bytes) to scratch (above all data)
    ld      bc, 32
    ldir                    ; HL now = $C020 (pixel data start)
    ld      de, $C000       ; write pixels to VRAM
    ld      bc, $3FE0       ; 16352 bytes
    ldir
    ld      bc, $7F88       ; GA: upper ROM off
    out     (c), c
    ld      bc, $DF00       ; deselect cart bank
    out     (c), c
    ENDIF

    ; Copy asset bank (cb01) to RAM $4000 (__ASSET_BIN__):
    ; Original semantics used by tilemap/scroll/image demos - asset data is
    ; accessed as normal RAM pointers at $4000 (see cpc_screen_load, tilemaps).
    IFDEF __ASSET_BIN__
    ld      bc, $7F80       ; GA: upper ROM on, mode 0
    out     (c), c
    ld      bc, $DF81       ; select CPR bank 1 (assets) at $C000
    out     (c), c
    ld      hl, $C000       ; read from ROM asset bank
    ld      de, $4000       ; write to RAM $4000
    ld      bc, $4000       ; full 16KB bank
    ldir
    ld      bc, $7F88       ; GA: upper ROM off
    out     (c), c
    ld      bc, $DF00       ; deselect cart bank
    out     (c), c
    ENDIF

    ; Copy sprite bank (cb02) to RAM $4000.
    ; Sprites stay at $4000 for the whole session.
    IFDEF __SPRITE_BIN__
    ld      bc, $7F80       ; GA: upper ROM on, mode 0
    out     (c), c
    ld      bc, $DF82       ; select CPR bank 2 (sprites) at $C000
    out     (c), c
    ld      hl, $C000       ; read from ROM sprite bank
    ld      de, $4000       ; write to RAM $4000 (permanent staging)
    ld      bc, $3720       ; 14112 bytes
    ldir
    ld      bc, $7F88       ; GA: upper ROM off
    out     (c), c
    ld      bc, $DF00       ; deselect cart bank
    out     (c), c
    ENDIF

    ; Leave display in Mode 0 (set by $7F80 above). cpc_init() in C will set final mode.
    ld      bc, $7F88       ; GA: upper ROM off, keep mode 0
    out     (c), c

    jp      $8000

asic_unlock_seq:
    defb $FF,$00,$FF,$77,$B3,$51,$A8,$D4,$62,$39,$9C,$46,$2B,$15,$8A,$CD,$EE

crtc_vals:
    defb 63, 40, 46, $8E, 38, 0, 25, 30, 0, 7, 0, 0, $30, 0

;==============================================================================
; $0200: Game code binary
; Copied to RAM $8000 at boot. SDCC --code-loc 0x8000.
; Maximum size: $3E00 bytes (15.5KB).
;==============================================================================
    defs    $0200 - $, $FF

__sdcc_bin_start:
    incbin  __SDCC_BIN__
__sdcc_bin_end:

game_bin_size EQU __sdcc_bin_end - __sdcc_bin_start

;==============================================================================
; $4000: CPR bank cb01 - asset bank (__ASSET_BIN__, copied to RAM $4000 at
; boot) or title image (__TITLE_BIN__, palette -> $B7B0, pixels -> VRAM).
; Define at most ONE of __ASSET_BIN__ / __TITLE_BIN__.
; Maximum size: $4000 bytes (16KB).
;==============================================================================
    defs    $4000 - $, $FF

    IFDEF __TITLE_BIN__
__title_bin_start:
    incbin  __TITLE_BIN__
__title_bin_end:
    ENDIF

    IFDEF __ASSET_BIN__
__asset_bin_start:
    incbin  __ASSET_BIN__
__asset_bin_end:
asset_bin_size EQU __asset_bin_end - __asset_bin_start
    ENDIF

;==============================================================================
; $8000: Sprite bank (CPR bank cb02)
; Sprite pixel data + palette. Copied to RAM $4000 by load_sprite_bank() in C.
; Maximum size: $4000 bytes (16KB).
;==============================================================================
    defs    $8000 - $, $FF

    IFDEF __SPRITE_BIN__
__sprite_bin_start:
    incbin  __SPRITE_BIN__
__sprite_bin_end:
    ENDIF
