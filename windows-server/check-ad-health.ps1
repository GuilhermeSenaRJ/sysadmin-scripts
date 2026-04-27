# ============================================================
# check-ad-health.ps1
# Diagnóstico de saúde do Active Directory - FUNARJ
# Autor: Guilherme Sena | FUNARJ - SSTI
# Domínio: funarj.br | DCs: DC (2008R2), DCS1 (2016), SRVFUNARJAD01 (2022)
# ============================================================

param(
    [switch]$ExportReport
)

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$report = @()

function Write-Check($test, $status, $detail = "") {
    $color = if ($status -eq "OK") { "Green" } elseif ($status -eq "AVISO") { "Yellow" } else { "Red" }
    Write-Host "[$status] $test" -ForegroundColor $color
    if ($detail) { Write-Host "  -> $detail" -ForegroundColor Gray }
    $script:report += [PSCustomObject]@{ Teste = $test; Status = $status; Detalhe = $detail }
}

Write-Host "`n=== DIAGNOSTICO AD - FUNARJ ===" -ForegroundColor Cyan
Write-Host "Data: $(Get-Date)" -ForegroundColor Gray

# 1. Replicacao AD
Write-Host "`n[1] Verificando replicacao..." -ForegroundColor White
try {
    $replSum = repadmin /replsummary 2>&1
    if ($replSum -match "0 fails") {
        Write-Check "Replicacao AD" "OK" "Sem falhas detectadas"
    } else {
        Write-Check "Replicacao AD" "ERRO" "Falhas encontradas - execute: repadmin /replsummary"
    }
} catch {
    Write-Check "Replicacao AD" "ERRO" $_.Exception.Message
}

# 2. Servicos essenciais no DC local
Write-Host "`n[2] Verificando servicos AD..." -ForegroundColor White
$servicos = @("ADWS", "DNS", "KDC", "Netlogon", "NTDS", "W32Time")
foreach ($svc in $servicos) {
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($s -and $s.Status -eq "Running") {
        Write-Check "Servico: $svc" "OK"
    } else {
        Write-Check "Servico: $svc" "ERRO" "Servico parado ou nao encontrado"
    }
}

# 3. SYSVOL e NETLOGON shares
Write-Host "`n[3] Verificando shares SYSVOL/NETLOGON..." -ForegroundColor White
$shares = net share 2>&1
if ($shares -match "SYSVOL") { Write-Check "Share SYSVOL" "OK" }
else { Write-Check "Share SYSVOL" "ERRO" "Share nao encontrado" }
if ($shares -match "NETLOGON") { Write-Check "Share NETLOGON" "OK" }
else { Write-Check "Share NETLOGON" "ERRO" "Share nao encontrado" }

# 4. DNS - resolucao interna
Write-Host "`n[4] Verificando DNS..." -ForegroundColor White
try {
    $dns = Resolve-DnsName -Name "funarj.br" -Server "10.9.64.2" -ErrorAction Stop
    Write-Check "DNS resolucao funarj.br" "OK" $dns[0].IPAddress
} catch {
    Write-Check "DNS resolucao funarj.br" "ERRO" $_.Exception.Message
}

# 5. FSMO Roles
Write-Host "`n[5] Verificando FSMO roles..." -ForegroundColor White
try {
    $fsmo = netdom query fsmo 2>&1
    Write-Check "FSMO roles" "OK" ($fsmo | Select-String "DC|SRV" | Out-String).Trim()
} catch {
    Write-Check "FSMO roles" "AVISO" "Nao foi possivel verificar"
}

# 6. Eventos criticos recentes (erros AD nas ultimas 24h)
Write-Host "`n[6] Verificando eventos criticos..." -ForegroundColor White
try {
    $errosAD = Get-EventLog -LogName "Directory Service" -EntryType Error -Newest 5 -ErrorAction SilentlyContinue
    if ($errosAD) {
        Write-Check "Eventos AD (ultimas 24h)" "AVISO" "$($errosAD.Count) erros encontrados no Directory Service"
        $errosAD | Select-Object TimeGenerated, EventID, Message | ForEach-Object {
            Write-Host "  $($_.TimeGenerated) | ID: $($_.EventID) | $($_.Message.Substring(0, [Math]::Min(80, $_.Message.Length)))" -ForegroundColor Yellow
        }
    } else {
        Write-Check "Eventos AD (ultimas 24h)" "OK" "Nenhum erro no Directory Service"
    }
} catch {
    Write-Check "Eventos AD" "AVISO" "Nao foi possivel verificar logs"
}

# Relatorio
Write-Host "`n=== RESUMO ===" -ForegroundColor Cyan
$ok    = ($report | Where-Object Status -eq "OK").Count
$aviso = ($report | Where-Object Status -eq "AVISO").Count
$erro  = ($report | Where-Object Status -eq "ERRO").Count
Write-Host "OK: $ok | AVISO: $aviso | ERRO: $erro" -ForegroundColor White

if ($ExportReport) {
    $path = "C:\Scripts\ad_health_$timestamp.csv"
    $report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    Write-Host "Relatorio exportado: $path" -ForegroundColor Green
}
