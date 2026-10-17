$ErrorActionPreference = "Stop"
$PocRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $PocRoot
$Server = $null
try {
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "Python is required on PATH." }
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { throw "ffmpeg is required on PATH." }

    # Optional: set VLC_HOME to the VLC 3.x x64 installation directory before running this script.
    if (-not $env:VLC_HOME -and (Test-Path "C:\Program Files\VideoLAN\VLC")) {
        $env:VLC_HOME = "C:\Program Files\VideoLAN\VLC"
    }
    if ($env:VLC_HOME -and (Test-Path $env:VLC_HOME)) {
        $env:PATH = "$env:VLC_HOME;$env:PATH"
        $PluginDir = Join-Path $env:VLC_HOME "plugins"
        if (Test-Path $PluginDir) { $env:VLC_PLUGIN_PATH = $PluginDir }
        Write-Host "Using VLC runtime from VLC_HOME=$env:VLC_HOME"
    } else {
        Write-Warning "VLC_HOME is not set; LibVLC runtime test may fail. JavaFX Media remains available."
    }

    python scripts\generate_test_media.py
    .\gradlew.bat clean build
    $Server = Start-Process -FilePath python -ArgumentList @("scripts\http_fixture.py", "--root", "test-media", "--port", "8765") -PassThru -WindowStyle Hidden -WorkingDirectory $PocRoot
    Start-Sleep -Seconds 2
    if ($Server.HasExited) { throw "The local HTTP fixture server exited during startup." }
    $null = Invoke-WebRequest -Uri "http://127.0.0.1:8765/sample.mp3" -Method Head
    Write-Host "In the harness, try these URIs one at a time or as a queue:"
    Write-Host "  http://127.0.0.1:8765/sample.mp3"
    Write-Host "  http://127.0.0.1:8765/sample.m4a"
    Write-Host "  http://127.0.0.1:8765/hls/sample.m3u8"
    Write-Host "Test Play/Pause/Resume/Seek/Next/Retry separately for each backend. Close the harness to stop the server."
    .\gradlew.bat run
} finally {
    if ($Server -and -not $Server.HasExited) { Stop-Process -Id $Server.Id -Force }
    Pop-Location
}
