/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Showing an image on the screen
*/

#include "cpc_init.h"
#include "cpc_gfx.h"

/* Boot stub copies CPR bank cb01 to RAM $4000 before main() runs. */
#define IMAGE_DATA  ((const uint8_t *)0x4000)

#ifndef SCREEN_MODE
#define SCREEN_MODE 0
#endif

void main(void)
{
    cpc_init(SCREEN_MODE);
    cpc_screen_load(IMAGE_DATA);

    while (1) {
        cpc_vblank_wait();
    }
}
