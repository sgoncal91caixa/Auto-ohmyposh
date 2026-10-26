<#
  setup-terminal.ps1
  Configura Windows Terminal + VS Code com Oh My Posh (tema montys) e a fonte MesloLGM Nerd Font.

  Uso interativo:       powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1
  Sem perguntas (-Yes): powershell -ExecutionPolicy Bypass -File .\setup-terminal.ps1 -Yes

  Nao precisa de administrador. Pode ser executado varias vezes (idempotente).
  Obs.: mensagens sem acentos de proposito, para funcionar no Windows PowerShell 5.1.
#>

param([switch]$Yes)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$Theme      = 'montys'   # tema padrao; pode ser trocado na etapa 3
$FontFace   = 'MesloLGM Nerd Font'
$FontZipUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip'
$ThemesZipUrl = 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip'
$ThemesDir  = Join-Path $HOME '.poshthemes'
$Work       = Join-Path ([IO.Path]::GetTempPath()) 'setup-terminal'

$script:AutoYes = [bool]$Yes
$script:Results = @()

# ---------------------------------------------------------------- Utilitarios
function Ask($number, $total, $title, $detail) {
    Write-Host ""
    Write-Host "==> Etapa $number/$total - $title" -ForegroundColor Cyan
    Write-Host "    $detail" -ForegroundColor DarkGray
    if ($script:AutoYes) { return $true }
    while ($true) {
        $r = (Read-Host '    Executar? [S]im (padrao) / [N]ao, pular / [T]odas as restantes / [Q]uitar').Trim().ToLower()
        switch ($r) {
            { $_ -in '', 's', 'y' } { return $true }
            'n' { return $false }
            't' { $script:AutoYes = $true; return $true }
            'q' { Write-Host 'Saindo.'; exit 0 }
        }
    }
}

function Install-WingetPackage($id, $extra = @()) {
    Write-Host "Instalando $id ..."
    winget install --id $id -e --accept-source-agreements --accept-package-agreements @extra
    # codigo diferente de 0 tambem ocorre quando o pacote ja esta instalado; nao e fatal
}

function Read-JsonFile($path) {
    if (-not (Test-Path $path)) { return [pscustomobject]@{} }
    $raw = Get-Content $path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return [pscustomobject]@{} }
    # remove comentarios de linha inteira (settings do VS Code e do Terminal aceitam JSONC)
    $raw = [regex]::Replace($raw, '(?m)^\s*//.*$', '')
    $raw = [regex]::Replace($raw, ',(\s*[}\]])', '$1')   # virgulas finais
    return $raw | ConvertFrom-Json
}

function Set-Prop($obj, $name, $value) {
    $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force
}

function Get-OrAddObject($obj, $name) {
    if (-not $obj.PSObject.Properties[$name] -or $null -eq $obj.$name) {
        Set-Prop $obj $name ([pscustomobject]@{})
    }
    return $obj.$name
}

function Write-JsonFile($path, $obj) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    if (Test-Path $path) { Copy-Item $path "$path.bak" -Force }
    $obj | ConvertTo-Json -Depth 100 | Set-Content -Path $path -Encoding UTF8
}

# ---------------------------------------------------------------- Etapas
function Install-Programs {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget nao encontrado. Instale o "App Installer" pela Microsoft Store e rode novamente.'
    }
    Install-WingetPackage 'Microsoft.PowerShell'
    Install-WingetPackage 'Microsoft.WindowsTerminal'
    Install-WingetPackage 'Microsoft.VisualStudioCode'
    Install-WingetPackage 'JanDeDobbeleer.OhMyPosh' @('-s', 'winget')
}

function Install-Font {
    New-Item -ItemType Directory -Force $Work | Out-Null
    $zip = Join-Path $Work 'Meslo.zip'
    $ext = Join-Path $Work 'Meslo'
    Invoke-WebRequest $FontZipUrl -OutFile $zip
    if (Test-Path $ext) { Remove-Item $ext -Recurse -Force }
    Expand-Archive $zip -DestinationPath $ext -Force

    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $regKey  = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -ItemType Directory -Force $fontDir | Out-Null
    if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }

    # apenas a familia "MesloLGM Nerd Font" (nao a Mono nem a Propo)
    Get-ChildItem $ext -Filter 'MesloLGMNerdFont-*.ttf' | ForEach-Object {
        $dest = Join-Path $fontDir $_.Name
        Copy-Item $_.FullName $dest -Force
        $style   = ($_.BaseName -split '-', 2)[1] -creplace '([a-z])([A-Z])', '$1 $2'   # ex.: BoldItalic -> Bold Italic
        $regName = "$FontFace $style (TrueType)"
        New-ItemProperty -Path $regKey -Name $regName -Value $dest -PropertyType String -Force | Out-Null
        Write-Host "OK: $regName"
    }
    Remove-Item $Work -Recurse -Force
}

function Install-Theme {
    New-Item -ItemType Directory -Force $ThemesDir, $Work | Out-Null
    $zip = Join-Path $Work 'themes.zip'
    Invoke-WebRequest $ThemesZipUrl -OutFile $zip
    Expand-Archive $zip -DestinationPath $ThemesDir -Force
    Remove-Item $Work -Recurse -Force
    $names = @(Get-ChildItem $ThemesDir -Filter '*.omp.json' | ForEach-Object { $_.Name -replace '\.omp\.json$', '' } | Sort-Object)
    Write-Host "OK: $($names.Count) temas em $ThemesDir"

    if (-not $script:AutoYes) {
        Write-Host "`nTemas disponiveis:" -ForegroundColor Cyan
        $names | Format-Wide -Column 4 | Out-Host
        while ($true) {
            $r = (Read-Host "Qual tema usar? [Enter = $Theme]").Trim() -replace '\.omp\.json$', ''
            if ($r -eq '') { break }
            $match = $names | Where-Object { $_ -ieq $r } | Select-Object -First 1
            if ($match) { $script:Theme = $match; break }
            Write-Host "    Tema '$r' nao encontrado, tente novamente." -ForegroundColor Yellow
        }
    }
    if ($names -notcontains $script:Theme) { throw "Tema padrao '$($script:Theme)' nao existe na pasta de temas." }
    Write-Host "Tema escolhido: $($script:Theme)" -ForegroundColor Green
}

function Set-PowerShellProfiles {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $profiles = @(
        (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
    )
    $profileLines = @(
        '$env:POSH_THEMES_PATH = "$HOME\.poshthemes"',
        "oh-my-posh init pwsh --config `"`$env:POSH_THEMES_PATH\$Theme.omp.json`" | Invoke-Expression"
    )
    foreach ($p in $profiles) {
        New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null
        $keep = @()
        if (Test-Path $p) {
            $keep = @(Get-Content $p | Where-Object { $_ -notmatch 'oh-my-posh init|POSH_THEMES_PATH' })
        }
        Set-Content -Path $p -Value ($keep + $profileLines) -Encoding UTF8
        Write-Host "OK: $p"
    }
}

function Set-WindowsTerminalFont {
    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    $wtPath = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $wtPath) { $wtPath = $wtPaths[0] }
    try {
        $wt       = Read-JsonFile $wtPath
        $profs    = Get-OrAddObject $wt 'profiles'
        $defaults = Get-OrAddObject $profs 'defaults'
        $font     = Get-OrAddObject $defaults 'font'
        Set-Prop $font 'face' $FontFace
        Write-JsonFile $wtPath $wt
        Write-Host "OK: $wtPath"
    } catch {
        Write-Warning "Nao consegui editar o settings.json do Windows Terminal: $_"
        Write-Warning "Configure manualmente: Configuracoes > Padroes > Aparencia > Fonte = $FontFace"
    }
}

function Set-VSCodeFont {
    $vsPath = Join-Path $env:APPDATA 'Code\User\settings.json'
    try {
        $vs = Read-JsonFile $vsPath
        Set-Prop $vs 'terminal.integrated.fontFamily' $FontFace
        Write-JsonFile $vsPath $vs
        Write-Host "OK: $vsPath"
    } catch {
        Write-Warning "Nao consegui editar o settings.json do VS Code: $_"
        Write-Warning "Configure manualmente: terminal.integrated.fontFamily = $FontFace"
    }
}

# ---------------------------------------------------------------- Execucao
$steps = @(
    @{ Title = 'Instalar programas';        Detail = 'winget: PowerShell 7, Windows Terminal, VS Code e Oh My Posh';                 Run = { Install-Programs } },
    @{ Title = 'Instalar a fonte';          Detail = "$FontFace, baixada do Nerd Fonts e instalada so para o usuario atual";         Run = { Install-Font } },
    @{ Title = 'Baixar temas e escolher um'; Detail = "Baixa todos os temas para $ThemesDir e pergunta qual usar (padrao: $Theme)";   Run = { Install-Theme } },
    @{ Title = 'Configurar perfis do PowerShell'; Detail = 'Atualiza o $PROFILE do PowerShell 7 e do 5.1 para iniciar o Oh My Posh'; Run = { Set-PowerShellProfiles } },
    @{ Title = 'Fonte no Windows Terminal'; Detail = 'Define profiles.defaults.font.face no settings.json (com backup .bak)';          Run = { Set-WindowsTerminalFont } },
    @{ Title = 'Fonte no VS Code';          Detail = 'Define terminal.integrated.fontFamily no settings.json (com backup .bak)';     Run = { Set-VSCodeFont } }
)

Write-Host "Setup de terminal: Oh My Posh + $FontFace" -ForegroundColor Green

$i = 0
foreach ($s in $steps) {
    $i++
    if (Ask $i $steps.Count $s.Title $s.Detail) {
        try {
            & $s.Run
            $script:Results += "[ok]      $($s.Title)"
        } catch {
            Write-Warning "Falhou: $_"
            $script:Results += "[falhou]  $($s.Title) - $_"
            if (-not $script:AutoYes) {
                $r = Read-Host '    Continuar com as proximas etapas? [S/n]'
                if ($r.Trim().ToLower() -eq 'n') { break }
            }
        }
    } else {
        Write-Host '    Etapa ignorada.' -ForegroundColor Yellow
        $script:Results += "[pulada]  $($s.Title)"
    }
}

Write-Host "`n==> Resumo" -ForegroundColor Cyan
$script:Results | ForEach-Object { Write-Host "    $_" }
Write-Host "    Tema: $($script:Theme)"
Write-Host "`nFeche e reabra o Windows Terminal e o VS Code para aplicar as mudancas."
Write-Host 'Backups dos settings alterados ficam ao lado dos arquivos (*.bak).'
