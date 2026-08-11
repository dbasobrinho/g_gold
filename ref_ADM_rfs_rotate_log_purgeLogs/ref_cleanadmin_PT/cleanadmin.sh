#!/bin/bash
#

. /oracle/JITOPRD/.bash_profile

AUDIT=`sqlplus -S "/ as sysdba" <<EOF
set heading off
set feedback off
select VALUE from V\\$PARAMETER where name='audit_file_dest';
exit
EOF
  `
if [ -w ${AUDIT} ]; then
  find ${AUDIT} -name \*.aud -mtime +2 -exec rm {} \;
fi


CORE=`sqlplus -S "/ as sysdba" <<EOF
set heading off
set feedback off
select VALUE from V\\$PARAMETER where name='core_dump_dest';
exit
EOF
  `
if [ -w ${CORE} ]; then
  find ${CORE} -type d -name core\* -exec rm -r {} \;
fi


BACKGROUND=`sqlplus -S "/ as sysdba" <<EOF
set heading off
set feedback off
select VALUE from V\\$PARAMETER where name='background_dump_dest';
exit
EOF
  `
if [ -w ${BACKGROUND} ]; then
  for basedir in `adrci exec="show home"`; do
    if [ ${basedir} != "ADR" -a ${basedir} != "Homes:" ]; then
      cd ${BACKGROUND}
      find ${BACKGROUND} -name \*.trc -mtime +2 -exec rm {} \;
      adrci exec="set home ${basedir};purge -age 4320;purge -age 4320 -type alert;purge -age 4320 -type incident;"
    fi
  done
fi


##cd /oracle/JITOPRD/diag/tnslsnr/COLPCPDWDP01/listener_jitcp/trace
##echo "`tail -160000 listener_jitcp.log`" > listener_jitcp.log

cd /oracle/JITOPRD/diag/tnslsnr/COLPCPDWDP02/listener_jitcp/trace
echo "`tail -160000 listener_jitcp.log`" > listener_jitcp.log


