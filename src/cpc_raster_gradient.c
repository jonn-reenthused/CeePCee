/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#include "cpc_raster.h"

/*
 * cpc_raster_set_gradient
 *
 * Quickly build a vertical gradient background using the ASIC palette.
 *
 *  start   - 16-bit CPC+ colour at the top of the screen (0x0GRB)
 *  end     - 16-bit CPC+ colour at the bottom of the screen (0x0GRB)
 *  count   - number of raster entries to generate (1 .. CPC_RASTER_MAX_ENTRIES)
 *
 * The function interpolates each 4-bit R/G/B component between the two
 * colours and installs the resulting raster program.
 */
void cpc_raster_set_gradient(uint16_t start, uint16_t end, uint8_t count)
{
    cpc_raster_entry_t tmp[CPC_RASTER_MAX_ENTRIES];
    uint8_t i;
    uint8_t max;
    uint8_t step;

    /* Clamp count and compute a step that covers the visible 200 lines */
    if (count == 0 || count > CPC_RASTER_MAX_ENTRIES)
        count = CPC_RASTER_MAX_ENTRIES;

    max = (count > 1) ? (count - 1) : 1;
    step = (count > 1) ? (199 / max) : 0;

    /* Extract 4-bit colour components */
    uint8_t s_g = (uint8_t)((start >> 8) & 0x0F);
    uint8_t s_r = (uint8_t)((start >> 4) & 0x0F);
    uint8_t s_b = (uint8_t)(start & 0x0F);

    uint8_t e_g = (uint8_t)((end >> 8) & 0x0F);
    uint8_t e_r = (uint8_t)((end >> 4) & 0x0F);
    uint8_t e_b = (uint8_t)(end & 0x0F);

    for (i = 0; i < count; i++) {
        int16_t t = (int16_t)i;
        int16_t d = (int16_t)max;

        uint8_t g = (uint8_t)(s_g + (int16_t)(((int16_t)e_g - (int16_t)s_g) * t) / d);
        uint8_t r = (uint8_t)(s_r + (int16_t)(((int16_t)e_r - (int16_t)s_r) * t) / d);
        uint8_t b = (uint8_t)(s_b + (int16_t)(((int16_t)e_b - (int16_t)s_b) * t) / d);

        tmp[i].line = (uint8_t)(i * step);
        tmp[i].pen  = 0;
        tmp[i].colour = (uint16_t)(((uint16_t)(g & 0x0F) << 8) |
                                    ((uint16_t)(r & 0x0F) << 4) |
                                    ((uint16_t)(b & 0x0F)));
    }

    cpc_raster_set_program(tmp, count);
}
