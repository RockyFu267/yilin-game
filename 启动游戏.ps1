$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$gameExecutable = Join-Path $projectRoot 'builds\jerrys-challenge\0.4.3\JerrysChallenge.exe'
if (Test-Path -LiteralPath $gameExecutable) {
    Start-Process -FilePath $gameExecutable -WorkingDirectory (Split-Path -Parent $gameExecutable) -WindowStyle Normal
    exit
}
$godotExecutable = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $godotExecutable)) {
    throw 'Godot or the Windows game build was not found. Import games/jerrys-challenge/project.godot with Godot 4.7.2.'
}
$gameProject = Join-Path $projectRoot 'games\jerrys-challenge'
Start-Process -FilePath $godotExecutable -ArgumentList @('--path', ('"' + $gameProject + '"')) -WorkingDirectory $gameProject -WindowStyle Normal
