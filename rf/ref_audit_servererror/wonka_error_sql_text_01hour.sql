--@/tmp/.g/wonka_error_sql_text.sql 
col total        format 99999
col server       format a20
col PROGRAM      format a10
col IP_ADDRESS   format a15
col OS_USER      format a16
col ACTION       format a10
col IS_LIMITED   format a10
col db_USER      format a16
col ERROR        format a40
col ACTION_TIME  format a21
col SQL_ID       format a13
col SQL_TEXT     format a70 word_wrapped
SET LINES       288
SET PAGES       800
select * from WONKA_ERROR_DB_SQL_TEXT
where ACTION_TIME > sysdate-1
/