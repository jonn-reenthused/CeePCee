/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_TILEMAP_H
#define CPC_TILEMAP_H

#include "cpc_types.h"

/*
 * Tilemap engine — 8x8 pixel tiles in Mode 0.
 *
 * Tiles are 8 pixels wide x 8 pixels tall. In Mode 0 (2 pixels per byte),
 * each row is 4 bytes wide. Each tile = 4 bytes x 8 rows = 32 bytes.
 *
 * The visible screen in Mode 0 is 160x200 pixels = 20 tiles wide x 25 tall.
 *
 * A tilemap is an array of tile indices (uint8_t) laid out row-major:
 *   map[row * map_width + col] = tile_id
 *
 * The viewport is always 20x25 tiles (full screen).
 * scroll_x / scroll_y in cpc_tilemap_draw are in tiles.
 */

/*
 * cpc_tilemap_init(tile_gfx, map_data, map_dims)
 * Set the active tilemap.
 *   tile_gfx:   pointer to tile graphics data. Each tile = 32 bytes.
 *   map_data:   pointer to tile index map (uint8_t array, row-major).
 *   map_dims:   (map_height << 8) | map_width  — packed into one uint16_t.
 */
void cpc_tilemap_init(const uint8_t *tile_gfx, const uint8_t *map_data,
                      uint16_t map_dims);

/*
 * cpc_tilemap_draw(scroll_x, scroll_y)
 * Draw the tilemap viewport to screen starting at tile offset
 * (scroll_x, scroll_y) within the map. The viewport fills the screen.
 * scroll_x and scroll_y are in tiles (not pixels).
 */
void cpc_tilemap_draw(uint8_t scroll_x, uint8_t scroll_y);

/*
 * cpc_tilemap_get(col, row)
 * Get the tile index at map position (col, row).
 */
uint8_t cpc_tilemap_get(uint8_t col, uint8_t row);

/*
 * cpc_tilemap_set(col, row, tile_id)
 * Set a tile in the map at position (col, row).
 */
void cpc_tilemap_set(uint8_t col, uint8_t row, uint8_t tile_id);

#endif
