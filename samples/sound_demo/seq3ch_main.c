/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"

/* Sequential test: A -> B -> C -> chord
 * Makes it obvious if all 3 channels work independently
 */

static const uint16_t seq_periods[] = {
    /* Step 0: only A (C4 low) */
    NOTE_C4, 0, 0,
    /* Step 1: only B (E4 mid) */
    0, NOTE_E4, 0,
    /* Step 2: only C (A4 high) */
    0, 0, NOTE_A4,
    /* Step 3: all together (chord) */
    NOTE_C4, NOTE_E4, NOTE_A4,
    /* Step 4: silence */
    0, 0, 0
};

static const uint8_t seq_volumes[] = {
    15, 0, 0,
    0, 15, 0,
    0, 0, 15,
    15, 15, 15,
    0, 0, 0
};

void main(void) {
    cpc_init(CPC_MODE_0);
    
    /* Should hear: low beep -> mid beep -> high beep -> chord */
    cpc_music_set_tempo(15);  /* 1/3 second per step */
    cpc_music_play(seq_periods, seq_volumes, 5);

    while (1) {
        cpc_vblank_wait();  /* music tick is handled inside vblank wait */
    }
}
