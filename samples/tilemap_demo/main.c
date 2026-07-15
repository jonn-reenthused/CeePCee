/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Sample of showing a tilemap
*/

#include "cpc_init.h"
#include "cpc_gfx.h"
#include "cpc_tilemap.h"

#define ASSET_BASE   ((const uint8_t *)0x4000)
#define TILE_PALETTE ((const uint16_t *)ASSET_BASE)
#define TILE_GFX     (ASSET_BASE + 32)
#define MAP_DATA     (ASSET_BASE + 32 + 512)

#define MAP_W   20
#define MAP_H   25

void main(void)
{
    cpc_init(CPC_MODE_0);
    cpc_palette_set_plus(TILE_PALETTE);
    cpc_tilemap_init(TILE_GFX, MAP_DATA, (MAP_H << 8) | MAP_W);
    __asm di __endasm;
    cpc_tilemap_draw(0, 0);
    __asm ei __endasm;

    while (1) {
        cpc_vblank_wait();
    }
}
