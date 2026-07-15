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
;==============================================================================
__cpc_raster_arm::
    ret

;==============================================================================
; __cpc_raster_apply()
; Call after HALT for raster interrupt. Applies colors and waits for vsync.
;==============================================================================
__cpc_raster_apply::
    push    af
    push    bc
    push    de
    push    hl
    push    ix
    
    ; Check if enabled
    ld      a, (__cpc_raster_enabled)
    or      a
    jp      Z, __ra_done
    
    ; ASIC is unlocked by the boot stub; re-sending the sequence can re-lock it.
    ; Wait for interrupt (start of visible frame)
    halt
    
    ; defs 20 - delay to get past border (like raster1b)
    ; Use defs-style padding: 20 bytes = 5 JP instructions or custom
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
    
    ; Page in ASIC registers at &4000-&7fff
    ld      bc, #0x7FB8
    out     (c), c
    
    ; DE = ASIC palette address for pen 0
    ld      de, #0x6400
    
    ; HL = pointer to first entry in __cpc_raster_table
    ; Each entry: line(1), pen(1), colour_lo(1), colour_hi(1)
    ld      hl, #__cpc_raster_table
    
    ; B = number of entries
    ld      a, (__cpc_raster_count)
    ld      b, a
    
    or      a
    jr      z, __ra_pageout
    
__ra_loop:
    ; Skip line byte
    inc     hl              ; skip line
    ; Read pen byte and compute palette address $6400 + pen*2
    ld      a, (hl)
    inc     hl
    add     a, a            ; A = pen * 2
    ld      d, #0x64
    ld      e, a            ; DE = $6400 + pen*2
    ; Read colour lo+hi and write to the selected pen
    ld      a, (hl)
    ld      (de), a
    inc     hl
    inc     e
    ld      a, (hl)
    ld      (de), a
    inc     hl              ; advance to next entry
    
    nop
    nop
    
    dec     b
    jp      nz, __ra_loop
    
    ; Page out ASIC registers
__ra_pageout:
    ld      bc, #0x7FA0
    out     (c), c
    
__ra_done:
    pop     ix
    pop     hl
    pop     de
    pop     bc
    pop     af
    ret

; __cpc_raster_table is defined in cpc_init.s ABS area
