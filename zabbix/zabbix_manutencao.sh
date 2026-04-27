#!/bin/bash
# ============================================================
# zabbix_manutencao.sh
# Manutenção preventiva do servidor Zabbix (Ubuntu/Debian)
# Autor: SysAdmin
# SrvMon - 192.168.1.21
# ============================================================

set -euo pipefail
LOG="/var/log/zabbix_manutencao.log"
DATA=$(date '+%Y-%m-%d %H:%M:%S')

log() { echo "[$DATA] $1" | tee -a "$LOG"; }

log "=== INICIO MANUTENCAO ZABBIX ==="

# 1. Verificar e reiniciar servicos se parados
for svc in zabbix-server zabbix-agent mysql apache2; do
    if ! systemctl is-active --quiet "$svc"; then
        log "AVISO: $svc parado. Reiniciando..."
        systemctl restart "$svc" && log "OK: $svc reiniciado" || log "ERRO: falha ao reiniciar $svc"
    else
        log "OK: $svc rodando"
    fi
done

# 2. Limpar slow queries acumuladas do MySQL
log "Limpando slow query log do MySQL..."
> /var/log/mysql/mysql-slow.log 2>/dev/null || true
log "OK: slow query log limpo"

# 3. Verificar uso de swap
SWAP_USED=$(free -m | awk '/Swap:/{print $3}')
log "Swap em uso: ${SWAP_USED} MB"
if [ "$SWAP_USED" -gt 512 ]; then
    log "AVISO: swap alto. Liberando cache..."
    sync && echo 3 > /proc/sys/vm/drop_caches
    log "OK: cache liberado"
fi

# 4. Verificar uso de disco
DISCO=$(df -h / | awk 'NR==2{print $5}' | tr -d '%')
log "Uso de disco /: ${DISCO}%"
if [ "$DISCO" -gt 85 ]; then
    log "CRITICO: disco acima de 85%. Verificar manualmente!"
fi

# 5. Rotacionar logs do Zabbix manualmente se necessario
find /var/log/zabbix/ -name "*.log" -size +100M -exec gzip {} \; 2>/dev/null || true

log "=== FIM MANUTENCAO | Status: OK ==="
