/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_SCROLL_H
#define CPC_SCROLL_H

#include "cpc_types.h"

/*
 * CPC+ Hardware Scroll
 *
 * The CPC+ ASIC provides both coarse (character-aligned) and fine (sub-pixel)
 * scrolling via CRTC register 12/13 and ASIC soft-scroll registers.
 *
 * Coarse scroll: moves the display origin by full character rows/columns.
 * Fine scroll: smooth sub-pixel scroll (0..7 pixels horizontal, 0..7 vertical).
 */

/*
 * cpc_scroll_set(x_chars, y_chars)
 * Set coarse scroll position. Units are character columns / rows.
 * Wraps the display window over a virtual screen.
 */
void cpc_scroll_set(uint8_t x_chars, uint8_t y_chars);

/*
 * cpc_scroll_set_fine(x_pixels, y_pixels)
 * Set fine (sub-character) scroll offset.
 * x_pixels: 0..7, y_pixels: 0..7.
 */
void cpc_scroll_set_fine(uint8_t x_pixels, uint8_t y_pixels);

/*
 * cpc_scroll_disable()
 * Reset scroll to (0,0) and disable any active scroll state.
 */
void cpc_scroll_disable(void);

/*===========================================================================
 * Tilemap hardware scroll engine
 *
 * Uses CPC+ ASIC soft-scroll ($6804 bits 3..0) for sub-character pixel
 * accuracy, combined with CRTC R12/R13 coarse offset for full-screen
 * hardware scrolling. Tile columns are blitted into the off-screen edge
 * when the scroll crosses a tile boundary.
 *
 * Scroll direction: positive dx = world moves left (camera moves right).
 *
 * Call sequence each frame:
 *   1. cpc_vblank_wait()          -- wait for vsync
 *   2. cpc_scroll_tilemap_tick()  -- update CRTC+ASIC registers, returns
 *                                    number of new tile columns needed
 *   3. while (cols--) cpc_scroll_tilemap_draw_column() -- blit new column
 *
 * VRAM layout:
 *   Screen VRAM = $C000-$FFFF (16KB). The 25-row x 21-column working area
 *   fits in 25*8 * 21*4 = 16800 bytes -- just over 16KB, so we keep the
 *   logical screen width at exactly 21 tiles (84 bytes/row) and let the
 *   CRTC wrap within the 16KB window.
 *===========================================================================*/

/*
 * cpc_scroll_tilemap_init(tile_gfx, map_data, map_dims)
 * Initialise the tilemap scroll engine.
 *   tile_gfx  : pointer to tile graphics (32 bytes/tile)
 *   map_data  : pointer to map data (uint8_t array, row-major)
 *   map_dims  : (map_height << 8) | map_width
 * Must be called before cpc_scroll_tilemap_draw_initial().
 */
void cpc_scroll_tilemap_init(const uint8_t *tile_gfx, const uint8_t *map_data,
                              uint16_t map_dims);

/*
 * cpc_scroll_tilemap_draw_initial()
 * Draw the first 21 tile columns (20 visible + 1 off-screen right edge)
 * to VRAM. Call once after init, before entering the main loop.
 */
void cpc_scroll_tilemap_draw_initial(void);

/*
 * cpc_scroll_tilemap_tick(dx)
 * Update CRTC R12/R13 and ASIC $6804 for one frame.
 *   dx: pixels to scroll this frame (1..4 for Mode 0; must be multiple of 1)
 * Returns the number of new tile columns that must be drawn (0 or 1).
 * Call at vsync. Draw any pending columns after this returns.
 */
uint8_t cpc_scroll_tilemap_tick(uint8_t dx);

/*
 * cpc_scroll_tilemap_draw_column()
 * Blit the next map column into the off-screen VRAM edge.
 * Call once per column reported by cpc_scroll_tilemap_tick().
 */
void cpc_scroll_tilemap_draw_column(void);

#endif
