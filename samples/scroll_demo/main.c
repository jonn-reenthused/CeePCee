/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Scrolling tilemap demo
*/

#include "cpc_init.h"
#include "cpc_gfx.h"
#include "cpc_scroll.h"
#include "asset_info.h"   /* ASSET_N_TILES, ASSET_MAP_W, ASSET_MAP_H */

/*
 * Asset binary at $4000 (produced by map_from_image.py):
 *   Bytes  0-31              : ASIC palette
 *   Bytes  32+               : Tile graphics (ASSET_N_TILES x 32 bytes)
 *   Bytes  32+ASSET_N_TILES*32 : Map data (ASSET_MAP_W x ASSET_MAP_H bytes)
 */
#define ASSET_BASE   ((const uint8_t *)0x4000)
#define TILE_PALETTE ((const uint16_t *)ASSET_BASE)
#define TILE_GFX     (ASSET_BASE + 32)
#define MAP_DATA     (ASSET_BASE + 32 + ASSET_N_TILES * 32)

void main(void)
{
    uint8_t cols;

    cpc_init(CPC_MODE_0);
    cpc_palette_set_plus(TILE_PALETTE);

    __asm di __endasm;
    cpc_scroll_tilemap_init(TILE_GFX, MAP_DATA,
                            (ASSET_MAP_H << 8) | ASSET_MAP_W);
    cpc_scroll_tilemap_draw_initial();
    __asm ei __endasm;

    while (1) {
        cpc_vblank_wait();
        __asm di __endasm;
        cols = cpc_scroll_tilemap_tick(2);
        __asm ei __endasm;
        if (cols) {
            cpc_scroll_tilemap_draw_column();
        }
    }
}
