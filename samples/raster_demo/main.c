/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard

Raster background drawing demo
*/

/*
 * Raster Bars Demo
 * 
 * Fire motif: Joystick Up
 * Sky/Grass motif: Joystick Down
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
#define RGB_RED      0x000F
#define RGB_ORANGE   0x008C
#define RGB_YELLOW   0x00FF
#define RGB_DKRED    0x0004
#define RGB_BLUE     0x0F00
#define RGB_LTBLUE   0x0FA0
#define RGB_CYAN     0x0FF0
#define RGB_GREEN    0x00F0
#define RGB_LTGREEN  0x08F0
#define RGB_DKGREEN  0x0040
#define RGB_BROWN    0x0824

/* Maximum raster entries for full screen coverage */
#define RASTER_COUNT  32

/* Current theme and raster program */
static uint8_t current_theme = 0;  /* 0 = fire, 1 = sky/grass */
static cpc_raster_entry_t raster_program[RASTER_COUNT];

/* Fire motif - reds, oranges, yellows, blacks */
static void init_fire_theme(void) {
    const uint16_t fire_colours[RASTER_COUNT] = {
        RGB_BLACK, RGB_DKRED, RGB_RED, RGB_ORANGE, 
        RGB_YELLOW, RGB_ORANGE, RGB_RED, RGB_DKRED,
        RGB_BLACK, RGB_DKRED, RGB_RED, RGB_ORANGE,
        RGB_YELLOW, RGB_ORANGE, RGB_RED, RGB_DKRED,
        RGB_BLACK, RGB_DKRED, RGB_RED, RGB_ORANGE,
        RGB_YELLOW, RGB_ORANGE, RGB_RED, RGB_DKRED,
        RGB_BLACK, RGB_DKRED, RGB_RED, RGB_ORANGE,
        RGB_YELLOW, RGB_ORANGE, RGB_RED, RGB_DKRED
    };
    
    uint8_t i;
    uint8_t line = 0;
    uint8_t step = 5;  /* ~5 lines per colour = ~200 lines total */
    
    for (i = 0; i < RASTER_COUNT; i++) {
        raster_program[i].line = line;
        raster_program[i].pen = 0;  /* Change pen 0 (background) */
        raster_program[i].colour = fire_colours[i % (sizeof(fire_colours)/sizeof(fire_colours[0]))];
        line += step;
    }
    
    cpc_raster_set_program(raster_program, RASTER_COUNT);
}

/* Sky and Grass motif - blues for sky, greens for grass */
static void init_skygrass_theme(void) {
    /* First 16 entries = sky (lines 0-80), last 16 = grass (lines 80-160) */
    const uint16_t sky_colours[] = {
        RGB_LTBLUE, RGB_BLUE, RGB_CYAN, RGB_LTBLUE,
        RGB_BLUE, RGB_LTBLUE, RGB_CYAN, RGB_BLUE,
        RGB_LTBLUE, RGB_BLUE, RGB_CYAN, RGB_LTBLUE,
        RGB_BLUE, RGB_LTBLUE, RGB_CYAN, RGB_LTBLUE
    };
    
    const uint16_t grass_colours[] = {
        RGB_LTGREEN, RGB_GREEN, RGB_DKGREEN, RGB_GREEN,
        RGB_LTGREEN, RGB_GREEN, RGB_DKGREEN, RGB_GREEN,
        RGB_LTGREEN, RGB_GREEN, RGB_DKGREEN, RGB_GREEN,
        RGB_BROWN, RGB_DKGREEN, RGB_GREEN, RGB_LTGREEN
    };
    
    uint8_t i;
    uint8_t line = 0;
    uint8_t step = 5;
    uint8_t half = RASTER_COUNT / 2;
    
    /* Sky section (first half) */
    for (i = 0; i < half; i++) {
        raster_program[i].line = line;
        raster_program[i].pen = 0;
        raster_program[i].colour = sky_colours[i];
        line += step;
    }
    
    /* Grass section (second half) */
    for (i = half; i < RASTER_COUNT; i++) {
        raster_program[i].line = line;
        raster_program[i].pen = 0;
        raster_program[i].colour = grass_colours[i - half];
        line += step;
    }
    
    cpc_raster_set_program(raster_program, RASTER_COUNT);
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
