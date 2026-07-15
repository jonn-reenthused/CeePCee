/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_INIT_H
#define CPC_INIT_H

#include "cpc_types.h"

/* Screen mode flags for cpc_init() */
#define CPC_MODE_0       0x00    /* 160x200, 16 colours */
#define CPC_MODE_1       0x01    /* 320x200, 4 colours  */
#define CPC_MODE_2       0x02    /* 640x200, 2 colours  */

/*
 * cpc_init(mode)
 * Initialise CPC+ / GX4000 hardware:
 *   - Unlocks the ASIC (enables Plus features)
 *   - Sets screen mode
 *   - Clears screen RAM ($C000..$FFFF)
 *   - Sets a default palette (black background)
 *   - Initialises runtime state (sprites, sound, input, text)
 *   - Installs IM1 safe interrupt handler
 *   - Enables interrupts
 *
 * mode: CPC_MODE_0 / CPC_MODE_1 / CPC_MODE_2
 */
void cpc_init(uint8_t mode);

/*
 * cpc_vblank_wait()
 * Wait for the next 50Hz frame sync.
 * Must be called once per game loop iteration.
 * Also services input polling and music playback.
 */
void cpc_vblank_wait(void);

/*
 * cpc_frame_count()
 * Return the current 16-bit frame counter. Increments at 50Hz.
 * Useful for frame-rate independent timing:
 *   elapsed = cpc_frame_count() - last_frame;
 */
uint16_t cpc_frame_count(void);

#endif
