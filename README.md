# sysadmin-scripts (Público)

Scripts genéricos de administração de sistemas, desenvolvidos e testados em ambiente de produção. Reutilizáveis em qualquer infraestrutura Windows/Linux.

---

## Scripts disponíveis

### 🪟 Hyper-V
| Script | Descrição |
|---|---|
| `hyper-v/export-vm-backup.ps1` | Backup automático de VMs com validação de VHDX e limpeza por retenção |

### 📊 Zabbix
| Script | Descrição |
|---|---|
| `zabbix/zabbix_manutencao.sh` | Manutenção preventiva: serviços, swap, disco, slow queries |

### 🏢 Windows Server / Active Directory
| Script | Descrição |
|---|---|
| `windows-server/check-ad-health.ps1` | Diagnóstico completo de saúde do AD: replicação, serviços, DNS, FSMO, eventos |

---

## Pré-requisitos

- **PowerShell scripts**: Windows Server 2016+ com módulos RSAT instalados
- **Bash scripts**: Ubuntu 20.04+ / Debian 11+
- Execução como Administrador/root onde indicado

## Uso

```powershell
# Exemplo: verificar saúde do AD com exportação de relatório
.\check-ad-health.ps1 -ExportReport
```

```bash
# Exemplo: manutenção do Zabbix (via cron, 03:00 diário)
bash /opt/scripts/zabbix_manutencao.sh
```

---

## Sobre

Scripts criados por **SysAdmin Author** durante a gestão de infraestrutura de TI da **Company — Fundação Anita Mantuano de Artes do Estado do RJ**, cobrindo 17 sites e ~500 usuários.

[![LinkedIn](https://img.shields.io/badge/LinkedIn-guilhermefelipe82-blue)](https://linkedin.com/in/guilhermefelipe82)
