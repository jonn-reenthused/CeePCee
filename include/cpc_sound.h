/*
CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
2026 Johnny Blanchard
*/

#ifndef CPC_SOUND_H
#define CPC_SOUND_H

#include "cpc_types.h"

/*
 * PSG channel numbers
 */
#define SOUND_CH_A      0
#define SOUND_CH_B      1
#define SOUND_CH_C      2

/*
 * Mixer mask bits for cpc_sound_mixer().
 * Bit=0 enables the source for that channel.
 */
#define SOUND_TONE_A    0x01
#define SOUND_TONE_B    0x02
#define SOUND_TONE_C    0x04
#define SOUND_NOISE_A   0x08
#define SOUND_NOISE_B   0x10
#define SOUND_NOISE_C   0x20
#define SOUND_ALL_OFF   0x3F

/*
 * Envelope shape codes for cpc_sound_envelope().
 * Bit pattern: CONT ATT ALT HOLD
 */
#define ENV_DECAY       0x08    /* single decay then silence */
#define ENV_ATTACK      0x0C    /* single attack then full */
#define ENV_DECAY_LOOP  0x0A    /* sawtooth down */
#define ENV_ATTACK_LOOP 0x0E    /* sawtooth up */
#define ENV_TRIANGLE    0x0E    /* alias */

/*
 * Volume flag: pass as volume to cpc_sound_tone/volume to use envelope output.
 */
#define SOUND_USE_ENVELOPE  16

/*
 * Musical note periods (CPC PSG, 1MHz clock)
 * Formula: period = 1,000,000 / (16 * freq_hz)
 * Example: A4 = 440 Hz -> period = 1000000 / 7040 = 142
 * Valid range: 1..4095 (12-bit period registers)
 */
#define NOTE_C3   478
#define NOTE_CS3  451
#define NOTE_D3   426
#define NOTE_DS3  402
#define NOTE_E3   379
#define NOTE_F3   358
#define NOTE_FS3  338
#define NOTE_G3   319
#define NOTE_GS3  301
#define NOTE_A3   284
#define NOTE_AS3  268
#define NOTE_B3   253

#define NOTE_C4   239
#define NOTE_CS4  225
#define NOTE_D4   213
#define NOTE_DS4  201
#define NOTE_E4   190
#define NOTE_F4   179
#define NOTE_FS4  169
#define NOTE_G4   159
#define NOTE_GS4  150
#define NOTE_A4   142
#define NOTE_AS4  134
#define NOTE_B4   127

#define NOTE_C5   119
#define NOTE_CS5  113
#define NOTE_D5   106
#define NOTE_DS5  100
#define NOTE_E5   95
#define NOTE_F5   89
#define NOTE_FS5  84
#define NOTE_G5   80
#define NOTE_GS5  75
#define NOTE_A5   71
#define NOTE_AS5  67
#define NOTE_B5   63

#define NOTE_C6   60
#define NOTE_REST 0     /* use period=0 to silence a channel in a sequence */

/*===========================================================================
 * Low-level PSG API
 *===========================================================================*/

/*
 * cpc_sound_write(reg, value)
 * Raw write to a PSG register (0-13). For advanced use.
 */
void cpc_sound_write(uint8_t reg, uint8_t value);

/*
 * cpc_sound_tone(channel, period, volume)
 * Set tone period and volume on one channel. Enables tone in mixer.
 * channel: 0-2 (SOUND_CH_A/B/C)
 * period:  12-bit tone period (0 = off, use NOTE_* constants)
 * volume:  0-15 direct level, or SOUND_USE_ENVELOPE (16) for envelope output
 */
void cpc_sound_tone(uint8_t channel, uint16_t period, uint8_t volume) __sdcccall(1);

/*
 * cpc_sound_noise(period)
 * Set the noise generator period (0-31).
 * Enable noise per channel via cpc_sound_mixer().
 */
void cpc_sound_noise(uint8_t period);

/*
 * cpc_sound_mixer(mask)
 * Directly set the PSG mixer register.
 * Use SOUND_TONE_x / SOUND_NOISE_x bit constants (0 = enabled).
 * Bits 6-7 (I/O direction) are always set to 1 automatically.
 */
void cpc_sound_mixer(uint8_t mask);

/*
 * cpc_sound_volume(channel, vol)
 * Set volume for a channel without changing period or mixer.
 * vol: 0-15 = direct level, 16 = use envelope generator output.
 */
void cpc_sound_volume(uint8_t channel, uint8_t vol);

/*
 * cpc_sound_envelope(shape, period)
 * Configure and trigger the PSG envelope generator.
 * shape:  ENV_* constant (0-15)
 * period: 16-bit envelope period (larger = slower)
 * Writing to R13 restarts the envelope immediately.
 */
void cpc_sound_envelope(uint8_t shape, uint16_t period);

/*
 * cpc_sound_silence(channel)
 * Set volume to 0 and disable tone+noise for one channel.
 */
void cpc_sound_silence(uint8_t channel);

/*
 * cpc_sound_silence_all()
 * Mute all channels and reset the mixer.
 */
void cpc_sound_silence_all(void);

/*===========================================================================
 * Music sequencer
 *
 * 3-channel step sequencer. Data arrays are indexed [step][channel].
 * Flat layout: periods[step*3+ch], volumes[step*3+ch].
 *
 * periods[i] = NOTE_REST (0) silences that channel for that step.
 * Sequencer loops continuously. Tempo default = 6 frames/step (~8.3 steps/sec).
 *===========================================================================*/

/*
 * cpc_music_play(periods, volumes, steps)
 * Start playing a sequence. Called once to set up.
 * periods: uint16_t[steps*3]  -- tone period per step per channel
 * volumes: uint8_t[steps*3]   -- volume per step per channel (0-15 or 16=env)
 * steps:   number of steps in the sequence
 */
void cpc_music_play(const uint16_t *periods, const uint8_t *volumes, uint8_t steps);

/*
 * cpc_music_tick()
 * Advance sequencer by one frame. Called automatically by cpc_vblank_wait().
 */
void cpc_music_tick(void);

/*
 * cpc_music_stop()
 * Stop sequencer and silence all channels.
 */
void cpc_music_stop(void);

/*
 * cpc_music_set_tempo(frames_per_step)
 * Set sequencer tempo. Default = 6 (50Hz / 6 ≈ 8 steps/sec).
 * Lower = faster. Minimum = 1.
 */
void cpc_music_set_tempo(uint8_t frames_per_step);

#endif
