;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_input.s
; Keyboard + Joystick input
;
; Scans the full 10-line CPC keyboard matrix via PPI/AY.
; Matrix layout (active-low from hardware, stored active-high):
;
;  Line  Bit7    Bit6    Bit5    Bit4    Bit3    Bit2    Bit1    Bit0
;  $40   FDot    ENTER   F3      F6      F9      CUR_D   CUR_R   CUR_U
;  $41   F0      F2      F1      F5      F8      F7      COPY    CUR_L
;  $42   CTRL    \       SHIFT   F4      ]       RETN    [       CLR
;  $43   .       /       :       ;       P       @       -       ^
;  $44   ,       M       K       L       I       O       9       0
;  $45   SPACE   N       J       H       Y       U       7       8
;  $46   V       B       F       G/J2F1  T/J2R   R/J2L   5/J2D   6/J2U
;  $47   X       C       D       S       W       E       3       4
;  $48   Z       CAPSLK  A       TAB     Q       ESC     2       1
;  $49   DEL     J1_F3   J1_F2   J1_F1   J1_R    J1_L    J1_D    J1_U
;
; Key constants: encoded as (line_index << 3) | bit
;   line_index = line - $40, so line $40 = 0, $49 = 9
;
; Joystick 1 lives on line 9 ($49), bits 0..4.
;
; cpc_input_poll() is called automatically by cpc_vblank_wait().
;

    .module cpc_input
    .globl  _cpc_input_poll
    .globl  _cpc_input_up
    .globl  _cpc_input_down
    .globl  _cpc_input_left
    .globl  _cpc_input_right
    .globl  _cpc_input_button1
    .globl  _cpc_input_button2
    .globl  _cpc_input_up_pressed
    .globl  _cpc_input_down_pressed
    .globl  _cpc_input_left_pressed
    .globl  _cpc_input_right_pressed
    .globl  _cpc_input_button1_pressed
    .globl  _cpc_input_button2_pressed
    .globl  _cpc_key_held
    .globl  _cpc_key_pressed
    .globl  __cpc_input_curr
    .globl  __cpc_input_prev
    .globl  __cpc_input_curr2
    .globl  __cpc_input_prev2
    .globl  __cpc_key_matrix
    .globl  __cpc_key_matrix_prev

    .area   _CODE

;------------------------------------------------------------------------------
; _cpc_input_poll()
; Scans all 10 keyboard matrix lines via PPI/AY into __cpc_key_matrix.
; Stores previous matrix in __cpc_key_matrix_prev.
; Also derives __cpc_input_curr from joystick line for backwards compat.
; Called automatically by cpc_vblank_wait().
;------------------------------------------------------------------------------
_cpc_input_poll::
    push    af
    push    bc
    push    de
    push    hl

    ; Copy current matrix to previous
    ld      hl, #__cpc_key_matrix
    ld      de, #__cpc_key_matrix_prev
    ld      bc, #10
    ldir

    di

    ; ---------------------------------------------------------------
    ; Read joystick by scanning keyboard matrix line $49 directly.
    ; Reference: CPC_V1_ReadJoystick.asm (proven sequence).
    ; Line $49 bits: 0=J1_U 1=J1_D 2=J1_L 3=J1_R 4=J1_F1 5=J1_F2
    ; ---------------------------------------------------------------

    ; PPI mode: port A=output, port C=output
    ld      bc, #0xF782
    out     (c), c

    ; Write AY register address ($0E) to PPI port A
    ld      bc, #0xF40E
    out     (c), c              ; port A = $0E

    ; BDIR=1, BC1=1: AY latches the register address
    ld      bc, #0xF6C0
    out     (c), c

    ; BDIR=0, BC1=0: inactive
    xor     a
    out     (c), a

    ; PPI mode: port A=input, port C=output
    ld      bc, #0xF792
    out     (c), c

    ; Select keyboard matrix line $49 (joystick line)
    ld      a, #0x49
    ld      bc, #0xF600
    out     (c), a

    ; Read key data from PPI port A
    ld      bc, #0xF400
    in      a, (c)              ; active-low: 0=pressed

    ; Restore PPI: port A=output, port C=output
    ld      bc, #0xF782
    out     (c), c

    ei

    ; Invert to active-high, mask to 6 bits
    xor     #0xFF
    and     #0x3F

    ; Save joystick result aside
    ld      c, a                        ; C = joystick bits (active-high)

    ; Save prev, store new joystick curr
    ld      a, (__cpc_input_curr)
    ld      (__cpc_input_prev), a
    ld      a, c
    ld      (__cpc_input_curr), a

    ; ---------------------------------------------------------------
    ; Full keyboard matrix scan: lines $40..$49 -> __cpc_key_matrix
    ; Reuse the PPI which is already restored to A=out, C=out
    ; ---------------------------------------------------------------
    di

    ; PPI port A=output, port C=output (already set, but be safe)
    ld      bc, #0xF782
    out     (c), c

    ; Select AY reg 14 on port A, latch, go inactive, switch A=input
    ld      bc, #0xF40E
    out     (c), c
    ld      bc, #0xF6C0
    out     (c), c
    xor     a
    out     (c), a
    ld      bc, #0xF792
    out     (c), c

    ; Scan lines $40..$48 (lines 0..8) - joystick line $49 done separately
    ld      hl, #__cpc_key_matrix
    ld      e, #0x40            ; E = current line

00002$:
    ld      bc, #0xF600
    ld      a, e
    out     (c), a              ; select line
    ld      bc, #0xF400
    in      a, (c)              ; read (active-low)
    xor     #0xFF               ; invert to active-high
    ld      (hl), a
    inc     hl
    inc     e
    ld      a, e
    cp      #0x49               ; stop before line $49 (joystick)
    jr      c, 00002$

    ; Restore PPI
    ld      bc, #0xF782
    out     (c), c

    ei

    ; Line 9 ($49): use joystick result already read above
    ld      a, (__cpc_input_curr)   ; C was clobbered by the scan loop
    ld      (__cpc_key_matrix + 9), a
    ld      a, (__cpc_input_prev)
    ld      (__cpc_key_matrix_prev + 9), a

    pop     hl
    pop     de
    pop     bc
    pop     af
    ret

;------------------------------------------------------------------------------
; _cpc_key_held(key)  - sdcccall(1): key in A
; Returns HL=1 if key currently held, HL=0 if not.
; key = (line_index << 3) | bit,  line_index = line - $40
;------------------------------------------------------------------------------
_cpc_key_held::
    ld      l, a                ; L = key code (sdcccall(1): 8-bit arg in A)
    and     #0x07               ; A = bit number (0..7)
    ld      b, a                ; B = shift count (0..7)
    ld      a, b                ; test if B==0
    or      a
    ld      a, #1               ; A = bitmask (flags not affected by ld)
    jr      z, 00051$           ; bit 0: no shift needed
00050$:
    rlca
    djnz    00050$
00051$:                         ; A = (1 << bit_number)
    ld      c, a                ; C = bitmask
    ld      a, l
    rrca
    rrca
    rrca                        ; A = line_index (bits 2..0 now at 0..2)
    and     #0x1F               ; mask to 5 bits (0..9)
    ld      hl, #__cpc_key_matrix
    add     a, l
    ld      l, a
    adc     a, h
    sub     l
    ld      h, a                ; HL = &__cpc_key_matrix[line_index]
    ld      a, (hl)
    and     c
    jr      z, 00052$
    ld      hl, #1
    ret
00052$:
    ld      hl, #0
    ret

;------------------------------------------------------------------------------
; _cpc_key_pressed(key)  - sdcccall(1): key in A
; Returns HL=1 on the frame the key first goes down, HL=0 otherwise.
;------------------------------------------------------------------------------
_cpc_key_pressed::
    ld      l, a                ; L = key code (sdcccall(1): 8-bit arg in A)
    ld      a, l
    and     #0x07
    ld      b, a
    ld      a, b                ; test if B==0
    or      a
    ld      a, #1               ; A = bitmask (flags not affected by ld)
    jr      z, 00061$           ; bit 0: no shift needed
00060$:
    rlca
    djnz    00060$
00061$:
    ld      c, a                ; C = bitmask
    ld      a, l
    rrca
    rrca
    rrca
    and     #0x1F
    ld      hl, #__cpc_key_matrix
    add     a, l
    ld      l, a
    adc     a, h
    sub     l
    ld      h, a                ; HL = &curr[line_index]
    ld      a, (hl)
    and     c                   ; curr bit
    ld      e, a                ; E = curr bit (0 or mask)
    ; compute prev address: prev = curr + 10
    ld      a, l
    add     a, #10
    ld      l, a
    jr      nc, 00062$
    inc     h
00062$:
    ld      a, (hl)             ; prev byte
    and     c                   ; prev bit
    cpl
    and     c                   ; NOT prev
    and     e                   ; curr AND NOT prev
    jr      z, 00063$
    ld      hl, #1
    ret
00063$:
    ld      hl, #0
    ret

;------------------------------------------------------------------------------
; Joystick/direction helpers - all read from __cpc_key_matrix line 9 ($49)
; Line 9 layout: bit0=J1_U, bit1=J1_D, bit2=J1_L, bit3=J1_R, bit4=J1_F1, bit5=J1_F2/J1_F3
;
; sdcccall(1): player in L (0=P1, 1=P2 - P2 not yet implemented, falls through to P1)
;------------------------------------------------------------------------------

; Helper: test bit in __cpc_input_curr, return 0/1
; Reused by held variants

_cpc_input_up::
    ld      a, (__cpc_input_curr)
    and     #0x01
    jr      z, 00100$
    ld      hl, #1
    ret
00100$:
    ld      hl, #0
    ret

_cpc_input_down::
    ld      a, (__cpc_input_curr)
    and     #0x02
    jr      z, 00101$
    ld      hl, #1
    ret
00101$:
    ld      hl, #0
    ret

_cpc_input_left::
    ld      a, (__cpc_input_curr)
    and     #0x04
    jr      z, 00102$
    ld      hl, #1
    ret
00102$:
    ld      hl, #0
    ret

_cpc_input_right::
    ld      a, (__cpc_input_curr)
    and     #0x08
    jr      z, 00103$
    ld      hl, #1
    ret
00103$:
    ld      hl, #0
    ret

_cpc_input_button1::
    ld      a, (__cpc_input_curr)
    and     #0x10
    jr      z, 00104$
    ld      hl, #1
    ret
00104$:
    ld      hl, #0
    ret

_cpc_input_button2::
    ld      a, (__cpc_input_curr)
    and     #0x20
    jr      z, 00105$
    ld      hl, #1
    ret
00105$:
    ld      hl, #0
    ret

; _pressed variants: (curr & mask) AND NOT (prev & mask)

_cpc_input_up_pressed::
    ld      a, (__cpc_input_curr)
    and     #0x01
    ld      c, a
    ld      a, (__cpc_input_prev)
    and     #0x01
    cpl
    and     c
    jr      z, 00110$
    ld      hl, #1
    ret
00110$:
    ld      hl, #0
    ret

_cpc_input_down_pressed::
    ld      a, (__cpc_input_curr)
    and     #0x02
    ld      c, a
    ld      a, (__cpc_input_prev)
    and     #0x02
    cpl
    and     c
    jr      z, 00111$
    ld      hl, #1
    ret
00111$:
    ld      hl, #0
    ret

_cpc_input_left_pressed::
    ld      a, (__cpc_input_curr)
    and     #0x04
    ld      c, a
    ld      a, (__cpc_input_prev)
    and     #0x04
    cpl
    and     c
    jr      z, 00112$
    ld      hl, #1
    ret
00112$:
    ld      hl, #0
    ret

_cpc_input_right_pressed::
    ld      a, (__cpc_input_curr)
    and     #0x08
    ld      c, a
    ld      a, (__cpc_input_prev)
    and     #0x08
    cpl
    and     c
    jr      z, 00113$
    ld      hl, #1
    ret
00113$:
    ld      hl, #0
    ret

_cpc_input_button1_pressed::
    ld      a, (__cpc_input_curr)
    and     #0x10
    ld      c, a
    ld      a, (__cpc_input_prev)
    and     #0x10
    cpl
    and     c
    jr      z, 00114$
    ld      hl, #1
    ret
00114$:
    ld      hl, #0
    ret

_cpc_input_button2_pressed::
    ld      a, (__cpc_input_curr)
    and     #0x20
    ld      c, a
    ld      a, (__cpc_input_prev)
    and     #0x20
    cpl
    and     c
    jr      z, 00115$
    ld      hl, #1
    ret
00115$:
    ld      hl, #0
    ret

;------------------------------------------------------------------------------
; _cpc_key_name(key) - sdcccall(1): key in A
; Returns HL = pointer to null-terminated short name string for the key.
; Returns pointer to "?" for unknown/out-of-range key codes.
;------------------------------------------------------------------------------
_cpc_key_name::
    cp      #0x50               ; valid range 0x00..0x4F (80 keys)
    jr      nc, 00120$          ; out of range -> return "?"
    ld      l, a
    ld      h, #0               ; HL = key code
    add     hl, hl              ; HL *= 2 (each entry is 2-byte pointer)
    ld      de, #__cpc_key_name_table
    add     hl, de              ; HL = &table[key]
    ld      a, (hl)
    inc     hl
    ld      h, (hl)
    ld      l, a                ; HL = pointer to name string
    ret
00120$:
    ld      hl, #__cpc_key_name_unknown
    ret

__cpc_key_name_unknown:
    .ascii  "?"
    .db     0

    ; Name strings (null terminated, .db 0 must be on its own line for sdasz80)
__kn_cur_u:  .ascii "UP"
    .db 0
__kn_cur_r:  .ascii "RIGHT"
    .db 0
__kn_cur_d:  .ascii "DOWN"
    .db 0
__kn_f9:     .ascii "F9"
    .db 0
__kn_f6:     .ascii "F6"
    .db 0
__kn_f3:     .ascii "F3"
    .db 0
__kn_enter:  .ascii "ENTR"
    .db 0
__kn_fdot:   .ascii "FDOT"
    .db 0
__kn_cur_l:  .ascii "LEFT"
    .db 0
__kn_copy:   .ascii "COPY"
    .db 0
__kn_f7:     .ascii "F7"
    .db 0
__kn_f8:     .ascii "F8"
    .db 0
__kn_f5:     .ascii "F5"
    .db 0
__kn_f1:     .ascii "F1"
    .db 0
__kn_f2:     .ascii "F2"
    .db 0
__kn_f0:     .ascii "F0"
    .db 0
__kn_clr:    .ascii "CLR"
    .db 0
__kn_lbr:    .ascii "["
    .db 0
__kn_retn:   .ascii "RETN"
    .db 0
__kn_rbr:    .ascii "]"
    .db 0
__kn_f4:     .ascii "F4"
    .db 0
__kn_shift:  .ascii "SHFT"
    .db 0
__kn_bsl:    .db 0x5C, 0
__kn_ctrl:   .ascii "CTRL"
    .db 0
__kn_caret:  .ascii "^"
    .db 0
__kn_minus:  .ascii "-"
    .db 0
__kn_at:     .ascii "@"
    .db 0
__kn_p:      .ascii "P"
    .db 0
__kn_semi:   .ascii ";"
    .db 0
__kn_colon:  .ascii ":"
    .db 0
__kn_fsl:    .ascii "/"
    .db 0
__kn_dot:    .ascii "."
    .db 0
__kn_0:      .ascii "0"
    .db 0
__kn_9:      .ascii "9"
    .db 0
__kn_o:      .ascii "O"
    .db 0
__kn_i:      .ascii "I"
    .db 0
__kn_l:      .ascii "L"
    .db 0
__kn_k:      .ascii "K"
    .db 0
__kn_m:      .ascii "M"
    .db 0
__kn_comma:  .ascii ","
    .db 0
__kn_8:      .ascii "8"
    .db 0
__kn_7:      .ascii "7"
    .db 0
__kn_u:      .ascii "U"
    .db 0
__kn_y:      .ascii "Y"
    .db 0
__kn_h:      .ascii "H"
    .db 0
__kn_j:      .ascii "J"
    .db 0
__kn_n:      .ascii "N"
    .db 0
__kn_spc:    .ascii "SPC"
    .db 0
__kn_6:      .ascii "6"
    .db 0
__kn_5:      .ascii "5"
    .db 0
__kn_r:      .ascii "R"
    .db 0
__kn_t:      .ascii "T"
    .db 0
__kn_g:      .ascii "G"
    .db 0
__kn_f:      .ascii "F"
    .db 0
__kn_b:      .ascii "B"
    .db 0
__kn_v:      .ascii "V"
    .db 0
__kn_4:      .ascii "4"
    .db 0
__kn_3:      .ascii "3"
    .db 0
__kn_e:      .ascii "E"
    .db 0
__kn_w:      .ascii "W"
    .db 0
__kn_s:      .ascii "S"
    .db 0
__kn_d:      .ascii "D"
    .db 0
__kn_c:      .ascii "C"
    .db 0
__kn_x:      .ascii "X"
    .db 0
__kn_1:      .ascii "1"
    .db 0
__kn_2:      .ascii "2"
    .db 0
__kn_esc:    .ascii "ESC"
    .db 0
__kn_q:      .ascii "Q"
    .db 0
__kn_tab:    .ascii "TAB"
    .db 0
__kn_a:      .ascii "A"
    .db 0
__kn_caps:   .ascii "CAPS"
    .db 0
__kn_z:      .ascii "Z"
    .db 0
__kn_j1u:    .ascii "J1U"
    .db 0
__kn_j1d:    .ascii "J1D"
    .db 0
__kn_j1l:    .ascii "J1L"
    .db 0
__kn_j1r:    .ascii "J1R"
    .db 0
__kn_j1f1:   .ascii "J1F1"
    .db 0
__kn_j1f2:   .ascii "J1F2"
    .db 0
__kn_j1f3:   .ascii "J1F3"
    .db 0
__kn_del:    .ascii "DEL"
    .db 0

    ; Pointer table: 80 entries, each 2 bytes (word), indexed by key code
__cpc_key_name_table:
    .dw __kn_cur_u,  __kn_cur_r,  __kn_cur_d,  __kn_f9
    .dw __kn_f6,     __kn_f3,     __kn_enter,  __kn_fdot
    .dw __kn_cur_l,  __kn_copy,   __kn_f7,     __kn_f8
    .dw __kn_f5,     __kn_f1,     __kn_f2,     __kn_f0
    .dw __kn_clr,    __kn_lbr,    __kn_retn,   __kn_rbr
    .dw __kn_f4,     __kn_shift,  __kn_bsl,    __kn_ctrl
    .dw __kn_caret,  __kn_minus,  __kn_at,     __kn_p
    .dw __kn_semi,   __kn_colon,  __kn_fsl,    __kn_dot
    .dw __kn_0,      __kn_9,      __kn_o,      __kn_i
    .dw __kn_l,      __kn_k,      __kn_m,      __kn_comma
    .dw __kn_8,      __kn_7,      __kn_u,      __kn_y
    .dw __kn_h,      __kn_j,      __kn_n,      __kn_spc
    .dw __kn_6,      __kn_5,      __kn_r,      __kn_t
    .dw __kn_g,      __kn_f,      __kn_b,      __kn_v
    .dw __kn_4,      __kn_3,      __kn_e,      __kn_w
    .dw __kn_s,      __kn_d,      __kn_c,      __kn_x
    .dw __kn_1,      __kn_2,      __kn_esc,    __kn_q
    .dw __kn_tab,    __kn_a,      __kn_caps,   __kn_z
    .dw __kn_j1u,    __kn_j1d,    __kn_j1l,    __kn_j1r
    .dw __kn_j1f1,   __kn_j1f2,   __kn_j1f3,   __kn_del
