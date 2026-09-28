--drop table TBL_WONKA_AUDIT_SERVERERROR;

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
	CURRENT_SQL            VARCHAR2(4000)
	);


CREATE OR REPLACE TRIGGER SYS.TRG_WONKA_AUDIT_SERVERERROR
AFTER SERVERERROR ON DATABASE
BEGIN
    IF SYS_CONTEXT('USERENV', 'DATABASE_ROLE') = 'PRIMARY' 
	THEN
		IF (not IS_SERVERERROR(25228)) 
		THEN
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
				CURRENT_SQL
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
				SUBSTR(SYS_CONTEXT('USERENV', 'CURRENT_SQL'), 1, 4000)
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
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi:ss') ACTION_TIME, 
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -10
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi:ss'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_SS FOR tvtspi.WONKA_ERROR_DB_SS
/
create or replace  view tvtspi.WONKA_ERROR_DB_MI AS
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi') ACTION_TIME, 
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -10
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd HH24:mi'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_MI FOR tvtspi.WONKA_ERROR_DB_MI
/

create or replace  view tvtspi.WONKA_ERROR_DB_HH AS
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd HH24') ACTION_TIME, 
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -10
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd HH24'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_HH FOR tvtspi.WONKA_ERROR_DB_HH
/

create or replace  view tvtspi.WONKA_ERROR_DB_DD AS
select count(1) total , to_char(ACTION_TIME,'yyyy-mm-dd') ACTION_TIME, 
substr(SYS.wonka_get_ora_error_message(replace(ERROR,'ORA-')),1,60) ERROR,
 replace(substr(replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp'),1 ,20),'\') server,IP_ADDRESS, substr(PROGRAM,1,10) PROGRAM, 
substr(OS_USER,1, 16) OS_USER, substr(DB_USER,1,16) DB_USER,  
substr(ACTION,1,10) ACTION
from SYS.TBL_WONKA_AUDIT_SERVERERROR
where DB_USER = DB_USER --'FPS_BO'
and trunc(ACTION_TIME) > sysdate -10
--AND substr(PROGRAM,1,10) = 'PK_AT_EVEN'
group by substr(ACTION,1,10), CLIENT_IDENTIFIER,ERROR,replace(replace(TERMINAL,'EMISSAO'),'.emissao.corp') , substr(PROGRAM,1,10), IP_ADDRESS, OS_USER,   to_char(ACTION_TIME,'yyyy-mm-dd'), DB_USER
order by 2 asc
/
--'
create or replace  PUBLIC SYNONYM WONKA_ERROR_DB_DD FOR tvtspi.WONKA_ERROR_DB_DD
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
