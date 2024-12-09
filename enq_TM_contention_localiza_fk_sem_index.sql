-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Identificação FK Não Indexadas geram TM Contention                           |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 29/11/2024                                                                   |
-- | Exemplo    : @enq_TM_contention_localiza_fk_sem_index.sql                                 |  
-- | Arquivo    : enq_TM_contention_localiza_fk_sem_index.sql                                  |
-- | Referncia  :                                                                              |
-- | Modificacao:                                                                              |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br | 
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
--
--grep -c "enq: TM - contention" /u01/app/oracle/TVTDBA/MONI/logs_snapper/*snapper_pback*.log | grep -v ":0$" | sort
--
WHENEVER SQLERROR EXIT SQL.SQLCODE;
WHENEVER OSERROR EXIT;
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'enq[TM_contention]', action_name =>  'enq[TM_contention]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/enq_TM_contention_localiza_fk_sem_index.sql|
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT | Script   : Identificação FK Não Indexadas geram TM Contention    +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|   |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT +--------------------------------------------------------------------------------------------+
PROMPT
SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       188
SET PAGES       300 

PROMPT
ACCEPT vv_table  CHAR PROMPT "ENTRE COM NOME DA TABELA [*] : "  
PROMPT

SET ECHO        OFF
SET FEEDBACK    off
SET HEADING     ON
SET LINES       188
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
set ECHO        ON
SET SERVEROUTPUT ON SIZE UNLIMITED;
SET LONG 1000
SET LONGCHUNKSIZE 1000
SET WRAP OFF
SET FEEDBACK 10


COLUMN OWNER          FORMAT A20
COLUMN TABLE_NAME     FORMAT A30
COLUMN CONSTRAINT_NAME FORMAT A30
COLUMN TYPE           FORMAT A10
COLUMN COLUMN_NAME    FORMAT A30
COLUMN INDEXED        FORMAT A10
COLUMN INDEX_NAME     FORMAT A30

WITH PRIMARY_CONSTRAINT AS ( -- Constraint primaria tabela
    SELECT OWNER, CONSTRAINT_NAME
    FROM   DBA_CONSTRAINTS
    WHERE  CONSTRAINT_TYPE = 'P'
      AND  TABLE_NAME = UPPER('&vv_table')  --'CT_CONTRACT' 
),
CONSTRAINT_INFO AS ( -- Constraints referenciadas
    SELECT a.OWNER,
           a.TABLE_NAME,
           a.CONSTRAINT_NAME,
           DECODE(a.CONSTRAINT_TYPE,
                  'P', 'Primary Key',
                  'C', 'Check',
                  'R', 'Referential',
                  'V', 'View Check',
                  'U', 'Unique',
                  a.CONSTRAINT_TYPE) AS CONSTRAINT_TYPE,
           NVL2(a.r_owner, a.r_owner || '.' || a.r_constraint_name, null) AS R_CONSTRAINT_NAME,
           a.DELETE_RULE,
           a.STATUS
    FROM   dba_constraints a
    WHERE  a.r_constraint_name =  (SELECT CONSTRAINT_NAME FROM PRIMARY_CONSTRAINT) 
	-->>NVL2(a.r_owner, a.r_owner || '.' || a.r_constraint_name, null) LIKE '%' || (SELECT CONSTRAINT_NAME FROM PRIMARY_CONSTRAINT) || '%'
),
CONSTRAINT_COLUMNS AS ( -- Colunas das constraints concatenadas
    SELECT b.OWNER,
           b.TABLE_NAME,
           b.CONSTRAINT_NAME,
           LISTAGG(b.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY b.POSITION) AS COLUMN_LIST
    FROM   dba_cons_columns b
    WHERE  b.owner||'.'||b.CONSTRAINT_NAME IN (SELECT OWNER||'.'||CONSTRAINT_NAME FROM CONSTRAINT_INFO)
	--and b.CONSTRAINT_NAME = 'FK_CT_CONTR_RF_CT_CON_CT_CONTR'
    GROUP BY b.OWNER, b.TABLE_NAME, b.CONSTRAINT_NAME
),
INDEXED_COLUMNS AS ( -- Colunas de indices concatenadas
    SELECT i.TABLE_OWNER AS OWNER,
           i.TABLE_NAME,
           i.INDEX_NAME,
           LISTAGG(ic.COLUMN_NAME, ', ') WITHIN GROUP (ORDER BY ic.COLUMN_POSITION) AS COLUMN_LIST
    FROM   dba_indexes i, dba_ind_columns ic
    WHERE  i.INDEX_NAME = ic.INDEX_NAME
      AND  i.TABLE_OWNER = ic.TABLE_OWNER
      AND  i.TABLE_NAME = ic.TABLE_NAME
    GROUP BY i.TABLE_OWNER, i.TABLE_NAME, i.INDEX_NAME
)
SELECT cc.OWNER, -- Verifica indices correspondentes
       cc.TABLE_NAME,
       cc.CONSTRAINT_NAME,
       'FK' AS TYPE,
       cc.COLUMN_LIST AS COLUMN_NAME,
       CASE WHEN ic.COLUMN_LIST IS NOT NULL THEN 'YES'
            ELSE 'NO'
       END AS INDEXED,
       ic.INDEX_NAME
FROM   CONSTRAINT_COLUMNS cc
LEFT JOIN INDEXED_COLUMNS ic
ON     cc.OWNER = ic.OWNER
   AND cc.TABLE_NAME = ic.TABLE_NAME
   AND cc.COLUMN_LIST = ic.COLUMN_LIST
ORDER BY CASE WHEN ic.COLUMN_LIST IS NOT NULL THEN 1 ELSE 2 END, 
         cc.OWNER, 
         cc.TABLE_NAME, 
         cc.CONSTRAINT_NAME
/
UNDEFINE vv_child_no

 