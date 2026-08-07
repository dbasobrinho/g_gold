# Rotina Snapper de Monitoramento Contínuo de Instâncias Oracle  
 
Este diretório contém scripts para monitoramento contínuo de instâncias Oracle. São utilizados o Snapper (criado por Tanel Poder), o oratop e scripts de análise de uso de CPU, organizados para facilitar o acompanhamento de performance em tempo real e a identificação antecipada de sessões e SQLs com alto consumo de recursos.

**Autor:** Roberto Fernandes Sobrinho
**Blog:** https://dbasobrinho.com.br

> **Diretório de instalação adotado neste manual:** `/u01/app/oracle/diag/TVTDBA/snapper`
> Ajuste o caminho conforme o ambiente. Todas as variáveis e linhas de crontab abaixo usam esse diretório.

---

## Índice

1. [Como a rotina funciona](#1-como-a-rotina-funciona)
2. [Arquivos inclusos](#2-arquivos-inclusos)
3. [Arquivos que precisam ser editados](#3-arquivos-que-precisam-ser-editados)
4. [Requisitos](#4-requisitos)
5. [Instalação passo a passo](#5-instalação-passo-a-passo)
6. [Como utilizar (execução manual)](#6-como-utilizar-execução-manual)
7. [Agendamento no crontab](#7-agendamento-no-crontab)
8. [Logs e retenção](#8-logs-e-retenção)
9. [Validação](#9-validação)
10. [Troubleshooting](#10-troubleshooting)
11. [Desinstalação](#11-desinstalação)
12. [Créditos](#12-créditos)

---

## 1. Como a rotina funciona

A coleta é feita por dois pares de scripts, um para CPU e outro por instância:

- **Coleta de CPU** (`snapper_cpu.sh`): coleta o uso de CPU no nível do sistema operacional e do banco. Aciona internamente o `snapper_cpu.pl` (análise de CPU por sessão) e o `snapper_cpu_stats.sh` (`top`, `mpstat`, `vmstat`). Para descobrir o `ORACLE_HOME` de cada processo, usa `sudo pwdx <pid>`.
- **Coleta por instância** (`snapper_instance.sh`): executa o `snapper_instance.sql` para a instância informada como argumento e usa o `oratop` para a visão de atividade da instância.

Os scripts de loop (`snapper_cpu_loop.sh` e `snapper_instance_loop.sh`) são os que vão no crontab. Cada um inicia uma vez por dia, logo após a meia-noite, e mantém a coleta em laço contínuo (com intervalo entre execuções) até o dia virar. No início de cada dia o loop também remove os logs mais antigos que `RETENTION_DAYS`. Os logs são gravados em `logs_snapper`, agrupados por hora.

---

## 2. Arquivos inclusos

| Arquivo | Descrição | Precisa editar |
|---|---|:---:|
| `snapper.sql` | Script original do Snapper (Tanel Poder), análise de performance via V$SESSION. | Não |
| `snapper_instance.sql` | Versão adaptada do Snapper, métricas agrupadas por instância Oracle. | Não |
| `snapper_s.sql` | Script s.sql (https://github.com/dbasobrinho/g_gold/blob/master/s.sql). | Não |
| `snapper_hora.sql` | Baseado no Snapper, agrupa estatísticas por hora para análise histórica. | Não |
| `snapper_instance.sh` | Shell que executa o `snapper_instance.sql` para a instância informada. | **Sim** |
| `snapper_instance_loop.sh` | Loop diário do `snapper_instance.sh` (crontab). | **Sim** |
| `snapper_cpu.sh` | Coleta detalhada de uso de CPU no sistema e no banco. | **Sim** |
| `snapper_cpu_loop.sh` | Loop diário do `snapper_cpu.sh` (crontab). | **Sim** |
| `snapper_cpu.pl` | Perl derivado do `cpu_per_db_sort.pl` (Bertrand Drouvot), CPU por sessão. | Não |
| `snapper_cpu_stats.sh` | Coleta `top`, `mpstat`, `vmstat` e grava no log de CPU. | Não |
| `oratop.LNX.RDBMS11` | Binário do `oratop` para Oracle 11g em Linux. | Não |
| `oratop.LNX.RDBMS19` | Binário do `oratop` para Oracle 19c em Linux. | Não |

---

## 3. Arquivos que precisam ser editados

Quatro scripts trazem variáveis apontando para o caminho padrão do repositório e precisam ser ajustados para o diretório real da instalação.

### 3.1 `snapper_cpu.sh`

```bash
# Caminho do diretório onde está o snapper_cpu.sh
SCRIPT_PATH="/u01/app/oracle/diag/TVTDBA/snapper"
# Caminho dos logs (serão criados aqui, se ainda não existirem)
LOG_DIR="$SCRIPT_PATH/logs_snapper"
```

### 3.2 `snapper_instance.sh`

```bash
# Caminho do diretório onde está o snapper_instance.sh
SCRIPT_PATH="/u01/app/oracle/diag/TVTDBA/snapper"
# Caminho dos logs
LOG_DIR="$SCRIPT_PATH/logs_snapper"
# Caminho do binário oratop (use o da versão do banco)
ORATOP="/u01/app/oracle/diag/TVTDBA/snapper/oratop.LNX.RDBMS19"
```

### 3.3 `snapper_cpu_loop.sh`

```bash
# Dias de retenção dos logs (padrão: 10 dias)
RETENTION_DAYS=10
# Caminho do diretório onde está o snapper_cpu.sh
SCRIPT_PATH="/u01/app/oracle/diag/TVTDBA/snapper"
# Caminho dos logs
LOG_DIR="$SCRIPT_PATH/logs_snapper"
```

### 3.4 `snapper_instance_loop.sh`

```bash
# Dias de retenção dos logs (padrão: 10 dias)
RETENTION_DAYS=10
# Caminho do diretório onde está o snapper_instance.sh
SCRIPT_PATH="/u01/app/oracle/diag/TVTDBA/snapper"
# Caminho dos logs
LOG_DIR="$SCRIPT_PATH/logs_snapper"
```

**Observações**

- O `LOG_DIR` acompanha o `SCRIPT_PATH`; mantenha a expressão `"$SCRIPT_PATH/logs_snapper"`.
- **`ORATOP`:** aponte para o binário da versão do banco. Use `oratop.LNX.RDBMS11` em bancos 11g e `oratop.LNX.RDBMS19` em bancos 19c.
- Os scripts `snapper_cpu.pl` e `snapper_cpu_stats.sh` são acionados pelo `snapper_cpu.sh`. Não têm variável de caminho a alterar, mas precisam estar no mesmo `SCRIPT_PATH` e com permissão de execução.
- Os arquivos `.sql` não exigem edição.

---

## 4. Requisitos

- Banco de dados Oracle (testado com sucesso nas versões 11g e 19c).
- Permissão SYSDBA para a execução dos scripts via SQL*Plus.
- Perl instalado no sistema operacional (necessário para o `snapper_cpu.pl`).
- Comandos de sistema disponíveis: `mpstat`, `iostat`, `vmstat`, `top`, `free` e `pwdx`. Os utilitários `mpstat` e `iostat` vêm do pacote `sysstat`. Se faltarem, instale como root:

  ```bash
  yum install -y sysstat procps-ng
  ```

### 4.1 Sudo sem senha para o `pwdx`

O usuário `oracle` precisa executar o `pwdx` via sudo sem solicitar senha (os scripts usam `sudo pwdx <pid>` para descobrir o `ORACLE_HOME` de cada processo).

Confirme o caminho real do `pwdx` (o caminho no sudoers tem que bater). Em Oracle Linux costuma ser `/bin/pwdx`:

```bash
which pwdx
```

Edite com o `visudo` (`visudo` para o `/etc/sudoers`, ou `visudo -f /etc/sudoers.d/oracle-snapper` para um drop-in) e inclua as linhas abaixo. Listar `/bin/pwdx` e `/usr/bin/pwdx` cobre os dois layouts. O `!requiretty` é necessário porque os scripts rodam pelo crontab, sem tty; sem ele o `sudo` falha com "you must have a tty to run sudo":

```
Defaults:oracle !requiretty
oracle ALL=(ALL) NOPASSWD: /bin/pwdx, /usr/bin/pwdx
```

Teste, como usuário `oracle`, que não pede senha:

```bash
sudo -n pwdx $$
```

Se retornar o diretório do processo sem pedir senha, o requisito está atendido.

---

## 5. Instalação passo a passo

Execute como usuário `oracle`, com o ambiente do banco carregado (`ORACLE_HOME`, `ORACLE_SID` e `PATH`). O procedimento é idêntico nos dois servidores.

### 5.1 Validar o ambiente

```bash
echo $ORACLE_HOME
echo $ORACLE_SID
$ORACLE_HOME/bin/orabase
```

O utilitário `orabase` devolve o `ORACLE_BASE` de forma dinâmica. A pasta trace da instância pode ser confirmada no SQL*Plus com `SELECT value FROM v$diag_info WHERE name = 'Diag Trace';`.

### 5.2 Criar a estrutura de diretórios

```bash
mkdir -p /u01/app/oracle/diag/TVTDBA/snapper/logs_snapper
```

### 5.3 Baixar a rotina (servidor com saída de internet)

```bash
cd ~
curl -L -o g_gold.tar.gz https://github.com/dbasobrinho/g_gold/archive/refs/heads/master.tar.gz
tar -xzf g_gold.tar.gz --strip-components=1 g_gold-master/ref_snapper_auto_moni
ls -la ~/ref_snapper_auto_moni
```

Sem saída de internet: baixe o pacote em uma estação com acesso e envie a pasta `ref_snapper_auto_moni` por SCP para o home do usuário `oracle`.

### 5.4 Copiar os arquivos para o diretório da rotina

```bash
cp -p ~/ref_snapper_auto_moni/* /u01/app/oracle/diag/TVTDBA/snapper/
ls -la /u01/app/oracle/diag/TVTDBA/snapper/
```

### 5.5 Ajustar as variáveis dos quatro scripts

Siga a seção 3.

### 5.6 Aplicar permissão de execução

```bash
chmod +x /u01/app/oracle/diag/TVTDBA/snapper/*.sh
chmod +x /u01/app/oracle/diag/TVTDBA/snapper/*.pl
chmod +x /u01/app/oracle/diag/TVTDBA/snapper/oratop.LNX.RDBMS*
```

### 5.7 Configurar o sudo do `pwdx`

Conforme a seção 4.1.

### 5.8 Teste manual

```bash
cd /u01/app/oracle/diag/TVTDBA/snapper
sh snapper_cpu.sh
sh snapper_instance.sh PEXBI
ls -ltr logs_snapper/
tail -40 logs_snapper/$(ls -tr logs_snapper/ | tail -1)
```

Troque `PEXBI` pelo nome da instância do servidor.

---

## 6. Como utilizar (execução manual)

1. Coleta pontual por instância:

   ```bash
   sh snapper_instance.sh PEXBI
   ```

2. Loop contínuo por instância (executa até o fim do dia):

   ```bash
   sh snapper_instance_loop.sh PEXBI
   ```

3. Coleta pontual de uso de CPU:

   ```bash
   sh snapper_cpu.sh
   ```

4. Loop contínuo de coleta de CPU:

   ```bash
   sh snapper_cpu_loop.sh
   ```

---

## 7. Agendamento no crontab

Os scripts de loop iniciam uma vez por dia e mantêm a coleta em laço contínuo até o dia virar. Agende apenas os dois loops, no crontab do usuário `oracle` (`crontab -e`):

```bash
# ==============================================================
# Coleta de performance Snapper
# Scripts de loop: iniciam uma vez por dia e coletam em laco
# continuo ate o dia virar. Logs em logs_snapper, com retencao
# controlada pela variavel RETENTION_DAYS (padrao 10 dias).
# ==============================================================

# Snapper Instance: inicia as 00:10 o loop de coleta de atividade
# da instancia (argumento = nome da instancia; troque PEXBI pela
# instancia do servidor).
10 00 * * * /u01/app/oracle/diag/TVTDBA/snapper/snapper_instance_loop.sh PEXBI > /dev/null 2>&1

# Snapper CPU: inicia as 00:15 o loop de coleta de uso de CPU no
# nivel do sistema operacional e do banco.
15 00 * * * /u01/app/oracle/diag/TVTDBA/snapper/snapper_cpu_loop.sh > /dev/null 2>&1
```

Confirme com `crontab -l`. Troque `PEXBI` pelo nome da instância de cada servidor (a instância do SENIOR é diferente da instância do LINX) e ajuste os horários conforme a janela desejada.

---

## 8. Logs e retenção

Os logs são gravados no diretório `logs_snapper` e agrupados por hora. A retenção é controlada pela variável `RETENTION_DAYS` (padrão 10 dias) dos scripts de loop. No início de cada dia o loop remove os logs mais antigos que `RETENTION_DAYS`, portanto não é necessário um job de limpeza separado no crontab. Para mudar o prazo, ajuste `RETENTION_DAYS` no `snapper_cpu_loop.sh` e no `snapper_instance_loop.sh`.

---

## 9. Validação

Checklist por servidor:

- [ ] Ambiente `oracle` carregado (`ORACLE_HOME` / `ORACLE_SID`).
- [ ] Estrutura de diretórios criada (`snapper` e `logs_snapper`).
- [ ] Rotina baixada e copiada para o `SCRIPT_PATH`.
- [ ] Variáveis ajustadas nos quatro scripts (base e loop).
- [ ] `ORATOP` apontando para o binário da versão do banco.
- [ ] Perl e comandos de sistema (`mpstat`, `iostat`, `vmstat`, `top`, `free`, `pwdx`) disponíveis.
- [ ] Sudo `NOPASSWD` do `pwdx` configurado e testado (`sudo -n pwdx $$`).
- [ ] Permissões de execução aplicadas.
- [ ] Teste manual do `snapper_cpu.sh` gerando log.
- [ ] Teste manual do `snapper_instance.sh` gerando log.
- [ ] Crontab configurado (00:10 instance e 00:15 cpu).
- [ ] Coleta recorrente validada após o primeiro ciclo.

---

## 10. Troubleshooting

| Sintoma | Causa provável | Correção |
|---|---|---|
| `Permission denied` ao executar o script | Script sem bit de execução | `chmod +x` nos `.sh` e `.pl` (seção 5.6) |
| Log não é gerado | `LOG_DIR` incorreto ou inexistente | Conferir `LOG_DIR` e recriar o diretório (seção 5.2) |
| `sudo: sorry, you must have a tty to run sudo` | `requiretty` habilitado e loop rodando pelo cron | Adicionar `Defaults:oracle !requiretty` (seção 4.1) |
| `sudo: no tty present and no askpass program` ou pede senha | Regra `NOPASSWD` do `pwdx` ausente ou com caminho errado | Ajustar o caminho do `pwdx` (`which pwdx`) na regra do sudoers |
| `oratop: not found` ou erro no instance | `ORATOP` com caminho errado ou binário incompatível | Ajustar `ORATOP` e usar o `oratop` da versão do banco (seções 3.2 e 4) |
| `mpstat`/`iostat: command not found` | Pacote `sysstat` não instalado | `yum install -y sysstat` |
| Erro de conexão com o banco | `ORACLE_SID`/`ORACLE_HOME` não carregados | Carregar o ambiente Oracle e repetir (seção 5.1) |
| `curl` sem resposta | Servidor sem saída de internet | Transferir o pacote por SCP (seção 5.3) |
| Coleta não roda no horário agendado | Serviço `cron`/`crond` parado | Verificar e iniciar o `crond` |

---

## 11. Desinstalação

Para remover a rotina em um servidor:

```bash
# 1) remover as linhas do snapper do crontab do oracle
crontab -e

# 2) remover o diretorio da rotina e os logs
rm -rf /u01/app/oracle/diag/TVTDBA/snapper

# 3) opcional: remover a regra de sudo, se nao for mais usada
#    (via visudo, apagando o drop-in oracle-snapper)
```

A remoção afeta apenas a rotina de coleta e seus logs. Não altera o banco de dados nem a instância.

---

## 12. Créditos

- **`snapper.sql`**: Tanel Poder. Fonte: https://github.com/tanelpoder/tpt-oracle/blob/master/snapper.sql
- **`snapper_cpu.pl`**: Bertrand Drouvot (renomeado de `cpu_per_db_sort.pl`). Fonte: https://bdrouvot.wordpress.com/os_cpu_per_dp/
- **`snapper_cpu_stats.sh`**: Steve Bosek. Patch por Bas van der Doorn e Philipp Lemke. Versão 2.3.6.
- Demais scripts desenvolvidos por Roberto Fernandes Sobrinho. https://dbasobrinho.com.br

---

> **Nota de manutenção:** para normalizar a data de modificação dos arquivos do pacote, use no diretório:
> `touch -t 202506041651 *`
