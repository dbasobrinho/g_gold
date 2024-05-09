-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Vizualizar historico de execucao de backups                                  |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 09/05/2024                                                                   | 
-- | Exemplo    : @rman_hist_f_date_type.sql                                                   | 
-- | Arquivo    : rman_hist_f_date_type.sql                                                    |
-- | Referncia  :                                                                              |
-- | Modificacao:                                                                              |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"Em troca de dinheiro e um cargo bom. Tem mano que rebola e usa até batom"
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's[rman_hist_f_date_type.sql]', action_name =>  's[rman_hist_f_date_type.sql]');
COL current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/rman_hist_f_date_type.sql                 |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Historico Backup                                      +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET FEED        OFF
SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       188
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES
SET COLSEP '|'

prompt +-------------------------------------------------------------------------------------------+
prompt BACKUP_TYPE:  DB FULL, DB INCR, CONTROLFILE, ARCHIVELOG
prompt +-------------------------------------------------------------------------------------------+
ACCEPT BBTYPE CHAR PROMPT 'BACKUP_TYPE (ALL) = ' DEFAULT ALL
ACCEPT DDDXXX CHAR PROMPT 'DAYS        (30 ) = ' DEFAULT 30
prompt +-------------------------------------------------------------------------------------------+
prompt ...

COL SESSION_STAMP      heading "SESSION|STAMP"    FOR 9999999999 JUSTIFY CENTER
COL session_recid      heading "SESSION|RECID"    FOR 9999999 JUSTIFY CENTER
COL start_time         heading 'STARTED|TIME'     FOR a20 JUSTIFY CENTER
COL end_time           heading 'FINISHED|TIME'    FOR a20 JUSTIFY CENTER
COL gbytes_processed   heading "PROCESSED|(GB)"   FOR 9,999,999,999 JUSTIFY CENTER
COL status             heading 'STATUS|'          FOR a25  JUSTIFY CENTER
COL backup_type        heading 'BACKUP|TYPE'      FOR a20 JUSTIFY CENTER
COL time_total         heading "TIME|TAKEN"       FOR a15 JUSTIFY CENTER
COL output_device_type heading "DEVICE|TYPE"      FOR a15 JUSTIFY CENTER


select   
  /*+ PARALLEL,10 */
  st.session_stamp,
  st.session_recid, 
  to_char(st.start_time, 'Dy dd/mm/yyyy hh24:mi') start_time,   to_char(st.end_time, 'Dy dd/mm/yyyy hh24:mi') end_time,
  round(st.mbytes_processed/1024,2) gbytes_processed,   lower(st.status) as status, 
  lower(case 
    when st.object_type = 'DB INCR' and i1=0 then 'Incr Lvl 0 (FULL)'
    when st.object_type = 'DB INCR' and i1>0 then 'Incr Lvl 1'
    when st.object_type = 'DB INCR' and i0 is NULL and i1 is NULL then st.object_type
  else 
    st.object_type end) as backup_type,   
  TO_CHAR( TRUNC( ((st.end_time-st.start_time)* 24 * 60 * 60) / 60 / 60 ), '999' ) ||':'|| trim(TO_CHAR( TRUNC( MOD( ((st.end_time-st.start_time)* 24 * 60 * 60), 3600 ) / 60 ), '09' )) ||':'|| trim(TO_CHAR( MOD( MOD( ((st.end_time-st.start_time)* 24 * 60 * 60), 3600 ), 60 ), '09' )) as time_total,
   dt.output_device_type
from v$rman_backup_job_details dt,
	 v$rman_status st 
left join (select   /*+ PARALLEL,10 */
                   d.session_recid, d.session_stamp,
                   sum(case when d.backup_type||d.incremental_level = 'D'  then d.pieces else 0 end) DF,
                   sum(case when d.backup_type||d.incremental_level = 'D0' then d.pieces else 0 end) I0,
                   sum(case when d.backup_type||d.incremental_level = 'I1' then d.pieces else 0 end) I1
             from V$BACKUP_SET_DETAILS d join V$BACKUP_SET s on (s.set_stamp = d.set_stamp and s.set_count = d.set_count)
            where s.input_file_scan_only = 'NO'
            group by d.session_recid, d.session_stamp) x
    on x.session_recid = st.session_recid and x.session_stamp = st.session_stamp 
Where st.start_time > (sysdate - trim(&&DDDXXX))
  and st.object_type is not null 
  and st.object_type =  DECODE(trim('&&BBTYPE'),'ALL',st.object_type ,trim('&&BBTYPE'))
  and st.session_recid = dt.session_recid
order by st.start_time
/

prompt
UNDEF BBTYPE
UNDEF DDDXXX