SET TERMOUT OFF;
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
exec dbms_application_info.set_module( module_name => 'KILL ALL SQLID . . . [DBA', action_name =>  'KILL ALL SQLID . . . [DBA]');
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/sess_kill_ACT_sqlid_instance_no_stop.sql  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : KILL SQLID INSTANCE  [STOP = CTRL +C]                 +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+

PROMPT . . .
PROMPT . .   
PROMPT . 
ACCEPT sssql_id char   PROMPT 'SQL ID FULL KILL IN LOOP = '
PROMPT . . .
PROMPT . . 
PROMPT . 
set timing on
set echo off
SET VERIFY OFF;
SET SERVEROUTPUT ON SIZE UNLIMITED;
declare
    cursor sid is
      select b.sid sid, b.serial# serial, '@'||B.inst_id inst_id,
      'alter system kill session ''' || b.sid || ',' ||b.serial# || ',@' ||b.inst_id||''' immediate ' comando
        from gv$session b
       where b.sql_id = '&sssql_id'
	   and b.status = 'ACTIVE'
	   and b.inst_id  in (select INSTANCE_NUMBER from v$instance)
       order by b.sid desc;
       v varchar2(600);
       v_tot INTEGER;
	   v_MAX INTEGER :=0;
begin
loop
    v_MAX := v_MAX +1;
	IF v_MAX > 200 THEN EXIT; END IF;
    DBMS_LOCK.sleep(1);
    v_tot :=0;
    for a in sid
    loop begin execute immediate a.comando; v_tot := v_tot +1;
         exception
          when others then dbms_output.put_line('Error Kill: sid: '||lpad(a.sid,4,'0')||' serial#: '||lpad(a.serial,6,'0'));
         end;
    end loop;
    dbms_output.put_line(' ');
    dbms_output.put_line('----------------------------------------------------------------');
    dbms_output.put_line(' T O T A L   K I L L : '||LPAD(v_tot,8,'0'));
    dbms_output.put_line('----------------------------------------------------------------');
end loop;	
end;
/
set echo off
UNDEF sssql_id
UNDEF iinst_id