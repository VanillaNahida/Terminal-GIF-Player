# Terminal GIF Player

![:name](https://count.getloli.com/@Terminal-GIF-Player?name=Terminal-GIF-Player&theme=minecraft&padding=6&offset=0&align=top&scale=1&pixelated=1&darkmode=auto)

**Play GIF animations in Windows terminal, with background music, lyric synchronization, scrolling marquee, and title rotation.**

[简体中文](README.md) | English

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---
<p align="center">
  <img src="assets\record.gif" alt="image">
</p>

## Features

| Feature | Description |
|---------|-------------|
| GIF Animation Playback | True color (24-bit) rendering with alpha channel support |
| Background Music | MP3 playback with loop and volume control |
| LRC Lyric Sync | Auto-detect matching `.lrc` file, synchronized line-by-line display |
| Scrolling Marquee | Custom scrolling text when no lyrics are available |
| Title Rotation | Window title cycles at intervals, supports multi-line config |
| INI Configuration | All parameters configurable via `config.ini`, auto-generated on first run |
| Custom Colors | Marquee and lyric colors customizable via RGB |

---

## Project Structure

```
terminal-gif-player/
├── play-gif.ps1      # Main program
├── config.ini         # Configuration file (auto-generated on first run)
├── cat.gif            # GIF animation file (prepare your own)
├── bgm.mp3            # Background music (optional)
├── bgm.lrc            # LRC lyrics (optional, auto-loaded if same name as music)
└── README.md
```

---

## Quick Start

### 1. Environment

- **Windows 10 / 11**
- **PowerShell 5.1+** (built-in)
- ANSI/VT-capable terminal (Windows Terminal recommended)

### 2. Prepare Files

Place your GIF file in the same directory as the script. Add music and lyrics if needed:

```
play-gif.ps1
cat.gif
bgm.mp3        <- optional
bgm.lrc        <- optional, auto-detected
```

### 3. Run

```powershell
# Run directly (uses default config.ini)
.\play-gif.ps1

# Specify a config file
.\play-gif.ps1 -ConfigPath "myconfig.ini"
```

> If `config.ini` does not exist, a default config file will be auto-generated on first run.

### 4. Exit

Press `Ctrl+C` to exit playback. The program will clean up the display, stop music, and restore the window title.

---

## Configuration

### `config.ini` Full Example

```ini
; config.ini

[General]
GifPath = cat.gif           ; GIF file path
Width = 80                  ; Render width (in characters)
FrameDelayMs = 40           ; Default frame delay (ms), overridden by GIF's own delay
AlphaThreshold = 128        ; Alpha threshold (0-255), pixels below this are transparent

[Window]
Title = I Really Love You~  ; Window title, use | to separate multiple titles for rotation
TitleSpeed = 2000            ; Title switch interval (ms)

[Music]
Path = bgm.mp3              ; Music file path, leave empty to disable
Loop = true                 ; Loop playback (true/false)
Volume = 0.8                ; Volume (0.0 ~ 1.0)

[Marquee]
; If a matching lrc file is detected, lyric sync display is used automatically
; The scrolling text below is only used when no lrc file is found
Speed = 150                 ; Scrolling speed (ms/step)
Lines = Meow~|Ctrl+C to exit  ; Scrolling text, use | to separate multiple lines
Color = 255,200,50          ; Marquee text color (R,G,B)
LrcColor = 100,255,200      ; Lyric color (R,G,B)
LrcMode = sync              ; Lyric mode: sync=centered sync / scroll=scrolling
LrcTitle = false            ; Sync lyrics to window title
```

### Parameter Details

#### `[General]` -- Basic Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `GifPath` | `cat.gif` | GIF file path (relative or absolute) |
| `Width` | `80` | Render width, larger = clearer but slower |
| `FrameDelayMs` | `40` | Default frame delay when GIF doesn't specify one |
| `AlphaThreshold` | `128` | Transparency pixel threshold |

#### `[Window]` -- Window Title

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Title` | `GIF Player` | Use `\|` to separate multiple titles for rotation |
| `TitleSpeed` | `2000` | Title rotation interval (ms) |

#### `[Music]` -- Background Music

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Path` | *(empty)* | Music file path, leave empty to disable |
| `Loop` | `true` | Loop playback |
| `Volume` | `0.8` | Volume 0.0 ~ 1.0 |

#### `[Marquee]` -- Subtitles / Lyrics

| Parameter | Default | Description |
|-----------|---------|-------------|
| `Speed` | `150` | Marquee scroll speed (ms/character) |
| `Lines` | *(empty)* | Scrolling text content, `\|` separated lines |
| `Color` | `255,200,50` | Marquee RGB color |
| `LrcColor` | `100,255,200` | Lyric RGB color |
| `LrcMode` | `sync` | `sync` = centered sync display / `scroll` = scrolling display |
| `LrcTitle` | `false` | Sync lyrics to window title (`true`/`false`) |

---

## LRC Lyric Synchronization

### Auto Detection

The program automatically looks for a `.lrc` file with the same name as the music file:

```
bgm.mp3  ->  auto-finds bgm.lrc
music.mp3  ->  auto-finds music.lrc
```

### Supported LRC Format

```lrc
[offset:0]
[00:00.00]First lyric line
[00:05.50]Second lyric line
[00:10.20]Third lyric line
```

### Lyric Display Modes

- **`sync`** (default) -- Current lyric centered and highlighted, next line previewed in dim color
- **`scroll`** -- Current lyric centered

---

## Rendering Principle

```
Every 2 pixel rows combined into 1 terminal character row

  Upper pixel -> foreground color (U+2580)
  Lower pixel -> background color

  Upper only visible -> foreground color with U+2580
  Lower only visible -> foreground color with U+2584
  Both invisible    -> space
```

Uses **ANSI 24-bit true color** escape sequences:

```
ESC[38;2;R;G;Bm    <- foreground color
ESC[48;2;R;G;Bm    <- background color
```

### Processing Flow

```
GIF file
  -> System.Drawing decoding
Extract pixels per frame
  -> Scale to specified width
Pre-render ANSI strings
  -> Cache all frames
Loop playback (cursor reset + output)
```

---

## FAQ

### Display is garbled / no color

Make sure you're using an ANSI VT-capable terminal:
- Windows Terminal (recommended)
- VS Code integrated terminal
- Legacy `cmd.exe` / PowerShell ISE may not support it

### Music doesn't play

- Verify the file path is correct
- Requires .NET Framework `PresentationCore` assembly (usually included with Windows)
- Supported formats: MP3, WAV, WMA

### Playback is choppy

- Reduce the `Width` value (e.g., `60` or `40`)
- High frame-count GIFs are slower during pre-rendering; actual playback should be smooth

### Chinese title shows only first character

Already fixed -- uses `@()` to ensure array type in pipeline results.

---

## System Requirements

| Item | Requirement |
|------|-------------|
| OS | Windows 10 / 11 |
| PowerShell | 5.1 or higher |
| .NET Framework | 4.5+ (required for music playback) |
| Terminal | ANSI VT100 / 24-bit true color support |

---

## License

MIT License -- Use freely and have fun!

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=VanillaNahida/Terminal-GIF-Player&type=Date)](https://star-history.com/#VanillaNahida/Terminal-GIF-Player&Date)
