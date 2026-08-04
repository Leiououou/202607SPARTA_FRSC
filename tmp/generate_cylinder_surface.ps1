param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [int]$Segments = 1000,
    [double]$Radius = 0.5
)

$culture = [System.Globalization.CultureInfo]::InvariantCulture
$lines = [System.Collections.Generic.List[string]]::new(2 * $Segments + 10)

$lines.Add('SPARTA 2d cylinder surface, radius 0.5 m, clockwise orientation')
$lines.Add('')
$lines.Add("$Segments points")
$lines.Add("$Segments lines")
$lines.Add('')
$lines.Add('Points')
$lines.Add('')

for ($i = 0; $i -lt $Segments; $i++) {
    $theta = -2.0 * [Math]::PI * $i / $Segments
    $x = $Radius * [Math]::Cos($theta)
    $y = $Radius * [Math]::Sin($theta)
    $xs = $x.ToString('G17', $culture)
    $ys = $y.ToString('G17', $culture)
    $lines.Add(('{0} {1} {2}' -f ($i + 1), $xs, $ys))
}

$lines.Add('')
$lines.Add('Lines')
$lines.Add('')

for ($i = 1; $i -le $Segments; $i++) {
    $next = if ($i -eq $Segments) { 1 } else { $i + 1 }
    $lines.Add(('{0} {1} {2}' -f $i, $i, $next))
}

$content = [string]::Join("`n", $lines) + "`n"
[System.IO.File]::WriteAllText($OutputPath, $content, [System.Text.UTF8Encoding]::new($false))
