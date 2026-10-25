param([string[]]$Tests = @('smoke', 'learning_smoke', 'balance_smoke', 'shop_journey', 'home_smoke', 'settings_smoke', 'market_smoke', 'fruit_orders', 'save_persistence'))
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $repoRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$qaRoot = Join-Path $repoRoot ('.tools\checks\' + [guid]::NewGuid().ToString('N'))
$originalAppData = $env:APPDATA
$originalLocalData = $env:LOCALAPPDATA
$originalQaDir = $env:YILIN_GAME_QA_DIR
try {
    foreach ($testName in $Tests) {
        if ($testName -notmatch '^[a-z_]+$') { throw 'Invalid test name.' }
        $profile = Join-Path $qaRoot $testName
        $env:APPDATA = Join-Path $profile 'roaming'
        $env:LOCALAPPDATA = Join-Path $profile 'local'
        $env:YILIN_GAME_QA_DIR = $env:APPDATA
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $engine
        $startInfo.Arguments = '--headless --path "' + (Join-Path $repoRoot 'games\jerrys-challenge') + '" --script "tests/' + $testName + '.gd" --quit-after 1800'
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $process.Start() | Out-Null
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(45000)) {
            $process.Kill()
            throw ('Game check timed out: ' + $testName)
        }
        $output = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        Write-Output $output
        if ($process.ExitCode -ne 0 -or $output -match '(?m)^(SCRIPT ERROR:|ERROR: FAIL:|ERROR: Family save failed|ERROR: Failed to load script)') {
            throw ('Game check failed: ' + $testName)
        }
    }
} finally {
    $env:APPDATA = $originalAppData
    $env:LOCALAPPDATA = $originalLocalData
    $env:YILIN_GAME_QA_DIR = $originalQaDir
}
