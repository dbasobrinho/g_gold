
#!/bin/bash
#============================================================================================================
# Referencia : snapper_cpu.sh
# Assunto    : Execução do Snapper CPU para análise de consumo por processo no servidor
# Criado por : Roberto Fernandes Sobrinho
# Blog       : https://dbasobrinho.com.br
# Data       : 06/11/2020
#
# Descrição:
# - Executa a coleta de estatísticas detalhadas de utilização de CPU no servidor, por processo e sessão
# - Gera logs agrupados por hora em arquivos nomeados por hostname
# - Enquanto os arquivos estiverem preservados, o histórico pode ser consultado
#
# Modo de uso:
# - O script deve ser executado diretamente via shell:
#     sh $ORACLE_BASE/ADMDBA/MONI/snapper_cpu.sh
#
# Requisitos:
# - Scripts auxiliares: snapper_cpu_stats.sh, snapper_cpu.pl (renomeado a partir de cpu_per_db_sort.pl)
# - É necessário que o Perl esteja disponível no ambiente
# - O diretório ./logs_snapper será criado automaticamente, caso não exista
#
# Explicação dos parâmetros utilizados no snapper_cpu.pl:
# - "10": intervalo de 10 segundos entre as amostragens
# - "06": número de amostras (repetições)
# - "displayuser=Y": exibe o nome do usuário que executa o processo
# - "displaycmd=Y": exibe o comando associado ao processo
# - "top=20": exibe os 20 processos que mais consumiram CPU durante o período
#
# Observação:
# - Caminho do diretório onde está o snapper_cpu.sh e scripts auxiliares:
#     SCRIPT_PATH="$ORACLE_BASE/ADMDBA/MONI"  # Este valor pode ser alterado conforme a estrutura do seu ambiente
# - Caminho dos logs:
#     LOG_DIR="$SCRIPT_PATH/logs_snapper"     # Diretório onde serão gerados os arquivos de log
#
# Referências:
# - Script snapper_cpu.pl baseado na abordagem publicada por Bertrand Drouvot
#   Fonte original: https://bdrouvot.wordpress.com/os_cpu_per_dp/
#   Script original: cpu_per_db_sort.pl
#   Adaptado e renomeado para snapper_cpu.pl por Roberto Fernandes Sobrinho
# - Script snapper_cpu_stats.sh utilizado neste processo foi originalmente escrito por:
#     Steve Bosek (BU Plugins)
#     Patched por Bas van der Doorn e Philipp Lemke
#     Release       : 2.3.6
#     Criação       : 08/09/2007
#     Última revisão: 05/08/2011
#============================================================================================================

# Caminho do diretório onde está o snapper_cpu.sh
SCRIPT_PATH="/u01/app/oracle/ADMDBA/MONI"

# Caminho dos logs (serão criados aqui, se ainda não existirem)
LOG_DIR="$SCRIPT_PATH/logs_snapper"

export dt=`date +%y%m%d%H%M%S`
HOSTN=$(hostname | tr '[a-z]' '[A-Z]')
OS=$(uname | tr '[a-z]' '[A-Z]')

if [ "${OS}" == "LINUX" ]; then
  . ~/.bash_profile > /dev/null
else
  . ~/.profile > /dev/null
fi

# Cria diretório de log, se não existir
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi

export DATA=`date +%Y%m%d%H`
export LOG="$LOG_DIR/${DATA}_snapper_cpu_${HOSTN}.log"
export DTC=`date +%d/%b/%Y_%k:%M:%S`

{
  echo "============================================================================="
  echo " CPU STAT: . . . . . . . . . . . : $DTC"
  echo "============================================================================="
} | tee -a "$LOG"

sh "$SCRIPT_PATH/snapper_cpu_stats.sh" >> "$LOG"

{
  echo "============================================================================="
  echo " INICIO SNAPPER CPU  . . . . . . : $HOSTN"
  echo "============================================================================="
  echo " DATA HRS: . . . . . . . . . . . : $DTC"
  echo "============================================================================="
} | tee -a "$LOG"

perl "$SCRIPT_PATH/snapper_cpu.pl" 10 06 displayuser=Y displaycmd=Y top=20 >> "$LOG"

export DTC=`date +%d/%b/%Y_%k:%M:%S`

{
  echo "  "
  echo "  "
  echo "============================================================================="
  echo " FIM SNAPPER CPU . . . . . . . . : $HOSTN"
  echo "============================================================================="
  echo " DATA HRS: . . . . . . . . . . . : $DTC"
  echo "============================================================================="
  echo " +-+-+-+                    +-+ +-+-+-+ +-+ +-+ +-+ +-+-+-+-+-+-+-+-+-+-+-+ "
  echo " |F|I|M|                    |E| |Z|A|S| |.| |.| |.| |D|B|A|S|O|B|R|I|N|H|O| "
  echo " +-+-+-+                    +-+ +-+-+-+ +-+ +-+ +-+ +-+-+-+-+-+-+-+-+-+-+-+ "
  echo ""
} | tee -a "$LOG"

