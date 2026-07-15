;
; CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
; 2026 Johnny Blanchard
;

;
; cpc_sound.s
; PSG (AY-3-8912) sound driver + music sequencer
;
; PSG access via PPI on CPC/GX4000:
;   Out to $F4xx (PPI port A) = data bus
;   Out to $F6xx (PPI port C) = control:
;     $C0 = BDIR=1,BC1=1  -> PSG latches register address
;     $80 = BDIR=1,BC1=0  -> PSG writes data from bus
;     $00 = BDIR=0,BC1=0  -> inactive
;
; PSG register map:
;   R0  fine period   ch A  (bits 7..0)
;   R1  coarse period ch A  (bits 3..0)
;   R2  fine period   ch B
;   R3  coarse period ch B
;   R4  fine period   ch C
;   R5  coarse period ch C
;   R6  noise period        (bits 4..0)
;   R7  mixer:  bits 0-2 = tone  A/B/C (0=on), bits 3-5 = noise A/B/C (0=on)
;   R8  volume  ch A  (bits 3..0 = level; bit4=1 -> use envelope)
;   R9  volume  ch B
;   R10 volume  ch C
;   R11 envelope period fine
;   R12 envelope period coarse
;   R13 envelope shape (write triggers envelope restart)
;

    .module cpc_sound
    .globl  _cpc_sound_write
    .globl  _cpc_sound_tone
    .globl  _cpc_sound_noise
    .globl  _cpc_sound_mixer
    .globl  _cpc_sound_volume
    .globl  _cpc_sound_envelope
    .globl  _cpc_sound_silence
    .globl  _cpc_sound_silence_all
    .globl  _cpc_music_play
    .globl  _cpc_music_tick
    .globl  _cpc_music_stop
    .globl  _cpc_music_set_tempo
    .globl  __cpc_music_tempo
    .globl  __cpc_music_counter
    .globl  __cpc_music_index
    .globl  __cpc_music_steps
    .globl  __cpc_music_paused
    .globl  __cpc_music_periods
    .globl  __cpc_music_volumes

    .area   _CEEPCEE_SND (ABS)
    .org    0xB180
__psg_mixer_shadow:: .ds 1      ; shadow copy of R7 (mixer)
__sc_music_step_ptr:: .ds 2     ; scratch: periods ptr during tick
__sc_music_vol_ptr::  .ds 2     ; scratch: volumes ptr during tick

; Note: music state (__cpc_music_*) defined at $B000 in cpc_init.s

    .area   _CODE

;==============================================================================
; __psg_write  --  INTERNAL: write one PSG register
; Entry: E = register (0..13), D = value
; Corrupts: A, BC
;==============================================================================
__psg_write::
    ; --- select register ---
    ld      a, e
    ld      bc, #0xF4FF         ; PPI port A (data bus)
    out     (c), a
    ld      bc, #0xF600         ; PPI port C (control)
    ld      a, #0xC0            ; BDIR=1, BC1=1 -> latch reg address
    out     (c), a
    xor     a                   ; BDIR=0, BC1=0 -> inactive
    out     (c), a
    ; --- write data ---
    ld      a, d
    ld      bc, #0xF4FF
    out     (c), a
    ld      bc, #0xF600
    ld      a, #0x80            ; BDIR=1, BC1=0 -> write data
    out     (c), a
    xor     a                   ; inactive
    out     (c), a
    ret

;==============================================================================
; _cpc_sound_write(reg, value)  -- public raw PSG register write
; sdcccall(1): reg in A, value in L
;==============================================================================
_cpc_sound_write::
    ld      e, a
    ld      d, l
    jp      __psg_write

;==============================================================================
; _cpc_sound_tone(channel, period, volume)
; sdcccall(1): channel in A (0-2), period in HL (H=coarse L=fine), volume on stack
; Stack after push ix,bc,de,hl (8 bytes) + ret (2) = vol at sp+10
;==============================================================================
_cpc_sound_tone::
    ; sdcccall(1): A=channel(0-2), DE=period(D=coarse E=fine), stack: [ret][vol]
    push    ix
    push    bc
    push    de                  ; save DE (period)

    ; set up IX frame to read volume from stack
    ; stack: saved_de(2) saved_bc(2) saved_ix(2) = 6 bytes, ret(2), vol at +8
    ld      ix, #0
    add     ix, sp

    ld      b, a                ; B = channel (0-2)

    ; reg base = channel * 2
    ld      a, b
    add     a, a
    ld      c, a                ; C = reg base

    ; write fine period: R(base) = E
    ld      e, c
    ld      d, 0(ix)              ; D = saved E = fine period
    call    __psg_write

    ; write coarse period: R(base+1) = D & $0F
    ld      a, b
    add     a, a
    inc     a                   ; reg base + 1
    ld      e, a
    ld      a, 1(ix)            ; saved D = coarse period
    and     #0x0F
    ld      d, a
    call    __psg_write

    ; write volume: R(8+channel)
    ld      a, 8(ix)            ; volume from stack
    and     a
    jr      nz, __st_vol_ok
    ld      a, #1               ; minimum volume instead of 0
__st_vol_ok:
    and     #0x1F
    ld      d, a
    ld      a, b
    add     a, #8
    ld      e, a
    call    __psg_write
__st_done:
    pop     de
    pop     bc
    pop     ix
    ; callee cleanup: discard volume (1 byte pushed by compiler)
    pop     hl
    inc     sp
    jp      (hl)

;==============================================================================
; _cpc_sound_noise(period)
; sdcccall(1): period in A (0-31, 5 bits)
;==============================================================================
_cpc_sound_noise::
    ld      d, a
    and     #0x1F
    ld      d, a
    ld      e, #6               ; R6 = noise period
    jp      __psg_write

;==============================================================================
; _cpc_sound_mixer(mask)
; sdcccall(1): mask in A
; Bits 0-2: tone A/B/C (0=on). Bits 3-5: noise A/B/C (0=on).
; Bits 6-7: I/O port direction -- must stay 0 (input) for keyboard scanning.
;==============================================================================
_cpc_sound_mixer::
    and     #0x3F               ; keep bits 7-6 clear: I/O port A = INPUT
                                ; (bit6=1 = output, which breaks keyboard/joystick
                                ; reads - the matrix is read via AY port A / R14)
    ld      (__psg_mixer_shadow), a
    ld      d, a
    ld      e, #7
    jp      __psg_write

;==============================================================================
; _cpc_sound_volume(channel, vol)
; sdcccall(1): channel in A, vol in L (0-15 = direct, 16 = use envelope)
;==============================================================================
_cpc_sound_volume::
    push    bc
    ld      b, a                ; B = channel
    ld      a, l
    and     #0x1F               ; 5 bits
    ld      d, a
    ld      a, b
    add     a, #8
    ld      e, a                ; E = R8/R9/R10
    call    __psg_write
    pop     bc
    ret

;==============================================================================
; _cpc_sound_envelope(shape, period)
; sdcccall(1): shape in A (0-15), period in DE (16-bit)
; Writes R11 (period fine), R12 (period coarse), R13 (shape - triggers restart)
;==============================================================================
_cpc_sound_envelope::
    push    bc
    ld      b, a                ; B = shape
    ld      c, d                ; C = period coarse (E/D clobbered by __psg_write)
    ; write R11 = period fine (E)
    ld      d, e
    ld      e, #11
    call    __psg_write
    ; write R12 = period coarse
    ld      e, #12
    ld      d, c
    call    __psg_write
    ; write R13 = shape (triggers envelope restart)
    ld      e, #13
    ld      d, b
    call    __psg_write
    pop     bc
    ret

;==============================================================================
; _cpc_sound_silence(channel)
; sdcccall(1): channel in A (0-2)
; Sets volume to 0. Does NOT disable tone to avoid clicks.
;==============================================================================
_cpc_sound_silence::
    push    bc
    push    de
    ld      b, a                ; B = channel

    ; volume = 0 (tone stays enabled, no click)
    ld      d, #0
    ld      a, b
    add     a, #8
    ld      e, a
    call    __psg_write

    pop     de
    pop     bc
    ret

;==============================================================================
; _cpc_sound_silence_all()
; Mute all channels by setting volumes to 0. Keep tones enabled (0xC0).
;==============================================================================
_cpc_sound_silence_all::
    push    de
    ; volumes all zero
    ld      e, #8
    ld      d, #0
    call    __psg_write
    ld      e, #9
    call    __psg_write
    ld      e, #10
    call    __psg_write
    ; mixer: tones ON, noise OFF, I/O port A input (bits 7-6 = 00)
    ld      e, #7
    ld      d, #0x38
    call    __psg_write
    ld      a, #0x38
    ld      (__psg_mixer_shadow), a
    pop     de
    ret

;==============================================================================
; _cpc_music_set_tempo(frames_per_step)
; sdcccall(1): value in A
;==============================================================================
_cpc_music_set_tempo::
    ld      (__cpc_music_tempo), a
    ret

;==============================================================================
; _cpc_music_play(periods, volumes, steps)
; sdcccall(1): periods in HL, volumes in DE, steps in stack (uint8_t)
;
; Music data format:
;   periods: uint16_t[steps * 3]  -- period per step per channel (A,B,C)
;            period=0 means silence that channel this step
;   volumes: uint8_t[steps * 3]   -- volume per step per channel (0-15, 16=env)
;==============================================================================
_cpc_music_play::
    push    ix
    ld      ix, #0
    add     ix, sp
    ; ix+0=saved ix lo, ix+1=hi, ix+2=ret lo, ix+3=hi, ix+4=steps lo

    ld      (__cpc_music_periods), hl
    ld      (__cpc_music_volumes), de
    ld      a, 4(ix)
    ld      (__cpc_music_steps), a
    xor     a
    ld      (__cpc_music_index), a
    ld      (__cpc_music_counter), a
    ld      (__cpc_music_paused), a

    pop     ix
    ; callee cleanup: discard steps (1 byte pushed by compiler)
    pop     hl
    inc     sp
    jp      (hl)

;==============================================================================
; _cpc_music_tick()
; Called each frame from cpc_vblank_wait(). Advances sequencer, plays step.
;==============================================================================
_cpc_music_tick::
    push    af
    push    bc
    push    de
    push    hl

    ld      a, (__cpc_music_steps)
    or      a
    jp      z, __mt_done

    ld      a, (__cpc_music_paused)
    or      a
    jp      nz, __mt_done

    ; tempo: only advance every N frames
    ld      a, (__cpc_music_counter)
    inc     a
    ld      (__cpc_music_counter), a
    ld      b, a
    ld      a, (__cpc_music_tempo)
    cp      b
    jp      nz, __mt_done

    ; reset counter, get current step index
    xor     a
    ld      (__cpc_music_counter), a
    ld      a, (__cpc_music_index)
    ld      b, a                ; B = step index

    ; --- compute pointer into periods: &periods[step * 3] (uint16_t, so *6 bytes) ---
    ld      hl, (__cpc_music_periods)
    ld      a, b
    add     a, a                ; *2
    add     a, b                ; *3
    add     a, a                ; *6
    ld      e, a
    ld      d, #0
    add     hl, de              ; HL = &periods[step*3]

    ; --- compute pointer into volumes: &volumes[step * 3] (uint8_t, so *3 bytes) ---
    ld      de, (__cpc_music_volumes)
    ld      a, b
    add     a, a                ; *2
    add     a, b                ; *3
    ld      c, a
    ld      b, #0
    ex      de, hl              ; HL = volumes base, DE = periods ptr
    add     hl, bc              ; HL = &volumes[step*3]
    ex      de, hl              ; HL = periods ptr, DE = volumes ptr

    ; HL = &periods[step*3], DE = &volumes[step*3]
    ; Store pointers for channel loop
    ld      (__sc_music_step_ptr), hl  ; save periods ptr
    ld      (__sc_music_vol_ptr), de   ; save volumes ptr
    ld      b, #0               ; B = channel (0,1,2)

__mt_ch_loop:
    ; load periods ptr
    ld      hl, (__sc_music_step_ptr)
    ; read period (uint16_t, little-endian)
    ld      c, (hl)             ; C = period lo
    inc     hl
    ld      a, (hl)             ; A = period hi
    inc     hl
    ld      (__sc_music_step_ptr), hl  ; update ptr past this period

    ld      h, a                ; HL = period
    ld      l, c

    ; load volumes ptr
    ld      de, (__sc_music_vol_ptr)
    ld      a, (de)             ; A = volume for this channel
    inc     de
    ld      (__sc_music_vol_ptr), de  ; update ptr past this volume
    ld      c, a                ; C = volume (A is clobbered below)

    ; check period==0 -> silence
    ld      a, h
    or      l
    jr      nz, __mt_play_ch

    ; period == 0: silence this channel
    ld      a, b                ; A = channel
    push    bc
    call    _cpc_sound_silence
    pop     bc
    jr      __mt_ch_next

__mt_play_ch:
    ; period != 0: play tone. sdcccall(1): channel in A, period in DE,
    ; volume pushed as 1 byte (callee cleans it up).
    push    bc                  ; save B=channel, C=volume
    ld      a, c
    push    af
    inc     sp                  ; push volume (1 byte)
    ex      de, hl              ; DE = period
    ld      a, b                ; A = channel
    call    _cpc_sound_tone     ; callee discards the volume byte
    pop     bc                  ; restore channel/volume

__mt_ch_next:
    inc     b
    ld      a, b
    cp      #3
    jr      c, __mt_ch_loop

    ; advance step index
    ld      a, (__cpc_music_index)
    inc     a
    ld      b, a
    ld      a, (__cpc_music_steps)
    cp      b
    jr      nz, __mt_no_wrap
    ld      b, #0
__mt_no_wrap:
    ld      a, b
    ld      (__cpc_music_index), a

__mt_done:
    pop     hl
    pop     de
    pop     bc
    pop     af
    ret

;==============================================================================
; _cpc_music_stop()
;==============================================================================
_cpc_music_stop::
    xor     a
    ld      (__cpc_music_steps), a
    jp      _cpc_sound_silence_all
