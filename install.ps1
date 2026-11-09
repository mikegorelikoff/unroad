# unroad installer for Windows: the ur binary, the roadmap web app and the ur-* skills.
#
#   irm https://github.com/mikegorelikoff/unroad/releases/latest/download/install.ps1 | iex
#
# Environment:
#   UR_VERSION       release tag (default: latest)
#   UR_INSTALL_DIR   where to put ur.exe (default: %LOCALAPPDATA%\unroad\bin)
#   UR_AGENT         claude, codex or all (default: detected)
#   UR_NO_WEB        set to 1 to skip the web app
#   GITHUB_TOKEN     token for private or internal repositories (or log in with gh)
#
# Every archive is checked against the release's SHA256SUMS before anything is installed.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Repo = if ($env:UR_REPO) { $env:UR_REPO } else { 'mikegorelikoff/unroad' }
$Version = if ($env:UR_VERSION) { $env:UR_VERSION } else { 'latest' }
$Dest = if ($env:UR_INSTALL_DIR) { $env:UR_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'unroad\bin' }
$UnroadHome = if ($env:UNROAD_HOME) { $env:UNROAD_HOME } else { Join-Path $HOME '.unroad' }
$Token = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { $null }
$Esc = [char]27
$Color = -not $env:NO_COLOR -and $Host.UI.SupportsVirtualTerminal
function C($code, $text) { if ($Color) { "$Esc[$($code)m$text$Esc[0m" } else { $text } }
function Row($sym, $label, $text) { Write-Host ("  {0} {1} {2}" -f $sym, (C '2' $label.PadRight(10)), $text) }
function Ok($label, $text) { Row (C '32' 'v') $label $text }
function Info($label, $text) { Row (C '2' '>') $label $text }
function Warn($label, $text) { Row (C '33' '!') $label $text }
function Fail($text) { Row (C '31' 'x') 'error' $text; exit 1 }

Write-Host ''
Write-Host ("  {0} {1}" -f (C '1;38;5;208' 'unroad'), (C '2' 'installer'))
Write-Host ("  {0}" -f (C '2' 'skills that teach you to build with AI agents'))
Write-Host ''

$arch = switch ($env:PROCESSOR_ARCHITECTURE) { 'AMD64' { 'x86_64' } 'ARM64' { 'x86_64' } default { Fail "unsupported CPU $($env:PROCESSOR_ARCHITECTURE)" } }
$target = "$arch-pc-windows-msvc"
$useGh = $false
if (Get-Command gh -ErrorAction SilentlyContinue) { gh auth status *> $null; if ($LASTEXITCODE -eq 0) { $useGh = $true } }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("unroad-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
$headers = @{}
if ($Token) { $headers['Authorization'] = "Bearer $Token" }

try {
  if ($useGh) {
    $tag = if ($Version -eq 'latest') { gh release view -R $Repo --json tagName -q .tagName } else { $Version }
  } elseif ($Token) {
    $api = if ($Version -eq 'latest') { "https://api.github.com/repos/$Repo/releases/latest" } else { "https://api.github.com/repos/$Repo/releases/tags/$Version" }
    $release = Invoke-RestMethod -Uri $api -Headers $headers
    $tag = $release.tag_name
  } else { $tag = $Version }
  $via = if ($useGh) { 'gh' } elseif ($Token) { 'GitHub token' } else { 'public download' }
  Info 'platform' $target
  Info 'release' "$tag $(C '2' "via $via")"

  function Get-Asset($name, $out) {
    if ($useGh) { gh release download $tag -R $Repo -p $name -O $out --clobber | Out-Null; if ($LASTEXITCODE -ne 0) { Fail "cannot download $name" } }
    elseif ($Token) {
      $asset = $release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
      if (-not $asset) { Fail "$name is not in release $tag" }
      Invoke-WebRequest -Uri $asset.url -Headers ($headers + @{ Accept = 'application/octet-stream' }) -OutFile $out
    } else {
      $url = if ($tag -eq 'latest') { "https://github.com/$Repo/releases/latest/download/$name" } else { "https://github.com/$Repo/releases/download/$tag/$name" }
      Invoke-WebRequest -Uri $url -OutFile $out
    }
  }
  function Test-Sum($file, $name) {
    $line = Get-Content (Join-Path $tmp 'SHA256SUMS') | Where-Object { $_ -match " $([regex]::Escape($name))$" } | Select-Object -First 1
    if (-not $line) { Fail "$name is not listed in SHA256SUMS" }
    $want = ($line -split '\s+')[0]
    $got = (Get-FileHash -Algorithm SHA256 $file).Hash.ToLower()
    if ($got -ne $want) { Fail "checksum mismatch for $name (expected $want, got $got); nothing was installed" }
  }

  Get-Asset 'SHA256SUMS' (Join-Path $tmp 'SHA256SUMS')
  Ok 'checksums' 'SHA256SUMS'
  $zip = (Get-Content (Join-Path $tmp 'SHA256SUMS') | ForEach-Object { ($_ -split '\s+')[1] } | Where-Object { $_ -like "*-$arch-pc-windows-*.zip" } | Select-Object -First 1)
  if (-not $zip) { Fail "no build for $target in $tag" }
  Get-Asset $zip (Join-Path $tmp $zip)
  Test-Sum (Join-Path $tmp $zip) $zip
  Expand-Archive -Path (Join-Path $tmp $zip) -DestinationPath $tmp -Force
  $exe = Get-ChildItem -Path $tmp -Recurse -Filter 'ur.exe' | Select-Object -First 1
  if (-not $exe) { Fail "$zip does not contain ur.exe" }
  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Copy-Item $exe.FullName (Join-Path $Dest 'ur.exe') -Force
  $ur = Join-Path $Dest 'ur.exe'
  Ok 'ur' "$(& $ur --version) -> $ur"

  if ($env:UR_NO_WEB -ne '1') {
    $web = (Get-Content (Join-Path $tmp 'SHA256SUMS') | ForEach-Object { ($_ -split '\s+')[1] } | Where-Object { $_ -like 'unroad-web-*.tar.gz' } | Select-Object -First 1)
    if ($web) {
      Get-Asset $web (Join-Path $tmp $web)
      Test-Sum (Join-Path $tmp $web) $web
      $webTmp = Join-Path $tmp 'web'; New-Item -ItemType Directory -Path $webTmp | Out-Null
      tar -xzf (Join-Path $tmp $web) -C $webTmp
      $inner = if (Test-Path (Join-Path $webTmp 'unroad-web')) { Join-Path $webTmp 'unroad-web' } else { $webTmp }
      New-Item -ItemType Directory -Force -Path $UnroadHome | Out-Null
      $webDest = Join-Path $UnroadHome 'web'
      if (Test-Path $webDest) { Remove-Item -Recurse -Force $webDest }
      Move-Item $inner $webDest
      Ok 'web' "-> $webDest"
    } else { Warn 'web' 'this release has no web bundle' }
  }

  $dirs = @()
  $codex = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
  switch ($env:UR_AGENT) {
    'claude' { $dirs += (Join-Path $HOME '.claude\skills') }
    'codex' { $dirs += (Join-Path $codex 'skills') }
    'all' { $dirs += (Join-Path $HOME '.claude\skills'); $dirs += (Join-Path $codex 'skills') }
    default {
      if (Test-Path (Join-Path $HOME '.claude')) { $dirs += (Join-Path $HOME '.claude\skills') }
      if (Test-Path $codex) { $dirs += (Join-Path $codex 'skills') }
      if ($dirs.Count -eq 0) { $dirs += (Join-Path $HOME '.claude\skills') }
    }
  }
  foreach ($d in $dirs) { & $ur install --target $d | Out-Null; if ($LASTEXITCODE -ne 0) { Fail "ur install --target $d failed" }; Ok 'skills' "-> $d" }

  if (Get-Command node -ErrorAction SilentlyContinue) { Ok 'node' "$(node --version) for the web app" }
  else { Warn 'node' 'not found; the web app needs Node.js 20+ (https://nodejs.org)' }

  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not ($userPath -split ';' | Where-Object { $_ -eq $Dest })) {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$Dest", 'User')
    Ok 'path' "added $Dest to your user PATH (open a new terminal)"
  }
  Write-Host ''
  Write-Host ("  {0}" -f (C '1' 'Next'))
  Write-Host ("  {0}" -f (C '2' 'Open your agent (Claude Code, Codex) in a repository you work on and type:'))
  Write-Host ("    {0}       {1}" -f (C '38;5;208' '/ur-start'), (C '2' 'set up your goal, level and lab repository'))
  Write-Host ("    {0}       {1}" -f (C '38;5;208' '/ur-learn'), (C '2' 'learn the next topic'))
  Write-Host ("    {0}         {1}" -f (C '38;5;208' '/ur-gui'), (C '2' 'open the roadmap in your browser'))
  Write-Host ''
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
