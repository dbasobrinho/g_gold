SET TERMOUT OFF; 
set feed on;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'PLANALL', action_name =>  'PLANALL');
set tab off
set timing ON
set lines 900 pages 600
--ALTER SYSTEM FLUSH SHARED_POOL;
--ALTER SESSION SET CURRENT_SCHEMA = FPSPIN;
ALTER SESSION SET statistics_level = ALL;
alter session set optimizer_adaptive_statistics = false;   
alter session set "_optimizer_use_feedback" = false;

SET echo ON
SET TERMOUT ON;
variable P_CD_ROTINA VARCHAR2(10);
variable B2 NUMBER;
exec  :P_CD_ROTINA := 'Electronics'
exec  :B2 := 1998;
SET echo ON
SET TERMOUT ON;

---------------------------------------------------------------------------------------
---\
-----> CONSULTA 
---/
---------------------------------------------------------------------------------------

SELECT /* QUERY_LAB11 */
       t.calendar_year,
       p.prod_category,
       COUNT(*)         AS rows_,
       SUM(s.amount_sold) AS amt
FROM   sales    s
JOIN   times    t
       ON t.time_id = s.time_id
JOIN   products p
       ON p.prod_id = s.prod_id
      AND s.amount_sold BETWEEN p.prod_min_price AND p.prod_list_price
WHERE  t.calendar_year = :B2
  AND  p.prod_category = :P_CD_ROTINA
GROUP  BY t.calendar_year, p.prod_category;
/

SELECT * FROM TABLE (dbms_xplan.display_cursor (NULL,NULL,'ADVANCED ALLSTATS LAST'));

