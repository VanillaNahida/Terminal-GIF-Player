# play-gif.ps1
param(
    [string]$ConfigPath = "config.ini"
)

# ============== INI Parser ==============
function Read-Ini {
    param([string]$Path)
    $result = @{}
    if (-not (Test-Path $Path)) { return $result }
    $section = ""
    foreach ($line in (Get-Content $Path -Encoding UTF8)) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith(";") -or $line.StartsWith("#")) { continue }
        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1]
            if (-not $result.ContainsKey($section)) { $result[$section] = @{} }
        }
        elseif ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim()
            if ($section) { $result[$section][$key] = $val }
        }
    }
    return $result
}

# ============== Generate default INI ==============
if (-not (Test-Path $ConfigPath)) {
    @"
; config.ini
[General]
GifPath = cat.gif
Width = 80
FrameDelayMs = 40
AlphaThreshold = 128

[Window]
Title = GIF Player
TitleSpeed = 2000

[Music]
Path =
Loop = true
Volume = 0.8

[Marquee]
Speed = 150
Lines = Hello! Welcome~|Ctrl+C to quit
Color = 255,200,50
LrcColor = 100,255,200
LrcMode = sync
LrcTitle = false
"@ | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "Generated default config: $ConfigPath" -ForegroundColor Yellow
}

# ============== Read config ==============
$cfg = Read-Ini $ConfigPath

function CfgGet($section, $key, $default) {
    if ($cfg.ContainsKey($section) -and $cfg[$section].ContainsKey($key)) {
        $v = $cfg[$section][$key]
        if ($v -ne "") { return $v }
    }
    return $default
}

$GifPath        = CfgGet "General" "GifPath" "cat.gif"
$Width          = [int](CfgGet "General" "Width" "80")
$FrameDelayMs   = [int](CfgGet "General" "FrameDelayMs" "40")
$AlphaThreshold = [int](CfgGet "General" "AlphaThreshold" "128")
$TitleRaw       = CfgGet "Window" "Title" "GIF Player"
$TitleSpeed     = [int](CfgGet "Window" "TitleSpeed" "2000")
$MusicPath      = CfgGet "Music" "Path" ""
$MusicLoop      = (CfgGet "Music" "Loop" "true") -match "^(true|1|yes)$"
$MusicVolume    = [double](CfgGet "Music" "Volume" "0.8")
$MarqueeSpeed   = [int](CfgGet "Marquee" "Speed" "150")
$MarqueeRaw     = CfgGet "Marquee" "Lines" ""
$MarqueeColorS  = CfgGet "Marquee" "Color" "255,200,50"
$LrcColorS      = CfgGet "Marquee" "LrcColor" "100,255,200"
$LrcMode        = CfgGet "Marquee" "LrcMode" "sync"
$LrcTitle       = (CfgGet "Marquee" "LrcTitle" "false") -match "^(true|1|yes)$"

# Parse title lines
$TitleLines = @($TitleRaw -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
if ($TitleLines.Count -eq 0) { $TitleLines = @("GIF Player") }

# Parse marquee lines
$MarqueeLines = @()
if ($MarqueeRaw) {
    $MarqueeLines = $MarqueeRaw -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}

# Parse colors
function ParseRGB($s, $dr, $dg, $db) {
    $parts = $s -split ',' | ForEach-Object { [int]$_.Trim() }
    if ($parts.Count -ge 3) { return $parts[0], $parts[1], $parts[2] }
    return $dr, $dg, $db
}

$mR, $mG, $mB = ParseRGB $MarqueeColorS 255 200 50
$lR, $lG, $lB = ParseRGB $LrcColorS 100 255 200

$ESC = [char]27

# ============== LRC Parser ==============
function Parse-Lrc {
    param([string]$Path)
    $lyrics = [System.Collections.ArrayList]::new()
    $offset = 0

    foreach ($line in (Get-Content $Path -Encoding UTF8)) {
        $line = $line.Trim()
        if ($line -eq "") { continue }

        # offset tag
        if ($line -match '^\[offset:\s*(-?\d+)\]') {
            $offset = [int]$Matches[1]
            continue
        }

        # skip metadata / awlrc tags
        if ($line -match '^\[(ti|ar|al|au|by|re|ve):') { continue }
        if ($line -match '^\[awlrc:') { continue }

        # Extract all time tags and the remaining text
        $times = [System.Collections.ArrayList]::new()
        $pattern = '^\[(\d{2}):(\d{2})\.(\d{2,3})\]'
        $remaining = $line

        while ($remaining -match $pattern) {
            $mm = [int]$Matches[1]
            $ss = [int]$Matches[2]
            $msStr = $Matches[3]
            if ($msStr.Length -eq 2) { $msStr = $msStr + "0" }
            $ms = [int]$msStr
            $timeMs = $mm * 60000 + $ss * 1000 + $ms + $offset
            $null = $times.Add($timeMs)

            # Remove this one time tag from the front
            $tagLen = $Matches[0].Length
            $remaining = $remaining.Substring($tagLen)
        }

        $text = $remaining

        # Clean remaining brackets from text
        $text = $text -replace '\[.*?\]', ''
        $text = $text.Trim()

        if ($text -eq "" -or $times.Count -eq 0) { continue }

        foreach ($t in $times) {
            $null = $lyrics.Add([PSCustomObject]@{ TimeMs = $t; Text = $text })
        }
    }

    # Sort by time
    $sorted = $lyrics | Sort-Object TimeMs
    return @($sorted)
}

# ============== Detect LRC file ==============
$lrcPath = ""
$useLrc = $false
$lrcData = @()

if ($MusicPath -and $MusicPath -ne "") {
    # Try same name .lrc
    $lrcCandidate = [System.IO.Path]::ChangeExtension($MusicPath, ".lrc")
    if (Test-Path $lrcCandidate) {
        $lrcPath = $lrcCandidate
    }
}

if ($lrcPath -and (Test-Path $lrcPath)) {
    Write-Host "LRC found: $lrcPath" -ForegroundColor Green
    $lrcData = Parse-Lrc $lrcPath
    if ($lrcData.Count -gt 0) {
        $useLrc = $true
        Write-Host "  Loaded $($lrcData.Count) lyric lines" -ForegroundColor Green
    } else {
        Write-Host "  No valid lyrics parsed, using marquee" -ForegroundColor Yellow
    }
}

# ============== Validate GIF ==============
if (-not (Test-Path $GifPath)) {
    Write-Host "GIF not found: $GifPath" -ForegroundColor Red
    Write-Host "Edit $ConfigPath to set the correct path." -ForegroundColor Yellow
    exit 1
}

# ============== Set initial title ==============
$origTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = $TitleLines[0]

# ============== Enable VT ==============
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class ConsoleVT9 {
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")]
    static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")]
    static extern bool SetConsoleMode(IntPtr h, uint m);
    public static void Enable() {
        IntPtr h = GetStdHandle(-11);
        uint m;
        GetConsoleMode(h, out m);
        SetConsoleMode(h, m | 4);
    }
}
'@ -ErrorAction SilentlyContinue

try { [ConsoleVT9]::Enable() } catch { }
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# ============== Music init ==============
$script:mediaPlayer = $null
$script:musicStartTime = $null

# ============== Decode GIF ==============
Add-Type -AssemblyName System.Drawing
Write-Host "Decoding GIF..." -ForegroundColor Cyan

$fullPath = (Resolve-Path $GifPath).Path
$bitmap = [System.Drawing.Image]::FromFile($fullPath)
$dim = [System.Drawing.Imaging.FrameDimension]::new($bitmap.FrameDimensionsList[0])
$frameCount = $bitmap.GetFrameCount($dim)

$delayBytes = $null
try { $delayBytes = $bitmap.GetPropertyItem(0x5100).Value } catch { }

$script:allPixels = @($null) * $frameCount
$script:allWidths = [int[]]::new($frameCount)
$script:allHeights = [int[]]::new($frameCount)
$script:allDelays = [int[]]::new($frameCount)

for ($i = 0; $i -lt $frameCount; $i++) {
    $bitmap.SelectActiveFrame($dim, $i)

    $delay = $FrameDelayMs
    if ($null -ne $delayBytes -and ($i * 4 + 3) -lt $delayBytes.Length) {
        $raw = [BitConverter]::ToInt32($delayBytes, $i * 4)
        if ($raw -gt 0) { $delay = $raw * 10 }
        if ($delay -lt 20) { $delay = 20 }
    }

    $srcW = $bitmap.Width
    $srcH = $bitmap.Height
    $pixH = [int]([Math]::Round($Width * ($srcH / $srcW)))
    if ($pixH % 2 -ne 0) { $pixH++ }

    $canvas = [System.Drawing.Bitmap]::new($Width, $pixH, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gfx = [System.Drawing.Graphics]::FromImage($canvas)
    $gfx.Clear([System.Drawing.Color]::Transparent)
    $gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $gfx.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $gfx.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $gfx.DrawImage($bitmap, 0, 0, $Width, $pixH)
    $gfx.Dispose()

    $rect = [System.Drawing.Rectangle]::new(0, 0, $Width, $pixH)
    $bmpData = $canvas.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $bmpData.Stride
    $totalBytes = [Math]::Abs($stride) * $pixH
    $rgbValues = [byte[]]::new($totalBytes)
    [System.Runtime.InteropServices.Marshal]::Copy($bmpData.Scan0, $rgbValues, 0, $totalBytes)
    $canvas.UnlockBits($bmpData)
    $canvas.Dispose()

    $flat = [byte[]]::new($pixH * $Width * 4)
    for ($y = 0; $y -lt $pixH; $y++) {
        for ($x = 0; $x -lt $Width; $x++) {
            $pos = $y * $stride + $x * 4
            $fi2 = ($y * $Width + $x) * 4
            $flat[$fi2]     = $rgbValues[$pos + 2]
            $flat[$fi2 + 1] = $rgbValues[$pos + 1]
            $flat[$fi2 + 2] = $rgbValues[$pos]
            $flat[$fi2 + 3] = $rgbValues[$pos + 3]
        }
    }

    $script:allPixels[$i] = $flat
    $script:allWidths[$i] = $Width
    $script:allHeights[$i] = $pixH
    $script:allDelays[$i] = $delay

    [Console]::Write("`r  Frame $($i+1) / $frameCount  ")
}
$bitmap.Dispose()
Write-Host ""

# ============== Pre-render ==============
Write-Host "Pre-rendering..." -ForegroundColor Cyan

$script:ansiFrames = [string[]]::new($frameCount)
$upperHalf = [char]0x2580
$lowerHalf = [char]0x2584
$thr = $AlphaThreshold
$termLines = 0

for ($i = 0; $i -lt $frameCount; $i++) {
    $w = $script:allWidths[$i]
    $h = $script:allHeights[$i]
    $px = $script:allPixels[$i]
    $sb = [System.Text.StringBuilder]::new($w * $h * 12)

    $lines = 0
    for ($y = 0; $y -lt $h; $y += 2) {
        $lastSeq = ""
        for ($x = 0; $x -lt $w; $x++) {
            $topIdx = ($y * $w + $x) * 4
            $tr = [int]$px[$topIdx]; $tg = [int]$px[$topIdx+1]; $tb = [int]$px[$topIdx+2]; $ta = [int]$px[$topIdx+3]

            $y2 = $y + 1
            if ($y2 -lt $h) {
                $botIdx = ($y2 * $w + $x) * 4
                $br = [int]$px[$botIdx]; $bg2 = [int]$px[$botIdx+1]; $bb = [int]$px[$botIdx+2]; $ba = [int]$px[$botIdx+3]
            } else {
                $br = 0; $bg2 = 0; $bb = 0; $ba = 0
            }

            $topVis = ($ta -ge $thr)
            $botVis = ($ba -ge $thr)

            if ($topVis -and $botVis) {
                $seq = "$ESC[38;2;${tr};${tg};${tb};48;2;${br};${bg2};${bb}m"
                if ($seq -ne $lastSeq) { $null = $sb.Append($seq); $lastSeq = $seq }
                $null = $sb.Append($upperHalf)
            }
            elseif ($topVis) {
                $seq = "$ESC[0;38;2;${tr};${tg};${tb}m"
                if ($seq -ne $lastSeq) { $null = $sb.Append($seq); $lastSeq = $seq }
                $null = $sb.Append($upperHalf)
            }
            elseif ($botVis) {
                $seq = "$ESC[0;38;2;${br};${bg2};${bb}m"
                if ($seq -ne $lastSeq) { $null = $sb.Append($seq); $lastSeq = $seq }
                $null = $sb.Append($lowerHalf)
            }
            else {
                if ($lastSeq -ne "RST") { $null = $sb.Append("$ESC[0m"); $lastSeq = "RST" }
                $null = $sb.Append(" ")
            }
        }
        $null = $sb.Append("$ESC[0m")
        $null = $sb.Append([Environment]::NewLine)
        $lastSeq = ""
        $lines++
    }

    $script:ansiFrames[$i] = $sb.ToString()
    if ($lines -gt $termLines) { $termLines = $lines }
    [Console]::Write("`r  Render $($i+1) / $frameCount  ")
}

$script:allPixels = $null
[GC]::Collect()
Write-Host ""

# ============== Start Music ==============
if ($MusicPath -and (Test-Path $MusicPath)) {
    try {
        Add-Type -AssemblyName PresentationCore

        $mp = New-Object System.Windows.Media.MediaPlayer
        $musicFull = (Resolve-Path $MusicPath).Path
        $musicUri = New-Object System.Uri($musicFull)
        $mp.Open($musicUri)

        Start-Sleep -Milliseconds 500
        $mp.Volume = $MusicVolume

        if ($MusicLoop) {
            Register-ObjectEvent -InputObject $mp -EventName MediaEnded -SourceIdentifier "MusicLoop" -Action {
                $Sender.Position = [TimeSpan]::Zero
                $Sender.Play()
            } | Out-Null
        }

        $mp.Play()
        $script:mediaPlayer = $mp
        $script:musicStartTime = [DateTime]::Now
        Write-Host "Music: $MusicPath (Vol=$MusicVolume Loop=$MusicLoop)" -ForegroundColor Magenta
    } catch {
        Write-Host "Music error: $_" -ForegroundColor Yellow
        $script:mediaPlayer = $null
    }
} elseif ($MusicPath) {
    Write-Host "Music not found: $MusicPath" -ForegroundColor Yellow
}

# ============== Resize window ==============
try {
    $targetW = $Width + 2
    $targetH = $termLines + 4
    if ($targetW -gt [Console]::LargestWindowWidth) { $targetW = [Console]::LargestWindowWidth }
    if ($targetH -gt [Console]::LargestWindowHeight) { $targetH = [Console]::LargestWindowHeight }
    [Console]::WindowWidth = $targetW
    [Console]::WindowHeight = $targetH
    [Console]::BufferWidth = $targetW
    [Console]::BufferHeight = $targetH
} catch { }

# ============== Marquee setup (non-LRC mode) ==============
$marqueeRow = $termLines + 1
$marqueeLineIdx = 0
$marqueeOffset = 0
$marqueeLastTick = [Environment]::TickCount
$currentMarqueeText = ""
$paddedLines = @()

if (-not $useLrc -and $MarqueeLines.Count -gt 0) {
    foreach ($ml in $MarqueeLines) {
        $paddedLines += ($(" " * $Width) + $ml + $(" " * $Width))
    }
    $currentMarqueeText = $paddedLines[0]
    $marqueeOffset = 0
}

# ============== LRC state ==============
$lrcLastIdx = -1
$lrcLastText = ""

function Get-MusicPositionMs {
    if ($script:mediaPlayer) {
        try {
            $pos = $script:mediaPlayer.Position
            return [int]$pos.TotalMilliseconds
        } catch { }
    }
    # Fallback: use elapsed wall time
    if ($script:musicStartTime) {
        return [int](([DateTime]::Now - $script:musicStartTime).TotalMilliseconds)
    }
    return 0
}

function Get-CurrentLyric {
    param([int]$posMs)
    $idx = -1
    for ($j = 0; $j -lt $lrcData.Count; $j++) {
        if ($lrcData[$j].TimeMs -le $posMs) {
            $idx = $j
        } else {
            break
        }
    }
    if ($idx -ge 0) {
        return $idx, $lrcData[$idx].Text
    }
    return -1, ""
}

# ============== Title rotation setup ==============
$titleEnabled = ($TitleLines.Count -gt 1)
$titleIdx = 0
$titleLastTick = [Environment]::TickCount

Write-Host "Ready! Ctrl+C to stop." -ForegroundColor Green
if ($useLrc) {
    Write-Host "LRC sync mode: $LrcMode" -ForegroundColor Cyan
}
Start-Sleep -Milliseconds 500

[Console]::Write("$ESC[?25l")
[Console]::Write("$ESC[0m$ESC[2J")

# Helper: center text in width
function Center-Text {
    param([string]$text, [int]$w)
    # Calculate display width (CJK chars = 2 columns)
    $dispWidth = 0
    foreach ($c in $text.ToCharArray()) {
        $code = [int]$c
        if (($code -ge 0x2E80 -and $code -le 0x9FFF) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFE30 -and $code -le 0xFE4F) -or
            ($code -ge 0xFF00 -and $code -le 0xFFEF)) {
            $dispWidth += 2
        } else {
            $dispWidth += 1
        }
    }
    if ($dispWidth -ge $w) { return $text }
    $pad = [Math]::Floor(($w - $dispWidth) / 2)
    $right = $w - $dispWidth - $pad
    return (" " * $pad) + $text + (" " * $right)
}

try {
    while ($true) {
        for ($i = 0; $i -lt $frameCount; $i++) {
            [Console]::Write("$ESC[H")
            [Console]::Write($script:ansiFrames[$i])

            # --- Title rotation ---
            if ($titleEnabled -and (-not $LrcTitle)) {
                $now = [Environment]::TickCount
                $elapsed = $now - $titleLastTick
                if ($elapsed -lt 0) { $elapsed = $TitleSpeed }
                if ($elapsed -ge $TitleSpeed) {
                    $titleLastTick = $now
                    $titleIdx = ($titleIdx + 1) % $TitleLines.Count
                    $Host.UI.RawUI.WindowTitle = $TitleLines[$titleIdx]
                }
            }

            # --- LRC sync mode ---
            if ($useLrc) {
                $posMs = Get-MusicPositionMs
                $curIdx, $curText = Get-CurrentLyric $posMs

                if ($curIdx -ne $lrcLastIdx) {
                    $lrcLastIdx = $curIdx
                    $lrcLastText = $curText

                    # Update window title with current lyric
                    if ($LrcTitle -and $curText) {
                        $Host.UI.RawUI.WindowTitle = $curText
                    }
                }

                if ($LrcMode -eq "sync") {
                    # Show current line centered, next line dimmed below
                    $line1 = Center-Text $curText $Width
                    [Console]::Write("$ESC[$marqueeRow;1H$ESC[0;1;38;2;${lR};${lG};${lB}m$line1$ESC[0m")

                    # Next lyric line (dimmed)
                    $nextRow = $marqueeRow + 1
                    $nextText = ""
                    if ($curIdx + 1 -lt $lrcData.Count) {
                        $nextText = $lrcData[$curIdx + 1].Text
                    }
                    $line2 = Center-Text $nextText $Width
                    $dimR = [Math]::Floor($lR * 0.5)
                    $dimG = [Math]::Floor($lG * 0.5)
                    $dimB = [Math]::Floor($lB * 0.5)
                    [Console]::Write("$ESC[$nextRow;1H$ESC[0;38;2;${dimR};${dimG};${dimB}m$line2$ESC[0m")
                }
                else {
                    # scroll mode: just show centered
                    $line1 = Center-Text $curText $Width
                    [Console]::Write("$ESC[$marqueeRow;1H$ESC[0;38;2;${lR};${lG};${lB}m$line1$ESC[0m")
                }
            }
            # --- Normal marquee (no LRC) ---
            elseif ($paddedLines.Count -gt 0) {
                $now2 = [Environment]::TickCount
                $elapsed2 = $now2 - $marqueeLastTick
                if ($elapsed2 -lt 0) { $elapsed2 = $MarqueeSpeed }

                if ($elapsed2 -ge $MarqueeSpeed) {
                    $marqueeLastTick = $now2
                    $marqueeOffset++

                    if ($marqueeOffset -ge $currentMarqueeText.Length) {
                        $marqueeOffset = 0
                        $marqueeLineIdx = ($marqueeLineIdx + 1) % $paddedLines.Count
                        $currentMarqueeText = $paddedLines[$marqueeLineIdx]
                    }
                }

                $visible = ""
                if ($marqueeOffset + $Width -le $currentMarqueeText.Length) {
                    $visible = $currentMarqueeText.Substring($marqueeOffset, $Width)
                } else {
                    $remaining = $currentMarqueeText.Length - $marqueeOffset
                    if ($remaining -gt 0) {
                        $visible = $currentMarqueeText.Substring($marqueeOffset, $remaining)
                    }
                    $visible = $visible.PadRight($Width)
                }

                [Console]::Write("$ESC[$marqueeRow;1H$ESC[0;38;2;${mR};${mG};${mB}m$visible$ESC[0m")
            }

            Start-Sleep -Milliseconds $script:allDelays[$i]
        }
    }
} finally {
    [Console]::Write("$ESC[?25h")
    [Console]::Write("$ESC[0m")
    [Console]::Write("$ESC[2J$ESC[H")

    if ($script:mediaPlayer) {
        try {
            $script:mediaPlayer.Stop()
            $script:mediaPlayer.Close()
        } catch { }
    }

    Get-EventSubscriber -SourceIdentifier "MusicLoop" -ErrorAction SilentlyContinue |
        Unregister-Event -ErrorAction SilentlyContinue

    $Host.UI.RawUI.WindowTitle = $origTitle
    Write-Host "Playback ended." -ForegroundColor Cyan
}