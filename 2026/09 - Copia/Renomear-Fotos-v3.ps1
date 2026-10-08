# ============================================================
#  Renomear-Fotos-v3.ps1
#
#  LOGICA:
#    1. Pega a string antes do primeiro "_"  (ex.: "Foto01")
#    2. Remove esse prefixo e o "_" do inicio do nome
#    3. Localiza a ULTIMA ocorrencia de " - " (espaco traco espaco)
#    4. Insere "_" + prefixo imediatamente antes dessa ultima ocorrencia
#
#  De:   Foto01_Encostas Lote 20 - 1o Trav. Pres. Costa e Silva - Placa.jpg
#  Para: Encostas Lote 20 - 1o Trav. Pres. Costa e Silva_Foto01 - Placa.jpg
#
#  USO: abra o PowerShell na pasta das fotos e rode:
#       .\Renomear-Fotos-v3.ps1
#  Ele mostra o antes/depois e pede confirmacao antes de alterar nada.
# ============================================================

# --- Ajustes ---

# Incluir subpastas? $true ou $false
$Recursivo = $false

# Separador usado para achar o corte
$Separador = ' - '

# ---------------

$ErrorActionPreference = 'Stop'
$pasta = (Get-Location).Path

Write-Host ""
Write-Host "Pasta: $pasta" -ForegroundColor Cyan

$extensoes = '.jpg', '.jpeg', '.png', '.bmp', '.tif', '.tiff', '.heic', '.webp'

$arquivos = Get-ChildItem -LiteralPath $pasta -File -Recurse:$Recursivo |
            Where-Object { $extensoes -contains $_.Extension.ToLower() }

if (-not $arquivos) {
    Write-Warning "Nenhuma imagem encontrada nesta pasta."
    return
}

$plano     = @()
$ignorados = @()

foreach ($arq in $arquivos) {

    $base = [System.IO.Path]::GetFileNameWithoutExtension($arq.Name)
    $ext  = $arq.Extension

    # --- Passo 1: string antes do primeiro "_" ---
    $pos = $base.IndexOf('_')

    if ($pos -lt 1) {
        $ignorados += [pscustomobject]@{
            Arquivo = $arq.Name
            Motivo  = 'Sem "_" no nome'
        }
        continue
    }

    $prefixo = $base.Substring(0, $pos)          # ex.: "Foto01"
    $resto   = $base.Substring($pos + 1)         # --- Passo 2: sem prefixo e sem "_"

    # --- Passo 3: ultima ocorrencia de " - " ---
    $corte = $resto.LastIndexOf($Separador)

    if ($corte -lt 1) {
        $ignorados += [pscustomobject]@{
            Arquivo = $arq.Name
            Motivo  = 'Sem " - " apos o prefixo'
        }
        continue
    }

    # --- Passo 4: insere "_" + prefixo antes do ultimo " - " ---
    $novaBase = $resto.Substring(0, $corte) + '_' + $prefixo + $resto.Substring($corte)
    $novoNome = $novaBase + $ext

    if ($novoNome -eq $arq.Name) { continue }

    if (Test-Path -LiteralPath (Join-Path $arq.DirectoryName $novoNome)) {
        $ignorados += [pscustomobject]@{
            Arquivo = $arq.Name
            Motivo  = 'Nome de destino ja existe'
        }
        continue
    }

    $plano += [pscustomobject]@{
        De     = $arq.Name
        Para   = $novoNome
        Origem = $arq.FullName
    }
}

# ---------- Previa ----------

if ($plano.Count -eq 0) {
    Write-Host "Nada a renomear." -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "$($plano.Count) arquivo(s) a renomear:" -ForegroundColor Cyan
    $plano | Select-Object De, Para | Format-Table -AutoSize -Wrap | Out-Host
}

if ($ignorados.Count -gt 0) {
    Write-Host "$($ignorados.Count) arquivo(s) ignorado(s):" -ForegroundColor Yellow
    $ignorados | Format-Table -AutoSize -Wrap | Out-Host
}

if ($plano.Count -eq 0) { return }

# ---------- Confirmacao ----------

$resposta = Read-Host "Confirma a renomeacao? (S/N)"

if ($resposta -notmatch '^[SsYy]') {
    Write-Host "Cancelado. Nada foi alterado." -ForegroundColor Magenta
    return
}

$ok    = 0
$falha = 0

foreach ($item in $plano) {
    try {
        Rename-Item -LiteralPath $item.Origem -NewName $item.Para
        $ok++
    }
    catch {
        $falha++
        Write-Warning ("Falha em " + $item.De + ": " + $_.Exception.Message)
    }
}

Write-Host ""
Write-Host "Concluido: $ok renomeado(s), $falha falha(s)." -ForegroundColor Green
