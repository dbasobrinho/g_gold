begin
 DBMS_LOCK.SLEEP(300); 
update hr.employees 
set employee_id = 100 
where employee_id = 101;
commit;
end;
/