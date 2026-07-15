/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_TEXT_H
#define CPC_TEXT_H

#include "cpc_types.h"

/*
 * Text rendering uses an 8x8 glyph font in Mode 0 (or Mode 1).
 * The default font is the CPC firmware ROM font (read from lower ROM at boot).
 * A custom font can be installed with cpc_text_set_font().
 *
 * Column/row coordinates are in character cells (not pixels).
 * At Mode 0 (160 pixels wide, 8px chars): 20 columns x 25 rows.
 * At Mode 1 (320 pixels wide, 8px chars): 40 columns x 25 rows.
 */

/*
 * cpc_text_print(col, row, str)
 * Print a null-terminated string at character column <col>, row <row>.
 * sdcccall(1): col in A, row in L, str in DE.
 */
void cpc_text_print(uint8_t col, uint8_t row, const char *str);

/*
 * cpc_text_putc(col, row, ch)
 * Print a single character at a specific column and row.
 * sdcccall(1): col in A, row in L, ch on stack.
 */
void cpc_text_putc(uint8_t col, uint8_t row, char ch);

/*
 * cpc_text_clear(col, row, n)
 * Zero n character cells starting at (col, row), across all 8 scan lines.
 * Use before redrawing text to prevent overlay.
 * sdcccall(1): col in A, row in L, n on stack.
 */
void cpc_text_clear(uint8_t col, uint8_t row, uint8_t n);

/*
 * cpc_text_set_ink(pen)
 * Set the pen used for text foreground. Default: pen 1.
 */
void cpc_text_set_ink(uint8_t pen);

/*
 * cpc_text_set_paper(pen)
 * Set the pen used for text background (transparent if 255). Default: pen 0.
 */
void cpc_text_set_paper(uint8_t pen);

/*
 * cpc_text_set_font(font_data, char_width, char_height, first_char)
 * Install a custom font.
 *   font_data:   pointer to raw glyph bitmap data.
 *                Each glyph is char_height bytes of char_width pixels wide.
 *   char_width:  glyph width in Mode 0 screen bytes (1 byte = 2 pixels in M0,
 *                4 pixels in M1). Typically 4 for Mode 0, 2 for Mode 1.
 *   char_height: glyph height in pixel rows. Typically 8.
 *   first_char:  ASCII code of the first glyph in font_data (typically 32).
 */
void cpc_text_set_font(const uint8_t *font_data, uint8_t char_width,
                       uint8_t char_height, uint8_t first_char);

/*
 * cpc_text_use_firmware_font()
 * Restore the default CPC firmware ROM font (undoes cpc_text_set_font).
 */
void cpc_text_use_firmware_font(void);

#endif
