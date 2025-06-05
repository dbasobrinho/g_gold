
#!/bin/bash
#============================================================================================================
# Referência  : snapper_cpu_loop.sh
# Assunto     : Execução contínua do Snapper CPU em loop diário
# Criado por  : Roberto Fernandes Sobrinho
# Blog        : https://dbasobrinho.com.br
# Data        : 25/11/2020
#
# Descrição:
# - Executa continuamente o script snapper_cpu.sh enquanto o dia atual não muda
# - Ideal para coleta de dados de CPU ao longo de todo o dia, com intervalo entre execuções
# - Os arquivos de log gerados pelo snapper_cpu.sh são agrupados por hora
#
# Modo de uso:
# - O script deve ser agendado para execução via crontab logo após a meia-noite, exemplo:
#     10 00 * * * /u01/app/oracle/ADMDBA/MONI/snapper_cpu_loop.sh > /dev/null 2>&1
#
# Observações:
# - O caminho do diretório onde está o snapper_cpu.sh pode ser alterado abaixo conforme o ambiente
# - O diretório de logs será mantido com histórico de até X dias, podendo ser ajustado via variável
#============================================================================================================

# Caminho do diretório onde está o snapper_cpu.sh
SCRIPT_PATH="/u01/app/oracle/ADMDBA/MONI"

# Caminho dos logs (serão criados aqui, se ainda não existirem)
LOG_DIR="$SCRIPT_PATH/logs_snapper"

# Quantidade de dias para manter os logs (padrão: 10 dias)
RETENTION_DAYS=10

# Coleta o dia atual no início do script
DATA=$(date '+%d')

# Remove logs antigos (com mais de $RETENTION_DAYS dias)
find "$LOG_DIR" -name 'snapper_cpu*.log' -mtime +"$RETENTION_DAYS" -exec rm -f {} \;

# Loop até o dia virar (diferente do dia inicial)
while [ "$DATA" -eq "$(date '+%d')" ]; do
  sh "$SCRIPT_PATH/snapper_cpu.sh"
  sleep 10
done

