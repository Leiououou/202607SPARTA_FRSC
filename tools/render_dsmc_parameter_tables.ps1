param(
    [string]$OutputDirectory = "D:\博一\catalytic\zupparid"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function New-Canvas {
    param([int]$Width, [int]$Height)
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.Clear([System.Drawing.Color]::White)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    return @($bitmap, $graphics)
}

function Draw-CellText {
    param(
        [System.Drawing.Graphics]$Graphics,
        [string]$Text,
        [System.Drawing.Font]$Font,
        [System.Drawing.Brush]$Brush,
        [float]$X,
        [float]$Y,
        [float]$Width,
        [float]$Height,
        [ValidateSet("Left", "Center")]
        [string]$Alignment = "Center"
    )
    $format = [System.Drawing.StringFormat]::new()
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    if ($Alignment -eq "Left") {
        $format.Alignment = [System.Drawing.StringAlignment]::Near
    }
    else {
        $format.Alignment = [System.Drawing.StringAlignment]::Center
    }
    $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
    $rect = [System.Drawing.RectangleF]::new($X, $Y, $Width, $Height)
    $Graphics.DrawString($Text, $Font, $Brush, $rect, $format)
    $format.Dispose()
}

function Save-Table74 {
    param([string]$Path)

    $sub2 = [char]0x2082
    $angstrom = [char]0x00C5
    $zeta = [char]0x03B6
    $thetaSymbol = [char]0x03B8
    $enDash = [char]0x2013

    $canvas = New-Canvas 540 272
    $bitmap = $canvas[0]
    $graphics = $canvas[1]

    $titleFont = [System.Drawing.Font]::new("Arial", 10.5, [System.Drawing.FontStyle]::Regular)
    $headerFont = [System.Drawing.Font]::new("Arial", 9.2, [System.Drawing.FontStyle]::Bold)
    $bodyFont = [System.Drawing.Font]::new("Arial", 9.1, [System.Drawing.FontStyle]::Regular)
    $bodyItalic = [System.Drawing.Font]::new("Arial", 9.1, [System.Drawing.FontStyle]::Italic)
    $whiteBrush = [System.Drawing.Brushes]::White
    $blackBrush = [System.Drawing.Brushes]::Black
    $headerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(156,156,156))
    $rowBrush1 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(211,211,211))
    $rowBrush2 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(232,232,232))

    $graphics.DrawString(
        "Table 7.4  DSMC Model Parameters for Each Species",
        $titleFont, $blackBrush, 20, 11
    )

    $x = 20
    $y = 33
    $tableWidth = 515
    $headerHeight = 28
    $rowHeight = 25
    $colWidths = @(150, 73, 73, 73, 73, 73)

    $graphics.FillRectangle($headerBrush, $x, $y, $tableWidth, $headerHeight)
    $headers = @("Species", ("N" + $sub2), ("O" + $sub2), "NO", "N", "O")
    $cx = $x
    for ($i = 0; $i -lt $headers.Count; $i++) {
        Draw-CellText $graphics $headers[$i] $headerFont $whiteBrush `
            $cx $y $colWidths[$i] $headerHeight $(if ($i -eq 0) { "Left" } else { "Center" })
        $cx += $colWidths[$i]
    }

    $rows = @(
        @("Muv (kg/kmol)", "28", "32", "30", "14", "16"),
        @(("d (" + $angstrom + ")"), "4.17", "4.07", "4.20", "3.00", "3.00"),
        @(($zeta + "rot"), "2", "2", "2", "0", "0"),
        @(($zeta + "vib"), "Eq. 3.132", "Eq. 3.132", "Eq. 3.132", "0", "0"),
        @(("Trot_ref" + $enDash + "Parker model"), "91.5 K", "90.0 K", "91.5 K", "N/A", "N/A"),
        @(("Zrot_ref" + $enDash + "Parker model"), "18.1", "14.4", "18.1", "N/A", "N/A"),
        @(($thetaSymbol + "rot"), "2.88 K", "2.07 K", "2.44 K", "N/A", "N/A"),
        @(($thetaSymbol + "vib"), "3390 K", "2270 K", "2740 K", "N/A", "N/A")
    )

    for ($r = 0; $r -lt $rows.Count; $r++) {
        $ry = $y + $headerHeight + $r * $rowHeight
        $graphics.FillRectangle($(if ($r % 2 -eq 0) { $rowBrush1 } else { $rowBrush2 }),
            $x, $ry, $tableWidth, $rowHeight - 2)
        $cx = $x
        for ($i = 0; $i -lt $rows[$r].Count; $i++) {
            $font = if ($i -eq 0) { $bodyItalic } else { $bodyFont }
            Draw-CellText $graphics $rows[$r][$i] $font $blackBrush `
                $cx $ry $colWidths[$i] ($rowHeight - 2) $(if ($i -eq 0) { "Left" } else { "Center" })
            $cx += $colWidths[$i]
        }
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $titleFont.Dispose(); $headerFont.Dispose(); $bodyFont.Dispose(); $bodyItalic.Dispose()
    $headerBrush.Dispose(); $rowBrush1.Dispose(); $rowBrush2.Dispose()
    $graphics.Dispose(); $bitmap.Dispose()
}

function Save-Table75 {
    param([string]$Path)

    $sub2 = [char]0x2082
    $omega = [char]0x03C9
    $angstrom = [char]0x00C5
    $enDash = [char]0x2013

    $canvas = New-Canvas 500 258
    $bitmap = $canvas[0]
    $graphics = $canvas[1]

    $titleFont = [System.Drawing.Font]::new("Arial", 10.5, [System.Drawing.FontStyle]::Regular)
    $headerFont = [System.Drawing.Font]::new("Arial", 9.3, [System.Drawing.FontStyle]::Bold)
    $bodyFont = [System.Drawing.Font]::new("Arial", 9.4, [System.Drawing.FontStyle]::Regular)
    $whiteBrush = [System.Drawing.Brushes]::White
    $blackBrush = [System.Drawing.Brushes]::Black
    $headerBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(156,156,156))
    $rowBrush1 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(211,211,211))
    $rowBrush2 = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(232,232,232))

    $graphics.DrawString(
        "Table 7.5  DSMC VHS Model Parameters for Each Species Pair",
        $titleFont, $blackBrush, 49, 27
    )

    $x = 49
    $y = 49
    $tableWidth = 362
    $headerHeight = 29
    $rowHeight = 25
    $colWidths = @(126, 61, 91, 84)

    $graphics.FillRectangle($headerBrush, $x, $y, $tableWidth, $headerHeight)
    $headers = @("Collision Pair", $omega, "Tref [K]", ("dref [" + $angstrom + "]"))
    $cx = $x
    for ($i = 0; $i -lt $headers.Count; $i++) {
        Draw-CellText $graphics $headers[$i] $headerFont $whiteBrush `
            $cx $y $colWidths[$i] $headerHeight $(if ($i -eq 0) { "Left" } else { "Center" })
        $cx += $colWidths[$i]
    }

    $rows = @(
        @(("N" + $sub2 + $enDash + "N" + $sub2), "0.74", "273", "4.17"),
        @(("O" + $sub2 + $enDash + "O" + $sub2), "0.77", "273", "4.07"),
        @(("NO" + $enDash + "NO"), "0.79", "273", "4.20"),
        @(("N" + $enDash + "N"), "0.80", "273", "3.00"),
        @(("O" + $enDash + "O"), "0.80", "273", "3.00")
    )

    for ($r = 0; $r -lt $rows.Count; $r++) {
        $ry = $y + $headerHeight + $r * $rowHeight
        $graphics.FillRectangle($(if ($r % 2 -eq 0) { $rowBrush1 } else { $rowBrush2 }),
            $x, $ry, $tableWidth, $rowHeight - 2)
        $cx = $x
        for ($i = 0; $i -lt $rows[$r].Count; $i++) {
            Draw-CellText $graphics $rows[$r][$i] $bodyFont $blackBrush `
                $cx $ry $colWidths[$i] ($rowHeight - 2) $(if ($i -eq 0) { "Left" } else { "Center" })
            $cx += $colWidths[$i]
        }
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $titleFont.Dispose(); $headerFont.Dispose(); $bodyFont.Dispose()
    $headerBrush.Dispose(); $rowBrush1.Dispose(); $rowBrush2.Dispose()
    $graphics.Dispose(); $bitmap.Dispose()
}

[void][System.IO.Directory]::CreateDirectory($OutputDirectory)
$table74Path = Join-Path $OutputDirectory "Table_7_4_DSMC_species_parameters.png"
$table75Path = Join-Path $OutputDirectory "Table_7_5_DSMC_VHS_pair_parameters.png"

Save-Table74 $table74Path
Save-Table75 $table75Path

Get-Item -LiteralPath $table74Path, $table75Path |
    Select-Object FullName, Length, LastWriteTime
