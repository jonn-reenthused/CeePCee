;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_scroll.s  v2
; Hardware tilemap horizontal scroll engine for CPC+/GX4000
;
; ============================================================================
; DESIGN
; ============================================================================
;
; Tile format: 8x8 px, Mode 0, 4 bytes/row * 8 rows = 32 bytes/tile.
; Screen:      160x200 px = 20 tiles wide * 25 tiles tall.
;
; VRAM ring buffer -- standard stride 80, R0/R1 unchanged.
;
;   The CPC VRAM is a flat 16KB ring of 8192 CRTC chars.
;   With crtc_offset=N, visible scan-line bytes are at:
;     $C000 + N*2  ..  $C000 + N*2 + 79
;   The off-screen write slot is always 40 chars (80 bytes) ahead:
;     write_slot_base = $C000 + (N+40)*2  (mod 8192 chars)
;   As N advances, the ring slides and the previously-written slot
;   becomes the new rightmost visible column exactly one tile later.
;
;   VRAM address for tile column tx (0..19) + write slot (tx=20 = N+40):
;   For tile row ty, pixel row r, char offset ch = N + tx*2:
;     addr = $C000 + ((ch + r_offset) & 0x1FFF) * 2
;   where r_offset = r * (2048/2) = r * 1024  (chars per 2048 bytes)
;
;   Simplified: write slot for tile row ty, pixel row r:
;     addr = $C000 + ty*80 + r*2048 + tx*4   using stride=80
;   BUT the write-slot tx=vram_col must use the CRTC-ring address:
;     addr = $C000 + (vram_col_chars + r*1024) * 2
;   where vram_col_chars = crtc_offset + 40  (always off-screen to the right).
;
;   For draw_initial, crtc_offset=0 so:
;     col 0  -> vram_col_chars=0  -> $C000 + 0  + r*2048
;     col 1  -> vram_col_chars=2  -> $C000 + 4  + r*2048
;     ...
;     col 19 -> vram_col_chars=38 -> $C000 + 76 + r*2048
;     buffer -> vram_col_chars=40 -> $C000 + 80 + r*2048
;
;   The +80 byte for the buffer wraps into the NEXT tile-row scanline in
;   the standard 80-stride layout -- but in the CRTC's linear address
;   space it is simply char 40, which is never displayed with R1=40. ✓
;
;   VRAM address for draw_column (absolute CRTC ring):
;     For pixel row r:  $C000 + (vram_col_chars + r*1024)*2  (mod $4000)
;   where vram_col_chars = __sc_vram_col (16-bit, wraps at 8192)
;
; CRTC R12/R13 screen-start offset (in CRTC chars, $C000 base):
;   base = $C000  ->  R12 = $30, R13 = $00  ->  offset = 0
;   After scrolling N chars right:  offset = N  (wraps within 16KB = 8192 chars)
;   The visible scan line starts at  $C000 + offset*2.
;
; Fine scroll (ASIC $6804 bits 3..0, Mode-2 pixel units):
;   1 Mode-0 pixel = 4 Mode-2 units.  Scrolling right by dx Mode-0 pixels:
;     fine_x  -= dx*4   (wraps 0..15, add 16 on underflow)
;     On underflow:  crtc_offset += 1
;     Every 2 such underflows (= 1 CRTC char pair = 4 bytes = 8 px = 1 tile):
;       signal caller to call draw_column once.
;
; draw_column writes into the off-screen 21st column slot for each tile row.
; After writing, the slot index wraps: (vram_col+1) % 21.
; vram_col is the RING INDEX (0..20) of the next write slot.
;
; Off-screen slot address for tile row ty, pixel row r:
;   $C000 + ty*84 + r*2048 + vram_col*4
;
; ============================================================================
; STATE  at $B740
; ============================================================================

    .module cpc_scroll

    .globl  _cpc_scroll_set
    .globl  _cpc_scroll_set_fine
    .globl  _cpc_scroll_disable
    .globl  _cpc_scroll_tilemap_init
    .globl  _cpc_scroll_tilemap_draw_initial
    .globl  _cpc_scroll_tilemap_tick
    .globl  _cpc_scroll_tilemap_draw_column

    .area   _CEEPCEE_SCROLL (ABS)
    .org    0xB740

__sc_tile_gfx::     .ds 2   ; ptr to tile graphics
__sc_map_data::     .ds 2   ; ptr to map data
__sc_map_width::    .ds 1   ; map width in tiles
__sc_map_height::   .ds 1   ; map height in tiles (must be <= 25)

__sc_crtc_offset::  .ds 2   ; CRTC screen-start offset (chars, no $30 bias)
__sc_fine_x::       .ds 1   ; ASIC $6804 fine-scroll value (0..15)
__sc_char_count::   .ds 1   ; chars advanced mod 2 (reaches 2 -> draw column)

__sc_map_col::      .ds 2   ; next map column index to blit (wraps at map_width)
__sc_vram_col::     .ds 2   ; absolute CRTC char offset of write slot
                            ; = crtc_offset + 40, advances +2 per draw_column

; draw_column scratch
__sc_dc_ty::        .ds 1
__sc_dc_map_ptr::   .ds 2
__sc_dc_vram_base:: .ds 2   ; $C000 + ty*84 + vram_col*4
__sc_dc_vram_ptr::  .ds 2   ; running scanline ptr within tile
__sc_dc_tile_src::  .ds 2
__sc_dc_retaddr::   .ds 2   ; saved return address for init

;==============================================================================
    .area   _CODE

; ─────────────────────────────────────────────────────────────────────────────
; __sc_write_crtc_hl
; Write HL as CRTC R12:R13 screen-start ($C000 base = OR $30 into high byte).
; Corrupts: A, BC
; ─────────────────────────────────────────────────────────────────────────────
__sc_write_crtc_hl::
    ld      a, h
    or      #0x30
    ld      bc, #0xBC0C
    out     (c), c          ; select R12
    inc     b               ; $BD
    out     (c), a          ; write R12
    dec     b               ; $BC
    inc     c               ; select R13
    out     (c), c
    inc     b               ; $BD
    ld      a, l
    out     (c), a          ; write R13
    ret

; ─────────────────────────────────────────────────────────────────────────────
; __sc_write_asic_6804
; Write A to ASIC $6804 (caller must hold DI).
; Corrupts: BC
; ─────────────────────────────────────────────────────────────────────────────
__sc_write_asic_6804::
    ld      bc, #0x7FB8
    out     (c), c          ; ASIC page-in
    ld      (0x6804), a
    ld      bc, #0x7FA0
    out     (c), c          ; ASIC page-out
    ret

; ─────────────────────────────────────────────────────────────────────────────
; _cpc_scroll_set / _cpc_scroll_set_fine / _cpc_scroll_disable
; Low-level public API (used independently of tilemap engine if needed).
; ─────────────────────────────────────────────────────────────────────────────
_cpc_scroll_set::
    push    bc
    push    de
    push    hl
    ld      b, a                ; B = x_chars
    ld      h, #0               ; HL = y_chars
    add     hl, hl              ; *2
    ld      d, h
    ld      e, l
    add     hl, hl              ; *4
    add     hl, hl              ; *8
    add     hl, de              ; *10
    add     hl, hl              ; *20
    add     hl, hl              ; *40
    ld      d, #0
    ld      e, b
    add     hl, de
    call    __sc_write_crtc_hl
    pop     hl
    pop     de
    pop     bc
    ret

_cpc_scroll_set_fine::
    push    bc
    add     a, a
    add     a, a
    and     #0x0F
    ld      b, a
    ld      a, l
    and     #0x07
    add     a, a
    add     a, a
    add     a, a
    add     a, a
    or      b
    di
    call    __sc_write_asic_6804
    ei
    pop     bc
    ret

_cpc_scroll_disable::
    push    bc
    ld      hl, #0
    call    __sc_write_crtc_hl
    xor     a
    di
    call    __sc_write_asic_6804
    ei
    pop     bc
    ret

; ─────────────────────────────────────────────────────────────────────────────
; _cpc_scroll_tilemap_init(tile_gfx, map_data, map_dims)
; sdcccall(1): HL=tile_gfx, DE=map_data, map_dims on stack
; Stack on entry: [SP+0]=retaddr  [SP+2]=map_dims (lo=width, hi=height)
;
; Sets CRTC R0=41 (stride 84), resets R12/R13 to $C000, clears ASIC scroll.
; Call with interrupts disabled.
; ─────────────────────────────────────────────────────────────────────────────
_cpc_scroll_tilemap_init::
    ld      (__sc_tile_gfx), hl
    ld      (__sc_map_data), de
    pop     hl                  ; return address
    ld      (__sc_dc_retaddr), hl
    pop     de                  ; E=map_width, D=map_height
    ld      a, e
    ld      (__sc_map_width), a
    ld      a, d
    ld      (__sc_map_height), a

    ; Zero scroll state
    xor     a
    ld      (__sc_fine_x), a
    ld      (__sc_char_count), a
    ld      hl, #0
    ld      (__sc_crtc_offset), hl
    ld      (__sc_map_col), hl

    ; vram_col = 0: draw_initial fills chars 0,2..40 (20 visible + 1 buffer)
    ld      hl, #0
    ld      (__sc_vram_col), hl

    ; CRTC R12/R13 = 0 ($C000)
    ld      hl, #0
    call    __sc_write_crtc_hl

    ; ASIC fine scroll = 0
    xor     a
    call    __sc_write_asic_6804

    ld      hl, (__sc_dc_retaddr)
    jp      (hl)

; ─────────────────────────────────────────────────────────────────────────────
; _cpc_scroll_tilemap_draw_initial()
; Blit 21 columns (20 visible + 1 off-screen buffer) into VRAM.
; Call with interrupts disabled.
; ─────────────────────────────────────────────────────────────────────────────
_cpc_scroll_tilemap_draw_initial::
    push    bc
    push    de
    push    hl
    ; Draw 21 columns into VRAM slots 0,2,4..40
    ; Set vram_col explicitly before each draw_column call
    ld      hl, #0          ; vram_col starts at slot 0
    ld      b, #21          ; draw all 21 slots (20 visible + 1 off-screen right)
__sdi_col_loop:
    push    bc
    ld      (__sc_vram_col), hl
    call    _cpc_scroll_tilemap_draw_column
    ld      hl, (__sc_vram_col)
    inc     hl              ; advance slot index by 1
    pop     bc
    djnz    __sdi_col_loop
    pop     hl
    pop     de
    pop     bc
    ret

; ─────────────────────────────────────────────────────────────────────────────
; _cpc_scroll_tilemap_tick(dx)
; sdcccall(1): A = dx (Mode-0 pixels to scroll, 1..4)
; Returns A = 1 if a new column must be drawn, 0 otherwise.
; Call at vsync with interrupts disabled.
;
; Updates ASIC fine-scroll and CRTC screen-start.
; Does NOT draw anything -- caller draws the column during active display.
; ─────────────────────────────────────────────────────────────────────────────
_cpc_scroll_tilemap_tick::
    push    bc
    push    de
    push    hl

    ; A = dx (1..4 Mode-0 pixels). step = dx*4 Mode-2 units.
    ; Matches reference pscrlhrz.asm: decrement fine_x by step, AND $0F to wrap.
    ; When fine_x wraps (carry set), advance crtc_offset by 1 char.
    add     a, a
    add     a, a            ; A = step (4..16)

    ld      b, a            ; B = step
    ld      a, (__sc_fine_x)
    sub     b               ; fine_x -= step; carry set if underflow (wrapped)
    jp      c, __sc_tick_wrapped
    and     #0x0F
    ld      (__sc_fine_x), a
    ld      c, #0
    jr      __sc_tick_hw

__sc_tick_wrapped:
    add     a, #16          ; bring back into 0..15 range
    and     #0x0F
    ld      (__sc_fine_x), a
    ld      c, #0

    ; Advance crtc_offset, wrap at 42 (21 slots * 2 chars)
    ld      hl, (__sc_crtc_offset)
    inc     hl
    ld      a, l
    cp      #42
    jr      c, __sc_tick_crtc_ok
    ld      hl, #0
__sc_tick_crtc_ok:
    ld      (__sc_crtc_offset), hl

    ; char_count: every 2 chars = 1 tile width
    ld      a, (__sc_char_count)
    inc     a
    cp      #2
    jr      c, __sc_tick_no_col
    xor     a
    ld      (__sc_char_count), a    ; reset count to 0 before A is clobbered
    ld      c, #1
    ; vram_col = (crtc_offset + 40) % 42 / 2 -- slot just past the right edge
    ; At crtc_offset=N, visible slots cover chars N..N+39.
    ; Slot at chars N+40..N+41 is 1 tile off-screen right -- write new tile there.
    ld      a, (__sc_crtc_offset)
    add     a, #40
    cp      #42
    jr      c, __sc_tick_vcol_ok
    sub     #42
__sc_tick_vcol_ok:
    rrca                    ; /2 -> slot index 0..20
    ld      l, a
    ld      h, #0
    ld      (__sc_vram_col), hl
    jr      __sc_tick_hw
__sc_tick_no_col:
    ld      (__sc_char_count), a

__sc_tick_hw:
    ; Write ASIC fine scroll ($6804 bits 3..0)
    ld      a, (__sc_fine_x)
    call    __sc_write_asic_6804

    ; Write CRTC R12/R13 screen start
    ld      hl, (__sc_crtc_offset)
    call    __sc_write_crtc_hl

    ld      a, c

    pop     hl
    pop     de
    pop     bc
    ret

; ─────────────────────────────────────────────────────────────────────────────
; _cpc_scroll_tilemap_draw_column()
; Blit one map column (__sc_map_col) into VRAM ring slot __sc_vram_col.
;
; VRAM address per scanline r:  ($C000 + (vram_col + r*1024)*2) & $FFFF
;   vram_col is the absolute CRTC char offset of the write slot.
;
; After blitting: map_col = (map_col+1) % map_width
;                 vram_col = (vram_col+2) & 0x1FFF
;
; Call with interrupts disabled (or during active display when ASIC not needed).
; ─────────────────────────────────────────────────────────────────────────────
_cpc_scroll_tilemap_draw_column::
    push    bc
    push    de
    push    hl
    push    ix

    ; ── map pointer: map_data + map_col ──────────────────────────────────────
    ld      hl, (__sc_map_data)
    ld      de, (__sc_map_col)
    add     hl, de
    ld      (__sc_dc_map_ptr), hl

    ; ── VRAM base for ty=0, r=0: $C000 + vram_col*4 ─────────────────────────
    ; vram_col is slot index 0..19; addr = $C000 + ty*80 + vram_col*4
    ld      hl, (__sc_vram_col)
    add     hl, hl
    add     hl, hl          ; * 4
    ld      de, #0xC000
    add     hl, de
    ld      (__sc_dc_vram_base), hl

    ; ── outer loop: ty = 0 .. map_height-1 ───────────────────────────────────
    xor     a
    ld      (__sc_dc_ty), a

__sc_dc_ty_loop:
    ; fetch tile_id, advance map_ptr by map_width
    ld      hl, (__sc_dc_map_ptr)
    ld      a, (hl)         ; A = tile_id
    ld      c, a            ; save tile_id
    ld      a, (__sc_map_width)
    ld      e, a
    ld      d, #0
    add     hl, de
    ld      (__sc_dc_map_ptr), hl
    ld      a, c            ; restore tile_id

    ; tile_src = tile_gfx + tile_id * 32
    ld      l, a
    ld      h, #0
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl          ; * 32
    ld      de, (__sc_tile_gfx)
    add     hl, de
    ld      (__sc_dc_tile_src), hl

    ; vram_ptr = vram_base (scanline 0 of this tile row)
    ld      hl, (__sc_dc_vram_base)
    ld      (__sc_dc_vram_ptr), hl

    ; ── inner loop: r = 0..7 (8 scanlines per tile) ──────────────────────────
    ld      b, #8
__sc_dc_row_loop:
    push    bc

    ; IX = VRAM dst for this scanline
    ld      hl, (__sc_dc_vram_ptr)
    push    hl
    pop     ix

    ; copy 4 bytes from tile_src
    ld      hl, (__sc_dc_tile_src)
    ld      a, (hl)
    ld      0(ix), a
    inc     hl
    ld      a, (hl)
    ld      1(ix), a
    inc     hl
    ld      a, (hl)
    ld      2(ix), a
    inc     hl
    ld      a, (hl)
    ld      3(ix), a
    inc     hl
    ld      (__sc_dc_tile_src), hl

    ; next scanline: vram_ptr += 2048
    ld      hl, (__sc_dc_vram_ptr)
    ld      de, #2048
    add     hl, de
    ld      (__sc_dc_vram_ptr), hl

    pop     bc
    djnz    __sc_dc_row_loop

    ; next tile row: vram_base += 80 bytes
    ld      hl, (__sc_dc_vram_base)
    ld      de, #80
    add     hl, de
    ld      (__sc_dc_vram_base), hl

    ; ty++, continue while ty < map_height
    ld      a, (__sc_dc_ty)
    inc     a
    ld      (__sc_dc_ty), a
    ld      b, a
    ld      a, (__sc_map_height)
    cp      b
    jp      nz, __sc_dc_ty_loop

    ; ── advance map_col: (map_col+1) % map_width ─────────────────────────────
    ld      hl, (__sc_map_col)
    inc     hl
    ld      a, (__sc_map_width)
    ld      e, a
    ld      d, #0
    ld      a, h
    cp      d
    jr      nz, __sc_dc_mapcol_ok
    ld      a, l
    cp      e
    jr      c, __sc_dc_mapcol_ok
    ld      hl, #0
__sc_dc_mapcol_ok:
    ld      (__sc_map_col), hl

    ; vram_col is set by tick, not modified here

    pop     ix
    pop     hl
    pop     de
    pop     bc
    ret
