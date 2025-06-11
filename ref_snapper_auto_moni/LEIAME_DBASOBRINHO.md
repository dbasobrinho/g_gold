Este diretório contém scripts para monitoramento contínuo de instâncias Oracle.
São utilizados o Snapper (criado por Tanel Poder), oratop e scripts para análise
do uso de CPU, organizados para facilitar o acompanhamento de performance em tempo real.

Autor: Roberto Fernandes Sobrinho 
Blog: https://dbasobrinho.com.br


ARQUIVOS INCLUSOS:

snapper.sql                 - Script original do Snapper, desenvolvido por Tanel Poder, para análise de performance via V$SESSION.
snapper_instance.sql        - Versão adaptada do Snapper para coletar métricas agrupadas por instância Oracle.
snapper_s.sql               - Script s.sql  (https://github.com/dbasobrinho/g_gold/blob/master/s.sql).
snapper_hora.sql            - Script baseado no Snapper que agrupa as estatísticas por hora para facilitar análises históricas.
snapper_instance.sh         - Script shell que executa o snapper_instance.sql para uma instância Oracle especificada.
snapper_instance_loop.sh    - Executa o snapper_instance.sh continuamente enquanto o dia atual não muda (útil para agendamento via crontab).
snapper_cpu.sh              - Executa coleta detalhada de uso de CPU no nível do sistema e do banco.
snapper_cpu_loop.sh         - Loop diário que executa o snapper_cpu.sh em intervalos definidos (ideal para monitoramento contínuo).
snapper_cpu.pl              - Script Perl derivado do cpu_per_db_sort.pl, criado por Bertrand Drouvot, para análise detalhada de CPU por sessão.
snapper_cpu_stats.sh        - Script shell que coleta estatísticas do sistema como `top`, `mpstat`, `vmstat` e carrega no log de CPU.
oratop.LNX.RDBMS11          - Binário do `oratop` compatível com Oracle 11g em sistemas Linux.
oratop.LNX.RDBMS19          - Binário do `oratop` compatível com Oracle 19c em sistemas Linux.

REQUISITOS:
- Banco de Dados Oracle (testado com sucesso nas versões 11g e 19c)
- Permissão SYSDBA para execução dos scripts via SQL*Plus
- Perl instalado no sistema operacional (necessário para executar o snapper_cpu.pl)
- Comandos de sistema como: mpstat, iostat, vmstat, top, free e pwdx devem estar disponíveis
- Alguns comandos podem exigir permissão de superusuário
  - O usuário 'oracle' precisa executar o comando 'pwdx' via sudo sem solicitar senha
    Para isso, adicione no arquivo /etc/sudoers usando o `visudo`:
    
    oracle ALL=(ALL) NOPASSWD: /usr/bin/pwdx


COMO UTILIZAR:

1) Coleta pontual por instância:  
   Exemplo:  
   sh snapper_instance.sh PEXBI

2) Loop contínuo por instância (executa até o fim do dia):  
   Exemplo:  
   sh snapper_instance_loop.sh PEXBI

3) Coleta pontual de uso de CPU:  
   Exemplo:  
   sh snapper_cpu.sh

4) Loop contínuo de coleta de CPU:  
   Exemplo:  
   sh snapper_cpu_loop.sh

USO COM CRONTAB:

Para iniciar o snapper_instance_loop.sh às 00:10 todos os dias:  
10 00 * * * /u01/app/oracle/ADMDBA/MONI/snapper_instance_loop.sh PEXBI > /dev/null 2>&1

Para iniciar o snapper_cpu_loop.sh às 00:15 todos os dias:  
15 00 * * * /u01/app/oracle/ADMDBA/MONI/snapper_cpu_loop.sh > /dev/null 2>&1

LOGS:

Os logs são gravados no diretório logs_snapper e agrupados por hora.
São mantidos por padrão por 10 dias, ajustável via variável RETENTION_DAYS.

CRÉDITOS:

snapper.sql: Tanel Poder  
Fonte: https://github.com/tanelpoder/tpt-oracle/blob/master/snapper.sql

snapper_cpu.pl: Bertrand Drouvot (renomeado de cpu_per_db_sort.pl)  
Fonte: https://bdrouvot.wordpress.com/os_cpu_per_dp/

snapper_cpu_stats.sh: Steve Bosek  
Patch por: Bas van der Doorn e Philipp Lemke  
Versão: 2.3.6

Demais scripts desenvolvidos por:  
Roberto Fernandes Sobrinho  
https://dbasobrinho.com.br


####-->  touch -t 202506041651 *
