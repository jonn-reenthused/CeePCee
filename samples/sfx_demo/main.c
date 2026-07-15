/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Sound Effects sample
*/

#include "cpc_init.h"
#include "cpc_sound.h"
#include "cpc_input.h"

#define PLAYER_1  0

static void sfx_beep(void) {
    /* Direct PSG write: Channel A, period 0x47, volume 15 */
    cpc_sound_write(0, 0x47);      /* R0 = fine period A */
    cpc_sound_write(1, 0x00);      /* R1 = coarse period A */
    cpc_sound_write(8, 15);        /* R8 = volume A */
    cpc_sound_mixer(0xC0);         /* tones on */
}

static void sfx_laser(void) {
    /* Direct PSG write: Channel B, period 0x47, volume 12 */
    cpc_sound_write(2, 0x47);      /* R2 = fine period B */
    cpc_sound_write(3, 0x00);      /* R3 = coarse period B */
    cpc_sound_write(9, 12);        /* R9 = volume B */
    cpc_sound_mixer(0xC0);         /* tones on */
}

static void sfx_explosion(void) {
    cpc_sound_noise(20);
    cpc_sound_mixer(0xC0 & ~SOUND_NOISE_A);  /* noise on A */
    cpc_sound_volume(SOUND_CH_A, 15);
}

static void sfx_chime(void) {
    /* Channel A: NOTE_E5=190(0xBE), Channel B: NOTE_B5=63(0x3F) */
    cpc_sound_write(0, 0xBE); cpc_sound_write(1, 0x00); cpc_sound_write(8, 10);
    cpc_sound_write(2, 0x3F); cpc_sound_write(3, 0x00); cpc_sound_write(9, 8);
    cpc_sound_mixer(0xC0);
}

static void sfx_clunk(void) {
    /* Channel C: NOTE_C3=0x1DE */
    cpc_sound_write(4, 0xDE); cpc_sound_write(5, 0x01); cpc_sound_write(10, 12);
    cpc_sound_mixer(0xC0);
}

/* Write byte to screen RAM at $C000 (top-left is $C000) */
#define SCREEN_BASE 0xC000
static void poke_screen(uint16_t offset, uint8_t val) {
    *(uint8_t*)(SCREEN_BASE + offset) = val;
}

static uint8_t sfx_timer = 0;
static uint8_t sfx_channels = 0;  /* bitmask of active channels */

static void sfx_update(void) {
    if (sfx_timer == 0) return;
    sfx_timer--;
    if (sfx_timer == 0) {
        /* Turn off all channels that were playing */
        if (sfx_channels & 0x01) cpc_sound_write(8, 0);
        if (sfx_channels & 0x02) cpc_sound_write(9, 0);
        if (sfx_channels & 0x04) cpc_sound_write(10, 0);
        /* Reset mixer to tones only, no noise */
        cpc_sound_mixer(0xC0);
        sfx_channels = 0;
    }
}

static void sfx_trigger(uint8_t ch_mask, uint8_t frames) {
    sfx_channels = ch_mask;
    sfx_timer = frames;
}

void main(void) {
    uint8_t frame = 0;
    
    cpc_init(CPC_MODE_0);
    cpc_sound_silence_all();
    cpc_sound_mixer(0xC0);  /* ensure tones enabled */
    
    /* Clear first 16 bytes of screen to black */
    uint16_t i;
    for (i = 0; i < 16; i++) poke_screen(i, 0);
    
    while (1) {
        /* Visual feedback + trigger SFX */
        if (cpc_input_button1_pressed(PLAYER_1)) { 
            poke_screen(0, 0xFF); sfx_beep(); sfx_trigger(0x01, 10);
        }
        if (cpc_input_up_pressed(PLAYER_1)) { 
            poke_screen(2, 0xFF); sfx_laser(); sfx_trigger(0x02, 15);
        }
        if (cpc_input_down_pressed(PLAYER_1)) { 
            poke_screen(4, 0xFF); sfx_explosion(); sfx_trigger(0x01, 20);
        }
        if (cpc_input_left_pressed(PLAYER_1)) { 
            poke_screen(6, 0xFF); sfx_chime(); sfx_trigger(0x03, 25);
        }
        if (cpc_input_right_pressed(PLAYER_1)) { 
            poke_screen(8, 0xFF); sfx_clunk(); sfx_trigger(0x04, 8);
        }
        
        /* Update SFX timer */
        sfx_update();
        
        /* Fade feedback pixels */
        frame++;
        if ((frame & 0x0F) == 0) {
            for (i = 0; i < 16; i++) {
                uint8_t v = *(uint8_t*)(SCREEN_BASE + i);
                if (v) poke_screen(i, v >> 1);
            }
        }
        
        cpc_vblank_wait();
    }
}
