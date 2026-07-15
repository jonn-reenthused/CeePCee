;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_tilemap.s
; Tilemap engine
;
; Tile format: 8x8 pixels, Mode 0, 4 bytes/row x 8 rows = 32 bytes/tile.
; Screen:      160x200 pixels = 20 tiles wide x 25 tiles tall.
;
; VRAM address for tile (tx, ty), pixel row r (0-7):
;   $C000 + ty*80 + r*2048 + tx*4
;
; State stored in fixed RAM at $B720 (above SDK state + $B700 scratch).
;

    .module cpc_tilemap
    .globl  _cpc_tilemap_init
    .globl  _cpc_tilemap_draw
    .globl  _cpc_tilemap_get
    .globl  _cpc_tilemap_set

;==============================================================================
; Tilemap state block at $B720
;==============================================================================
    .area   _CEEPCEE_TILEMAP (ABS)
    .org    0xB720

__tm_tile_gfx::     .ds 2   ; pointer to tile graphics data
__tm_map_data::     .ds 2   ; pointer to map data
__tm_map_width::    .ds 1   ; map width in tiles
__tm_map_height::   .ds 1   ; map height in tiles
__tm_scroll_x::     .ds 1
__tm_scroll_y::     .ds 1
__tm_ty_cur::       .ds 1
__tm_tx_cur::       .ds 1
__tm_row_cur::      .ds 1
__tm_tile_id::      .ds 1
__tm_map_row_ptr::  .ds 2
__tm_vram_ty_base:: .ds 2
__tm_vram_tx_base:: .ds 2
__tm_tile_src::     .ds 2

;==============================================================================
    .area   _CODE

;------------------------------------------------------------------------------
; _cpc_tilemap_init(tile_gfx, map_data, map_dims)
; sdcccall(1): HL=tile_gfx, DE=map_data, map_dims on stack
; SDCC call sequence: push map_dims / ld de,map_data / ld hl,tile_gfx / call
; On entry stack: [SP+0]=retaddr [SP+2]=map_dims(lo=width, hi=height)
;
; Strategy: save HL/DE, pop retaddr into BC, pop map_dims into HL, jp (BC)
;------------------------------------------------------------------------------
_cpc_tilemap_init::
    ld      (__tm_tile_gfx), hl
    ld      (__tm_map_data), de
    pop     hl                  ; HL = return address
    pop     de                  ; DE = map_dims (E=width, D=height)
    ld      a, e
    ld      (__tm_map_width), a
    ld      a, d
    ld      (__tm_map_height), a
    jp      (hl)

;------------------------------------------------------------------------------
; _cpc_tilemap_draw(scroll_x, scroll_y)
; sdcccall(1): A=scroll_x (uint8_t), L=scroll_y (uint8_t)
;
; Draws the full 20x25 tile viewport to VRAM.
; VRAM address for tile (tx,ty) pixel row r: $C000 + ty*80 + r*2048 + tx*4
;
; Uses RAM variables to avoid register pressure and stack confusion.
;------------------------------------------------------------------------------
_cpc_tilemap_draw::
    push    bc
    push    de
    push    hl
    push    ix
    push    iy

    ld      (__tm_scroll_x), a
    ld      a, l
    ld      (__tm_scroll_y), a

    ; ty loop: ty = 0..24
    xor     a
    ld      (__tm_ty_cur), a
__td_ty_loop:
    ; map_row = scroll_y + ty
    ld      a, (__tm_scroll_y)
    ld      b, a
    ld      a, (__tm_ty_cur)
    add     a, b                    ; A = map_row

    ; HL = map_row * map_width  (8-bit multiply)
    ld      b, a                    ; B = map_row
    ld      a, (__tm_map_width)
    ld      c, a                    ; C = map_width
    ld      hl, #0
    ld      a, b
    or      a
    jr      z, __td_mul_done
__td_mul:
    ld      b, #0
    add     hl, bc
    dec     a
    jr      nz, __td_mul
__td_mul_done:
    ld      a, (__tm_scroll_x)
    ld      e, a
    ld      d, #0
    add     hl, de
    ld      de, (__tm_map_data)
    add     hl, de
    ld      (__tm_map_row_ptr), hl  ; map row ptr for this ty

    ; vram_ty_base = $C000 + ty * 80
    ld      a, (__tm_ty_cur)
    ld      l, a
    ld      h, #0
    add     hl, hl                  ; *2
    ld      d, h
    ld      e, l
    add     hl, hl                  ; *4
    add     hl, hl                  ; *8
    add     hl, de                  ; *10
    add     hl, hl                  ; *20
    add     hl, hl                  ; *40
    add     hl, hl                  ; *80
    ld      de, #0xC000
    add     hl, de
    ld      (__tm_vram_ty_base), hl

    ; tx loop: tx = 0..19
    xor     a
    ld      (__tm_tx_cur), a
__td_tx_loop:
    ; fetch tile_id from map
    ld      hl, (__tm_map_row_ptr)
    ld      a, (hl)
    inc     hl
    ld      (__tm_map_row_ptr), hl
    ld      (__tm_tile_id), a

    ; tile_src = tile_gfx + tile_id * 32
    ld      l, a
    ld      h, #0
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl                  ; *32
    ld      de, (__tm_tile_gfx)
    add     hl, de
    ld      (__tm_tile_src), hl

    ; vram_tx_base = vram_ty_base + tx*4
    ld      a, (__tm_tx_cur)
    ld      l, a
    ld      h, #0
    add     hl, hl
    add     hl, hl                  ; *4
    ld      de, (__tm_vram_ty_base)
    add     hl, de
    ld      (__tm_vram_tx_base), hl

    ; row loop: r = 0..7
    xor     a
    ld      (__tm_row_cur), a
__td_row_loop:
    ; vram_dst = vram_tx_base + r*2048
    ld      a, (__tm_row_cur)
    ld      l, a
    ld      h, #0
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl                  ; *2048
    ld      de, (__tm_vram_tx_base)
    add     hl, de                  ; HL = vram dst

    ; tile_src pointer
    ld      de, (__tm_tile_src)
    push    de
    pop     iy                      ; IY = tile src

    ; copy 4 bytes: 0(IY)..3(IY) -> (HL)
    ld      a, 0(iy)
    ld      (hl), a
    inc     hl
    ld      a, 1(iy)
    ld      (hl), a
    inc     hl
    ld      a, 2(iy)
    ld      (hl), a
    inc     hl
    ld      a, 3(iy)
    ld      (hl), a

    ; tile_src += 4
    ld      hl, (__tm_tile_src)
    ld      de, #4
    add     hl, de
    ld      (__tm_tile_src), hl

    ; row_cur++, loop while < 8
    ld      a, (__tm_row_cur)
    inc     a
    ld      (__tm_row_cur), a
    cp      #8
    jp      c, __td_row_loop

    ; tx_cur++, loop while < 20
    ld      a, (__tm_tx_cur)
    inc     a
    ld      (__tm_tx_cur), a
    cp      #20
    jp      c, __td_tx_loop

    ; ty_cur++, loop while < 25
    ld      a, (__tm_ty_cur)
    inc     a
    ld      (__tm_ty_cur), a
    cp      #25
    jp      c, __td_ty_loop

    pop     iy
    pop     ix
    pop     hl
    pop     de
    pop     bc
    ret


;------------------------------------------------------------------------------
; _cpc_tilemap_get(col, row) -> uint8_t
; sdcccall(1): A=col, L=row
; Returns tile index in A.
;------------------------------------------------------------------------------
    .area   _CODE
_cpc_tilemap_get::
    push    bc
    push    de
    push    hl

    ld      b, a                    ; B = col
    ld      c, l                    ; C = row

    ; HL = row * map_width
    ld      a, (__tm_map_width)
    ld      d, #0
    ld      e, a                    ; DE = map_width
    ld      h, #0
    ld      l, c                    ; HL = row
    ; multiply HL * DE
    ld      c, h
    ld      a, l                    ; A = row
    ld      hl, #0
    or      a
    jr      z, .get_mul_done
.get_mul_loop:
    add     hl, de
    dec     a
    jr      nz, .get_mul_loop
.get_mul_done:
    ; HL = row * map_width + col
    ld      a, b
    ld      d, #0
    ld      e, a
    add     hl, de

    ld      de, (__tm_map_data)
    add     hl, de
    ld      a, (hl)                 ; A = tile_id

    pop     hl
    pop     de
    pop     bc
    ret

;------------------------------------------------------------------------------
; _cpc_tilemap_set(col, row, tile_id)
; sdcccall(1): A=col, L=row, E=tile_id (uint8_t 3rd arg goes in E for sdcccall1)
; Actually for 3 uint8_t args: A=col, L=row, C(or E)=tile_id.
; SDCC sdcccall(1): arg0=A, arg1=L, arg2=C
;------------------------------------------------------------------------------
_cpc_tilemap_set::
    push    bc
    push    de
    push    hl

    push    bc                      ; save C (tile_id) on stack temporarily
    ld      b, a                    ; B = col

    ld      a, (__tm_map_width)
    ld      d, #0
    ld      e, a
    ld      h, #0
    ld      a, l                    ; A = row
    ld      l, #0
    or      a
    jr      z, .set_mul_done
.set_mul_loop:
    add     hl, de
    dec     a
    jr      nz, .set_mul_loop
.set_mul_done:
    ld      a, b
    ld      d, #0
    ld      e, a
    add     hl, de

    ld      de, (__tm_map_data)
    add     hl, de

    pop     bc                      ; restore BC (C = tile_id)
    ld      (hl), c

    pop     hl
    pop     de
    pop     bc
    ret
