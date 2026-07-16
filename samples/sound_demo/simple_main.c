/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"

/* Simple test: just 3 notes, one channel, no MIDI conversion */

static const uint16_t simple_periods[] = {
    /* step 0-7: E4 notes/rests on channel A only */
    NOTE_E4, 0, 0,
    NOTE_REST, 0, 0,
    NOTE_E4, 0, 0,
    NOTE_REST, 0, 0,
    NOTE_E4, 0, 0,
    NOTE_REST, 0, 0,
    0, 0, 0,
    0, 0, 0
};

static const uint8_t simple_volumes[] = {
    15, 0, 0,
    0, 0, 0,
    15, 0, 0,
    0, 0, 0,
    15, 0, 0,
    0, 0, 0,
    0, 0, 0,
    0, 0, 0
};

void main(void) {
    cpc_init(CPC_MODE_0);

    /* Start with everything silent */
    cpc_sound_silence_all();

    /* Play just channel A with E4 notes */
    cpc_music_set_tempo(6);
    cpc_music_play(simple_periods, simple_volumes, 8);

    while (1) {
        cpc_vblank_wait();  /* music tick is handled inside vblank wait */
    }
}
