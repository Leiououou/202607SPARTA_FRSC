param(
    [string]$CatPartPath = "D:\博一\气固相互作用\Zupparid\Orion_Zuppardi_coordinate_priority.CATPart",
    [string]$StepPath = "D:\博一\气固相互作用\Zupparid\Orion_Zuppardi_coordinate_priority.stp"
)

$ErrorActionPreference = "Stop"

function Add-Point2D {
    param(
        [System.Collections.Generic.List[object]]$Points,
        [double]$X,
        [double]$Y
    )
    $Points.Add([pscustomobject]@{ X = $X; Y = $Y })
}

# Published meridian-plane coordinates, converted from metres to millimetres.
$A = [pscustomobject]@{ X = 3302.0; Y = 0.0 }
$B = [pscustomobject]@{ X = 3302.0; Y = 883.8 }
$C = [pscustomobject]@{ X = 847.7;  Y = 2475.2 }
$D = [pscustomobject]@{ X = 712.6;  Y = 2514.6 }
$E = [pscustomobject]@{ X = 0.0;    Y = 0.0 }

$points = [System.Collections.Generic.List[object]]::new()

# Coordinate-priority interpretation:
# The heat-shield arc passes exactly through E and D, with its centre on the x axis.
# This gives R=4.7930198709 m. The paper's stated R=6.04 m is inconsistent with
# the published E and D coordinates, so the discrepancy is retained in the model name.
$noseRadius = (($D.X * $D.X) + ($D.Y * $D.Y)) / (2.0 * $D.X)
$noseCenterX = $noseRadius
$noseThetaE = [math]::PI
$noseThetaD = [math]::Atan2($D.Y, $D.X - $noseCenterX)

# C-D is represented by a circle through the exact published endpoints. Its centre is
# the point on the C-D perpendicular bisector nearest the published centre (710,2260) mm.
$midX = 0.5 * ($C.X + $D.X)
$midY = 0.5 * ($C.Y + $D.Y)
$chordX = $C.X - $D.X
$chordY = $C.Y - $D.Y
$normalX = -$chordY
$normalY = $chordX
$targetCenterX = 710.0
$targetCenterY = 2260.0
$projection = ((($targetCenterX - $midX) * $normalX) +
               (($targetCenterY - $midY) * $normalY)) /
              (($normalX * $normalX) + ($normalY * $normalY))
$shoulderCenterX = $midX + $projection * $normalX
$shoulderCenterY = $midY + $projection * $normalY
$shoulderRadius = [math]::Sqrt(
    (($D.X - $shoulderCenterX) * ($D.X - $shoulderCenterX)) +
    (($D.Y - $shoulderCenterY) * ($D.Y - $shoulderCenterY))
)
$shoulderThetaD = [math]::Atan2($D.Y - $shoulderCenterY, $D.X - $shoulderCenterX)
$shoulderThetaC = [math]::Atan2($C.Y - $shoulderCenterY, $C.X - $shoulderCenterX)

# Match the paper's surface discretisation: 350 TPS intervals from E to C and
# 130 afterbody intervals from C to A, for 480 exposed surface intervals total.
$noseSegments = 320
$shoulderSegments = 30
$backShellSegments = 100
$baseSegments = 30

for ($i = 0; $i -le $noseSegments; $i++) {
    $f = $i / [double]$noseSegments
    $theta = $noseThetaE + $f * ($noseThetaD - $noseThetaE)
    Add-Point2D $points `
        ($noseCenterX + $noseRadius * [math]::Cos($theta)) `
        ($noseRadius * [math]::Sin($theta))
}

for ($i = 1; $i -le $shoulderSegments; $i++) {
    $f = $i / [double]$shoulderSegments
    $theta = $shoulderThetaD + $f * ($shoulderThetaC - $shoulderThetaD)
    Add-Point2D $points `
        ($shoulderCenterX + $shoulderRadius * [math]::Cos($theta)) `
        ($shoulderCenterY + $shoulderRadius * [math]::Sin($theta))
}

for ($i = 1; $i -le $backShellSegments; $i++) {
    $f = $i / [double]$backShellSegments
    Add-Point2D $points `
        ($C.X + $f * ($B.X - $C.X)) `
        ($C.Y + $f * ($B.Y - $C.Y))
}

for ($i = 1; $i -le $baseSegments; $i++) {
    $f = $i / [double]$baseSegments
    Add-Point2D $points `
        ($B.X + $f * ($A.X - $B.X)) `
        ($B.Y + $f * ($A.Y - $B.Y))
}

$catia = $null
$partDocument = $null
$stage = "initialising CATIA"
try {
    try {
        $catia = [Runtime.InteropServices.Marshal]::GetActiveObject("CATIA.Application")
    }
    catch {
        try {
            $catia = New-Object -ComObject CATIA.Application
        }
        catch {
            # Some CATIA installations launch CNEXT successfully but return E_FAIL
            # before PowerShell receives the COM proxy. Allow the server to register
            # in the Running Object Table, then attach to that clean session.
            Start-Sleep -Seconds 6
            $catia = [Runtime.InteropServices.Marshal]::GetActiveObject("CATIA.Application")
        }
    }
    $catia.Visible = $true

    $stage = "creating CATPart document"
    $partDocument = $catia.Documents.Add("Part")
    $part = $partDocument.Part
    $part.Name = "Orion_Zuppardi_CoordinatePriority"

    $body = $part.Bodies.Item("PartBody")
    $body.Name = "Orion_Solid"
    $part.InWorkObject = $body

    $stage = "creating meridian sketch"
    $sketch = $body.Sketches.Add($part.OriginElements.PlaneXY)
    $sketch.Name = "Published_Meridian_Profile_480_Intervals"
    $factory2D = $sketch.OpenEdition()

    for ($i = 0; $i -lt ($points.Count - 1); $i++) {
        $p1 = $points[$i]
        $p2 = $points[$i + 1]
        [void]$factory2D.CreateLine($p1.X, $p1.Y, $p2.X, $p2.Y)
    }

    # Close the section on the x axis from A back to E; this is not an exposed
    # capsule-surface interval.
    [void]$factory2D.CreateLine($A.X, $A.Y, $E.X, $E.Y)
    $stage = "updating closed meridian sketch"
    $sketch.CloseEdition()
    $part.Update()

    $stage = "creating 360-degree shaft"
    $shaft = $part.ShapeFactory.AddNewShaft($sketch)
    $shaft.Name = "Axisymmetric_360deg_Solid"
    $shaft.FirstAngle.Value = 360.0
    $shaft.SecondAngle.Value = 0.0
    $stage = "updating solid"
    $part.Update()

    $catPartDirectory = Split-Path -Parent $CatPartPath
    $stepDirectory = Split-Path -Parent $StepPath
    [void][System.IO.Directory]::CreateDirectory($catPartDirectory)
    [void][System.IO.Directory]::CreateDirectory($stepDirectory)

    $stage = "saving CATPart"
    $partDocument.SaveAs($CatPartPath)
    $stage = "exporting STEP"
    $partDocument.ExportData($StepPath, "stp")

    [pscustomobject]@{
        CatPart = $CatPartPath
        STEP = $StepPath
        SurfaceIntervals = 480
        TPSIntervals = 350
        CoordinatePriorityNoseRadius_m = $noseRadius / 1000.0
        PublishedNoseRadius_m = 6.04
        ShoulderRadius_m = $shoulderRadius / 1000.0
        ShoulderCenterX_m = $shoulderCenterX / 1000.0
        ShoulderCenterY_m = $shoulderCenterY / 1000.0
    } | Format-List
}
catch {
    throw "CATIA automation failed while $stage. $($_.Exception.Message)"
}
finally {
    if ($null -ne $partDocument) {
        try { $partDocument.Close() } catch { Write-Warning "Could not close CATPart document: $($_.Exception.Message)" }
    }
    if ($null -ne $catia) {
        try { $catia.Quit() } catch { Write-Warning "Could not quit CATIA: $($_.Exception.Message)" }
    }
}
