;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_text.s
; Text rendering (Mode 0 / Mode 1, 8x8 font)
;
; Screen address for character (col, row) in Mode 1 ($C000 base):
;   Each character is 8 pixels tall x 8 pixels wide.
;   Mode 1: 320px wide = 40 chars/row; 200px tall = 25 rows.
;   Screen address = $C000 + row*8*80 + col*2
;   (80 bytes/line, 8 lines per char row, 2 bytes per char width in Mode 1)
;
; Font: 8x8 bitmaps, 1 bit per pixel. Glyph for char c = font_base + (c - first_char)*8.
; Default font is the CPC firmware ROM font at lower-ROM address $3A00 (mapped at $BA00).
; We copy it to RAM during init.
;

    .module cpc_text
    .globl  _cpc_text_print
    .globl  _cpc_text_putc
    .globl  _cpc_text_clear
    .globl  _cpc_text_set_ink
    .globl  _cpc_text_set_paper
    .globl  _cpc_text_set_font
    .globl  _cpc_text_use_firmware_font
    .globl  _cpc_builtin_font
    .globl  __cpc_text_ink
    .globl  __cpc_text_paper
    .globl  __cpc_font_ptr
    .globl  __cpc_font_width
    .globl  __cpc_font_height
    .globl  __cpc_font_first
    .globl  __cpc_text_col
    .globl  __cpc_text_row
    .globl  __cpc_text_tmp
    .globl  __cpc_text_tmp2

    .area   _CEEPCEE_TEXT (ABS)
    .org    0xB200
_font_ram:: .ds 768             ; 96 chars * 8 bytes (not used - font ptr points to ROM copy)
__cpc_text_col:: .ds 1
__cpc_text_row:: .ds 1
__cpc_text_tmp:: .ds 1
__cpc_text_tmp2:: .ds 1

    .area   _CODE

;------------------------------------------------------------------------------
; _cpc_text_clear(col, row, n)  sdcccall(1)
; Zero n character cells at (col, row) across all 8 scan lines.
; A = col, L = row, n pushed on stack (1 byte, padded to 2).
;------------------------------------------------------------------------------
_cpc_text_clear::
    push    ix
    push    bc
    push    de
    push    hl

    ; Save col (A) and row (L) before clobbering them.
    ld      (__cpc_text_col), a
    ld      a, l
    ld      (__cpc_text_row), a

    ; Compute base screen address: $C000 + row*80 + col*font_width
    ld      a, (__cpc_text_row)
    ld      h, #0
    ld      l, a                ; HL = row
    add     hl, hl              ; *2
    add     hl, hl              ; *4
    add     hl, hl              ; *8
    add     hl, hl              ; *16
    ld      b, h
    ld      c, l                ; BC = row*16
    add     hl, hl              ; *32
    add     hl, hl              ; *64
    add     hl, bc              ; HL = row*80

    ld      a, (__cpc_text_col)
    ld      e, a
    ld      d, #0               ; DE = col
    ld      a, (__cpc_font_width)
00058$:
    add     hl, de
    dec     a
    jr      NZ, 00058$          ; HL += col*font_width

    ld      bc, #0xC000
    add     hl, bc              ; HL = screen base address
    ld      a, l
    ld      (__cpc_text_tmp), a ; save screen address low byte
    ld      a, h
    ld      (__cpc_text_tmp2), a; save screen address high byte

    ; Fetch n from stack
    ld      ix, #0
    add     ix, sp
    ; ix+0,1 = HL; ix+2,3 = DE; ix+4,5 = BC; ix+6,7 = IX; ix+8,9 = ret; ix+10 = n
    ld      a, 10 (ix)          ; A = n (number of chars)
    ld      e, a
    ld      d, #0               ; DE = n
    ld      hl, #0
    ld      a, (__cpc_font_width)
00059$:
    add     hl, de
    dec     a
    jr      NZ, 00059$          ; HL = n*font_width
    ld      c, l                ; C = byte width (n*font_width, fits in 8 bits)

    ; Restore screen address into HL
    ld      a, (__cpc_text_tmp)
    ld      l, a
    ld      a, (__cpc_text_tmp2)
    ld      h, a

    ; 8 scan lines
    ld      b, #8
00060$:
    push    bc
    push    hl
    ; zero C bytes at HL
    ld      b, c
    ld      a, #0
00061$:
    ld      (hl), a
    inc     hl
    djnz    00061$

    pop     hl
    pop     bc

    ; advance HL to next scan line (CPC interleave: +$0800, wrap at $38xx)
    ld      a, h
    add     a, #8
    ld      h, a
    and     #0x38
    jr      NZ, 00062$
    ld      a, l
    add     a, #0x50
    ld      l, a
    ld      a, h
    adc     a, #0xC0
    ld      h, a
00062$:
    djnz    00060$

    pop     hl
    pop     de
    pop     bc
    pop     ix
    ; discard n from stack (1 byte pushed by compiler)
    pop     hl
    inc     sp
    jp      (hl)

;------------------------------------------------------------------------------
; _cpc_text_set_ink(pen) - sdcccall(1): pen in A
;------------------------------------------------------------------------------
_cpc_text_set_ink::
    ld      (__cpc_text_ink), a
    ret

;------------------------------------------------------------------------------
; _cpc_text_set_paper(pen) - sdcccall(1): pen in A
;------------------------------------------------------------------------------
_cpc_text_set_paper::
    ld      (__cpc_text_paper), a
    ret

;------------------------------------------------------------------------------
; _cpc_text_set_font(font_data, char_width, char_height, first_char)
; sdcccall(1): font_data in HL, char_width in A,
;              char_height and first_char pushed on stack (1 byte each).
;------------------------------------------------------------------------------
_cpc_text_set_font::
    push    ix
    push    bc
    push    de
    push    hl                  ; save font_data ptr (was in HL on entry)

    ; char_width is in A on entry (sdcccall(1) 2nd 8-bit arg)
    ld      (__cpc_font_width), a

    ; Read char_height and first_char from stack.
    ; Stack on entry: [ret] [char_width(1)] [char_height(1)] [first_char(1)]
    ; (char_width is also passed in A, but the compiler pushes a padding byte)
    ; After push ix,bc,de,hl (8 bytes): ix+0,1=HL; ix+2,3=DE; ix+4,5=BC; ix+6,7=IX;
    ; ix+8,9=ret; ix+10=char_width padding; ix+11=char_height; ix+12=first_char
    ld      ix, #0
    add     ix, sp

    ld      a, 12 (ix)          ; first_char
    ld      (__cpc_font_first), a
    ld      a, 11 (ix)          ; char_height
    ld      (__cpc_font_height), a

    ld      l, 0 (ix)           ; font_data lo
    ld      h, 1 (ix)           ; font_data hi
    ld      (__cpc_font_ptr), hl

    pop     hl
    pop     de
    pop     bc
    pop     ix
    ; discard 3 bytes of args pushed by compiler (char_height, first_char, char_width)
    pop     hl                  ; return address
    inc     sp
    inc     sp
    inc     sp
    jp      (hl)

;------------------------------------------------------------------------------
; _cpc_text_use_firmware_font()
; Point the font system at the built-in 8x8 font (ASCII 32-127).
; The GX4000 has no firmware ROM, so we use _cpc_builtin_font from
; cpc_font_data.s which is linked into the binary.
;------------------------------------------------------------------------------
_cpc_text_use_firmware_font::
    ld      hl, #_cpc_builtin_font
    ld      (__cpc_font_ptr), hl
    ld      a, #8
    ld      (__cpc_font_height), a
    ld      a, #2               ; Mode 1: 8 pixels wide = 2 screen bytes
    ld      (__cpc_font_width), a
    ld      a, #32              ; first char = ASCII space
    ld      (__cpc_font_first), a
    ret

;------------------------------------------------------------------------------
; _cpc_text_print(col, row, str)  sdcccall(1)
; A = col, L = row, str pushed on stack (2 bytes).
;------------------------------------------------------------------------------
_cpc_text_print::
    push    bc
    push    de
    push    hl
    push    ix

    ; Keep col and row in registers only (no shared SDK state variables).
    ; Save col on the stack while computing row*80, then restore it for
    ; the col*font_width multiplication. This avoids any chance of stale
    ; values from __cpc_text_col / __cpc_text_row being used.
    ld      b, l                ; B = row
    push    af                  ; save col on stack (A = col on entry)

    ; Screen address: $C000 + row*80 + col*font_width
    ; Compute row*80 using B = row
    ld      l, b
    ld      h, #0
    add     hl, hl              ; *2
    add     hl, hl              ; *4
    add     hl, hl              ; *8
    add     hl, hl              ; *16
    ld      c, l
    ld      b, h                ; BC = row*16
    add     hl, hl              ; *32
    add     hl, hl              ; *64
    add     hl, bc              ; HL = row*80

    ; Restore col and compute col*font_width
    pop     af                  ; A = col
    ld      c, a
    ld      b, #0               ; BC = col
    ld      a, (__cpc_font_width)
00038$:
    add     hl, bc
    dec     a
    jr      NZ, 00038$
    ld      bc, #0xC000
    add     hl, bc              ; HL = screen address

    ; Fetch str pointer from stack
    ld      ix, #0
    add     ix, sp
    ; ix+0,1 = IX; ix+2,3 = HL; ix+4,5 = DE; ix+6,7 = BC; ix+8,9 = ret; ix+10,11 = str
    ld      e, 10 (ix)
    ld      d, 11 (ix)          ; DE = str ptr

    ; Print loop: DE=str ptr, HL=screen addr
00040$:
    ld      a, (de)
    or      a
    jr      Z, 00041$
    push    hl
    push    de
    call    __draw_char
    pop     de
    pop     hl
    ld      a, (__cpc_font_width)
    ld      c, a
    ld      b, #0
    add     hl, bc
    inc     de
    jr      00040$
00041$:
    pop     ix
    pop     hl
    pop     de
    pop     bc
    ; discard str from stack (2 bytes pushed by compiler)
    pop     hl
    inc     sp
    inc     sp
    jp      (hl)

;------------------------------------------------------------------------------
; _cpc_text_putc(col, row, ch)  sdcccall(1)
; A = col, L = row, ch pushed on stack (1 byte, padded to 2).
;------------------------------------------------------------------------------
_cpc_text_putc::
    push    bc
    push    de
    push    hl
    push    ix

    ld      (__cpc_text_col), a
    ld      a, l
    ld      (__cpc_text_row), a

    ; Screen address: $C000 + row*80 + col*font_width
    ld      a, (__cpc_text_row)
    ld      l, a
    ld      h, #0
    add     hl, hl                  ; *2
    add     hl, hl                  ; *4
    add     hl, hl                  ; *8
    add     hl, hl                  ; *16
    ld      b, h
    ld      c, l
    add     hl, hl                  ; *32
    add     hl, hl                  ; *64
    add     hl, bc                  ; *80
    ld      a, (__cpc_text_col)
    ld      e, a
    ld      d, #0
    ld      a, (__cpc_font_width)
00051$:
    add     hl, de
    dec     a
    jr      NZ, 00051$
    ld      bc, #0xC000
    add     hl, bc

    ; Fetch ch from stack
    ld      ix, #0
    add     ix, sp
    ; ix+0,1 = IX; ix+2,3 = HL; ix+4,5 = DE; ix+6,7 = BC; ix+8,9 = ret; ix+10 = ch
    ld      a, 10 (ix)
    call    __draw_char

    pop     ix
    pop     hl
    pop     de
    pop     bc
    ; discard ch from stack (1 byte pushed by compiler)
    pop     hl
    inc     sp
    jp      (hl)

;------------------------------------------------------------------------------
; __draw_char
; Input: A = ASCII char, HL = screen address ($C000 base)
; Mode selected by __cpc_font_width: 2 = Mode 1, 4 = Mode 0.
; Draws one 8x8 character using the current font (transparent paper).
; Corrupts: AF, BC, DE, HL, IX, IY
;------------------------------------------------------------------------------
__draw_char::
    push    ix
    push    iy
    push    bc
    push    de
    push    hl                  ; [sp+0] = screen address

    ; Calculate font glyph address: font_ptr + (char - first_char) * font_height
    ld      b, a                ; B = char
    ld      a, (__cpc_font_first)
    ld      c, a
    ld      a, b
    sub     c                   ; A = char - first_char
    jp      M, 00042$
    cp      #96
    jp      NC, 00042$

    ; glyph offset = A * font_height
    ld      e, a
    ld      d, #0               ; DE = char index
    ld      a, (__cpc_font_height)
    ld      b, a                ; B = loop count
    ld      hl, #0
00043$:
    or      a
    jr      Z, 00044$
    add     hl, de
    dec     b
    ld      a, b
    jr      00043$
00044$:
    ld      de, (__cpc_font_ptr)
    add     hl, de              ; HL = glyph data address
    push    hl
    pop     ix                  ; IX = glyph data address

    pop     hl                  ; HL = screen address
    push    hl                  ; re-save

    ld      a, (__cpc_font_height)
    ld      b, a                ; B = row count

    ; Branch on font_width to select mode
    ld      a, (__cpc_font_width)
    cp      #4
    jp      Z, 00060$           ; Mode 0 path

    ; =====================================================================
    ; MODE 1 path (font_width=2): 2 bytes per row, 4 pixels per byte
    ; Screen byte layout: {p0b1,p1b1,p2b1,p3b1, p0b0,p1b0,p2b0,p3b0}
    ; =====================================================================
00045$:
    ld      a, 0(ix)            ; A = font row byte
    ld      c, a                ; C = font byte saved

    ; --- Screen byte 0 (font bits 7..4 -> pixels 0..3) ---
    and     #0xF0
    ld      e, a                ; E = mask_hi
    rrca
    rrca
    rrca
    rrca
    or      e
    ld      e, a                ; E = full mask

    ld      a, (__cpc_text_ink)
    ld      d, a
    ld      a, #0
    bit     0, d
    jr      Z, 00047$
    ld      a, e
    and     #0x0F
00047$:
    ld      (__cpc_text_tmp), a
    ld      a, #0
    bit     1, d
    jr      Z, 00048$
    ld      a, e
    and     #0xF0
00048$:
    ld      d, a
    ld      a, (__cpc_text_tmp)
    or      d
    ld      (__cpc_text_tmp), a
    ld      d, (hl)
    ld      a, e
    cpl
    and     d
    ld      d, a
    ld      a, (__cpc_text_tmp)
    and     e
    or      d
    ld      (hl), a
    inc     hl

    ; --- Screen byte 1 (font bits 3..0 -> pixels 4..7) ---
    ld      a, c
    and     #0x0F
    ld      e, a
    rlca
    rlca
    rlca
    rlca
    or      e
    ld      e, a

    ld      a, (__cpc_text_ink)
    ld      d, a
    ld      a, #0
    bit     0, d
    jr      Z, 00049$
    ld      a, e
    and     #0x0F
00049$:
    ld      (__cpc_text_tmp), a
    ld      a, #0
    bit     1, d
    jr      Z, 00050$
    ld      a, e
    and     #0xF0
00050$:
    ld      d, a
    ld      a, (__cpc_text_tmp)
    or      d
    ld      (__cpc_text_tmp), a
    ld      d, (hl)
    ld      a, e
    cpl
    and     d
    ld      d, a
    ld      a, (__cpc_text_tmp)
    and     e
    or      d
    ld      (hl), a

    ; Advance HL to next scan line (back to byte 0 of row)
    dec     hl
    ld      a, h
    add     a, #8
    ld      h, a
    and     #0x38
    jr      NZ, 00046$
    ld      a, l
    add     a, #0x50
    ld      l, a
    ld      a, h
    adc     a, #0xC0
    ld      h, a
00046$:
    inc     ix
    dec     b
    jp      NZ, 00045$
    jp      00042$              ; done

    ; =====================================================================
    ; MODE 0 path (font_width=4): 4 bytes per row, 2 pixels per byte
    ; CPC Mode 0 screen byte: bit7=p0b3,bit6=p1b3,bit5=p0b2,bit4=p1b2,
    ;                          bit3=p0b1,bit2=p1b1,bit1=p0b0,bit0=p1b0
    ; Pixel 0 (left)  occupies bits 7,5,3,1 -> mask 0xAA
    ; Pixel 1 (right) occupies bits 6,4,2,0 -> mask 0x55
    ; For ink pen N, pixel 0 encoding: scatter N bits to 7,5,3,1
    ; For ink pen N, pixel 1 encoding: scatter N bits to 6,4,2,0
    ; Font byte: bit7=px0, bit6=px1, bit5=px2, bit4=px3,
    ;            bit3=px4, bit2=px5, bit1=px6, bit0=px7
    ; Each pair of font bits -> one screen byte.
    ; =====================================================================
    ;
    ; Precompute p0_ink and p1_ink from __cpc_text_ink:
    ;   p0_ink: N bits scattered to 7,5,3,1
    ;     bit3->7, bit2->5, bit1->3, bit0->1
    ;   p1_ink: N bits scattered to 6,4,2,0
    ;     bit3->6, bit2->4, bit1->2, bit0->0
    ; Store p0_ink in __cpc_text_tmp, p1_ink in __cpc_text_tmp2.
00060$:
    ld      a, 0(ix)            ; A = font row byte
    ld      c, a                ; C = font byte saved

    ; Compute p0_ink (pen bits scattered to 7,5,3,1)
    ld      a, (__cpc_text_ink)
    ld      d, #0
    bit     0, a
    jr      Z, 00071$
    ld      a, d
    or      #0x02
    ld      d, a
    ld      a, (__cpc_text_ink)
00071$:
    bit     1, a
    jr      Z, 00072$
    ld      a, d
    or      #0x08
    ld      d, a
    ld      a, (__cpc_text_ink)
00072$:
    bit     2, a
    jr      Z, 00073$
    ld      a, d
    or      #0x20
    ld      d, a
    ld      a, (__cpc_text_ink)
00073$:
    bit     3, a
    jr      Z, 00074$
    ld      a, d
    or      #0x80
    ld      d, a
00074$:
    ld      a, d
    ld      (__cpc_text_tmp), a ; p0_ink saved

    ; Compute p1_ink (pen bits scattered to 6,4,2,0)
    ld      a, (__cpc_text_ink)
    ld      d, #0
    bit     0, a
    jr      Z, 00075$
    ld      a, d
    or      #0x01
    ld      d, a
    ld      a, (__cpc_text_ink)
00075$:
    bit     1, a
    jr      Z, 00076$
    ld      a, d
    or      #0x04
    ld      d, a
    ld      a, (__cpc_text_ink)
00076$:
    bit     2, a
    jr      Z, 00077$
    ld      a, d
    or      #0x10
    ld      d, a
    ld      a, (__cpc_text_ink)
00077$:
    bit     3, a
    jr      Z, 00078$
    ld      a, d
    or      #0x40
    ld      d, a
00078$:
    ld      a, d
    ld      (__cpc_text_tmp2), a ; p1_ink saved

    ; --- Screen byte 0: font bits 7 (p0), 6 (p1) ---
    ; Build mask: 0xAA if bit7 set, 0x55 if bit6 set, combine
    ld      e, #0               ; E = pixel mask for this byte
    ld      d, #0               ; D = ink pattern for this byte
    bit     7, c
    jr      Z, 00061$
    ld      a, (__cpc_text_tmp) ; p0_ink
    or      d
    ld      d, a
    ld      a, #0xAA
    or      e
    ld      e, a
00061$:
    bit     6, c
    jr      Z, 00062$
    ld      a, (__cpc_text_tmp2); p1_ink
    or      d
    ld      d, a
    ld      a, #0x55
    or      e
    ld      e, a
00062$:
    ld      a, e
    cpl
    ld      e, a                ; E = ~mask
    ld      a, (hl)
    and     e
    or      d
    ld      (hl), a
    inc     hl

    ; --- Screen byte 1: font bits 5 (p0), 4 (p1) ---
    ld      e, #0
    ld      d, #0
    bit     5, c
    jr      Z, 00063$
    ld      a, (__cpc_text_tmp)
    or      d
    ld      d, a
    ld      a, #0xAA
    or      e
    ld      e, a
00063$:
    bit     4, c
    jr      Z, 00064$
    ld      a, (__cpc_text_tmp2)
    or      d
    ld      d, a
    ld      a, #0x55
    or      e
    ld      e, a
00064$:
    ld      a, e
    cpl
    ld      e, a
    ld      a, (hl)
    and     e
    or      d
    ld      (hl), a
    inc     hl

    ; --- Screen byte 2: font bits 3 (p0), 2 (p1) ---
    ld      e, #0
    ld      d, #0
    bit     3, c
    jr      Z, 00065$
    ld      a, (__cpc_text_tmp)
    or      d
    ld      d, a
    ld      a, #0xAA
    or      e
    ld      e, a
00065$:
    bit     2, c
    jr      Z, 00066$
    ld      a, (__cpc_text_tmp2)
    or      d
    ld      d, a
    ld      a, #0x55
    or      e
    ld      e, a
00066$:
    ld      a, e
    cpl
    ld      e, a
    ld      a, (hl)
    and     e
    or      d
    ld      (hl), a
    inc     hl

    ; --- Screen byte 3: font bits 1 (p0), 0 (p1) ---
    ld      e, #0
    ld      d, #0
    bit     1, c
    jr      Z, 00067$
    ld      a, (__cpc_text_tmp)
    or      d
    ld      d, a
    ld      a, #0xAA
    or      e
    ld      e, a
00067$:
    bit     0, c
    jr      Z, 00068$
    ld      a, (__cpc_text_tmp2)
    or      d
    ld      d, a
    ld      a, #0x55
    or      e
    ld      e, a
00068$:
    ld      a, e
    cpl
    ld      e, a
    ld      a, (hl)
    and     e
    or      d
    ld      (hl), a

    ; Advance HL back to byte 0 of this row, then to next scan line
    ld      a, l
    sub     #3
    ld      l, a
    ld      a, h
    jr      NC, 00070$
    dec     a
00070$:
    ld      h, a                ; HL = byte 0 of this scan line
    ld      a, h
    add     a, #8
    ld      h, a
    and     #0x38
    jr      NZ, 00069$
    ld      a, l
    add     a, #0x50
    ld      l, a
    ld      a, h
    adc     a, #0xC0
    ld      h, a
00069$:
    inc     ix
    dec     b
    jp      NZ, 00060$

00042$:
    pop     hl
    pop     de
    pop     bc
    pop     iy
    pop     ix
    ret

;------------------------------------------------------------------------------
; __encode_byte_m1_hi
; Input:  A = 8-bit font byte
; Output: A = Mode 1 screen byte for high 4 pixels (bits 7..4 of font byte)
; Ink pen = 1 (both pixel bits set if font bit = 1)
;------------------------------------------------------------------------------
__encode_byte_m1_hi::
    ; Input A = font byte. Encode high 4 pixels (font bits 7..4) for pen 1.
    ; Mode 1 screen byte: {p0b1,p1b1,p2b1,p3b1, p0b0,p1b0,p2b0,p3b0}
    ; Pen 1 = colour 01: b1=0, b0=font_bit.
    ; So upper nibble of screen byte = 0, lower nibble = font bits 7..4 shifted down.
    ; font bit7->screen bit3, bit6->bit2, bit5->bit1, bit4->bit0
    rrca
    rrca
    rrca
    rrca                        ; rotate right 4: font bits 7..4 now in bits 3..0
    and     #0x0F               ; mask to low nibble only (upper nibble = 0 = pen b1=0)
    ret

;------------------------------------------------------------------------------
; __encode_byte_m1_lo
; Same but for low 4 pixels (bits 3..0 of font byte)
;------------------------------------------------------------------------------
__encode_byte_m1_lo::
    ; Input A = font byte. Encode low 4 pixels (font bits 3..0) for pen 1.
    ; Pen 1 = colour 01: b1=0, b0=font_bit.
    ; font bit3->screen bit3, bit2->bit2, bit1->bit1, bit0->bit0
    ; Upper nibble = 0 (b1=0 for pen 1)
    and     #0x0F               ; keep bits 3..0, upper nibble = 0
    ret
