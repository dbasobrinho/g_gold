--drop table TBL_WONKA_AUDIT_SERVERERROR; 
GRANT SELECT ANY DICTIONARY TO TVTZBX2;
GRANT SELECT_CATALOG_ROLE TO TVTZBX2;

BEGIN EXECUTE IMMEDIATE 'drop table TBL_WONKA_AUDIT_SERVERERROR';
EXCEPTION when others then null;
END;
/

	CREATE TABLE TBL_WONKA_AUDIT_SERVERERROR (
	ACTION_TIME         TIMESTAMP,
	ERROR               VARCHAR2(700),
	DB_USER         VARCHAR2(700),
	OS_USER             VARCHAR2(700),
	RAC_INSTANCE        VARCHAR2(700),   
	SERVICE_NAME        VARCHAR2(700), 
	SESSION_ID          VARCHAR2(700),
	TERMINAL            VARCHAR2(700),
	PROGRAM             VARCHAR2(700),
	ACTION              VARCHAR2(700),
	IP_ADDRESS          VARCHAR2(700),
	CLIENT_IDENTIFIER   VARCHAR2(700),      
	CURRENT_SCHEMA      VARCHAR2  (300),
	AUTHENTICATION_METHOD  VARCHAR2(300),
	DB_NAME                VARCHAR2(300),
	SQL_TEXT       CLOB,   
	SQL_ID         VARCHAR2(20)
	);

CREATE INDEX IDX_WONKA_AUDIT_ACTION_TIME ON TBL_WONKA_AUDIT_SERVERERROR (ACTION_TIME);
CREATE INDEX IDX_WONKA_AUDIT_ERROR       ON TBL_WONKA_AUDIT_SERVERERROR (ERROR);


BEGIN EXECUTE IMMEDIATE 'BEGIN DBMS_SCHEDULER.drop_job(job_name => ''JOB_CLEANUP_WONKA_AUDIT''); EXCEPTION when others then null; END;';
END;
/


BEGIN
    DBMS_SCHEDULER.create_job (
        job_name        => 'JOB_CLEANUP_WONKA_AUDIT',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN DELETE FROM TBL_WONKA_AUDIT_SERVERERROR WHERE ACTION_TIME < SYSDATE - 360; COMMIT; END;',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=WEEKLY; BYDAY=WED; BYHOUR=6; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE
    );
END;
/

CREATE OR REPLACE TRIGGER SYS.TRG_WONKA_AUDIT_SERVERERROR
AFTER SERVERERROR ON DATABASE
DECLARE
    v_sql_text     clob;
	v_sql_id       varchar2(15);
	v_open_mode   VARCHAR2(20);
BEGIN
    IF SYS_CONTEXT('USERENV', 'DATABASE_ROLE') = 'PRIMARY' 
	THEN
		IF (not IS_SERVERERROR(25228)) 
		THEN
		SELECT OPEN_MODE INTO v_open_mode FROM V$DATABASE;
		IF v_open_mode = 'READ WRITE' THEN return; END IF;
        --/
            begin
                declare
                  v_sql_out      ora_name_list_t;
                  v_num          number;
                begin
                  v_num := ora_sql_txt(v_sql_out);
                  for i in 1 .. v_num loop
                        v_sql_text := v_sql_text || v_sql_out(i);
                  end loop;
                end;
		    	--/
		        select max(a.sql_id) 
		    	  into v_sql_id
                  from v$session a
                 where a.sid||a.audsid = sys_context ('userenv', 'sid')||sys_context ('userenv', 'sessionid') 
		    	   and a.sql_id is not null;
            exception
            when invalid_number then
                null;
            when others then
                null;
            end;
		    --/
			INSERT INTO TBL_WONKA_AUDIT_SERVERERROR (
				ACTION_TIME,
				ERROR,
				db_USER,
				OS_USER,
				RAC_INSTANCE,
				SERVICE_NAME,
				SESSION_ID,
				TERMINAL,
				PROGRAM,
				ACTION,
				IP_ADDRESS,
				CLIENT_IDENTIFIER,
				CURRENT_SCHEMA,
				AUTHENTICATION_METHOD,
				DB_NAME,
				SQL_TEXT, SQL_ID
			) VALUES (
				SYSTIMESTAMP,
				'ORA-'||lpad(sys.server_error(1),5,'0'),
				SYS_CONTEXT('USERENV', 'AUTHENTICATED_IDENTITY'),
				SUBSTR(UPPER(SYS_CONTEXT('USERENV', 'OS_USER')), 1, 300),
				SUBSTR(SYS_CONTEXT('USERENV', 'INSTANCE'), 1, 300), 
				SUBSTR(NVL(UPPER(SYS_CONTEXT('USERENV', 'SERVICE_NAME')), 'Service Unknown'), 1, 300),
				SYS_CONTEXT('USERENV', 'SID'),
				SUBSTR(NVL(SYS_CONTEXT('USERENV', 'HOST'), 'Unknown Host'), 1, 300),  
				SUBSTR(NVL(SYS_CONTEXT('USERENV', 'MODULE'), 'Module unknown'), 1, 300),
				SUBSTR(SYS_CONTEXT('USERENV', 'ACTION'), 1, 300),
				SUBSTR(NVL(SYS_CONTEXT('USERENV', 'IP_ADDRESS'), 'Unknown IP'), 1, 300),
				SUBSTR(SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER'), 1, 300),
				SUBSTR(SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA'), 1, 300),
				SUBSTR(SYS_CONTEXT('USERENV', 'AUTHENTICATION_METHOD'), 1, 300),
				SUBSTR(SYS_CONTEXT('USERENV', 'DB_NAME'), 1, 300),
				v_sql_text,decode(v_sql_id,'2nqv7t5mw8203',null,v_sql_id)
			);
		END IF;
	END IF;
exception when others then
    dbms_system.ksdwrt (2, 'ORA-00902 ERRO NA TRIGGER WONKA [SYS.TRG_WONKA_AUDIT_SERVERERROR] - Backtrace: '||dbms_utility.format_error_backtrace||' SQLERRM: '||substr(sqlerrm,1,300));
END;
/


create or replace  FUNCTION wonka_get_ora_error_message (p_error_code IN NUMBER)
   RETURN VARCHAR2
IS
   v_err_msg VARCHAR2(4000);
BEGIN
   v_err_msg := SQLERRM(-p_error_code);
   RETURN v_err_msg;
EXCEPTION
   WHEN OTHERS THEN
      RETURN 'Código de erro inválido';
END;
/

GRANT ALL ON SYS.TBL_WONKA_AUDIT_SERVERERROR TO TVTSPI;
GRANT EXECUTE ON SYS.wonka_get_ora_error_message TO TVTSPI;



create or replace  view tvtspi.WONKA_ERROR_DB_SS AS
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi:ss') ACTION_TIME,SQL_ID,
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -20
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by SQL_ID, substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi:ss'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_SS FOR tvtspi.WONKA_ERROR_DB_SS
/
create or replace  view tvtspi.WONKA_ERROR_DB_MI AS
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi') ACTION_TIME,SQL_ID,
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -20
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by SQL_ID,substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_MI FOR tvtspi.WONKA_ERROR_DB_MI
/

create or replace  view tvtspi.WONKA_ERROR_DB_HH AS
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd HH24') ACTION_TIME, SQL_ID,
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -20
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by SQL_ID,substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd HH24'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_HH FOR tvtspi.WONKA_ERROR_DB_HH
/

create or replace  view tvtspi.WONKA_ERROR_DB_DD AS
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd') ACTION_TIME, SQL_ID,
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -20
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by SQL_ID, substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_DD FOR tvtspi.WONKA_ERROR_DB_DD
/


create or replace  view tvtspi.WONKA_ERROR_DB_SQL_TEXT AS
select  to_char(ACTION_TIME,'yyyy-mm-dd hh24:mi:ss') ACTION_TIME, DB_USER,
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,40) ERROR,
SQL_ID, DBMS_LOB.SUBSTR(SQL_TEXT, 4000, 1)  SQL_TEXT
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -20
and DBMS_LOB.SUBSTR(SQL_TEXT, 4000, 1)  is not null
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
order by 1 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_SQL_TEXT FOR tvtspi.WONKA_ERROR_DB_SQL_TEXT
/



create or replace view tvtspi.WONKA_ERROR AS
SELECT 'SELECT * FROM '|| OBJECT_NAME||';' AS command,  '@/tmp/.g/wonka_error_'||lower(SUBSTR(OBJECT_NAME, -2))||'.sql' as script
FROM DBA_OBJECTS WHERE OBJECT_NAME LIKE 'WONKA_ERROR_DB%' AND OBJECT_TYPE = 'VIEW' ORDER BY 1
/

create or replace  PUBLIC SYNONYM WONKA_ERROR FOR tvtspi.WONKA_ERROR
/


--@/tmp/.g/wonka_error_ss.sql
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
select * from WONKA_ERROR_DB_SS
/


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

--@/tmp/.g/wonka_error_hh.sql
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
select * from WONKA_ERROR_DB_hh
/


--@/tmp/.g/wonka_error_dd.sql
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
select * from WONKA_ERROR_DB_DD
/


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
/