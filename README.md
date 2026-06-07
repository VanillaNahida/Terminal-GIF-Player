# 🎞️ Terminal GIF Player

![:name](https://count.getloli.com/@Terminal-GIF-Player?name=Terminal-GIF-Player&theme=minecraft&padding=6&offset=0&align=top&scale=1&pixelated=1&darkmode=auto)

**在 Windows 终端中播放 GIF 动画，支持背景音乐、歌词同步、滚动字幕和标题轮播。**

简体中文 | [English](README.en.md)

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey?logo=windows)
![License](https://img.shields.io/badge/License-MIT-green)

---
<p align="center">
  <img src="assets\record.gif" alt="image">
</p>

## ✨ 功能特性

| 功能 | 说明 |
|------|------|
| 🎬 **GIF 动画播放** | 真彩色（24-bit）渲染，支持透明通道 |
| 🎵 **背景音乐** | 支持 MP3 播放，可循环、可调音量 |
| 📝 **LRC 歌词同步** | 自动检测同名 `.lrc` 文件，逐句同步显示 |
| 📢 **滚动字幕** | 无歌词时显示自定义滚动文字 |
| 🏷️ **标题轮播** | 窗口标题定时切换，支持多行配置 |
| ⚙️ **INI 配置** | 所有参数通过 `config.ini` 配置，首次运行自动生成 |
| 🎨 **自定义颜色** | 字幕、歌词颜色均可 RGB 自定义 |

---

## 📁 项目结构

```
📦 terminal-gif-player/
├── 📄 play-gif.ps1      # 主程序
├── 📄 config.ini         # 配置文件（首次运行自动生成）
├── 🖼️ cat.gif            # GIF 动画文件（自行准备）
├── 🎵 bgm.mp3            # 背景音乐（可选）
├── 📝 bgm.lrc            # LRC 歌词（可选，与音乐同名自动加载）
└── 📄 README.md
```

---

## 🚀 快速开始

### 1. 准备环境

- **Windows 10 / 11**
- **PowerShell 5.1+**（系统自带）
- 支持 ANSI/VT 的终端（推荐使用 Windows Terminal）

### 2. 准备文件

将你的 GIF 文件放到脚本同目录，如需音乐和歌词也一并放入：

```
play-gif.ps1
cat.gif
bgm.mp3        ← 可选
bgm.lrc        ← 可选，自动识别
```

### 3. 运行

```powershell
# 直接运行（使用默认 config.ini）
.\play-gif.ps1

# 指定配置文件
.\play-gif.ps1 -ConfigPath "myconfig.ini"
```

> 💡 首次运行时如果不存在 `config.ini`，会自动生成默认配置文件。

### 4. 退出

按 `Ctrl+C` 退出播放，程序会自动清理画面、停止音乐、恢复窗口标题。

---

## ⚙️ 配置说明

### `config.ini` 完整示例

```ini
; config.ini

[General]
GifPath = cat.gif           ; GIF 文件路径
Width = 80                  ; 渲染宽度（字符数）
FrameDelayMs = 40           ; 默认帧延迟（毫秒），GIF 自带延迟时会被覆盖
AlphaThreshold = 128        ; 透明度阈值（0-255），低于此值视为透明

[Window]
Title = 我真的特别爱你~      ; 窗口标题，用 | 分隔多个标题可轮播
TitleSpeed = 2000            ; 标题切换间隔（毫秒）

[Music]
Path = bgm.mp3              ; 音乐文件路径，留空则不播放
Loop = true                 ; 是否循环播放（true/false）
Volume = 0.8                ; 音量（0.0 ~ 1.0）

[Marquee]
; 如果检测到同名 lrc 文件，自动使用歌词同步显示
; 没有 lrc 时才使用这里的滚动文字
Speed = 150                 ; 滚动速度（毫秒/步）
Lines = 喵喵喵~|Ctrl+C 退出  ; 滚动文字，用 | 分隔多行
Color = 255,200,50          ; 滚动字幕颜色（R,G,B）
LrcColor = 100,255,200      ; 歌词颜色（R,G,B）
LrcMode = sync              ; 歌词模式：sync=同步居中 / scroll=滚动
LrcTitle = false            ; 是否将歌词同步到窗口标题
```

### 各参数详解

#### `[General]` — 基本设置

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `GifPath` | `cat.gif` | GIF 文件路径（相对或绝对路径） |
| `Width` | `80` | 画面渲染宽度，越大越清晰但越慢 |
| `FrameDelayMs` | `40` | GIF 未指定帧延迟时的默认值 |
| `AlphaThreshold` | `128` | 透明像素判定阈值 |

#### `[Window]` — 窗口标题

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `Title` | `GIF Player` | 用 `\|` 分隔可设置多个标题轮播 |
| `TitleSpeed` | `2000` | 标题轮播间隔（毫秒） |

#### `[Music]` — 背景音乐

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `Path` | *(空)* | 音乐文件路径，留空不播放 |
| `Loop` | `true` | 循环播放 |
| `Volume` | `0.8` | 音量 0.0 ~ 1.0 |

#### `[Marquee]` — 字幕 / 歌词

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `Speed` | `150` | 滚动字幕移动速度（毫秒/字符） |
| `Lines` | *(空)* | 滚动文字内容，`\|` 分隔多行 |
| `Color` | `255,200,50` | 滚动字幕 RGB 颜色 |
| `LrcColor` | `100,255,200` | 歌词 RGB 颜色 |
| `LrcMode` | `sync` | `sync` 居中同步显示 / `scroll` 滚动显示 |
| `LrcTitle` | `false` | 是否将歌词同步到窗口标题（`true`/`false`） |

---

## 🎤 LRC 歌词同步

### 自动识别

程序会自动查找与音乐文件同名的 `.lrc` 文件：

```
bgm.mp3  →  自动查找 bgm.lrc
music.mp3  →  自动查找 music.lrc
```

### 支持的 LRC 格式

```lrc
[offset:0]
[00:00.00]歌词第一行
[00:05.50]歌词第二行
[00:10.20]歌词第三行
```

### 歌词显示模式

- **`sync`**（默认）— 当前歌词居中高亮显示，下一句以暗色预览
- **`scroll`** — 当前歌词居中显示

---

## 🖥️ 渲染原理

```
每 2 行像素合并为 1 行终端字符

  上半像素 → 前景色 (▀ U+2580)
  下半像素 → 背景色

  仅上半可见 → 前景色 ▀
  仅下半可见 → 前景色 ▄ (U+2584)
  均不可见   → 空格
```

使用 **ANSI 24-bit 真彩色** 转义序列：

```
ESC[38;2;R;G;Bm    ← 前景色
ESC[48;2;R;G;Bm    ← 背景色
```

### 处理流程

```
GIF 文件
  ↓ System.Drawing 解码
逐帧提取像素
  ↓ 缩放到指定宽度
预渲染 ANSI 字符串
  ↓ 缓存所有帧
循环播放（光标复位 + 输出）
```

---

## ❓ 常见问题

### 画面显示乱码 / 无颜色

确保使用支持 ANSI VT 序列的终端：
- ✅ **Windows Terminal**（推荐）
- ✅ **VS Code 内置终端**
- ⚠️ 旧版 `cmd.exe` / PowerShell ISE 可能不支持

### 音乐不播放

- 确认文件路径正确
- 需要 .NET Framework 的 `PresentationCore` 程序集（Windows 系统通常自带）
- 支持格式：MP3、WAV、WMA

### 播放卡顿

- 减小 `Width` 值（如 `60` 或 `40`）
- GIF 帧数过多时预渲染阶段较慢，播放阶段应该流畅

### 中文标题只显示第一个字

已修复 — 使用 `@()` 确保管道结果为数组类型。

---

## 📋 系统要求

| 项目 | 要求 |
|------|------|
| 操作系统 | Windows 10 / 11 |
| PowerShell | 5.1 或更高 |
| .NET Framework | 4.5+（音乐播放需要） |
| 终端 | 支持 ANSI VT100 / 24-bit 真彩色 |

---

## 📜 License

MIT License — 随便用，开心就好 🐱

# Star History

[![Star History Chart](https://api.star-history.com/svg?repos=VanillaNahida/Terminal-GIF-Player&type=Date)](https://star-history.com/#VanillaNahida/Terminal-GIF-Player&Date)