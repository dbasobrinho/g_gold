#!/bin/sh
# For details see man 4 crontabs
# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed
# rfsobrinho - 2018 06 10 
# 01 08 * * 6 /u01/app/oracle/product/11.2.0.4/db_1/scripts/log_rotate/rotate_logs.sh 1>/u01/app/oracle/product/11.2.0.4/db_1/scripts/log_rotate/rotate_logs.log 2>/u01/app/oracle/product/11.2.0.4/db_1/scripts/log_rotate/rotate_logs.err
# Compativel com AIX e Linux - compatibilidade com Solaris sendo desenvolvida.
#
# --------------------------------------------------------------------------

# Local onde esta o arquivo de configuracao. Setar conforme ambiente
# Variaveis globais ao script
DIR_FILE_CONFIG_ROT=/u/app/oracle/TVTDBA
FILE_CONFIG=oracle_rotation_logs.cfg
COMPRESS_COMMAND=gzip
LSNRCTL="lsnrctl"
DELETE_COMMAND=rm
BKP_LOG_DIR=$ORACLE_HOME/scripts/logs
DATA=`date '+%Y%m%d_%H%M%S'`

echo `date` "Rotate Started!"

if [ -f ${DIR_FILE_CONFIG_ROT}/${FILE_CONFIG} ]; then
    echo "Loading the rotate_logs.conf..."
    . ${DIR_FILE_CONFIG_ROT}/${FILE_CONFIG}
else
    echo "Does not exists ${DIR_FILE_CONFIG_ROT}/${FILE_CONFIG}"
    echo "Terminate rotate_logs"
    exit 1
fi
unalias=rm
unset $BDUMP
unset $UDUMP
unset $CDUMP
unset $ADUMP
unset $ADUMP_R

if [ -f ${ORAT} ]; then
   TMP_SID=`egrep -v "\*|^#|^$" /etc/oratab | awk -F":" '{ print $1 ":" $2 }'`
else
   echo "Does not exists the file ${ORAT}."
   exit 1
fi

## FUNCAO DELETE DE ARQUIVOS ANTIGOS COMPACTADOS
rot_del ()
{

case ${1} in
'*.log.gz')
     echo "Finding the logs files ${LOGFILE} to remove..."
     find ${LOGFILE} -name "${1}" -mtime +$DELETE_LOGS_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;

     if [ "$LOGFILE" = "$BDUMP" ] ; then
       echo "Finding the SubDirectory cdmp* on $LOGFILE to remove..."
       find $LOGFILE -name "cdmp_*" -mtime +$DELETE_DIR_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;
     fi
;;
'*.trc.gz')
     echo "Finding the traces files ${LOGFILE} to remove..."
     find "${LOGFILE}" -name "${1}" -mtime +$DELETE_TRACE_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;

     if [ "$LOGFILE" = "$BDUMP" ] ; then
         echo "Finding the SubDirectory cdmp* on $LOGFILE to remove..."
         find "${LOGFILE}" -name "cdmp_*" -mtime +$DELETE_DIR_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;
     fi


     if [ "$LOGFILE" = "$CDUMP" ] ; then
         echo "Finding the SubDirectory core* on $LOGFILE to remove..."
         find "${LOGFILE}" -name "core_*" -mtime +$DELETE_DIR_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;
     fi
;;
'*.trm.gz')
     echo "Finding the traces files ${LOGFILE} to remove..."
     find "${LOGFILE}" -name "${1}" -mtime +$DELETE_TRACE_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;

     if [ "$LOGFILE" = "$BDUMP" ] ; then
         echo "Finding the SubDirectory cdmp* on $LOGFILE to remove..."
         find "${LOGFILE}" -name "cdmp_*" -mtime +$DELETE_DIR_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;
     fi


     if [ "$LOGFILE" = "$CDUMP" ] ; then
         echo "Finding the SubDirectory core* on $LOGFILE to remove..."
         find "${LOGFILE}" -name "core_*" -mtime +$DELETE_DIR_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;
     fi
;;
'*.aud.gz')
     echo "Finding the audit files ${LOGFILE} to remove..."
     find ${LOGFILE} -name "${1}" -mtime +$DELETE_AUDIT_AFTER_DAYS -exec $DELETE_COMMAND -rf {} \;

;;
*)
  echo $"Usage: {*.trc.gz|*.aud.gz|*.trw.gz|*.log.gz}"
esac
}

## FUNCAO VERIFICA SE O ARQUIVO EM USO ANTES DE ZIPAR
check_use_gzip ()
{
#for filename in `find $LOGFILE -type f -name "$1" -mtime +$COMPRESS_AFTER_DAYS`; do
for filename in `find $LOGFILE -type f -name "$1"`; do

        fuser $filename
        if [ $? -ne 0 ] ; then
                echo "Compressing file $filename ..."
                ${COMPRESS_COMMAND} -f $filename
        else
                false
        fi
done
}

## FUNCAO COMPACTAR ARQUIVOS
rot_zipa() {
case ${1} in
'*.log')
for LOGFILE in $BDUMP ; do
        if [ ${COMPRESS_AFTER_DAYS} -gt 0 ]; then
           check_use_gzip \*.log
        fi
        rot_del \*.log.gz
done
        ;;
'*.aud')
for LOGFILE in $ADUMP_R $ADUMP ; do
        if [ ${COMPRESS_AFTER_DAYS} -gt 0 ]; then
           check_use_gzip \*.aud
        fi
        rot_del \*.aud.gz
done
        ;;
'*.trc')
for LOGFILE in $BDUMP $CDUMP $UDUMP ; do
        if [ ${COMPRESS_AFTER_DAYS} -gt 0 ]; then
           check_use_gzip \*.trc
        fi
        rot_del \*.trc.gz

done
        ;;
'*.trm')
for LOGFILE in $BDUMP $CDUMP $UDUMP ; do
        if [ ${COMPRESS_AFTER_DAYS} -gt 0 ]; then
           check_use_gzip \*.trm
        fi
        rot_del \*.trm.gz

done
        ;;




*)
        echo $"Usage: $0 {*.trc|*.aud|*.trw|*.log}"
esac

}

## FUNCAO PARA O ROTATE DO ALERT
rot_alert() {
for DB_ORACLE in ${TMP_SID} ; do
       export ORACLE_SID=`echo ${DB_ORACLE}|awk -F":" '{ print $1}'`
       export ORACLE_HOME=`echo ${DB_ORACLE}|awk -F":" '{ print $2}'`
       export PROCESS_EXISTS=`ps -ef|grep pmon_${ORACLE_SID}|grep -v grep|wc -l`
       if [ ${PROCESS_EXISTS} -eq 0 ]; then
          echo "Does not exist instance ${ORACLE_SID} up"
          exit 1
       else
            export ORACLE_HOME
        export ORACLE_SID
        export PATH=$ORACLE_HOME/bin:$PATH
        get_info_bd
        cd ${BDUMP}
        echo "Copying alert_${ORACLE_SID}.log."
        cat alert_${ORACLE_SID}.log >> alert_${ORACLE_SID}_$DATA.log
        echo "Compressing alert_${ORACLE_SID}_$DATA.log ..."
        ${COMPRESS_COMMAND} alert_${ORACLE_SID}_$DATA.log
        chmod 644 alert_${ORACLE_SID}_$DATA.log.gz
        > alert_${ORACLE_SID}.log
        LOGFILE=${BDUMP}
       fi

done
}



## FUNCAO PARA O ROTATE DO LISTENER
rot_listener() {

for LSNRCTL_ALL in `ps -ef | grep -v -i SCAN | egrep -v "egrep|sed"|egrep tns|grep -v netns|awk '{print $8 ":" $9}'|sed 's/\/bin\/tnslsnr//g'`; do


export LISTENER_HOME=`echo ${LSNRCTL_ALL}|awk -F":" '{ print $1}'`
export ORACLE_HOME=$LISTENER_HOME
export PATH=$ORACLE_HOME/bin:$PATH
export LISTENER_NAME=`echo ${LSNRCTL_ALL}|awk -F":" '{ print $2}'|tr '[A-Z]' '[a-z]'`
export LSNRCTL_STATUS_LOGFILE=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME} | grep "Listener Log File" | awk '{print $4}'`
export LSNRCTL_STATUS_VERSION=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME} | grep "LSNRCTL for" | awk '{print $5}'|sed 's/\.[0-9]\.[0-9].[0-9]\.[0-9]//g'`

if [ $LSNRCTL_STATUS_VERSION -gt 10 ]; then
export LSNRCTL_DIR_11G_LOG=`echo ${LSNRCTL_STATUS_LOGFILE}| sed 's/\/alert\/log.xml/\/trace/g'`
export LSNRCTL_11G_LOG_NAME=`echo ${LSNRCTL_DIR_11G_LOG}/${LISTENER_NAME}.log`

  if [ -f ${LSNRCTL_11G_LOG_NAME} ] ; then
                cd ${LSNRCTL_DIR_11G_LOG}
                echo "Copying listener logfile..."
                cat ${LISTENER_NAME}.log >> ${LISTENER_NAME}_$DATA.log
                echo "Compressing LISTENER_NAME_$DATA.log ..."
                ${COMPRESS_COMMAND} ${LISTENER_NAME}_$DATA.log
                chmod 644 ${LISTENER_NAME}_$DATA.log.gz
                > ${LISTENER_NAME}.log
                rot_del \*.log.gz
  fi


else
export AUX_VAR=`${LISTENER_HOME}/bin/lsnrctl << EOF
   set current_listener ${LISTENER_NAME}
   show log_file
EOF`
export LISTENER_LOGFILE=`echo $AUX_VAR | awk -F \"log_file\" '{print $2}' | awk '{print $3}' |awk -F/ '{print $NF}'`
export LISTENERFILE=`echo ${LISTENER_LOGFILE}|sed 's/\.log//g'`
  if [ -f ${LSNRCTL_STATUS_LOGFILE} ] ; then
       cat ${LSNRCTL_STATUS_LOGFILE} > ${LSNRCTL_STATUS_LOGFILE}_${DATA}.log
       > ${LSNRCTL_STATUS_LOGFILE}
  fi

fi

done

}

## FUNCAO PARA O ROTATE DOS TRACES
rot_traces() {
for DB_ORACLE in ${TMP_SID} ; do
       ORACLE_SID=`echo ${DB_ORACLE}|awk -F":" '{ print $1}'`
       ORACLE_HOME=`echo ${DB_ORACLE}|awk -F":" '{ print $2}'`
       PROCESS_EXISTS=`ps -ef|grep pmon_${ORACLE_SID}|grep -v grep|wc -l`

       if [ ${PROCESS_EXISTS} -eq 0 ]; then
           echo "Does not exists instance ${ORACLE_SID} up"
           exit 1
       else
        export ORACLE_HOME
        export ORACLE_SID
        export PATH=$ORACLE_HOME/bin:$PATH
        get_info_bd
        rot_zipa \*.trc
        rot_zipa \*.trm
        rot_zipa \*.aud
       fi
done
}

## FUNCAO PARA PEGAR INFORMACOES NO BANCO
get_info_bd() {

CONNECT_BD="/ as sysdba"

GT11G=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
SELECT substr(version,1,instr(version,'.')-1) FROM v\\$instance;
exit;
EOF
`
if [ $GT11G == 11 ];
then
echo "ADRCI will be used"
BDUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$diag_info where name = 'Diag Trace';
exit;
EOF
`
CDUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$diag_info where name = 'Diag Cdump';
exit;
EOF
`
UDUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$diag_info where name = 'Diag Incident';
exit;
EOF
`
ADUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$parameter where name='audit_file_dest';
exit;
EOF
`
else
echo "Legacy database rotate will be used"
BDUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$parameter where name='background_dump_dest';
exit;
EOF
`
CDUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$parameter where name='core_dump_dest';
exit;
EOF
`
UDUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$parameter where name='user_dump_dest';
exit;
EOF
`
ADUMP=`${ORACLE_HOME}/bin/sqlplus -s /nolog <<EOF
connect / as sysdba ;
set head off;
set feedback off;
set verify off;
select value from v\\$parameter where name='audit_file_dest';
exit;
EOF
`
fi

}

## FUNCAO PARA TRATAR OS TRACES e ALERT.LOG GERADO PELO BANCO
rot_full() {

for DB_ORACLE in ${TMP_SID} ; do
       ORACLE_SID=`echo ${DB_ORACLE}|awk -F":" '{ print $1}'`
       ORACLE_HOME=`echo ${DB_ORACLE}|awk -F":" '{ print $2}'`

       echo "Current Instance: $ORACLE_SID"
       PROCESS_EXISTS=`ps -ef|grep pmon_$ORACLE_SID|grep -v grep|wc -l`

       if [ ${PROCESS_EXISTS} -eq 0 ]; then
            echo "Does not exists process instance ${ORACLE_SID} up"
            exit 1
       else
          export ORACLE_HOME
          export ORACLE_SID
          export PATH=$ORACLE_HOME/bin:$PATH
          get_info_bd
                  adrci exec="purge -age 7"
          rot_zipa \*.trc
          rot_zipa \*.trm
          rot_zipa \*.aud
          cd ${BDUMP}
          echo "Copying alert_${ORACLE_SID}.log..."
          cat alert_${ORACLE_SID}.log >> alert_${ORACLE_SID}_$DATA.log
          echo "Compressing alert_${ORACLE_SID}_$DATA.log ..."
          ${COMPRESS_COMMAND} alert_${ORACLE_SID}_$DATA.log
          chmod 644 alert_${ORACLE_SID}_$DATA.log.gz
          > alert_${ORACLE_SID}.log
          LOGFILE=${BDUMP}
       fi

done

}


# Show options if user dont choose a valid one

OPCAO_USED=$1
echo ${OPTION_USED}
case $1 in

'ALERT')
        rot_alert
        echo `date` "Rotate finalized!"
        ;;
'LISTENER')
        rot_listener
        echo `date` "Rotate finalized!"
        ;;
'TRACES')
        rot_traces
        echo `date` "Rotate finalized!"
        ;;
'FULL')
        rot_full
        rot_listener
        echo `date` "Rotate finalized!"
        ;;
*)
        echo "Rotate_logs versao 2.0"
        echo ""
        echo "Pre-requisitos"
        echo ""
        echo "Editar o /etc/oratab"
                echo "E necessario editar o arquivo /etc/oratab, deixando apenas as entradas referentes as instancias ativas."
        echo ""
        echo "E possivel alterar os valores retenÃ§adrÃ£valide o arquivo rotate.conf"
        echo ""
        echo $"Usage: $0 {ALERT|LISTENER|TRACES|FULL}"
        echo ""
        echo "Rodando com a clausula FULL"
        echo ""
        rot_full
        rot_listener
        echo `date` "Rotate finalized!"
        ;;
esac

