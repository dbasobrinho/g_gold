--@/tmp/.g/wonka_error_mi.sql 
col total        format 99999
col ERROR        format a60
col server       format a20
col PROGRAM      format a10
col IP_ADDRESS   format a15
col OS_USER      format a16
col db_USER      format a16
col ACTION       format a10
col IS_LIMITED   format a10
col ACTION_TIME  format a21
SET LINES       288
SET PAGES       800
select * from WONKA_ERROR_DB_mi
/