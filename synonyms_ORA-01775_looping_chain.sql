-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Identificar Sinonimos invalidos erro ORA-01775: looping chain of synonyms    |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 18/06/2024                                                                   |
-- | Exemplo    : @synonyms_ORA-01775_looping_chain.sql <o: synonym_nme>                       |  
-- | Arquivo    : synonyms_ORA-01775_looping_chain.sql                                         |
-- | Referncia  :                                                                              |
-- | Modificacao: 1.0 - 18/06/2024 - rfsobrinho - Versao Inicial                               |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"Estamos trabalhando para resolver seu problema, dentro dos limites da física e da lógica"
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
SET SERVEROUTPUT ON
EXEC dbms_application_info.set_module( module_name => 'd[synonyms_ORA-01775_looping_chain.sql]', action_name =>  'd[synonyms_ORA-01775_looping_chain.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
col p1 new_value 1
select null p1 from dual where 1=2;
select nvl( '&1','-1') p1 from dual ;
--define v_synonym_name=&1
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/synonyms_ORA-01775_looping_chain.sql      |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Lista Sinonimos Sem Apontamento                       +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET ECHO         OFF
SET FEEDBACK     OFF
SET HEADING      ON
SET LINES        188
SET PAGES        300 
SET TERMOUT      ON
SET TIMING       OFF
SET TRIMOUT      ON
SET TRIMSPOOL    ON
SET VERIFY       OFF
SET SERVEROUTPUT ON
SET VERIFY       OFF

DECLARE
    v_exists INTEGER;
    v_synonym_name VARCHAR2(100);
BEGIN
    select UPPER(DECODE(LENGTH('&&1'), 0, NULL, '&&1')) into v_synonym_name from dual;

    FOR rec_syn IN (SELECT OWNER, SYNONYM_NAME, TABLE_OWNER, TABLE_NAME, DB_LINK
                      FROM DBA_SYNONYMS
                     WHERE OWNER NOT IN ('SYS', 'SYSTEM', 'AUDSYS', 'DBSNMP', 'XDB') 
                       AND TABLE_OWNER NOT IN ('SYS', 'SYSTEM', 'AUDSYS', 'DBSNMP', 'XDB')
                       AND DB_LINK IS NULL
                       AND (v_synonym_name = '-1' OR SYNONYM_NAME like '%'||v_synonym_name||'%')
                     ORDER BY TABLE_OWNER, OWNER)
    LOOP
        SELECT COUNT(*)
        INTO v_exists
        FROM DBA_OBJECTS
        WHERE OWNER = rec_syn.TABLE_OWNER
        AND OBJECT_NAME = rec_syn.TABLE_NAME;

        IF v_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('SYNONYM ' || RPAD(rec_syn.OWNER || '.' || rec_syn.SYNONYM_NAME,40,' ') ||
                                 ' esta INVALIDO porque nao existe o objeto de apontamento ' ||
                                 rec_syn.TABLE_OWNER || '.' || rec_syn.TABLE_NAME);
		ELSIF v_exists > 0 AND v_synonym_name <> '-1' THEN
            DBMS_OUTPUT.PUT_LINE('SYNONYM ' || RPAD(rec_syn.OWNER || '.' || rec_syn.SYNONYM_NAME,50,' ') ||
                                 ' esta VALIDO! Objeto de apontamento ' ||
                                 rec_syn.TABLE_OWNER || '.' || rec_syn.TABLE_NAME);
        END IF;
    END LOOP;
END;
/
SET FEEDBACK  ON
SET VERIFY    ON
PROMPT
PROMPT

