# Generator pentru iconitele si splash-ul Voltera.
# Ruleaza:  powershell -ExecutionPolicy Bypass -File tools\generate_voltera_assets.ps1
# Output:   assets\images\voltera_icon.png, voltera_icon_fg.png,
#           voltera_splash.png, voltera_wordmark.png

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$out = Join-Path $projectRoot 'assets\images'
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# Paleta Voltera (sincronizat cu lib/theme/app_theme.dart)
$colorBg     = [System.Drawing.Color]::FromArgb(255, 7, 11, 18)        # #070B12
$colorBgHi   = [System.Drawing.Color]::FromArgb(255, 16, 24, 36)       # gradient top
$colorCyan   = [System.Drawing.Color]::FromArgb(255, 0, 215, 255)      # #00D7FF
$colorCyanLo = [System.Drawing.Color]::FromArgb(200, 0, 165, 220)
$colorWhite  = [System.Drawing.Color]::FromArgb(255, 235, 245, 255)

function Draw-VLetter {
    param(
        [System.Drawing.Graphics]$g,
        [float]$cx,
        [float]$cy,
        [float]$size,
        [System.Drawing.Color]$color,
        [System.Drawing.Color]$glow
    )
    # V geometric: doua benzi care converg in jos. Latime banda = size * 0.16
    $h = $size
    $w = $size * 0.92
    $strokeW = $size * 0.18

    $leftTop  = New-Object System.Drawing.PointF (($cx - $w/2), ($cy - $h/2))
    $rightTop = New-Object System.Drawing.PointF (($cx + $w/2), ($cy - $h/2))
    $bottom   = New-Object System.Drawing.PointF ($cx, ($cy + $h/2))

    # Trapezul stang
    $leftInner = New-Object System.Drawing.PointF (($cx - $w/2 + $strokeW * 1.4), ($cy - $h/2))
    $bottomInL = New-Object System.Drawing.PointF (($cx - $strokeW * 0.3), ($cy + $h/2 - $strokeW * 0.5))
    $bottomInR = New-Object System.Drawing.PointF (($cx + $strokeW * 0.3), ($cy + $h/2 - $strokeW * 0.5))
    $rightInner = New-Object System.Drawing.PointF (($cx + $w/2 - $strokeW * 1.4), ($cy - $h/2))

    $leftPoly = @($leftTop, $leftInner, $bottomInL, $bottom)
    $rightPoly = @($rightTop, $rightInner, $bottomInR, $bottom)

    # Glow underlay (cyan blur effect simulat cu 3 layere transparente)
    for ($i = 6; $i -ge 1; $i--) {
        $alpha = [Math]::Round(80 / $i)
        $glowColor = [System.Drawing.Color]::FromArgb($alpha, $glow.R, $glow.G, $glow.B)
        $glowPen = New-Object System.Drawing.Pen $glowColor, ($i * 4)
        $glowPen.LineJoin = 'Round'
        $g.DrawPolygon($glowPen, $leftPoly)
        $g.DrawPolygon($glowPen, $rightPoly)
        $glowPen.Dispose()
    }

    # Fill principal
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.FillPolygon($brush, $leftPoly)
    $g.FillPolygon($brush, $rightPoly)
    $brush.Dispose()
}

function Draw-Wordmark {
    param(
        [System.Drawing.Graphics]$g,
        [float]$cx,
        [float]$cy,
        [float]$fontSize,
        [System.Drawing.Color]$color
    )
    # Cuvant "VOLTERA" cu spacing larg, font sans-serif gros
    $font = New-Object System.Drawing.Font 'Arial Black', $fontSize, ([System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = 'Center'
    $sf.LineAlignment = 'Center'
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.DrawString('VOLTERA', $font, $brush, $cx, $cy, $sf)
    $brush.Dispose()
    $font.Dispose()
}

function Make-Icon {
    param([int]$Size, [string]$OutPath, [bool]$WithBackground = $true, [bool]$WithWordmark = $false)
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode = 'HighQuality'

    if ($WithBackground) {
        # Gradient radial fundal (dark cu glow cyan in centru)
        $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            (New-Object System.Drawing.Point 0, 0),
            (New-Object System.Drawing.Point 0, $Size),
            $colorBgHi, $colorBg)
        $g.FillRectangle($bgBrush, 0, 0, $Size, $Size)
        $bgBrush.Dispose()

        # Glow radial cyan in centru
        $gradPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $gradPath.AddEllipse([float]($Size * 0.1), [float]($Size * 0.1), [float]($Size * 0.8), [float]($Size * 0.8))
        $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($gradPath)
        $pgb.CenterColor = [System.Drawing.Color]::FromArgb(70, $colorCyan.R, $colorCyan.G, $colorCyan.B)
        $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        $g.FillEllipse($pgb, ($Size * 0.1), ($Size * 0.1), ($Size * 0.8), ($Size * 0.8))
        $pgb.Dispose()
        $gradPath.Dispose()
    } else {
        # Transparent — pentru adaptive icon foreground
        $g.Clear([System.Drawing.Color]::Transparent)
    }

    $cx = $Size / 2.0
    $vSize = $Size * 0.5
    $vCy = if ($WithWordmark) { $Size * 0.42 } else { $cx }

    Draw-VLetter -g $g -cx $cx -cy $vCy -size $vSize -color $colorCyan -glow $colorCyan

    if ($WithWordmark) {
        Draw-Wordmark -g $g -cx $cx -cy ($Size * 0.82) -fontSize ($Size * 0.09) -color $colorWhite
    }

    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "[OK] $OutPath ($Size x $Size)" -ForegroundColor Green
}

function Make-Wordmark-Only {
    param([int]$Width, [int]$Height, [string]$OutPath)
    $bmp = New-Object System.Drawing.Bitmap $Width, $Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.Clear([System.Drawing.Color]::Transparent)

    Draw-Wordmark -g $g -cx ($Width / 2.0) -cy ($Height / 2.0) `
        -fontSize ($Height * 0.55) -color $colorCyan

    $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "[OK] $OutPath ($Width x $Height wordmark)" -ForegroundColor Green
}

# 1. Icon principal pentru launcher (1024x1024)
Make-Icon -Size 1024 -OutPath (Join-Path $out 'voltera_icon.png') -WithBackground $true -WithWordmark $false

# 2. Foreground pentru adaptive icon Android (transparent, V centrata, safe zone)
Make-Icon -Size 1024 -OutPath (Join-Path $out 'voltera_icon_fg.png') -WithBackground $false -WithWordmark $false

# 3. Splash image (1024x1024, fond + V mare)
Make-Icon -Size 1024 -OutPath (Join-Path $out 'voltera_splash.png') -WithBackground $true -WithWordmark $false

# 4. Wordmark separat (text VOLTERA pentru bottom branding splash)
Make-Wordmark-Only -Width 768 -Height 160 -OutPath (Join-Path $out 'voltera_wordmark.png')

Write-Host ""
Write-Host "Assets generate cu succes in $out" -ForegroundColor Cyan
Write-Host "Urmatorul pas: flutter pub get && dart run flutter_launcher_icons && dart run flutter_native_splash:create" -ForegroundColor Yellow
