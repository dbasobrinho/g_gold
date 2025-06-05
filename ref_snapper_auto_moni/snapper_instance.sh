#============================================================================================================
# Referencia : snapper_instance.sh
# Assunto    : Execução do Snapper em uma ou mais instâncias Oracle do servidor
# Autor      : Roberto Fernandes Sobrinho (todos os scripts, exceto o snapper_instance.sql)
# Blog       : https://dbasobrinho.com.br
# Data       : 06/11/2020
#
# Observação:
# - O script `snapper_instance.sql` utilizado neste processo foi escrito por **Tanel Poder**
#   e está disponível publicamente em:
#     https://github.com/tanelpoder/tpt-oracle/blob/master/snapper.sql
#
# Descrição:
# - Executa o Snapper em todas as instâncias Oracle ativas que contenham o padrão passado como argumento ($1)
# - Identifica o ORACLE_HOME automaticamente com base no processo ora_pmon_<SID>
# - Gera logs individuais por instância, agrupados por hora, permitindo análise posterior
# - Enquanto os arquivos forem mantidos no diretório de logs, o histórico poderá ser consultado livremente
# - Ao final da execução de cada instância, também é chamado o oratop, se estiver disponível
#
# Logs:
# - Os arquivos de log são gerados no diretório ./logs_snapper com o nome no formato:
#     <ANO><MÊS><DIA><HORA>_snapper_<INSTANCIA>.log
# - Exemplo: 20250604_10_snapper_PEXBI.log
#
# Dependências:
# - sqlplus disponível no $ORACLE_HOME/bin
# - Scripts: snapper_hora.sql, snapper_s.sql, snapper_instance.sql
# - Binário do oratop configurado na variável ORATOP
#
# Permissões:
# - O usuário 'oracle' precisa executar o comando 'pwdx' via sudo sem solicitar senha
#   Para isso, adicione no /etc/sudoers com visudo:
#
#     oracle ALL=(ALL) NOPASSWD: /usr/bin/pwdx
#
# IMPORTANTE:
# - Altere a variável ORATOP para refletir o caminho correto do seu ambiente.
#============================================================================================================

# Caminho fixo do oratop (ajuste conforme seu ambiente)
ORATOP="/u01/app/oracle/ADMDBA/MONI/oratop.LNX.RDBMS11"

# Verifica se o argumento foi informado
if [ -z "$1" ]; then
  echo "Uso: $0 <nome_parcial_da_instancia>"
  echo "Exemplo: $0 PEXBI"
  exit 1
fi

export dt=`date +%y%m%d%H%M%S`

##DESCOBRINHO 0 SSISTEMA OPERACIONAL
HOSTN=$(hostname)
HOSTN=`echo ${HOSTN} | tr '[a-z]' '[A-Z]'`
OS="`uname`"
OS=`echo ${OS} | tr '[a-z]' '[A-Z]'`
if [  "${OS}" == LINUX ]; then
#!/bin/bash
. ~/.bash_profile > /dev/null
else
#!/usr/bin/ksh
. ~/.profile > /dev/null
fi

#########################
for instance in $(
  ps -ef | grep pmon | grep -v grep | grep -iv asm | grep "$1" |
  grep -vE 'ora_pmon_(\+ASM|MGMTDB)' |
  awk '{print $NF}' | sed 's/^ora_pmon_//'
)
do
##instance=bunda_branca
IDP=`ps -ef | grep pmon | grep -v grep | grep pmon_${instance} | awk '{print$'2'}'`
if [  "${OS}" == LINUX ]; then
HO=`sudo pwdx ${IDP} |awk -F ":" '{print $NF}' `
HO=`echo "$HO" | rev | cut -c5- | rev`
elif [  "${OS}" == SUNOS ]; then
HO=`pwdx ${IDP}`
HO=`echo "$HO" | awk '{print$'NF'}'`
HO=`echo $HO | sed 's/[/]dbs//g'`
else
HO=`ls -l /proc/${IDP}/cwd |awk -F " " '{print $NF}'`
HO=`echo "$HO" | rev | cut -c6- | rev`
fi
HO=`echo $HO |sed 's/ /\(&\)/'`
##
cd $ORACLE_BASE/ADMDBA/MONI
export DATA=`date +%Y%m%d%H`
if [ ! -d ./logs_snapper ]; then
  mkdir -p ./logs_snapper
fi
export LOG=./logs_snapper/${DATA}_snapper_${instance}.log
export DTC=`date +%d/%b/%Y_%k:%M:%S`
echo "==========================================================================="  2>&1 |tee -a $LOG
echo " INICIO SNAPPER INSTANCE . . . . : "$instance                                 2>&1 |tee -a $LOG
echo "==========================================================================="  2>&1 |tee -a $LOG
echo " DATA HRS: . . . . . . . . . . . : "$DTC                                      2>&1 |tee -a $LOG
echo "==========================================================================="  2>&1 |tee -a $LOG
ORACLE_HOME=$HO; export ORACLE_HOME
ORACLE_SID=$instance; export ORACLE_SID
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:$LD_LIBRARY_PATH
##echo $ORACLE_HOME
##echo $ORACLE_SID
$ORACLE_HOME/bin/sqlplus -S /  as sysdba <<EOF
SET heading     ON
SET newpage     NONE
SET define      ON;
SET ECHO        OFF;
SET VERIFY      OFF;
SET FEEDBACK    OFF;
SET TIMING      OFF;
set LINES       1000;
set PAGES       500;
set colsep     '|'
set trimspool  ON
set headsep    OFF
ALTER SESSION SET NLS_DATE_FORMAT                 = 'DD/MM/YYYY HH24:MI:SS';
begin execute immediate 'ALTER SESSION SET "_OPTIMIZER_JOIN_FACTORIZATION"=FALSE'; exception when others then null; end;
/
spool ${LOG} APPEND
--variable v_start number
--exec :v_start := dbms_utility.get_time;
@snapper_hora.sql
@snapper_instance.sql ash=inst_id+sql_id+event+wait_class+blocking_session 10 06 "select inst_id,sid from gv\$session where status = 'ACTIVE' and type = 'USER' and sql_id = sql_id"
@snapper_s.sql
----->>> COLUMN PSEG NEW_VALUE PSEG NOPRINT;
----->>> select round((dbms_utility.get_time - :v_start )/100,2) PSEG from  dual;
----->>> PROMPT +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
----->>> PROMPT OI BUM BUM
----->>> PROMPT TEMPO (s) : &PSEG
----->>> PROMPT +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
exit
EOF

if [ -x "$ORATOP" ]; then
  echo "==========================================================================="  2>&1 |tee -a $LOG
  $ORATOP -d -bfs -n 1 -i 1 / as sysdba | perl -pe 's/\e\[[0-9;?]*[a-zA-Z]//g' | tr -d '\r' | sed 's/^[[:space:]]\+//' | tee -a "$LOG"
  echo "==========================================================================="  2>&1 |tee -a $LOG
  echo "==========================================================================="  2>&1 |tee -a $LOG 
  $ORATOP -d -bf  -n 1 -i 1 / as sysdba | perl -pe 's/\e\[[0-9;?]*[a-zA-Z]//g' | tr -d '\r' | sed 's/^[[:space:]]\+//' | tee -a "$LOG"
  echo "==========================================================================="  2>&1 |tee -a $LOG
fi

export DTC=`date +%d/%b/%Y_%k:%M:%S`
echo "  "                                                                           2>&1 |tee -a $LOG
echo "  "                                                                           2>&1 |tee -a $LOG
echo "==========================================================================="  2>&1 |tee -a $LOG
echo " FIM SNAPPER INSTANCE  . . . . . : "$instance                                 2>&1 |tee -a $LOG
echo "==========================================================================="  2>&1 |tee -a $LOG
echo " DATA HRS: . . . . . . . . . . . : "$DTC                                      2>&1 |tee -a $LOG
echo "==========================================================================="  2>&1 |tee -a $LOG
echo " +-+-+-+                    +-+ +-+-+-+ +-+ +-+ +-+ +-+-+-+-+-+-+-+-+-+-+-+ " 2>&1 |tee -a $LOG
echo " |F|I|M|                    |E| |Z|A|S| |.| |.| |.| |D|B|A|S|O|B|R|I|N|H|O| " 2>&1 |tee -a $LOG
echo " +-+-+-+                    +-+ +-+-+-+ +-+ +-+ +-+ +-+-+-+-+-+-+-+-+-+-+-+ " 2>&1 |tee -a $LOG
echo ""                                                                             2>&1 |tee -a $LOG
done

