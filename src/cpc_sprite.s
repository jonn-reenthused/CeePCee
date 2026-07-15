;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_sprite.s
; CPC+ / GX4000 hardware sprites
;
; 16 sprites, each 16x16 Mode 0 pixels (256 bytes pixel data).
; ASIC register window at $4000-$7FFF (paged in/out around accesses).
; Sprite pixel RAM:  $4000 + id * $0100  (256 bytes each)
; Sprite registers:  $6000 + id * 8      (x-lo, x-hi, y-lo, y-hi, mag, _, _, _)
; Sprite palette:    $6422               (15 * 2 bytes, $0GRB format)
;

    .module cpc_sprite
    .globl  _cpc_sprite_set_pixels
    .globl  _cpc_sprite_set_palette
    .globl  _cpc_sprite_show
    .globl  _cpc_sprite_move
    .globl  _cpc_sprite_set_x
    .globl  _cpc_sprite_set_y
    .globl  _cpc_sprite_set_magnification
    .globl  _cpc_sprite_collides
    .globl  __cpc_pagein_asic
    .globl  __cpc_pageout_asic
    .globl  __cpc_asic_unlock
    .globl  __cpc_sprite_state

    .area   _CODE

; ASIC unlock sequence (from documentation)
asic_unlock_seq:
    .db     0xFF, 0x00, 0xFF, 0x77, 0xB3, 0x51, 0xA8, 0xD4
    .db     0x62, 0x39, 0x9C, 0x46, 0x2B, 0x15, 0x8A, 0xCD, 0xEE

;------------------------------------------------------------------------------
; _cpc_sprite_set_pixels(id, pixels)
; sdcccall(1): id in A, pixels ptr in DE
;------------------------------------------------------------------------------
_cpc_sprite_set_pixels::
    ; sdcccall(1): A = id (0..15), DE = src ptr (256 bytes, 1 byte/pixel)
    ; Writes 256 bytes to ASIC sprite pixel RAM at $4000 + id*256.
    ; Source may be in $4000-$7FFF; copy to $BE00 scratch first.
    push    bc
    push    de                  ; save source pointer
    push    af                  ; save id
    
    ; Copy 256 bytes from src (DE) to $BE00 scratch
    ld      hl, #0xBE00         ; HL = scratch destination
    ex      de, hl              ; DE = scratch destination, HL = source
    ld      bc, #256
    ldir

    ; Compute ASIC dest: $4000 + id*256
    pop     af                  ; restore id
    and     #0x0F
    ld      d, a                ; D = id = high byte of (id << 8)
    ld      e, #0
    ld      hl, #0x4000
    add     hl, de              ; HL = $4000 + id*256
    ex      de, hl              ; DE = ASIC dest
    ld      hl, #0xBE00         ; HL = scratch source
    
    di
    ld      bc, #0x7FB8
    out     (c), c              ; ASIC page in
    ld      bc, #256
    ldir

    ld      bc, #0x7FA0
    out     (c), c              ; ASIC page out
    ei

    pop     de                  ; restore source pointer
    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_sprite_set_palette(colours)
; sdcccall(1): colours ptr in HL
; Writes 15 * 2 bytes to ASIC $6422
;------------------------------------------------------------------------------
_cpc_sprite_set_palette::
    push    bc
    push    de
    ; HL = colours ptr. Copy to $B700 scratch first (src may be in $4000-$7FFF
    ; which becomes inaccessible when ASIC is paged in).
    ld      de, #0xB700
    ld      bc, #30             ; 15 colours * 2 bytes
    ldir
    ; Now write from scratch to ASIC $6422
    di
    ld      bc, #0x7FB8
    out     (c), c              ; ASIC page in
    ld      hl, #0xB700
    ld      de, #0x6422
    ld      bc, #30
    ldir
    ld      bc, #0x7FA0
    out     (c), c              ; ASIC page out
    ei
    pop     de
    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_sprite_show(id, visible)
; sdcccall(1): id in A, visible in L
;------------------------------------------------------------------------------
_cpc_sprite_show::
    push    bc
    push    de
    push    hl

    ld      e, l                ; E = visible (save before L is trashed)
    and     #0x0F               ; A = id
    ld      c, a                ; C = id

    ; Update state table: __cpc_sprite_state + id*8 + 5
    add     a, a
    add     a, a
    add     a, a                ; A = id*8
    ld      l, a
    ld      h, #0
    ld      d, h
    ld      hl, #__cpc_sprite_state + 5
    add     hl, de              ; HL = &state[id*8 + 5]
    ld      (hl), e             ; store visible

    ; mag value: visible=1 -> $09 (x2 width, x1 height for Mode 1), visible=0 -> $00
    ld      a, e
    or      a
    jr      Z, 00050$
    ld      e, #0x09
00050$:
    ; ASIC mag register: $6004 + id*8
    ld      a, c                ; A = id
    add     a, a
    add     a, a
    add     a, a                ; id*8
    add     a, #4
    ld      l, a
    ld      h, #0x60

    di
    call    __cpc_pagein_asic
    ld      (hl), e
    call    __cpc_pageout_asic
    ei

    pop     hl
    pop     de
    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_sprite_set_x(id, x)
; sdcccall(1): id in A, x in DE
;------------------------------------------------------------------------------
_cpc_sprite_set_x::
    push    bc
    push    hl

    and     #0x0F               ; A = id
    ld      c, a                ; C = id

    ; Update state: x at offset 0,1
    add     a, a
    add     a, a
    add     a, a                ; id*8
    ld      l, a
    ld      h, #>__cpc_sprite_state
    ld      a, #<__cpc_sprite_state
    add     a, l
    ld      l, a                ; HL = &state[id*8]
    ld      (hl), e             ; x lo
    inc     hl
    ld      (hl), d             ; x hi

    ; ASIC x register: $6000 + id*8
    ld      a, c
    add     a, a
    add     a, a
    add     a, a
    ld      l, a
    ld      h, #0x60

    di
    call    __cpc_pagein_asic
    ld      (hl), e             ; x lo
    inc     hl
    ld      (hl), d             ; x hi
    call    __cpc_pageout_asic
    ei

    pop     hl
    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_sprite_set_y(id, y)
; sdcccall(1): id in A, y in DE (2nd 16-bit argument goes in DE)
;------------------------------------------------------------------------------
_cpc_sprite_set_y::
    push    bc
    push    de

    and     #0x0F               ; A = id
    ld      c, a                ; C = id

    ; Update state: y at offset 2,3
    add     a, a
    add     a, a
    add     a, a                ; id*8
    add     a, #2
    ld      l, a
    ld      h, #>__cpc_sprite_state
    ld      a, #<__cpc_sprite_state
    add     a, l
    ld      l, a                ; HL = &state[id*8+2]
    ld      (hl), e             ; y lo
    inc     hl
    ld      (hl), d             ; y hi

    ; ASIC y register: $6002 + id*8
    ld      a, c
    add     a, a
    add     a, a
    add     a, a
    add     a, #2
    ld      l, a
    ld      h, #0x60

    di
    call    __cpc_pagein_asic
    ld      (hl), e             ; y lo
    inc     hl
    ld      (hl), d             ; y hi
    call    __cpc_pageout_asic
    ei

    pop     de
    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_sprite_move(id, x, y) - convenience wrapper
; sdcccall(1): id in A, x in DE, y in HL (3rd arg - but SDCC may spill)
; NOTE: prefer cpc_sprite_set_x + cpc_sprite_set_y for reliable 2-arg calls
;------------------------------------------------------------------------------
_cpc_sprite_move::
    push    ix
    push    bc
    push    de
    push    hl

    ld      c, a                ; save id
    ; call set_x(id, x): id in A, x in DE
    call    _cpc_sprite_set_x

    ; y was pushed by caller before CALL (3rd sdcccall(1) arg)
    ; after push ix,bc,de,hl (8 bytes):
    ;   sp+0,1=hl_saved, sp+2,3=de_saved, sp+4,5=bc_saved, sp+6,7=ix_saved,
    ;   sp+8,9=ret_addr, sp+10=y_lo, sp+11=y_hi
    ld      ix, #0
    add     ix, sp
    ld      e, 10(ix)           ; y lo into DE
    ld      d, 11(ix)           ; y hi
    ld      a, c
    call    _cpc_sprite_set_y

    pop     hl
    pop     de
    pop     bc
    pop     ix
    ; callee-cleanup: discard y (2 bytes) pushed by caller before CALL
    pop     hl                  ; HL = return address
    inc     sp
    inc     sp                  ; discard y
    jp      (hl)

;------------------------------------------------------------------------------
; _cpc_sprite_set_magnification(id, mag)
; sdcccall(1): id in A, mag in L
;------------------------------------------------------------------------------
_cpc_sprite_set_magnification::
    push    bc

    ld      c, l                ; C = mag
    and     #0x0F               ; A = id

    ; ASIC sprite mag register: $6004 + id*8
    add     a, a
    add     a, a
    add     a, a                ; A = id*8
    add     a, #4
    ld      l, a
    ld      h, #0x60

    di
    call    __cpc_pagein_asic
    ld      (hl), c
    call    __cpc_pageout_asic
    ei

    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_sprite_collides(id_a, id_b, tolerance)
; sdcccall(1): id_a in A, id_b in L, tolerance on stack (1 byte, callee cleans)
; Returns A = 1 if colliding, 0 if not (uint8_t return in A).
; Simple 8-bit bounding-box test using runtime sprite state x/y positions.
;------------------------------------------------------------------------------
_cpc_sprite_collides::
    push    ix
    push    bc
    push    de

    ld      ix, #0
    add     ix, sp              ; 3 pushes (6) + ret (2) = 8; tolerance at +8

    ; --- get sprite A x,y (8-bit) from state table ---
    and     #0x0F               ; id_a (in A on entry)
    add     a, a
    add     a, a
    add     a, a                ; id_a * 8
    ld      e, a
    ld      d, #0
    push    hl                  ; save L = id_b
    ld      hl, #__cpc_sprite_state
    add     hl, de              ; HL = &state[id_a*8]
    ld      b, (hl)             ; B = ax lo
    inc     hl
    inc     hl
    ld      c, (hl)             ; C = ay lo
    pop     hl                  ; L = id_b

    ; --- get sprite B x,y ---
    ld      a, l
    and     #0x0F               ; id_b
    add     a, a
    add     a, a
    add     a, a                ; id_b * 8
    ld      e, a                ; D still 0
    ld      hl, #__cpc_sprite_state
    add     hl, de              ; HL = &state[id_b*8]
    ld      a, (hl)             ; bx lo
    inc     hl
    inc     hl
    ld      e, (hl)             ; E = by lo

    ; |ax - bx|
    sub     b
    jp      P, 00030$
    neg
00030$:
    ld      d, a                ; D = |dx|

    ; |ay - by|
    ld      a, e
    sub     c
    jp      P, 00031$
    neg
00031$:                         ; A = |dy|

    ; Collide if |dx| < tolerance AND |dy| < tolerance
    ld      e, 8 (ix)           ; E = tolerance
    cp      e
    jp      NC, 00032$          ; |dy| >= tolerance: no collide
    ld      a, d
    cp      e
    jp      NC, 00032$          ; |dx| >= tolerance: no collide

    pop     de
    pop     bc
    pop     ix
    ld      a, #1               ; return 1 (uint8_t in A)
    pop     hl                  ; return address
    inc     sp                  ; callee cleanup: discard tolerance byte
    jp      (hl)
00032$:
    pop     de
    pop     bc
    pop     ix
    xor     a                   ; return 0
    pop     hl                  ; return address
    inc     sp                  ; callee cleanup: discard tolerance byte
    jp      (hl)
