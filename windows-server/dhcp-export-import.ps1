# ============================================================
# dhcp-export-import.ps1
# Migração de escopo DHCP entre servidores Windows
# Cenário: DC 2008 R2 (10.9.64.2) -> DCS1 (10.9.64.4)
# Autor: Guilherme Sena | FUNARJ - SSTI
# ============================================================

param(
    [ValidateSet("export","import","verify")]
    [string]$Mode = "verify",
    [string]$ServidorOrigem  = "10.9.64.2",
    [string]$ServidorDestino = "10.9.64.4",
    [string]$ArquivoExport   = "C:\Scripts\dhcp_export.xml"
)

function Log($msg) {
    Write-Host "$(Get-Date -Format 'HH:mm:ss') | $msg"
}

switch ($Mode) {

    "export" {
        Log "Exportando DHCP de $ServidorOrigem..."
        try {
            Export-DhcpServer -ComputerName $ServidorOrigem -File $ArquivoExport -Force
            Log "OK: export salvo em $ArquivoExport"
            $escopos = Get-DhcpServerv4Scope -ComputerName $ServidorOrigem
            Log "Escopos exportados: $($escopos.Count)"
            $reservas = Get-DhcpServerv4Reservation -ComputerName $ServidorOrigem -ScopeId $escopos[0].ScopeId
            Log "Reservas no primeiro escopo: $($reservas.Count) (total pode ser maior)"
        } catch {
            Log "ERRO: $($_.Exception.Message)"
        }
    }

    "import" {
        Log "Importando DHCP para $ServidorDestino..."
        if (-not (Test-Path $ArquivoExport)) {
            Log "ERRO: arquivo $ArquivoExport nao encontrado. Execute o modo 'export' primeiro."
            exit 1
        }
        try {
            # Para o DHCP no servidor destino para evitar conflito
            Stop-Service -Name DHCPServer -ComputerName $ServidorDestino -ErrorAction SilentlyContinue
            Log "Servico DHCP parado em $ServidorDestino"

            Import-DhcpServer -ComputerName $ServidorDestino -File $ArquivoExport -BackupPath "C:\Windows\system32\dhcp\backup" -Force
            Log "OK: import concluido"

            # Reativa o DHCP no destino
            Start-Service -Name DHCPServer -ComputerName $ServidorDestino
            Log "OK: servico DHCP iniciado em $ServidorDestino"

            # Autoriza o novo servidor no AD
            Add-DhcpServerInDC -DnsName "dcs1.funarj.br" -IPAddress $ServidorDestino
            Log "OK: servidor autorizado no AD"

            # Pausa o DHCP no servidor antigo para evitar conflito
            Log "AVISO: pare o DHCP no servidor antigo manualmente: Stop-Service DHCPServer -ComputerName $ServidorOrigem"
        } catch {
            Log "ERRO: $($_.Exception.Message)"
        }
    }

    "verify" {
        Log "Verificando estado atual do DHCP..."
        try {
            Log "--- Servidor: $ServidorOrigem ---"
            $escopos = Get-DhcpServerv4Scope -ComputerName $ServidorOrigem -ErrorAction SilentlyContinue
            if ($escopos) {
                foreach ($e in $escopos) {
                    $reservas = (Get-DhcpServerv4Reservation -ComputerName $ServidorOrigem -ScopeId $e.ScopeId).Count
                    Log "  Escopo: $($e.ScopeId) | Range: $($e.StartRange)-$($e.EndRange) | Reservas: $reservas"
                }
            } else {
                Log "  Nao foi possivel conectar ou sem escopos"
            }

            Log "--- Servidor destino: $ServidorDestino ---"
            $status = Get-Service -Name DHCPServer -ComputerName $ServidorDestino -ErrorAction SilentlyContinue
            if ($status) { Log "  DHCP status: $($status.Status)" }
        } catch {
            Log "ERRO: $($_.Exception.Message)"
        }
    }
}

# Uso:
# .\dhcp-export-import.ps1 -Mode verify
# .\dhcp-export-import.ps1 -Mode export
# .\dhcp-export-import.ps1 -Mode import
