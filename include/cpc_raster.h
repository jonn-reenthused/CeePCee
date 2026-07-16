/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_RASTER_H
#define CPC_RASTER_H

#include "cpc_types.h"

/*
 * Raster / Copper-bar effects using the CPC+ programmable raster interrupt.
 *
 * The CPC+ ASIC can generate an interrupt at a specific scan line, allowing
 * palette changes mid-screen to create colour bars, gradients, and split-screen.
 *
 * A raster program is a table of (scan_line, pen, colour) entries applied
 * automatically each frame during cpc_vblank_wait().
 *
 * Scan lines are 0-based from the top of the visible display area.
 */

/* Maximum entries in a raster program */
#define CPC_RASTER_MAX_ENTRIES  64

typedef struct {
    uint8_t  line;      /* scan line to trigger at (0 = top of display) */
    uint8_t  pen;       /* pen number to change (0..15) */
    uint16_t colour;    /* CPC+ ASIC colour (0x0GRB format) */
} cpc_raster_entry_t;

/*
 * cpc_raster_set_program(entries, count)
 * Install a raster program. The entries are applied in order each frame.
 * entries: array of cpc_raster_entry_t, sorted by line ascending.
 * count:   number of entries (max CPC_RASTER_MAX_ENTRIES).
 */
void cpc_raster_set_program(const cpc_raster_entry_t *entries, uint8_t count);

/*
 * cpc_raster_disable()
 * Remove the active raster program.
 */
void cpc_raster_disable(void);

/*
 * cpc_raster_set_gradient(start, end, count)
 * Quickly generate a vertical gradient from start to end colour.
 * Both colours are in CPC+ 0x0GRB format. count is the number of
 * raster bands (max CPC_RASTER_MAX_ENTRIES); more bands = smoother.
 * The gradient is applied to pen 0 (background).
 */
void cpc_raster_set_gradient(uint16_t start, uint16_t end, uint8_t count);

#endif
