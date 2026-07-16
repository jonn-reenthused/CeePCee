/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

/*
 * Raster Bars / Gradient Demo
 * 
 * Smooth fire gradient: Joystick Up
 * Smooth sky/grass gradient: Joystick Down
 * Toggle: Fire button
 */

#include "cpc_init.h"
#include "cpc_input.h"
#include "cpc_raster.h"
#include "cpc_gfx.h"

#define PLAYER_1  0

/* CPC+ ASIC colours in 0x0GRB format (4 bits each) */
#define RGB_BLACK    0x0000
#define RGB_WHITE    0x0FFF
#define RGB_RED      0x00F0
#define RGB_ORANGE   0x08F0
#define RGB_YELLOW   0x0FF0
#define RGB_DKRED    0x0040
#define RGB_BLUE     0x000F
#define RGB_LTBLUE   0x005A
#define RGB_CYAN     0x0F0F
#define RGB_GREEN    0x0F00
#define RGB_LTGREEN  0x0FA0
#define RGB_DKGREEN  0x0840
#define RGB_BROWN    0x0840

/* Maximum raster entries for full screen coverage */
#define RASTER_COUNT  32

/* Current theme */
static uint8_t current_theme = 0;  /* 0 = fire, 1 = sky/grass */

/* Fire motif - smooth black to red/orange/yellow gradient */
static void init_fire_theme(void) {
    cpc_raster_set_gradient(RGB_BLACK, RGB_YELLOW, CPC_RASTER_MAX_ENTRIES);
}

/* Sky and Grass motif - blue sky to green grass gradient */
static void init_skygrass_theme(void) {
    cpc_raster_set_gradient(RGB_LTBLUE, RGB_LTGREEN, CPC_RASTER_MAX_ENTRIES);
}

void main(void) {
    cpc_init(CPC_MODE_1);
    
    /* Set initial theme */
    init_fire_theme();
    
    /* Set pen 0 to white initially (will be overridden by raster) */
    cpc_palette_set_ink(0, INK_WHITE);
    
    /* Clear screen to black */
    cpc_screen_clear(INK_BLACK);
    
    while (1) {
        /* Toggle theme with fire button */
        if (cpc_input_button1_pressed(PLAYER_1)) {
            current_theme = !current_theme;
            if (current_theme == 0) {
                init_fire_theme();
            } else {
                init_skygrass_theme();
            }
        }
        
        /* Direct theme selection */
        if (cpc_input_up_pressed(PLAYER_1)) {
            current_theme = 0;
            init_fire_theme();
        }
        if (cpc_input_down_pressed(PLAYER_1)) {
            current_theme = 1;
            init_skygrass_theme();
        }
        
        cpc_vblank_wait();
    }
}
