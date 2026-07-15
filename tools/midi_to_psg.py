#!/usr/bin/env python3
# CeePCee v0.8alpha Amstrad CPC Plus and GX4000 SDK
# 2026 Johnny Blanchard

"""
midi_to_psg.py  --  Convert a MIDI file to CeePCee PSG music data.

Outputs a C header file containing:
  - uint16_t periods[]  -- PSG tone periods per step per channel (A,B,C)
  - uint8_t  volumes[]  -- PSG volumes per step per channel (0-15)
  - uint8_t  SONG_STEPS -- number of steps
  - uint8_t  SONG_TEMPO -- suggested frames-per-step for cpc_music_set_tempo()

Usage:
  python3 midi_to_psg.py input.mid output.h [options]

Options:
  --name NAME        C symbol prefix (default: derived from filename)
  --tempo FPS        Override frames-per-step (default: auto from MIDI BPM)
  --channels A,B,C   MIDI channel numbers to map to PSG ch A/B/C (1-indexed)
                     Default: auto-pick 3 busiest channels
  --tracks A,B,C     MIDI track indices to map (0-indexed, alternative to --channels)
  --quantize N       Quantize step size in MIDI ticks (default: auto = 1 beat / 4)
  --max-steps N      Truncate output to N steps (default: no limit)
  --loop             Find loop point (not yet implemented)
  --verbose          Print conversion details

PSG clock: 1 MHz. Period = 62500 / (2 * freq_hz).
CPC target framerate: 50 Hz.
"""

import sys
import os
import argparse
import struct
import math
from collections import defaultdict

# ---------------------------------------------------------------------------
# PSG period table: MIDI note 0-127 -> PSG period
# PSG clock = 1,000,000 Hz. Period = clock / (16 * freq)
# freq = 440 * 2^((note - 69) / 12)
# ---------------------------------------------------------------------------
PSG_CLOCK = 1_000_000  # CPC PSG runs at 1 MHz

def midi_note_to_period(note):
    """Convert MIDI note number to PSG period register value.
    Formula: period = clock / (16 * freq)
    freq = 440 * 2^((note-69)/12)
    """
    if note <= 0:
        return 0
    freq = 440.0 * (2.0 ** ((note - 69) / 12.0))
    period = PSG_CLOCK / (16.0 * freq)
    p = int(round(period))
    return max(1, min(4095, p))

# Pre-build table
NOTE_PERIODS = [midi_note_to_period(n) for n in range(128)]

# ---------------------------------------------------------------------------
# Minimal MIDI parser (no dependencies)
# ---------------------------------------------------------------------------

class MidiParseError(Exception):
    pass

def read_vlq(data, pos):
    """Read a MIDI variable-length quantity. Returns (value, new_pos)."""
    value = 0
    while True:
        if pos >= len(data):
            raise MidiParseError("Unexpected end of data reading VLQ")
        b = data[pos]
        pos += 1
        value = (value << 7) | (b & 0x7F)
        if not (b & 0x80):
            break
    return value, pos

def parse_midi(data):
    """
    Parse a MIDI file. Returns:
      {
        'format': 0/1/2,
        'ticks_per_beat': int,
        'tracks': [ [(abs_tick, event_type, channel, data...), ...], ... ]
      }
    event_type values: 'note_on', 'note_off', 'tempo', 'end'
    """
    if data[:4] != b'MThd':
        raise MidiParseError("Not a MIDI file")
    hdr_len = struct.unpack('>I', data[4:8])[0]
    fmt = struct.unpack('>H', data[8:10])[0]
    num_tracks = struct.unpack('>H', data[10:12])[0]
    ticks_per_beat = struct.unpack('>H', data[12:14])[0]

    if fmt == 2:
        raise MidiParseError("MIDI format 2 not supported")

    pos = 8 + hdr_len
    tracks = []

    for _ in range(num_tracks):
        if data[pos:pos+4] != b'MTrk':
            raise MidiParseError("Expected MTrk chunk")
        track_len = struct.unpack('>I', data[pos+4:pos+8])[0]
        track_data = data[pos+8 : pos+8+track_len]
        pos += 8 + track_len

        events = []
        t = 0
        p = 0
        running_status = 0

        while p < len(track_data):
            delta, p = read_vlq(track_data, p)
            t += delta

            # Peek at status byte
            b = track_data[p]
            if b & 0x80:
                status = b
                running_status = b
                p += 1
            else:
                status = running_status

            stype = status & 0xF0
            chan = status & 0x0F

            if stype == 0x80 or stype == 0x90:
                note = track_data[p]; vel = track_data[p+1]; p += 2
                if stype == 0x80 or vel == 0:
                    events.append((t, 'note_off', chan, note, vel))
                else:
                    events.append((t, 'note_on', chan, note, vel))

            elif stype == 0xA0:  # aftertouch
                p += 2
            elif stype == 0xB0:  # control change
                p += 2
            elif stype == 0xC0:  # program change
                p += 1
            elif stype == 0xD0:  # channel pressure
                p += 1
            elif stype == 0xE0:  # pitch bend
                p += 2
            elif status == 0xFF:  # meta event
                mtype = track_data[p]; p += 1
                mlen, p = read_vlq(track_data, p)
                mdata = track_data[p:p+mlen]; p += mlen
                if mtype == 0x51 and mlen == 3:  # tempo
                    us_per_beat = (mdata[0] << 16) | (mdata[1] << 8) | mdata[2]
                    events.append((t, 'tempo', 0, us_per_beat))
                elif mtype == 0x2F:
                    events.append((t, 'end', 0))
            elif status == 0xF0 or status == 0xF7:  # sysex
                slen, p = read_vlq(track_data, p)
                p += slen
            else:
                # Unknown / unhandled - try to skip
                p += 1

        tracks.append(events)

    return {
        'format': fmt,
        'ticks_per_beat': ticks_per_beat,
        'tracks': tracks
    }

# ---------------------------------------------------------------------------
# Channel activity analysis
# ---------------------------------------------------------------------------

def get_channel_activity(midi):
    """Count note events per (track, channel) pair."""
    activity = defaultdict(int)
    for ti, track in enumerate(midi['tracks']):
        for ev in track:
            if ev[1] in ('note_on', 'note_off'):
                activity[(ti, ev[2])] += 1
    return activity

def auto_pick_channels(midi, n=3, verbose=False):
    """Pick the n busiest (track, channel) pairs."""
    activity = get_channel_activity(midi)
    # Exclude MIDI channel 9 (drums, 0-indexed)
    filtered = {k: v for k, v in activity.items() if k[1] != 9}
    sorted_ch = sorted(filtered.items(), key=lambda x: -x[1])
    picked = [k for k, _ in sorted_ch[:n]]
    # Pad with None if fewer than n
    while len(picked) < n:
        picked.append(None)
    if verbose:
        print(f"Auto-selected channels (track, midi_ch):")
        for i, ch in enumerate(picked):
            if ch:
                print(f"  PSG ch {'ABC'[i]}: track {ch[0]}, MIDI ch {ch[1]+1}"
                      f" ({activity.get(ch,0)} events)")
            else:
                print(f"  PSG ch {'ABC'[i]}: (empty)")
    return picked

# ---------------------------------------------------------------------------
# Flatten MIDI to per-channel note streams
# ---------------------------------------------------------------------------

def flatten_notes(midi, src_channels):
    """
    For each PSG channel (list of 3 src_channels = (track,midi_ch) or None),
    produce a sorted list of (abs_tick, 'on'/'off', note, velocity).
    """
    streams = [[] for _ in range(3)]
    for psg_ch, src in enumerate(src_channels):
        if src is None:
            continue
        track_idx, midi_ch = src
        if track_idx >= len(midi['tracks']):
            continue
        for ev in midi['tracks'][track_idx]:
            if ev[1] == 'note_on' and ev[2] == midi_ch:
                streams[psg_ch].append((ev[0], 'on', ev[3], ev[4]))
            elif ev[1] == 'note_off' and ev[2] == midi_ch:
                streams[psg_ch].append((ev[0], 'off', ev[3], ev[4]))
        streams[psg_ch].sort(key=lambda x: x[0])
    return streams

# ---------------------------------------------------------------------------
# Determine tempo and quantize step
# ---------------------------------------------------------------------------

def get_tempo_map(midi):
    """Return list of (abs_tick, us_per_beat) sorted by tick."""
    tempo_map = [(0, 500000)]  # default 120 BPM
    for track in midi['tracks']:
        for ev in track:
            if ev[1] == 'tempo':
                tempo_map.append((ev[0], ev[3]))
    tempo_map.sort(key=lambda x: x[0])
    return tempo_map

def ticks_to_seconds(tick, ticks_per_beat, tempo_map):
    """Convert absolute tick to seconds using tempo map."""
    secs = 0.0
    prev_tick = 0
    prev_us = tempo_map[0][1]
    for tm_tick, tm_us in tempo_map[1:]:
        if tick <= tm_tick:
            break
        secs += (tm_tick - prev_tick) * prev_us / (ticks_per_beat * 1_000_000)
        prev_tick = tm_tick
        prev_us = tm_us
    secs += (tick - prev_tick) * prev_us / (ticks_per_beat * 1_000_000)
    return secs

def compute_frames_per_step(ticks_per_beat, tempo_map, step_ticks, cpc_fps=50):
    """Compute suggested frames-per-step for CPC."""
    # Use initial tempo to get step duration in seconds
    us_per_beat = tempo_map[0][1]
    step_secs = step_ticks * us_per_beat / (ticks_per_beat * 1_000_000)
    fps = step_secs * cpc_fps
    fps_int = max(1, int(round(fps)))
    return fps_int

# ---------------------------------------------------------------------------
# Quantize note streams into steps
# ---------------------------------------------------------------------------

def quantize_streams(streams, step_ticks, total_ticks, max_steps=None):
    """
    Convert per-channel note streams into step arrays.
    Returns list of 3 lists, each of length num_steps: [(period, volume), ...]
    """
    num_steps = (total_ticks + step_ticks - 1) // step_ticks
    if max_steps:
        num_steps = min(num_steps, max_steps)

    result = [[(0, 0)] * num_steps for _ in range(3)]

    for psg_ch, stream in enumerate(streams):
        # Build a timeline: at each tick, what note is active?
        active_note = 0
        active_vel = 0
        note_stack = {}  # note -> velocity (for polyphony: last wins)
        event_idx = 0
        events = stream

        step_states = []
        for step in range(num_steps):
            step_start = step * step_ticks
            step_end = step_start + step_ticks

            # Process all events up to step_end
            while event_idx < len(events) and events[event_idx][0] < step_end:
                ev = events[event_idx]
                if ev[1] == 'on':
                    note_stack[ev[2]] = ev[3]
                    active_note = ev[2]
                    active_vel = ev[3]
                elif ev[1] == 'off':
                    note_stack.pop(ev[2], None)
                    if note_stack:
                        # Fall back to last remaining note
                        active_note = list(note_stack.keys())[-1]
                        active_vel = note_stack[active_note]
                    else:
                        active_note = 0
                        active_vel = 0
                event_idx += 1

            if active_note > 0 and active_vel > 0:
                period = NOTE_PERIODS[min(active_note, 127)]
                vol = max(1, min(15, active_vel >> 3))  # 0-127 -> 1-15
            else:
                period = 0
                vol = 0
            result[psg_ch][step] = (period, vol)

    return result, num_steps

# ---------------------------------------------------------------------------
# Find total ticks in MIDI
# ---------------------------------------------------------------------------

def get_total_ticks(midi):
    total = 0
    for track in midi['tracks']:
        for ev in track:
            if ev[0] > total:
                total = ev[0]
    return total

# ---------------------------------------------------------------------------
# Output C header
# ---------------------------------------------------------------------------

def write_header(out_path, name, step_data, num_steps, frames_per_step,
                 step_ticks, ticks_per_beat, src_channels, verbose):
    uname = name.upper()

    periods_flat = []
    volumes_flat = []
    for step in range(num_steps):
        for ch in range(3):
            p, v = step_data[ch][step]
            periods_flat.append(p)
            volumes_flat.append(v)

    with open(out_path, 'w') as f:
        f.write(f"/* Generated by midi_to_psg.py */\n")
        f.write(f"#ifndef {uname}_H\n")
        f.write(f"#define {uname}_H\n\n")
        f.write(f"#include \"cpc_sound.h\"\n\n")

        f.write(f"/* {num_steps} steps, {frames_per_step} frames/step "
                f"(~{50/frames_per_step:.1f} steps/sec at 50Hz) */\n")
        f.write(f"/* Step size: {step_ticks} ticks = 1/{ticks_per_beat//step_ticks} beat */\n")
        f.write(f"/* Channels: ")
        for i, src in enumerate(src_channels):
            if src:
                f.write(f"PSG-{'ABC'[i]}=MIDI-track{src[0]}/ch{src[1]+1} ")
            else:
                f.write(f"PSG-{'ABC'[i]}=silent ")
        f.write(f"*/\n\n")

        f.write(f"#define {uname}_STEPS  {num_steps}\n")
        f.write(f"#define {uname}_TEMPO  {frames_per_step}\n\n")

        # periods array
        f.write(f"static const uint16_t {name}_periods[{uname}_STEPS * 3] = {{\n")
        for step in range(num_steps):
            f.write(f"    /* step {step:3d} */ ")
            for ch in range(3):
                p, _ = step_data[ch][step]
                f.write(f"{p:5d}, ")
            f.write(f"\n")
        f.write(f"}};\n\n")

        # volumes array
        f.write(f"static const uint8_t {name}_volumes[{uname}_STEPS * 3] = {{\n")
        for step in range(num_steps):
            f.write(f"    /* step {step:3d} */  ")
            for ch in range(3):
                _, v = step_data[ch][step]
                f.write(f"{v:3d}, ")
            f.write(f"\n")
        f.write(f"}};\n\n")

        f.write(f"#endif /* {uname}_H */\n")

    if verbose:
        print(f"Written {out_path}: {num_steps} steps, tempo={frames_per_step}")
        active = sum(1 for s in range(num_steps)
                     for c in range(3) if step_data[c][s][0] > 0)
        print(f"  Active note-steps: {active}/{num_steps*3}")

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description='Convert MIDI to CeePCee PSG music header')
    parser.add_argument('input',  help='Input .mid file')
    parser.add_argument('output', help='Output .h file')
    parser.add_argument('--name',      default=None,
                        help='C symbol prefix (default: filename stem)')
    parser.add_argument('--tempo',     type=int, default=None,
                        help='Override frames-per-step (1=fastest, higher=slower)')
    parser.add_argument('--channels',  default=None,
                        help='MIDI channels for PSG A,B,C e.g. "1,2,10" (1-indexed, 10=drums skip)')
    parser.add_argument('--tracks',    default=None,
                        help='MIDI track indices for PSG A,B,C e.g. "1,2,3" (0-indexed)')
    parser.add_argument('--quantize',  type=int, default=None,
                        help='Step size in MIDI ticks (default: ticks_per_beat/4 = 1 semiquaver)')
    parser.add_argument('--max-steps', type=int, default=255,
                        help='Max steps to output (default: 255, max for uint8_t steps arg)')
    parser.add_argument('--verbose',   action='store_true')
    args = parser.parse_args()

    # Load MIDI
    with open(args.input, 'rb') as f:
        data = f.read()
    try:
        midi = parse_midi(data)
    except MidiParseError as e:
        print(f"Error parsing MIDI: {e}", file=sys.stderr)
        sys.exit(1)

    tpb = midi['ticks_per_beat']
    if args.verbose:
        print(f"MIDI format {midi['format']}, {len(midi['tracks'])} tracks, "
              f"{tpb} ticks/beat")

    # Step quantization
    step_ticks = args.quantize or max(1, tpb // 4)
    if args.verbose:
        print(f"Step size: {step_ticks} ticks (1/{tpb//step_ticks} beat)")

    # Channel selection
    if args.channels:
        parts = args.channels.split(',')
        # Map MIDI channel (1-indexed) across all tracks - pick first track with activity
        src_channels = []
        activity = get_channel_activity(midi)
        for p in parts[:3]:
            midi_ch = int(p.strip()) - 1  # convert to 0-indexed
            # Find track with most activity on this channel
            best = max(
                ((ti, midi_ch) for ti in range(len(midi['tracks']))
                 if activity.get((ti, midi_ch), 0) > 0),
                key=lambda x: activity.get(x, 0),
                default=None
            )
            src_channels.append(best)
        while len(src_channels) < 3:
            src_channels.append(None)
    elif args.tracks:
        parts = args.tracks.split(',')
        # Use track index, pick the most active MIDI channel within that track
        src_channels = []
        activity = get_channel_activity(midi)
        for p in parts[:3]:
            ti = int(p.strip())
            # find most active channel in this track (excluding drums ch9)
            best_ch = max(
                (c for c in range(16) if c != 9 and activity.get((ti, c), 0) > 0),
                key=lambda c: activity.get((ti, c), 0),
                default=None
            )
            src_channels.append((ti, best_ch) if best_ch is not None else None)
        while len(src_channels) < 3:
            src_channels.append(None)
    else:
        src_channels = auto_pick_channels(midi, n=3, verbose=args.verbose)

    # Flatten note streams
    streams = flatten_notes(midi, src_channels)

    # Total ticks
    total_ticks = get_total_ticks(midi)
    if args.verbose:
        print(f"Total ticks: {total_ticks}")

    # Quantize
    step_data, num_steps = quantize_streams(
        streams, step_ticks, total_ticks, max_steps=args.max_steps)

    # Tempo
    tempo_map = get_tempo_map(midi)
    if args.tempo:
        frames_per_step = args.tempo
    else:
        frames_per_step = compute_frames_per_step(tpb, tempo_map, step_ticks)

    if args.verbose:
        bpm = 60_000_000 / tempo_map[0][1]
        print(f"MIDI BPM: {bpm:.1f}, frames/step: {frames_per_step}")

    # Symbol name
    name = args.name or os.path.splitext(os.path.basename(args.input))[0]
    name = ''.join(c if c.isalnum() or c == '_' else '_' for c in name)
    if name[0].isdigit():
        name = 'song_' + name

    # Write output
    write_header(args.output, name, step_data, num_steps, frames_per_step,
                 step_ticks, tpb, src_channels, args.verbose)

    print(f"Converted {args.input} -> {args.output}")
    print(f"  {num_steps} steps, tempo={frames_per_step} frames/step, "
          f"step={step_ticks} ticks")
    print(f"Usage in C:")
    print(f"  #include \"{os.path.basename(args.output)}\"")
    print(f"  cpc_music_set_tempo({name.upper()}_TEMPO);")
    print(f"  cpc_music_play({name}_periods, {name}_volumes, {name.upper()}_STEPS);")

if __name__ == '__main__':
    main()
