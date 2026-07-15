# CeePCee

An SDK for the Amstrad CPC Plus and GX4000

This is very incomplete, before we go through what IS working, let's talk about what isn't.  And there are other ways of making CPC+ software, for instance there's a branch of CPCTelera that can do it. I had a lot of issues getting it working for me, but I know other people have had a lot of success and, at this point in time, CPCTelera is probably the better option, because more is working. But I think CeePCee will be more usable across more systems.

## TODOs:
- Sound is not working, pretty much at all. I tried to create a simple enough to use SFX system and a pipeline for getting MIDIs to work, but I just couldn't get it working, at the moment at least.
- Scrolling backgrounds are broken. I've never had much success getting them to work on the CPC+ in the past either.
- Text is "iffy". It mostly works, but to make the text transparent I broke the clearing the previous text bits. So you either end up overlaying text across itself or having a nasty flashing clear cycle.
- Mode 0 and 1 are pretty much there, but nothing other than that and no multimode stuff.
- DMA sound is not implemented
- Sprite collisions don't work well, you can always just roll your own though
- Copper/Raster doesn't work, I just can't seem to get the timing right.
- There's no disk access yet, at least not in the SDK - you can write something to handle it yourself.
- Probably more that i'm forgetting.

## What does work then?
- You can add and move hardware sprites
- Keyboard and Joystick works
- Static tilemaps work
- Text works
- It'll build a working cartridge
- Works on any system that can run SDCC (i've tested with 4.5.0), sjasmplus (1.18.2), sdasz80 (02.00) and sdar (2.38).

## Prerequisites
- python3
- SDCC
- sjasmplus
- sdasz80
- sdar

There are a number of examples in the samples folder. These have been made over the course of developing the SDK so some of them aren't written in the right way, such as not using the sdk's init function and, instead, using inline assembler to initialise.  I'll have to go back over some of the older examples to fix them.

But they all should work.

## Building the Library

```sh
make -C V2
```

Produces `V2/lib/ceepcee.lib`.

## Building a Game

```sh
sdcc -mz80 --no-std-crt0 -I V2/include \
     --code-loc 0xA000 --data-loc 0xA000 \
     game.c V2/lib/crt0.rel V2/lib/ceepcee.lib \
     -o game.ihx
```

Then pack into a CPR cartridge (see example makefiles)

## Memory Layout

| Region         | Address       | Purpose                              |
|----------------|---------------|--------------------------------------|
| ROM bank 0     | `$0000–$3FFF` | CRT0 + runtime ROM image             |
| Runtime RAM    | `$8000–$9FFF` | Library runtime (copied from ROM)    |
| User code/data | `$A000–$BFFF` | SDCC compiled game code + data       |
| Screen RAM     | `$C000–$FFFF` | Video memory (mode 0)                |
| ASIC window    | `$4000–$7FFF` | CPC+ ASIC registers (paged in/out)   |

## API Modules

| Header              | Purpose                              |
|---------------------|--------------------------------------|
| `cpc.h`             | Master include (all modules)         |
| `cpc_init.h`        | Initialisation, mode set             |
| `cpc_gfx.h`         | Palette, border, screen clear        |
| `cpc_sprite.h`      | Hardware sprites (CPC+/GX4000)       |
| `cpc_input.h`       | Joystick + keyboard input            |
| `cpc_sound.h`       | PSG sound effects and music          |
| `cpc_text.h`        | Text rendering (firmware + custom)   |
| `cpc_tilemap.h`     | Background tilemap engine            |
| `cpc_scroll.h`      | Hardware scroll (coarse + fine)      |
| `cpc_raster.h`      | Raster/copper line effects           |

## Calling Convention

All multi-argument functions use `sdcccall(1)`:
- **Last argument** → `HL` register
- **Remaining arguments** → stack, right-to-left
- **Single-argument** → `HL` (same as `__z88dk_fastcall`)
- **Return value** → `HL`
