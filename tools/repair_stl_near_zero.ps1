param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [double]$Tolerance = 1.0e-12
)

$ErrorActionPreference = "Stop"
$culture = [System.Globalization.CultureInfo]::InvariantCulture
$numberStyle = [System.Globalization.NumberStyles]::Float
$encoding = [System.Text.ASCIIEncoding]::new()

$inputResolved = [System.IO.Path]::GetFullPath($InputPath)
$outputResolved = [System.IO.Path]::GetFullPath($OutputPath)

if ($inputResolved -eq $outputResolved) {
    throw "Input and output paths must differ so the original STL is preserved."
}

$outputDirectory = [System.IO.Path]::GetDirectoryName($outputResolved)
[void][System.IO.Directory]::CreateDirectory($outputDirectory)

$reader = [System.IO.StreamReader]::new($inputResolved, $encoding)
$writer = [System.IO.StreamWriter]::new($outputResolved, $false, $encoding)
$changedComponents = 0
$changedVertexLines = 0

try {
    while (($line = $reader.ReadLine()) -ne $null) {
        if ($line -match '^(\s*vertex\s+)(\S+)\s+(\S+)\s+(\S+)(\s*)$') {
            $prefix = $Matches[1]
            $tokens = @($Matches[2], $Matches[3], $Matches[4])
            $suffix = $Matches[5]
            $lineChanged = $false

            for ($i = 0; $i -lt 3; $i++) {
                $value = 0.0
                if (-not [double]::TryParse($tokens[$i], $numberStyle, $culture, [ref]$value)) {
                    throw "Invalid numeric coordinate '$($tokens[$i])' in line: $line"
                }
                if ([math]::Abs($value) -lt $Tolerance -and $value -ne 0.0) {
                    $tokens[$i] = "0.000000e+00"
                    $changedComponents++
                    $lineChanged = $true
                }
            }

            if ($lineChanged) {
                $changedVertexLines++
            }
            $writer.WriteLine(
                $prefix + $tokens[0] + " " + $tokens[1] + " " + $tokens[2] + $suffix
            )
        }
        else {
            $writer.WriteLine($line)
        }
    }
}
finally {
    $reader.Dispose()
    $writer.Dispose()
}

[pscustomobject]@{
    Input = $inputResolved
    Output = $outputResolved
    Tolerance = $Tolerance
    ChangedVertexLines = $changedVertexLines
    ChangedCoordinateComponents = $changedComponents
} | Format-List
