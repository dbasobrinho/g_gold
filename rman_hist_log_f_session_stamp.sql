-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Vizualizar log de execucao de um backup espcifico                            |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 09/05/2024                                                                   |
-- | Exemplo    : @rman_hist_log_f_session_stamp                                               | 
-- | Arquivo    : rman_hist_log_f_session_stamp.sql                                            |
-- | Referncia  : Christopher Santos Cavalcante, ele que me ensinou essa! Valeu!!!!!!          |
-- | Modificacao:                                                                              |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"Quando a caminhada fica dura, só os duros continuam caminhando."
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's[rman_hist_log_f_session_stamp.sql]', action_name =>  's[rman_hist_log_f_session_stamp.sql]');
COL current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
exec dbms_metadata.set_transform_param(dbms_metadata.session_transform,'SQLTERMINATOR',true);
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/rman_hist_log_f_session_stamp.sql         |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Log Backup                                            +-+-+-+-+-+-+-+-+-+-+-+  |
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
prompt SESSION_STAMP:  @rman_hist_f_date_type.sql
prompt +-------------------------------------------------------------------------------------------+
ACCEPT VVPAR01 CHAR PROMPT 'SESSION_STAMP = ' DEFAULT ALL
prompt +-------------------------------------------------------------------------------------------+
prompt ...
COLUMN OUTPUT FORMAT a9999;
SELECT OUTPUT FROM V$RMAN_OUTPUT WHERE SESSION_STAMP = TRIM(&&VVPAR01);
/
prompt
UNDEF VVPAR01
