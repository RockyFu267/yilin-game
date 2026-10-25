param([string]$SourcePath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $SourcePath) {
    $SourcePath = Join-Path $projectRoot '素材\已解压\Pixel Lands Interiors Demo\Pixel Lands Interiors Demo\interiors_demo.png'
}
if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw 'Download the free Pixel Lands Interiors Demo from https://trislin.itch.io/pixel-lands-interiors, extract it, then pass -SourcePath with the interiors_demo.png path.'
}
$destination = Join-Path $projectRoot 'games\jerrys-challenge\assets\home'
New-Item -ItemType Directory -Path $destination -Force | Out-Null
Copy-Item -LiteralPath $SourcePath -Destination (Join-Path $destination 'interiors_demo.png') -Force
Write-Output 'Home art copied locally. Reimport the Godot project before exporting. Raw art is excluded from Git; retain the author license.'
