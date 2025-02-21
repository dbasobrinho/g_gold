-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Verificar Espaço da FRA                                                      |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 15/12/2015                                                                   |
-- | Exemplo    : @size_fra_recovery_file_dest.sql                                             |  
-- | Arquivo    : size_fra_recovery_file_dest.sql                                              |
-- | Referência :                                                                              |
-- | Modificação: 1.0 - 06/09/2024 - DBASobrinho                                               |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se reagir, BUMMM! vira pó!"                                         |
-- +-------------------------------------------------------------------------------------------+

SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module(module_name => 'size_fra_recovery_file_dest.sql', action_name => 'Verificação FRA');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/size_fra_recovery_file_dest.sql           |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Verificar Espaço da FRA                               +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT | Instância: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o| |
PROMPT | Versão   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+ |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |   - "Tamanho|Total"    → Capacidade total da área de recuperação                          
PROMPT |   - "Utilizado|(MB)"   → Espaço atualmente consumido                                      
PROMPT |   - "Recuperável|(MB)" → Espaço que pode ser liberado automaticamente pelo Oracle         
PROMPT |   - "%|Usado"          → Porcentagem efetiva de uso                                       
PROMPT |   - "Espaço|Livre"    → Capacidade restante considerando arquivos deletáveis             
PROMPT |   - "Limite|Máx"      → Tamanho máximo configurado para o FRA                            
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET FEEDBACK ON;
SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       188
SET PAGES       300
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

COLUMN nome                  HEADING 'Local|FRA'           FORMAT A32  JUSTIFY CENTER
COLUMN tamanho               HEADING 'Tamanho|Total'       FORMAT A12  JUSTIFY CENTER
COLUMN utilizado             HEADING 'Utilizado|(MB)'      FORMAT A12  JUSTIFY CENTER
COLUMN espaco_recuperavel    HEADING 'Recuperável|(MB)'    FORMAT A12  JUSTIFY CENTER
COLUMN pct_usado             HEADING '%|Usado'             FORMAT 999  JUSTIFY CENTER
COLUMN espaco_livre          HEADING 'Espaço|Livre'        FORMAT A12  JUSTIFY CENTER
COLUMN limite_max            HEADING 'Limite|Máx'          FORMAT A12  JUSTIFY CENTER
COLUMN tipo_uso              HEADING 'Tipo de|Uso'         FORMAT A25  JUSTIFY CENTER
COLUMN espaco_usado_tipo     HEADING 'Espaço|Usado'        FORMAT A12  JUSTIFY CENTER
COLUMN pct_usado_tipo        HEADING '%|Uso'               FORMAT 999  JUSTIFY CENTER

SELECT name AS nome,
       DBMS_XPLAN.FORMAT_SIZE(space_limit) AS tamanho,
       DBMS_XPLAN.FORMAT_SIZE(space_used) AS utilizado,
       DBMS_XPLAN.FORMAT_SIZE(space_reclaimable) AS espaco_recuperavel,
       CASE 
           WHEN space_used = 0 THEN 0 
           ELSE CEIL(((space_used - space_reclaimable) / space_limit) * 100) 
       END AS pct_usado,
       DBMS_XPLAN.FORMAT_SIZE(space_limit - space_used + space_reclaimable) AS espaco_livre,
       DBMS_XPLAN.FORMAT_SIZE(space_limit) AS limite_max
  FROM v$recovery_file_dest
ORDER BY name;

SELECT file_type AS tipo_uso,
       DBMS_XPLAN.FORMAT_SIZE((percent_space_used / 100) * (SELECT space_limit FROM v$recovery_file_dest)) AS espaco_usado_tipo,
       CEIL(percent_space_used) AS pct_usado_tipo
  FROM v$flash_recovery_area_usage
ORDER BY file_type;

SET FEEDBACK ON;
