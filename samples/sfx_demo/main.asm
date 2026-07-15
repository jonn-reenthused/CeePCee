;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;--------------------------------------------------------
; File Created by SDCC : free open source ISO C Compiler
; Version 4.5.0 #15242 (Mac OS X ppc)
;--------------------------------------------------------
	.module main
	
	.optsdcc -mz80 sdcccall(1)
;--------------------------------------------------------
; Public variables in this module
;--------------------------------------------------------
	.globl _main
	.globl _cpc_input_button1_pressed
	.globl _cpc_input_right_pressed
	.globl _cpc_input_left_pressed
	.globl _cpc_input_down_pressed
	.globl _cpc_input_up_pressed
	.globl _cpc_sound_silence_all
	.globl _cpc_sound_volume
	.globl _cpc_sound_mixer
	.globl _cpc_sound_noise
	.globl _cpc_sound_tone
	.globl _cpc_vblank_wait
	.globl _cpc_init
;--------------------------------------------------------
; special function registers
;--------------------------------------------------------
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _DATA
;--------------------------------------------------------
; ram data
;--------------------------------------------------------
	.area _INITIALIZED
;--------------------------------------------------------
; absolute external ram data
;--------------------------------------------------------
	.area _DABS (ABS)
;--------------------------------------------------------
; global & static initialisations
;--------------------------------------------------------
	.area _HOME
	.area _GSINIT
	.area _GSFINAL
	.area _GSINIT
;--------------------------------------------------------
; Home
;--------------------------------------------------------
	.area _HOME
	.area _HOME
;--------------------------------------------------------
; code
;--------------------------------------------------------
	.area _CODE
;main.c:7: static void sfx_beep(void) {
;	---------------------------------
; Function sfx_beep
; ---------------------------------
_sfx_beep:
;main.c:8: cpc_sound_mixer(0xC0);  /* tones on */
	ld	a, #0xc0
	call	_cpc_sound_mixer
;main.c:9: cpc_sound_tone(SOUND_CH_A, NOTE_A5, 15);
	ld	a, #0x0f
	push	af
	inc	sp
	ld	de, #0x0047
	xor	a, a
	call	_cpc_sound_tone
;main.c:10: }
	ret
;main.c:12: static void sfx_laser(void) {
;	---------------------------------
; Function sfx_laser
; ---------------------------------
_sfx_laser:
;main.c:13: cpc_sound_mixer(0xC0);  /* tones on */
	ld	a, #0xc0
	call	_cpc_sound_mixer
;main.c:14: cpc_sound_tone(SOUND_CH_B, NOTE_A5, 12);
	ld	a, #0x0c
	push	af
	inc	sp
	ld	de, #0x0047
	ld	a, #0x01
	call	_cpc_sound_tone
;main.c:15: }
	ret
;main.c:17: static void sfx_explosion(void) {
;	---------------------------------
; Function sfx_explosion
; ---------------------------------
_sfx_explosion:
;main.c:18: cpc_sound_noise(20);
	ld	a, #0x14
	call	_cpc_sound_noise
;main.c:19: cpc_sound_mixer(0xC0 & ~SOUND_NOISE_A);  /* noise on A */
	ld	a, #0xc0
	call	_cpc_sound_mixer
;main.c:20: cpc_sound_volume(SOUND_CH_A, 15);
	ld	l, #0x0f
	xor	a, a
;main.c:21: }
	jp	_cpc_sound_volume
;main.c:23: static void sfx_chime(void) {
;	---------------------------------
; Function sfx_chime
; ---------------------------------
_sfx_chime:
;main.c:24: cpc_sound_mixer(0xC0);  /* tones on */
	ld	a, #0xc0
	call	_cpc_sound_mixer
;main.c:25: cpc_sound_tone(SOUND_CH_A, NOTE_E5, 10);
	ld	a, #0x0a
	push	af
	inc	sp
	ld	de, #0x005f
	xor	a, a
	call	_cpc_sound_tone
;main.c:26: cpc_sound_tone(SOUND_CH_B, NOTE_B5, 8);
	ld	a, #0x08
	push	af
	inc	sp
	ld	de, #0x003f
	ld	a, #0x01
	call	_cpc_sound_tone
;main.c:27: }
	ret
;main.c:29: static void sfx_clunk(void) {
;	---------------------------------
; Function sfx_clunk
; ---------------------------------
_sfx_clunk:
;main.c:30: cpc_sound_mixer(0xC0);  /* tones on */
	ld	a, #0xc0
	call	_cpc_sound_mixer
;main.c:31: cpc_sound_tone(SOUND_CH_C, NOTE_C3, 12);
	ld	a, #0x0c
	push	af
	inc	sp
	ld	de, #0x01de
	ld	a, #0x02
	call	_cpc_sound_tone
;main.c:32: }
	ret
;main.c:36: static void poke_screen(uint16_t offset, uint8_t val) {
;	---------------------------------
; Function poke_screen
; ---------------------------------
_poke_screen:
;main.c:37: *(uint8_t*)(SCREEN_BASE + offset) = val;
	ld	c, l
	ld	a, h
	add	a, #0xc0
	ld	b, a
	ld	iy, #2
	add	iy, sp
	ld	a, 0 (iy)
	ld	(bc), a
;main.c:38: }
	pop	hl
	inc	sp
	jp	(hl)
;main.c:40: void main(void) {
;	---------------------------------
; Function main
; ---------------------------------
_main::
	push	ix
	ld	ix,#0
	add	ix,sp
	dec	sp
;main.c:43: cpc_init(CPC_MODE_0);
	xor	a, a
	call	_cpc_init
;main.c:44: cpc_sound_silence_all();
	call	_cpc_sound_silence_all
;main.c:45: cpc_sound_mixer(0xC0);  /* ensure tones enabled */
	ld	a, #0xc0
	call	_cpc_sound_mixer
;main.c:49: for (i = 0; i < 16; i++) poke_screen(i, 0);
	ld	hl, #0x0000
00120$:
	push	hl
	xor	a, a
	push	af
	inc	sp
	call	_poke_screen
	pop	hl
	inc	hl
	ld	a, l
	sub	a, #0x10
	jr	C, 00120$
;main.c:51: while (1) {
	ld	-1 (ix), #0x00
00118$:
;main.c:53: if (cpc_input_button1_pressed(PLAYER_1)) { 
	xor	a, a
	call	_cpc_input_button1_pressed
	or	a, a
	jr	Z, 00103$
;main.c:54: poke_screen(0, 0xFF); sfx_beep(); 
	ld	a, #0xff
	push	af
	inc	sp
	ld	hl, #0x0000
	call	_poke_screen
	call	_sfx_beep
00103$:
;main.c:56: if (cpc_input_up_pressed(PLAYER_1)) { 
	xor	a, a
	call	_cpc_input_up_pressed
	or	a, a
	jr	Z, 00105$
;main.c:57: poke_screen(2, 0xFF); sfx_laser(); 
	ld	a, #0xff
	push	af
	inc	sp
	ld	hl, #0x0002
	call	_poke_screen
	call	_sfx_laser
00105$:
;main.c:59: if (cpc_input_down_pressed(PLAYER_1)) { 
	xor	a, a
	call	_cpc_input_down_pressed
	or	a, a
	jr	Z, 00107$
;main.c:60: poke_screen(4, 0xFF); sfx_explosion(); 
	ld	a, #0xff
	push	af
	inc	sp
	ld	hl, #0x0004
	call	_poke_screen
	call	_sfx_explosion
00107$:
;main.c:62: if (cpc_input_left_pressed(PLAYER_1)) { 
	xor	a, a
	call	_cpc_input_left_pressed
	or	a, a
	jr	Z, 00109$
;main.c:63: poke_screen(6, 0xFF); sfx_chime(); 
	ld	a, #0xff
	push	af
	inc	sp
	ld	hl, #0x0006
	call	_poke_screen
	call	_sfx_chime
00109$:
;main.c:65: if (cpc_input_right_pressed(PLAYER_1)) { 
	xor	a, a
	call	_cpc_input_right_pressed
	or	a, a
	jr	Z, 00111$
;main.c:66: poke_screen(8, 0xFF); sfx_clunk(); 
	ld	a, #0xff
	push	af
	inc	sp
	ld	hl, #0x0008
	call	_poke_screen
	call	_sfx_clunk
00111$:
;main.c:70: frame++;
	inc	-1 (ix)
;main.c:71: if ((frame & 0x0F) == 0) {
	ld	a, -1 (ix)
	and	a, #0x0f
	jr	NZ, 00116$
;main.c:72: for (i = 0; i < 16; i++) {
	ld	bc, #0x0000
00122$:
;main.c:73: uint8_t v = *(uint8_t*)(SCREEN_BASE + i);
	ld	hl, #0xc000
	add	hl, bc
	ld	a, (hl)
	ld	d, a
;main.c:74: if (v) poke_screen(i, v >> 1);
	or	a, a
	jr	Z, 00123$
	srl	d
	push	bc
	push	de
	inc	sp
	ld	l, c
	ld	h, b
	call	_poke_screen
	pop	bc
00123$:
;main.c:72: for (i = 0; i < 16; i++) {
	inc	bc
	ld	a, c
	sub	a, #0x10
	jr	C, 00122$
00116$:
;main.c:78: cpc_vblank_wait();
	call	_cpc_vblank_wait
	jp	00118$
;main.c:80: }
	inc	sp
	pop	ix
	ret
	.area _CODE
	.area _INITIALIZER
	.area _CABS (ABS)
