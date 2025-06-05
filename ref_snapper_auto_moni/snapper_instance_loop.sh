#!/bin/bash
#============================================================================================================
# Referencia : snapper_instance_loop.sh
# Assunto    : Inicia o Snapper em loop contínuo, com execução a cada 10 segundos
# Criado por : Roberto Fernandes Sobrinho
# Blog       : https://dbasobrinho.com.br
# Data       : 06/11/2020
#
# Descrição:
# - Este script executa o snapper_instance.sh continuamente, a cada 10 segundos, até a data do sistema mudar.
# - Ele é útil para acompanhar o comportamento do banco de forma contínua durante o dia.
# - Os logs antigos são automaticamente removidos conforme a retenção configurada.
#
# IMPORTANTE:
# - Altere a variável SCRIPT_PATH abaixo com o diretório correto onde está o script snapper_instance.sh no seu ambiente.
# - Esse script **depende do snapper_instance.sh** para funcionar corretamente.
#
# Retenção de logs:
# - Os logs do Snapper são mantidos por padrão por 10 dias.
# - Para ajustar esse período, altere o valor da variável RETENTION_DAYS logo abaixo.
#
# Como utilizar manualmente:
#   sh /u01/app/oracle/ADMDBA/MONI/snapper_instance_loop.sh PEXBI
#
# Recomendação para agendamento via crontab:
# - Para iniciar o loop logo após a virada do dia, adicione a seguinte linha no crontab do usuário oracle:
#
#     10 00 * * *  sh /u01/app/oracle/ADMDBA/MONI/snapper_instance_loop.sh PEXBI > /dev/null 2>&1
#
#============================================================================================================

# Dias de retenção dos logs (ajuste conforme necessidade)
RETENTION_DAYS=10

# Caminho do diretório onde está o snapper_instance.sh
SCRIPT_PATH="/u01/app/oracle/ADMDBA/MONI"

# Caminho dos logs
LOG_DIR="$SCRIPT_PATH/logs_snapper"

# Corrige o erro de terminal somente se for um terminal interativo
if [ -t 0 ]; then
  stty erase ^H
fi

# Armazena o dia atual
DATA=$(date '+%d')

# Remove logs com mais de $RETENTION_DAYS dias
find "$LOG_DIR" -name '*snapper*.log' ! -name 'snapper_cpu*.log' -mtime +$RETENTION_DAYS -exec rm -f {} \;
##find "$LOG_DIR" -name '*snapper*.log' -mtime +$RETENTION_DAYS -exec rm -f {} \;

# Loop até mudar o dia
while [ "$DATA" -eq "$(date '+%d')" ]
do
  sh "$SCRIPT_PATH/snapper_instance.sh" "$1"
  sleep 10
done

