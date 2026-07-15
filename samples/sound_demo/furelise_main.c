/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_init.h"
#include "cpc_sound.h"
#include "furelise.h"

/*
 * Für Elise via MIDI conversion
 * Auto-converted from FURELIS3.mid using midi_to_psg.py
 * 200 steps, tempo=6 (~8 steps/sec)
 */

void main(void) {
    cpc_init(CPC_MODE_0);

    cpc_music_set_tempo(FURELIS3_TEMPO);
    cpc_music_play(FURELIS3_periods, FURELIS3_volumes, FURELIS3_STEPS);

    while (1) {
        cpc_vblank_wait();
        cpc_music_tick();
    }
}
