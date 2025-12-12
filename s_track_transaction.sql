-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Traking Transacrion Det                                                      | 
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 12/12/2025                                                                   |
-- | Exemplo    : @s_track_transaction.sql                                                     |  
-- | Arquivo    : s_track_transaction                                                          | 
-- | Referncia  :                                                                              |
-- | Modificacao: 2.1 - 03/08/2019 - rfsobrinho - Vizulizar MODULE no USERNAME                 |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
--> while true; do 
-->   echo ===================================================
-->   date '+%Y-%m-%d %H:%M:%S'
-->   echo "@s.sql" | sqlplus -s / as sysdba | tail -n +12 | egrep -i 'f2xb0s01bh9cy|SESSIONWAIT'
-->   sleep 10
-->   echo . . . 
--> done
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's_track.sql', action_name =>  's_track.sql');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/s_track_transaction.sql                   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : TRAKING TRANSACTION                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
sET ECHO        OFF
SET FEEDBACK    on
SET HEADING     ON 
SET LINES       600
SET PAGES       600
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
CLEAR COLUMNS
CLEAR BREAKS 
CLEAR COMPUTES
col sum_used_ublk format 99999999999 head 'USED UNDO|BLOKS'    JUSTIFY CENTER
col total         format 99999999999 head 'TOTAL|-'            JUSTIFY CENTER
col operation     format a09         head 'OPERATION|-'        JUSTIFY CENTER  
col TBLE          format a40         head 'OWNER.TABLE|-'      JUSTIFY CENTER 
col START_SCN     format a13         head 'START_SCN|-'        JUSTIFY CENTER 
col COMMIT_SCN    format a13         head 'COMMIT_SCN|-'       JUSTIFY CENTER 
col logon_user    format a12         head 'USERNAME|-'         JUSTIFY CENTER
col ROW_ID           format a19      head 'ROWID|-'            JUSTIFY CENTER
col UNDO_SEQ         format 9999999  head 'ROLLBACK|SEQ'       JUSTIFY CENTER
col START_TIMESTAMP  format a20      head 'START|TIMESTAMP'       JUSTIFY CENTER
col undo_sql      FORMAT a150 word_wrapped  head 'UNDO|SQL'       JUSTIFY CENTER
col xid           format a16         head 'XID|TRANSACTION'    JUSTIFY CENTER
col status_s      format a08         head 'STATUS|SESSION'     JUSTIFY CENTER
col username      format a12         head 'USERNAME|-'         JUSTIFY CENTER
col used_ublk     format 99999999999 head 'USED UNDO|BLOKS'    JUSTIFY CENTER
col used_urec     format 99999999999 head 'USED UNDO|ROWS'     JUSTIFY CENTER
col roll_in_exec  format a09         head 'ROLLBACK|EXECUTION' JUSTIFY CENTER
col rssize        format a11         head 'SIZE|TRANSACTION'   JUSTIFY CENTER
col status_r      format a08         head 'STATUS|ROLLBACK'    JUSTIFY CENTER
col START_DATE    format a20         head 'START|DATE'         JUSTIFY CENTER
col inst_id       format a07         head 'INST_ID|-'          JUSTIFY CENTER
SET COLSEP '|'
SELECT SUBSTR(logon_user, 1,12) logon_user, operation, TO_CHAR(start_scn) AS start_scn ,  TO_CHAR(commit_scn) commit_scn,--undo_sql, 
SUBSTR(TABLE_OWNER||'.'||TABLE_NAME,1,40) as TBLE, ROW_ID, UNDO_CHANGE# UNDO_SEQ, START_TIMESTAMP
FROM   flashback_transaction_query
WHERE  xid = HEXTORAW('&XID')
ORDER BY UNDO_SEQ DESC
/
UNDEF XID

