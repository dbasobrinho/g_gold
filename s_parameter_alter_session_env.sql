-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Verificar parâmetros do otimizador alterados na sessão                       |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 05/02/25                                                                     |
-- | Exemplo    : @s_parameter_alter_session_env.sql                                           |  
-- | Arquivo    : s_parameter_alter_session_env.sql                                            |
-- | Referência :                                                                              |
-- | Modificacao:                                                                              |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se reagir, BUMMM! vira pó!"                                         |
-- +-------------------------------------------------------------------------------------------+
-- |
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's_parameter_alter_session_env.sql', action_name =>  's_parameter_alter_session_env.sql');

COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/s_parameter_alter_session_env.sql         |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Diferença de Parâmetros na Sessão                     +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instância: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versão   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+

SET LINESIZE 200
SET PAGESIZE 100
SET VERIFY OFF
SET TRIMSPOOL ON
SET WRAP OFF 
SET COLSEP '|'

PROMPT
PROMPT **************************************************
PROMPT **  🛠️    SELEÇÃO DA SESSÃO PARA ANÁLISE        **
PROMPT **************************************************
PROMPT
PROMPT -> Digite o número da instância (INST_ID):
ACCEPT inst_id NUMBER
PROMPT
PROMPT -> Agora, digite o número da sessão (SID):
ACCEPT sid NUMBER
PROMPT
PROMPT ✅ Sessão &sid da Instância &inst_id selecionada!
PROMPT


COLUMN inst_id FORMAT 999
COLUMN sid FORMAT 99999
COLUMN name FORMAT A40
COLUMN session_value FORMAT A40
COLUMN system_value FORMAT A40

SELECT s.inst_id, 
       s.sid, 
       s.name, 
       s.value AS session_value, 
       p.value AS system_value
FROM GV$SES_OPTIMIZER_ENV s
JOIN GV$PARAMETER p 
    ON s.inst_id = p.inst_id  
   AND s.name = p.name
WHERE s.inst_id = &inst_id
  AND s.sid = &sid
  AND UPPER(s.value) <> UPPER(p.value)
  AND p.ISSYS_MODIFIABLE = 'IMMEDIATE' 
  AND s.name NOT IN ('parallel_degree_limit', 'parallel_min_time_threshold', 'pga_aggregate_target') 
ORDER BY s.name
/

-- Limpa as variáveis após a execução
UNDEFINE inst_id
UNDEFINE sid
