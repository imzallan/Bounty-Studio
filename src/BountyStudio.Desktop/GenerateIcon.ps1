$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function New-RoundedPath([single]$X, [single]$Y, [single]$Width, [single]$Height, [single]$Radius) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = $Radius * 2
    $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
    $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
    $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

$bitmap = New-Object System.Drawing.Bitmap(256, 256, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$graphics.Clear([System.Drawing.Color]::Transparent)

$panel = New-RoundedPath 19 19 218 218 54
$panelBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(20, 20, 216, 216)),
    ([System.Drawing.Color]::FromArgb(255, 27, 48, 44)),
    ([System.Drawing.Color]::FromArgb(255, 8, 13, 20)),
    45)
$graphics.FillPath($panelBrush, $panel)
$border = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 237, 201, 121), 5)
$graphics.DrawPath($border, $panel)

$ring = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(88, 87, 230, 174), 3)
$graphics.DrawEllipse($ring, 48, 48, 160, 160)
$dots = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170, 237, 201, 121), 2)
$dots.DashPattern = [single[]]@(1, 5)
$graphics.DrawEllipse($dots, 62, 62, 132, 132)

$gem = New-Object System.Drawing.Drawing2D.GraphicsPath
$gemPoints = [System.Drawing.Point[]]@(
    (New-Object System.Drawing.Point(128, 69)),
    (New-Object System.Drawing.Point(184, 128)),
    (New-Object System.Drawing.Point(128, 187)),
    (New-Object System.Drawing.Point(72, 128)))
$gem.AddPolygon($gemPoints)
$gemBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle(72, 69, 112, 118)),
    ([System.Drawing.Color]::FromArgb(255, 184, 255, 223)),
    ([System.Drawing.Color]::FromArgb(255, 28, 114, 86)),
    55)
$gemBorder = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 255, 240, 181), 4)
$graphics.FillPath($gemBrush, $gem)
$graphics.DrawPath($gemBorder, $gem)

$facet = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(155, 232, 255, 245), 3)
$graphics.DrawLine($facet, 128, 69, 111, 128)
$graphics.DrawLine($facet, 111, 128, 128, 187)
$graphics.DrawLine($facet, 128, 69, 145, 128)
$graphics.DrawLine($facet, 145, 128, 128, 187)
$graphics.DrawLine($facet, 72, 128, 184, 128)

$spark = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 240, 181))
$graphics.FillEllipse($spark, 123, 39, 10, 20)
$graphics.FillEllipse($spark, 123, 197, 10, 20)

$frames = New-Object System.Collections.Generic.List[object]
foreach ($size in @(16, 32, 48, 256)) {
    $small = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $draw = [System.Drawing.Graphics]::FromImage($small)
    $draw.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $draw.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $draw.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $draw.Clear([System.Drawing.Color]::Transparent)
    $draw.DrawImage($bitmap, 0, 0, $size, $size)
    $stream = New-Object System.IO.MemoryStream
    $small.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $frames.Add(@{ Size = $size; Bytes = $stream.ToArray() })
    $stream.Dispose(); $draw.Dispose(); $small.Dispose()
}

$output = Join-Path $PSScriptRoot 'BountyStudio.ico'
$file = [System.IO.File]::Create($output)
$writer = New-Object System.IO.BinaryWriter($file)
$writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]$frames.Count)
$offset = 6 + (16 * $frames.Count)
foreach ($frame in $frames) {
    $dimension = if ($frame.Size -eq 256) { [byte]0 } else { [byte]$frame.Size }
    $writer.Write($dimension); $writer.Write($dimension); $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([UInt16]1); $writer.Write([UInt16]32); $writer.Write([UInt32]$frame.Bytes.Length); $writer.Write([UInt32]$offset)
    $offset += $frame.Bytes.Length
}
foreach ($frame in $frames) { $writer.Write([byte[]]$frame.Bytes) }
$writer.Dispose(); $file.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
$panel.Dispose(); $panelBrush.Dispose(); $border.Dispose(); $ring.Dispose(); $dots.Dispose()
$gem.Dispose(); $gemBrush.Dispose(); $gemBorder.Dispose(); $facet.Dispose(); $spark.Dispose()
Write-Output $output
