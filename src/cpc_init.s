;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_init.s
; Hardware initialisation
;
; Provides:
;   _cpc_runtime_init  - called by CRT0, sets up hardware, called before _main
;   _cpc_init          - public API: cpc_init(mode), called by user
;   _cpc_vblank_wait   - wait for vertical blank
;
;

    .module cpc_init
    .globl  _cpc_runtime_init
    .globl  _cpc_init
    .globl  _cpc_vblank_wait
    .globl  __cpc_asic_unlock
    .globl  __cpc_pagein_asic
    .globl  __cpc_pageout_asic
    .globl  _cpc_text_use_firmware_font

;==============================================================================
; Runtime state variables in RAM at $B000.
; Using a named ABS area so SDCC linker places them at a fixed address
; completely separate from _CODE at $A000.
;==============================================================================
    .area   _CEEPCEE_STATE (ABS)
    .org    0xB000

__cpc_asic_unlocked::   .ds 1   ; 0 = locked, 1 = unlocked
__cpc_screen_mode::     .ds 1   ; current screen mode (0/1/2)
__cpc_input_curr::      .ds 1   ; current joystick state byte
__cpc_input_prev::      .ds 1   ; previous joystick state byte
__cpc_input_curr2::     .ds 1   ; player 2
__cpc_input_prev2::     .ds 1   ; player 2 previous
__cpc_music_tempo::     .ds 1   ; frames per music step
__cpc_music_counter::   .ds 1   ; frame counter
__cpc_music_index::     .ds 1   ; current step index
__cpc_music_steps::     .ds 1   ; total steps
__cpc_music_paused::    .ds 1
__cpc_music_periods::   .ds 2   ; pointer to periods array
__cpc_music_volumes::   .ds 2   ; pointer to volumes array
__cpc_sprite_state::    .ds 128 ; 16 sprites * 8 bytes (x lo, x hi, y lo, y hi, mag, vis, _, _)
    .globl  __cpc_raster_enabled
    .globl  __cpc_raster_count
    .globl  __cpc_raster_index
    .globl  __cpc_raster_table
    .globl  __cpc_raster_handler

__cpc_raster_enabled::  .ds 1
__cpc_raster_count::    .ds 1
__cpc_raster_index::    .ds 1     ; current position in raster program
__cpc_raster_table::    .ds 256  ; up to 64 entries * 4 bytes (line, pen, colour lo, colour hi)
__cpc_raster_handler::  .ds 2     ; pointer to raster IRQ handler (for boot stub)
__cpc_text_ink::        .ds 1
__cpc_text_paper::      .ds 1
__cpc_font_ptr::        .ds 2
__cpc_font_width::      .ds 1
__cpc_font_height::     .ds 1
__cpc_font_first::      .ds 1
__cpc_key_matrix::      .ds 10  ; current keyboard matrix (10 lines, active-high)
__cpc_key_matrix_prev:: .ds 10  ; previous frame keyboard matrix
__cpc_irq_count::       .ds 1   ; interrupts within current frame (0..5)
__cpc_frame_count::     .ds 2   ; 16-bit frame counter, incremented at 50Hz

;==============================================================================
    .area   _CODE

;------------------------------------------------------------------------------
; _cpc_runtime_init
; Called by CRT0 before _main. Not part of the public API.
; Performs the minimum hardware setup to get into a safe known state.
;------------------------------------------------------------------------------
_cpc_runtime_init::
    di

    ; Zero runtime state block ($B000 to $B03F)
    xor     a
    ld      hl, #0xB000
    ld      (hl), a
    ld      de, #0xB001
    ld      bc, #0x003F
    ldir

    ; Initialize PSG mixer to 0x38: tones ON, noise OFF, I/O port A INPUT
    ; Bits: 7-6=I/O(00=input - REQUIRED for keyboard/joystick reads via R14),
    ;       5-3=noise(111=off), 2-0=tone(000=on)
    ld      a, #0x38
    ld      (__psg_mixer_shadow), a
    ld      d, a
    ld      e, #7               ; R7 = mixer
    call    __psg_silence_init

    ; Default values
    xor     a
    ld      (__cpc_music_steps), a   ; 0 = no music playing
    ld      (__cpc_music_paused), a
    ld      (__cpc_music_index), a
    ld      (__cpc_music_counter), a
    ld      (__cpc_irq_count), a
    ld      hl, #0
    ld      (__cpc_frame_count), hl
    ld      a, #6
    ld      (__cpc_music_tempo), a
    ld      a, #1
    ld      (__cpc_text_ink), a
    ld      a, #0xFF            ; 0xFF = transparent paper
    ld      (__cpc_text_paper), a

    ; Boot stub already unlocked ASIC inline - mark flag so __cpc_asic_unlock is idempotent
    ld      a, #1
    ld      (__cpc_asic_unlocked), a

    ; Boot stub already handled: CRTC, GA mode, screen clear, ASIC unlock.
    ; We just need: palette, sprite state, font.
    ; NOTE: $0038 is still in ROM on GX4000 - do NOT write there.

    ; Screen clear intentionally omitted: boot stub already cleared the screen,
    ; and may have loaded the title image into VRAM. Re-clearing here would
    ; erase the title before main() runs. Games clear the screen in level_start().

    ; Set GA palette (legacy, pen 0=black, pen 1=white)
    ld      hl, #_default_palette
    call    __cpc_palette_set_hl

    ; Set CPC+ ASIC palette (pen 0=black, pen 1=white, rest=black)
    ld      hl, #_default_asic_palette
    call    _cpc_palette_set_plus

    ; Raster system completely disabled
    xor     a
    ld      (__cpc_raster_enabled), a
    ld      (__cpc_raster_count), a

    ; Zero sprite state
    ld      hl, #__cpc_sprite_state
    ld      de, #__cpc_sprite_state + 1
    xor     a
    ld      (hl), a
    ld      bc, #127
    ldir

    ; Load firmware font so text functions work immediately
    call    _cpc_text_use_firmware_font

    ei
    ret

;------------------------------------------------------------------------------
; _cpc_init(mode)  - sdcccall(1): mode in A (uint8_t)
; Public init called by user code. Sets screen mode and re-applies palette.
;------------------------------------------------------------------------------
_cpc_init::
                                ; A = mode (sdcccall(1): uint8_t arg in A)
    and     #0x03
    cp      #0x03
    jr      C, 00003$
    xor     a
00003$:
    ld      (__cpc_screen_mode), a

    ; Set GA screen mode: 0x88|mode = upper ROM off, lower ROM stays, mode n
    ; Bit2=0 is critical: bit2=1 (as in $8C) disables lower ROM = instant crash
    or      #0x88
    ld      b, #0x7F
    out     (c), a

    ret

;------------------------------------------------------------------------------
; _cpc_vblank_wait()
; Wait for the next 50Hz frame by polling the frame counter.
; The boot stub's IM1 handler increments __cpc_frame_count once per frame
; (6 interrupts = 1 frame on the CPC). This also services input and music.
;------------------------------------------------------------------------------
_cpc_vblank_wait::
    push    af
    push    bc
    push    de
    push    hl

    ld      hl, (__cpc_frame_count)
00001$:
    halt                            ; wait for next interrupt
    ld      de, (__cpc_frame_count)
    or      a
    sbc     hl, de
    jr      z, 00001$               ; loop until frame counter changes

    ; Poll input and tick music after a new frame
    call    _cpc_input_poll
    call    _cpc_music_tick

    pop     hl
    pop     de
    pop     bc
    pop     af
    ret

;------------------------------------------------------------------------------
; _cpc_frame_count()
; Return the current 16-bit frame counter. Increments at 50Hz.
; sdcccall(1): return value in HL.
;------------------------------------------------------------------------------
_cpc_frame_count::
    ld      hl, (__cpc_frame_count)
    ret

;==============================================================================
; Internal helpers (not in public header but used by other modules)
;==============================================================================

;------------------------------------------------------------------------------
; __cpc_asic_unlock
; Send the 17-byte ASIC unlock sequence to port $BC.
; This enables all CPC+ features.
; Source: official CPC+ documentation + docs/cpc_plus_info.txt
;------------------------------------------------------------------------------
__cpc_asic_unlock::
    ld      a, (__cpc_asic_unlocked)
    or      a
    ret     NZ                  ; already unlocked - do nothing

    push    af
    push    bc
    push    de
    push    hl

    di
    ; Pass 1: raw bytes to port $BC00
    ld      b, #0xBC
    ld      c, #0x00
    ld      hl, #__asic_unlock_seq
    ld      e, #17
00007$:
    ld      a, (hl)
    out     (c), a
    inc     hl
    dec     e
    jr      NZ, 00007$

    ; Pass 2: OR $40 bytes to port $7F00
    ld      b, #0x7F
    ld      c, #0x00
    ld      hl, #__asic_unlock_seq
    ld      e, #17
00008$:
    ld      a, (hl)
    or      #0x40
    out     (c), a
    inc     hl
    dec     e
    jr      NZ, 00008$

    ld      a, #1
    ld      (__cpc_asic_unlocked), a
    ei

    pop     hl
    pop     de
    pop     bc
    pop     af
    ret

;------------------------------------------------------------------------------
; __cpc_pagein_asic
; Map the ASIC register window into $4000-$7FFF.
; Must be paired with __cpc_pageout_asic. Interrupts should be disabled.
;------------------------------------------------------------------------------
__cpc_pagein_asic::
    ld      bc, #0x7FB8
    out     (c), c
    ret

;------------------------------------------------------------------------------
; __cpc_pageout_asic
; Restore normal memory map ($4000-$7FFF = RAM).
;------------------------------------------------------------------------------
__cpc_pageout_asic::
    ld      bc, #0x7FA0
    out     (c), c
    ret

;==============================================================================
; Data tables
;==============================================================================

; CRTC register values 0..13 for standard CPC display at $C000
; Matches values from gx4000_api.asm __gx4000_default_crtc_vals
; R0=63  R1=40 R2=46 R3=$8E R4=38 R5=0 R6=25 R7=30 R8=0 R9=7 R10=0 R11=0 R12=$30 R13=$00
_crtc_defaults:
    .db     0x3F, 40, 46, 0x8E, 38, 0, 25, 30, 0, 7, 0, 0, 0x30, 0x00

    .globl  __asic_unlock_seq

; ASIC unlock sequence (17 bytes)
; Source: docs/cpc_plus_info.txt and confirmed against multiple commercial carts
__asic_unlock_seq:
    .db     0xFF, 0x00, 0xFF, 0x77, 0xB3, 0x51, 0xA8, 0xD4
    .db     0x62, 0x39, 0x9C, 0x46, 0x2B, 0x15, 0x8A, 0xCD, 0xEE

;------------------------------------------------------------------------------
; PSG mixer shadow (defined in cpc_sound.s at $B180)
;------------------------------------------------------------------------------
    .globl  __psg_mixer_shadow

;------------------------------------------------------------------------------
; __psg_silence_init - minimal PSG write for boot init
; Entry: E=reg, D=value
;------------------------------------------------------------------------------
__psg_silence_init::
    push    af
    push    bc
    ld      a, e
    ld      bc, #0xF4FF
    out     (c), a
    ld      bc, #0xF600
    ld      a, #0xC0
    out     (c), a
    xor     a
    out     (c), a
    ld      a, d
    ld      bc, #0xF4FF
    out     (c), a
    ld      bc, #0xF600
    ld      a, #0x80
    out     (c), a
    xor     a
    out     (c), a
    pop     bc
    pop     af
    ret

; Default firmware-ink palette: pen 0=black, pen 1=white, rest=black
_default_palette:
    .db     0, 13, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; Default ASIC palette: pen0=black, pen1=white, pen2=cyan, pen3=red
_default_asic_palette:
    .dw     0x0000, 0x00F0, 0x0F0F, 0x0FFF
    .dw     0x0000, 0x0000, 0x0000, 0x0000
    .dw     0x0000, 0x0000, 0x0000, 0x0000
    .dw     0x0000, 0x0000, 0x0000, 0x0000

; Raster table that re-applies the default palette every frame.
; Format: line(1), pen(1), colour_lo(1), colour_hi(1)
_default_raster_table:
    .db     0,  0, 0x00, 0x00    ; pen0 = black
    .db     0,  1, 0xF0, 0x00    ; pen1 = red
    .db     0,  2, 0x0F, 0x0F    ; pen2 = bright cyan
    .db     0,  3, 0xFF, 0x0F    ; pen3 = white
    .db     0,  4, 0x00, 0x00
    .db     0,  5, 0x00, 0x00
    .db     0,  6, 0x00, 0x00
    .db     0,  7, 0x00, 0x00
    .db     0,  8, 0x00, 0x00
    .db     0,  9, 0x00, 0x00
    .db     0, 10, 0x00, 0x00
    .db     0, 11, 0x00, 0x00
    .db     0, 12, 0x00, 0x00
    .db     0, 13, 0x00, 0x00
    .db     0, 14, 0x00, 0x00
    .db     0, 15, 0x0F, 0x0F
