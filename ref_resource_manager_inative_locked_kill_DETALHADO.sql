--===========================================================================
--## Nome do script: ref_resource_manager_inative_locked_kill_DETALHADO.sql
--## Baseado em:     ref_resource_manager_inative_locked_kill_NEW.sql
--## Chamado:        2208145 - Lock TX (row lock contention) na E301TCR
--## Autor:          DBA Sobrinho
--## Data de criacao:12/06/2026
--## Blog:           https://dbasobrinho.com.br
--===========================================================================
--## OBJETIVO
--##
--## Versao detalhada, passo a passo, da configuracao do Oracle Resource Manager
--## (DBRM) para DETECTAR e ENCERRAR sessoes INATIVAS que estejam BLOQUEANDO
--## sessoes ativas (evento "enq: TX - row lock contention").
--##
--##   1. Corrige o fluxograma (estava sem comentario e quebrava a execucao).
--##   2. Corrige o typo "sgundos".
--##   3. Substitui o usuario fixo por um LOGON TRIGGER que exige as TRES
--##      condicoes em AND (ORACLE_USER + OS_USER + PROGRAM).
--##
--## Referencias:
--##   - Doc ID 1557657.1 (Oracle MOS)
--##   - https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_RESOURCE_MANAGER.html
--##   - https://oracle-base.com/articles/misc/resource-manager-max-idle-time
--===========================================================================

/*
--===========================================================================
-- FLUXO LOGICO DA DIRETIVA MAX_IDLE_BLOCKER_TIME
--===========================================================================
+-------------------------------+
|           INICIO              |
+-------------------------------+
               |
               v
+-------------------------------+
| Sessao A inicia e adquire LOCK|
+-------------------------------+
               |
               v
      +-------------------+
      | Outra sessao pede |
      | o mesmo recurso?  |
      +-------------------+
        |             |
   [NAO]|             |[SIM]
        v             v
+----------------+   +-----------------------+
| Sem bloqueio.  |   | Sessao B esperando    |
| Vida que segue |   | (aguarda LOCK)        |
+----------------+   +-----------------------+
        |                         |
        v                         v
      [FIM]         +-----------------------------+
                    | Sessao A esta ATIVA         |
                    | (executando comandos)?      |
                    +-----------------------------+
                       |                   |
                  [SIM]|                   |[NAO, esta IDLE]
                       v                   v
        +------------------------+   +-------------------------------+
        | RM nao age.            |   | Plano ativo                   |
        | A esta trabalhando.    |   | (PLAN_KILL_IDLE_BLOCKER)?     |
        +------------------------+   +-------------------------------+
              |                           |                 |
              v                           |[NAO]            |[SIM]
            [AGUARDA]                      v                 v
                             +---------------------+   +------------------------------+
                             | Sem acao automatica |   | Sessao esta no grupo         |
                             | So monitorar        |   | CG_KILL_IDLE_BLOCKER?        |
                             +---------------------+   +------------------------------+
                                                           |              |
                                                      [NAO]|              |[SIM]
                                                           v              v
                                            +--------------------+   +-----------------------+
                                            | Diretiva nao se    |   | Inicia contagem do    |
                                            | aplica             |   | max_idle_blocker_time |
                                            +--------------------+   +-----------------------+
                                                                         |
                                                                         v
                                                        +-------------------------------+
                                                        | Sessao A continua IDLE        |
                                                        | e bloqueando?                 |
                                                        +-------------------------------+
                                                             |               |
                                                        [NAO]|               |[SIM]
                                                             v               v
                                           +-----------------------+    +--------------------+
                                           | Timer zera. A voltou  |    | Tempo >= limite ?  |
                                           | a trabalhar ou liberou|    +--------------------+
                                           | o LOCK.               |         |          |
                                           +-----------------------+    [NAO]|          |[SIM]
                                                  |                      v   |          v
                                                  v            +-------------------+  +-------------------+
                                                [FIM]          | Continua contando |  | RM MATA sessao A  |
                                                               +-------------------+  +-------------------+
                                                                                             |
                                                                                             v
                                                                                    +-------------------+
                                                                                    | Locks liberados   |
                                                                                    +-------------------+
                                                                                             |
                                                                                             v
                                                                                    +-------------------+
                                                                                    | Sessao B prossegue|
                                                                                    +-------------------+
                                                                                             |
                                                                                             v
                                                                   +------------------------------------------+
                                                                   | v$rsrc_consumer_group atualizada:        |
                                                                   | idle_blkr_sessions_killed = +1           |
                                                                   +------------------------------------------+
                                                                                             |
                                                                                             v
                                                                                           [FIM]
--===========================================================================
*/

SET ECHO ON
SET LINESIZE 200
SET PAGESIZE 200
SET TRIMSPOOL ON
SET SERVEROUTPUT ON SIZE UNLIMITED

SPOOL ref_resource_manager_inative_locked_kill_DETALHADO.out

--===========================================================================
--## ETAPA 0 - CONTEXTO (CDB/PDB)
--##
--## Em ambiente multitenant, consumer group / plano / diretivas / mapeamentos
--## sao objetos LOCAIS do PDB. Conecte no PDB de aplicacao e confirme abaixo.
--## Se CON_NAME for CDB$ROOT, ABORTE e reconecte no PDB.
--===========================================================================

SHOW CON_NAME
SELECT name, is_top_plan FROM v$rsrc_plan WHERE is_top_plan = 'TRUE';   -- plano atual (anotar p/ rollback)
SHOW PARAMETER resource_manager_plan

--===========================================================================
--## ETAPA 1 - AREA DE PENDENCIA (PENDING AREA)
--##
--## O que e: uma "transacao de configuracao". Toda alteracao do RM e montada
--##   dentro dela e so passa a valer no SUBMIT.
--## clear_pending_area: descarta qualquer pendencia orfa de tentativa anterior.
--## create_pending_area: abre a area limpa para as proximas etapas.
--===========================================================================

BEGIN
  DBMS_RESOURCE_MANAGER.clear_pending_area;
  DBMS_RESOURCE_MANAGER.create_pending_area;
END;
/

--===========================================================================
--## ETAPA 2 - CRIAR O RESOURCE PLAN
--##
--## O plano e o "conjunto de regras". Aqui ele existe apenas para hospedar a
--## diretiva de ociosidade. Nao gerencia CPU.
--===========================================================================

BEGIN
  DBMS_RESOURCE_MANAGER.create_plan(
    plan    => 'PLAN_KILL_IDLE_BLOCKER',
    comment => 'Encerra holders de lock TX ociosos (enq TX row lock - E301TCR)');
END;
/

--===========================================================================
--## ETAPA 3 - CRIAR O CONSUMER GROUP
--##
--## O grupo e o "balde" onde colocaremos (via mapeamento) as sessoes a vigiar.
--===========================================================================

BEGIN
  DBMS_RESOURCE_MANAGER.create_consumer_group(
    consumer_group => 'CG_KILL_IDLE_BLOCKER',
    comment        => 'Sessoes candidatas a encerramento por bloqueio ocioso de row lock');
END;
/

--===========================================================================
--## ETAPA 4 - CRIAR AS PLAN DIRECTIVES
--##
--## MAX_IDLE_BLOCKER_TIME: tempo maximo (segundos) que a sessao pode ficar
--##   INACTIVE ENQUANTO bloqueia outra. Estourado, o RM encerra a sessao.
--##   Valor inicial: 60 (1 hora seria 3600). Ajustavel (ver ETAPA 11).
--##
--## MAX_IDLE_TIME: deixado NULO de proposito. Mataria conexoes ociosas
--##   legitimas do pool do SapiensSrv.exe que NAO estejam bloqueando ninguem,
--##   provocando tempestade de reconexao. O MAX_IDLE_BLOCKER_TIME ja e
--##   autolimitante (so age sobre quem esta ocioso E bloqueando).
--##
--## A diretiva de OTHER_GROUPS e OBRIGATORIA: representa "todo o resto" e fica
--##   sem qualquer limite de ociosidade.
--===========================================================================

BEGIN
  -- Diretiva do grupo alvo
  DBMS_RESOURCE_MANAGER.create_plan_directive(
    plan                  => 'PLAN_KILL_IDLE_BLOCKER',
    group_or_subplan      => 'CG_KILL_IDLE_BLOCKER',
    max_idle_blocker_time => 100,    -- segundos (ajustar conforme SLA)
    max_idle_time         => NULL,  -- intencionalmente nulo
    comment               => 'Encerra apenas sessao INACTIVE que esteja bloqueando outra');

  -- Diretiva obrigatoria para as demais sessoes
  DBMS_RESOURCE_MANAGER.create_plan_directive(
    plan             => 'PLAN_KILL_IDLE_BLOCKER',
    group_or_subplan => 'OTHER_GROUPS',
    comment          => 'Demais sessoes: sem encerramento por ociosidade');
END;
/

--===========================================================================
--## ETAPA 5 - VALIDAR E SUBMETER
--##
--## validate_pending_area: checa a consistencia da configuracao.
--## submit_pending_area: efetiva tudo o que foi montado nas etapas 2 a 4.
--===========================================================================

BEGIN
  DBMS_RESOURCE_MANAGER.validate_pending_area;
  DBMS_RESOURCE_MANAGER.submit_pending_area;
END;
/

--===========================================================================
--## ETAPA 6 - CONCEDER O PRIVILEGIO DE SWITCH
--##
--## Sem este privilegio, o mapeamento automatico NAO consegue mover a sessao
--## para o consumer group. Passo silencioso porem indispensavel.
--## Nao usa pending area.
--===========================================================================

BEGIN
  DBMS_RESOURCE_MANAGER_PRIVS.grant_switch_consumer_group(
    grantee_name   => 'SAPIENSPRD',
    consumer_group => 'CG_KILL_IDLE_BLOCKER',
    grant_option   => FALSE);
END;
/

--===========================================================================
--## ETAPA 7 - MAPEAMENTO DAS SESSOES: AS DUAS FORMAS DE FAZER
--##
--## Ha duas formas de colocar a sessao no consumer group, com logicas distintas.
--##
--## FORMA A - SET_CONSUMER_GROUP_MAPPING (logica OR)
--##   Cada regra e INDEPENDENTE; a sessao entra se casar com QUALQUER uma (OR).
--##   Nao combina atributos. A regra por ORACLE_USER sozinha varre o schema e
--##   arrasta tambem os clientes Sapiens.exe. Case-sensitive. Imediata (sem
--##   pending area). A prioridade (set_consumer_group_mapping_pri) NAO vira AND,
--##   so desempata entre grupos diferentes.
--##
--## FORMA B - LOGON TRIGGER (logica AND)   [ADOTADA]
--##   Avalia as TRES condicoes em codigo e so troca de grupo se TODAS baterem
--##   (SAPIENSPRD E senior E SapiensSrv.exe). Garante por logica que clientes
--##   Sapiens.exe, SQL Developer e JDBC nunca entrem no grupo.
--##
--## DIFERENCA ENTRE AS DUAS:
--##   +--------------------+--------------------+-----------------------+
--##   | Aspecto            | A - mapping (OR)   | B - trigger (AND)     |
--##   +--------------------+--------------------+-----------------------+
--##   | Logica             | OR (um atributo)   | AND (os tres juntos)  |
--##   | Combina atributos  | Nao                | Sim                   |
--##   | Resultado          | pega demais        | so a tripla exata     |
--##   | Objeto extra       | nenhum             | 1 trigger no login    |
--##   | Risco no login     | nenhum             | mitigado c/ EXCEPTION |
--##   | Case               | sensitive          | insensitive (UPPER)   |
--##   +--------------------+--------------------+-----------------------+
--##   Em uma frase: no comando o que existe e OR; o AND so com logon trigger.
--##
--## A FORMA A acima e apenas explicativa (comparacao). A solucao ADOTADA e a
--## FORMA B (logon trigger), criada abaixo. NAO usar set_consumer_group_mapping.
--##
--## Observacoes da Forma B:
--##   - Criar conectado no PDB, preferencialmente como SYS (precisa SELECT em v$session).
--##   - O programa NAO esta em USERENV; e lido de v$session pela SID atual.
--##   - EXCEPTION WHEN OTHERS e proposital: trigger de logon que falha pode
--##     IMPEDIR o login (ORA-00604). Nunca deixar o erro propagar.
--##   - A sessao precisa do switch concedido (ETAPA 6).
--##   - Comparacoes em CAIXA ALTA com UPPER (case-insensitive).
--===========================================================================

CREATE OR REPLACE TRIGGER trg_map_kill_idle_blocker
AFTER LOGON ON DATABASE
DECLARE
  v_program  VARCHAR2(48);
  v_old      VARCHAR2(128);
BEGIN
  -- Condicao 1 (usuario Oracle) E Condicao 2 (usuario do SO)
  -- comparacoes em CAIXA ALTA com UPPER (case-insensitive)
  IF UPPER(SYS_CONTEXT('USERENV','SESSION_USER')) = 'SAPIENSPRD'
     AND UPPER(SYS_CONTEXT('USERENV','OS_USER'))  = 'SENIOR'
  THEN
    -- Condicao 3 (programa): ler de v$session pela SID atual
    BEGIN
      SELECT program INTO v_program
      FROM   v$session
      WHERE  sid = SYS_CONTEXT('USERENV','SID')
      AND    rownum = 1;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN v_program := NULL;
    END;

    -- AND final: so troca de grupo se as TRES baterem
    IF UPPER(v_program) = 'SAPIENSSRV.EXE' THEN
      DBMS_SESSION.switch_current_consumer_group(
        new_consumer_group     => 'CG_KILL_IDLE_BLOCKER',
        old_consumer_group     => v_old,
        initial_group_on_error => FALSE);
    END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;  -- nunca impedir o logon por causa do mapeamento
END;
/

--===========================================================================
--## ETAPA 8 - PRIORIDADE DE MAPEAMENTO (NAO SE APLICA)
--##
--## Com a abordagem por LOGON TRIGGER (ETAPA 7), nao usamos
--## set_consumer_group_mapping nem set_consumer_group_mapping_pri: a combinacao
--## AND e resolvida dentro do trigger. Esta etapa fica apenas como marcador.
--##
--## Se existir mapeamento nativo OR herdado para este grupo, REMOVA para nao
--## reintroduzir a semantica OR, por exemplo:
--##   EXEC DBMS_RESOURCE_MANAGER.set_consumer_group_mapping(DBMS_RESOURCE_MANAGER.client_program,'SapiensSrv.exe',NULL);
--===========================================================================

--===========================================================================
--## ETAPA 9 - ATIVAR O PLANO NO PDB (COM FORCE)
--##
--## Passo que liga o encerramento automatico. Executar em janela controlada.
--## SCOPE=BOTH aplica e persiste no estado do PDB.
--##
--## POR QUE FORCE: a diretiva MAX_IDLE_BLOCKER_TIME (e o switch que a trigger
--## faz no logon) so produzem efeito ENQUANTO PLAN_KILL_IDLE_BLOCKER for o
--## plano ATIVO no parametro resource_manager_plan. Por padrao, o Oracle TROCA
--## esse parametro automaticamente nas JANELAS DE MANUTENCAO do Scheduler
--## (ativa o DEFAULT_MAINTENANCE_PLAN, normalmente a noite). Nessa troca o
--## nosso plano sai de cena e os bloqueadores ociosos DEIXAM de ser encerrados
--## justamente na janela noturna. O prefixo FORCE: trava o plano: impede que o
--## Scheduler ou o Resource Manager o troquem automaticamente; so um ALTER
--## SYSTEM manual muda. Assim a protecao fica continua, 24x7. (O rollback com
--## resource_manager_plan = '' continua valendo, por ser troca manual.)
--===========================================================================

ALTER SYSTEM SET resource_manager_plan = 'FORCE:PLAN_KILL_IDLE_BLOCKER' SCOPE = BOTH;

SHOW PARAMETER resource_manager_plan
SELECT name, is_top_plan FROM v$rsrc_plan WHERE is_top_plan = 'TRUE';

--===========================================================================
--## ETAPA 10 - (OPCIONAL) JANELAS DO SCHEDULER
--##
--## ATENCAO: ESTUDE ANTES DE EXECUTAR. Isto normalmente e acao no CDB$ROOT,
--## nao no PDB, e afeta a manutencao automatica de todo o CDB.
--## Objetivo: impedir que janelas de manutencao troquem o plano ativo para o
--## DEFAULT_MAINTENANCE_PLAN. A alternativa mais segura e usar o prefixo
--## FORCE: na ETAPA 9, em vez de mexer nas janelas.
--##
--## Os blocos abaixo ficam COMENTADOS de proposito. Descomente apenas se,
--## apos analise, decidir remover o atributo RESOURCE_PLAN das janelas.
--===========================================================================

-- BEGIN
--   FOR w IN (SELECT window_name FROM dba_scheduler_windows) LOOP
--     DBMS_SCHEDULER.set_attribute_null(name => w.window_name, attribute => 'RESOURCE_PLAN');
--   END LOOP;
-- END;
-- /
--
-- BEGIN
--   FOR w IN (SELECT window_name FROM dba_scheduler_windows WHERE active = 'TRUE') LOOP
--     DBMS_SCHEDULER.close_window(w.window_name);
--   END LOOP;
-- END;
-- /

--===========================================================================
--## ETAPA 11 - VALIDACOES OPERACIONAIS
--===========================================================================

-- Diretivas do plano
SELECT plan, group_or_subplan, max_idle_time, max_idle_blocker_time, comments
FROM   dba_rsrc_plan_directives
WHERE  plan = 'PLAN_KILL_IDLE_BLOCKER'
ORDER  BY group_or_subplan;

-- Trigger de mapeamento (AND das tres condicoes)
SELECT owner, trigger_name, triggering_event, status
FROM   dba_triggers
WHERE  trigger_name = 'TRG_MAP_KILL_IDLE_BLOCKER';

-- Conferencia: NAO deve haver mapeamento nativo OR para este grupo
SELECT attribute, value, consumer_group
FROM   dba_rsrc_group_mappings
WHERE  consumer_group = 'CG_KILL_IDLE_BLOCKER';

-- Plano efetivo
SELECT name, is_top_plan FROM v$rsrc_plan WHERE is_top_plan = 'TRUE';

-- Em que grupo as sessoes alvo cairam (mapping so vale p/ sessoes novas)
SELECT inst_id, sid, serial#, osuser, program, status,
       resource_consumer_group, blocking_session, last_call_et AS idle_secs, event
FROM   gv$session
WHERE  username = 'SAPIENSPRD'
ORDER  BY resource_consumer_group, status;

-- Ajuste fino do limite (exemplo: reduzir para 30s), sem recriar o plano:
-- BEGIN
--   DBMS_RESOURCE_MANAGER.clear_pending_area;
--   DBMS_RESOURCE_MANAGER.create_pending_area;
--   DBMS_RESOURCE_MANAGER.update_plan_directive(
--     plan => 'PLAN_KILL_IDLE_BLOCKER', group_or_subplan => 'CG_KILL_IDLE_BLOCKER',
--     new_max_idle_blocker_time => 30);
--   DBMS_RESOURCE_MANAGER.validate_pending_area;
--   DBMS_RESOURCE_MANAGER.submit_pending_area;
-- END;
-- /

--===========================================================================
--## ETAPA 12 - MONITORAMENTO E COMO VALIDAR
--##
--## O RM nao marca status 'KILLED'. O encerramento ocorre via rollback +
--## disconnect. Use as duas consultas abaixo em conjunto: (1) o CONTADOR
--## acumulado e (2) os CANDIDATOS no momento (quem deve ser encerrado no
--## proximo ciclo do RM).
--##
--## COMO VALIDAR, passo a passo:
--##   1. Anote a linha de base: o valor de idle_blkr_sessions_killed da linha
--##      CG_KILL_IDLE_BLOCKER na consulta (1).
--##   2. Rode a consulta (2) repetidamente (a cada poucos segundos). Ela lista
--##      as sessoes no grupo, INACTIVE e com waiters > 0 (alguem espera o lock).
--##      A coluna IDLE (last_call_et) e o tempo ocioso em segundos.
--##   3. Quando uma sessao da (2) passar do limite (idle >= 60 + a granularidade
--##      do RM, alguns segundos), ela deve ser encerrada e SUMIR da lista na
--##      proxima execucao.
--##   4. Confirme: na consulta (1), idle_blkr_sessions_killed INCREMENTA, e os
--##      waiters daquele bloqueador caem (as sessoes que esperavam prosseguem).
--##
--## LEITURA DOS RESULTADOS:
--##   - idle_blkr_sessions_killed subindo ...... RM encerrando bloqueadores (OK).
--##   - idle_sessions_killed deve ficar 0 ....... MAX_IDLE_TIME esta nulo.
--##   - consulta (2) vazia ..................... sem bloqueador ocioso agora (saudavel).
--##   - (2) cheia, idle crescente e contador PARADO ... investigar: plano ativo?
--##     (SHOW PARAMETER resource_manager_plan), o trigger classificou a sessao?,
--##     o limite esta alto demais?
--===========================================================================

SET LINESIZE 200 PAGESIZE 100

-- (1) CONTADOR: quantos bloqueadores ociosos ja foram encerrados
COLUMN name FORMAT A24
SELECT name, idle_sessions_killed, idle_blkr_sessions_killed
FROM   v$rsrc_consumer_group
WHERE  name IN ('CG_KILL_IDLE_BLOCKER','OTHER_GROUPS');

-- (2) CANDIDATOS AGORA: sessoes no grupo, INACTIVE e bloqueando (com no. de waiters)
COLUMN osuser  FORMAT A12
COLUMN program FORMAT A16
COLUMN rcg     FORMAT A22
SELECT s.sid, s.serial#, s.osuser, s.program, s.status,
       s.last_call_et AS idle,
       (SELECT COUNT(*) FROM gv$session w WHERE w.blocking_session = s.sid) AS waiters
FROM   gv$session s
WHERE  s.resource_consumer_group = 'CG_KILL_IDLE_BLOCKER'
AND    s.status = 'INACTIVE'
AND    EXISTS (SELECT 1 FROM gv$session w WHERE w.blocking_session = s.sid)
ORDER  BY s.last_call_et DESC;

--===========================================================================
--## ETAPA 13 - RELATORIO DE SESSOES NO LIMITE (candidatas ao kill)
--===========================================================================

SET COLSEP '|' PAGESIZE 200 LINESIZE 300 TRIMSPOOL ON
COLUMN plan_name        FORMAT A25
COLUMN consumer_group   FORMAT A30
COLUMN qtd_sessoes_kill FORMAT 999,990

WITH top_plan AS (
  SELECT name AS plan_name FROM v$rsrc_plan WHERE is_top_plan = 'TRUE'
),
dir AS (
  SELECT d.plan, d.group_or_subplan AS consumer_group,
         NVL(d.max_idle_blocker_time,0) AS max_idle_blocker_time
  FROM   dba_rsrc_plan_directives d
  JOIN   top_plan p ON p.plan_name = d.plan
),
blockers AS (
  SELECT s.inst_id, s.sid, s.serial#, s.username,
         s.resource_consumer_group AS consumer_group,
         s.last_call_et AS idle_secs, d.max_idle_blocker_time AS limit_secs
  FROM   gv$session s
  JOIN   dir d ON d.consumer_group = s.resource_consumer_group
  WHERE  s.type = 'USER'
  AND    s.status = 'INACTIVE'
  AND    EXISTS (SELECT 1 FROM gv$session v WHERE v.blocking_session = s.sid)
)
SELECT (SELECT plan_name FROM top_plan) AS plan_name,
       consumer_group, COUNT(*) AS qtd_sessoes_kill
FROM   blockers
WHERE  limit_secs > 0 AND idle_secs >= limit_secs
GROUP  BY consumer_group
ORDER  BY 1,2;

--===========================================================================
--## ROLLBACK
--##
--## O rollback completo (desativar plano, remover mapeamentos, revogar switch,
--## apagar diretivas/plano/grupo) esta no script 2208145_dbrm_rollback.sql.
--===========================================================================

--===========================================================================
--## OBSERVACOES FINAIS
--##
--## 1. So encerra sessao INACTIVE que esteja bloqueando. Os SELECT FOR UPDATE
--##    (ACTIVE) nunca sao mortos.
--## 2. Nao e instantaneo: o RM avalia em ciclos. Kill efetivo = limite + atraso.
--## 3. O holder recebe ORA-00028 e precisa reconectar (validar com a Senior).
--## 4. Nao corrige a causa raiz (hot row na E301TCR). E mitigacao controlada;
--##    a correcao definitiva e na aplicacao. Avaliar tambem o indice de 11/06.
--## 5. Manter o paliativo (kill_lock_senior.sh) ate comprovar o RM por 24-48h.
--===========================================================================

SPOOL OFF
SET COLSEP ' '
SET ECHO OFF
