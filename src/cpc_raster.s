;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_raster.s
; Raster/Copper bar effects using CPC+ ASIC
;
; Simplified HALT-based approach matching the sample code.
; The raster program is applied each frame by waiting for the raster
; interrupt then doing palette changes with precise timing.
;

    .module cpc_raster
    .globl  _cpc_raster_set_program
    .globl  _cpc_raster_disable
    .globl  __cpc_raster_enabled
    .globl  __cpc_raster_count
    .globl  __cpc_raster_table
    .globl  __cpc_raster_arm
    .globl  __cpc_raster_apply
    .globl  __cpc_asic_unlock

    .area   _CODE

;==============================================================================
; _cpc_raster_set_program(entries, count)
; sdcccall(1): entries in HL (pointer to array), count in A
; Copies the raster program to internal table and enables it.
;==============================================================================
_cpc_raster_set_program::
    push    ix
    push    bc
    push    de
    push    hl
    
    ld      b, a                ; B = count
    ld      a, #64
    cp      b
    jr      NC, __rp_count_ok
    ld      b, #64              ; clamp to max 64
__rp_count_ok:
    
    ; Save count
    ld      a, b
    ld      (__cpc_raster_count), a
    
    ; Copy entries from HL to __cpc_raster_table
    ; Each entry is 4 bytes: line(1), pen(1), colour(2)
    ld      de, #__cpc_raster_table
    pop     hl                  ; HL = entries pointer
    
__rp_copy_loop:
    ld      a, b
    or      a
    jr      Z, __rp_copy_done
    
    ld      a, (hl)
    ld      (de), a
    inc     hl
    inc     de
    
    ld      a, (hl)
    ld      (de), a
    inc     hl
    inc     de
    
    ld      a, (hl)
    ld      (de), a
    inc     hl
    inc     de
    
    ld      a, (hl)
    ld      (de), a
    inc     hl
    inc     de
    
    dec     b
    jr      __rp_copy_loop
    
__rp_copy_done:
    ; Enable raster
    ld      a, #1
    ld      (__cpc_raster_enabled), a
    
    pop     de
    pop     bc
    pop     ix
    ret

;==============================================================================
; _cpc_raster_disable()
; Disables the raster program.
;==============================================================================
_cpc_raster_disable::
    xor     a
    ld      (__cpc_raster_enabled), a
    ret

;==============================================================================
; __cpc_raster_arm()
; Currently unused - placeholder for future programmable raster use.
; Simple HALT-based approach is used instead.
;===============================================================================
__cpc_raster_arm::
    ret

;==============================================================================
; __cpc_raster_apply()
; Called from _cpc_vblank_wait() at the top of each frame.
; Applies the raster program by reprogramming the ASIC palette at each entry line.
;===============================================================================
__cpc_raster_apply::
    push    af
    push    bc
    push    de
    push    hl
    push    ix

    ; Check if a raster program is active
    ld      a, (__cpc_raster_enabled)
    or      a
    jp      z, __ra_done

    ; Wait out the top border so the first entry's line 0 lands at the
    ; top of the visible display. With the default CRTC this is 48 scanlines
    ; (VSYNC ends at line 256, total = 304 lines, visible = 200 lines).
    di                              ; palette timing must be exact
    ld      a, #48
    call    __ra_wait_lines

    ; Small delay to get past the top border / HSYNC jitter (matching docs examples)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop

    ; Page in ASIC registers at &4000-&7FFF
    ld      bc, #0x7FB8
    out     (c), c

    ; HL = pointer to first entry
    ; Each entry: line(1), pen(1), colour_lo(1), colour_hi(1)
    ld      hl, #__cpc_raster_table
    ld      a, (__cpc_raster_count)
    ld      b, a

    or      a
    jr      z, __ra_pageout

    ld      c, #0                   ; current scan line

__ra_loop:
    ld      e, (hl)                 ; E = target scan line
    inc     hl
    ld      a, e
    sub     c                       ; A = lines to wait since last entry
    push    bc                      ; preserve entry count (B) and current line (C)
    call    __ra_wait_lines
    pop     bc
    ld      c, e                    ; current line = target line

    ; Read pen and compute ASIC palette address $6400 + pen*2
    ld      a, (hl)
    inc     hl
    add     a, a                    ; A = pen * 2
    ld      d, #0x64
    ld      e, a                    ; DE = $6400 + pen*2

    ; Write the 16-bit CPC+ colour
    ld      a, (hl)                 ; low byte
    ld      (de), a
    inc     hl
    inc     e
    ld      a, (hl)                 ; high byte
    ld      (de), a
    inc     hl

    djnz    __ra_loop

__ra_pageout:
    ; Page out ASIC registers
    ld      bc, #0x7FA0
    out     (c), c

    ei

__ra_done:
    pop     ix
    pop     hl
    pop     de
    pop     bc
    pop     af
    ret

;==============================================================================
; __ra_wait_lines
; Wait A scan lines (A * ~64us) using a tight NOP loop.
; Clobbers A, B and flags.
;===============================================================================
__ra_wait_lines:
    or      a
    ret     z
    ld      b, a
__ra_wl_loop:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    djnz    __ra_wl_loop
    ret

; __cpc_raster_table is defined in cpc_init.s ABS area
