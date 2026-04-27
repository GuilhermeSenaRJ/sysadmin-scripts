# ============================================================
# Export-VM-Backup.ps1
# Backup automatizado de VMs Hyper-V para share de rede
# Autor: Guilherme Sena | FUNARJ - SSTI
# ============================================================

$destino   = "\\dc\ATI\backup servidor VHD\SEDE\DCS1"
$data      = Get-Date -Format "yyyy-MM-dd"
$log       = "C:\Scripts\backup_$data.log"
$retencao  = 7
$erros     = 0

function Log($msg) {
    $linha = "$(Get-Date -Format 'HH:mm:ss') | $msg"
    $linha | Out-File $log -Append -Encoding UTF8
    Write-Host $linha
}

Log "=== INICIO BACKUP ==="

$vms = @(
    @{ Nome = "Srv03 - glpi";                Pasta = "GLPI"   },
    @{ Nome = "Srv04 - Zabbix";              Pasta = "Zabbix" },
    @{ Nome = "Srv02 - Gestor de Patrimonio"; Pasta = "Gestor" }
)

foreach ($vm in $vms) {
    $caminho = "$destino\$($vm.Pasta)\$data"
    Log "Iniciando export: $($vm.Nome) -> $caminho"
    try {
        New-Item -ItemType Directory -Path $caminho -Force | Out-Null
        Export-VM -Name $vm.Nome -Path $caminho -ErrorAction Stop

        # Confirma que o VHDX existe e tem tamanho real
        $vhdx = Get-ChildItem "$caminho" -Recurse -Filter "*.vhdx" | Select-Object -First 1
        if ($vhdx -and $vhdx.Length -gt 1MB) {
            Log "OK: $($vm.Nome) | VHDX: $($vhdx.FullName) | Tamanho: $([math]::Round($vhdx.Length/1GB,2)) GB"
        } else {
            Log "AVISO: Export concluiu mas VHDX nao encontrado ou vazio em $caminho"
            $erros++
        }
    } catch {
        Log "ERRO: $($vm.Nome) | $($_.Exception.Message)"
        $erros++
    }
}

# Limpeza de backups antigos (retencao de $retencao dias)
foreach ($vm in $vms) {
    try {
        $removidos = Get-ChildItem "$destino\$($vm.Pasta)" -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-$retencao) }
        foreach ($dir in $removidos) {
            Remove-Item $dir.FullName -Recurse -Force
            Log "Limpeza: removido $($dir.FullName)"
        }
    } catch {
        Log "ERRO limpeza $($vm.Pasta): $($_.Exception.Message)"
        $erros++
    }
}

Log "=== FIM BACKUP | Erros: $erros ==="
exit $erros  # Tarefa Agendada detecta falha pelo exit code
