#!/bin/bash
set -e
#set -x # Descomente esta linha para ver a execução passo a passo

# ETAPA 0: LIMPEZA E DEFINIÇÕES
#----------------------------------------------------------------
# Limpa execuções anteriores para começar do zero
rm -rf /tmp/node-*

# Define as portas de cada participante
PORTCAR=8334
PORTLUC=8335
PORTANA=8336
PORTARTH=8337
PORTTROL=8338

# Cria um array com todas as portas para facilitar os loops
PORTS=($PORTCAR $PORTLUC $PORTANA $PORTARTH $PORTTROL)

$CHAIN="#quiz"

# FUNÇÕES DE APOIO
#----------------------------------------------------------------

# Mostra a reputação de todos os participantes
mostrar_reputacao(){
    sleep 2
    echo "==== Reputações ===="
    echo "@carla: $(../freechains --port=$PORTCAR chain '#quiz' reps "$pubcar")" 
    echo "@lucas: $(../freechains --port=$PORTLUC chain '#quiz' reps "$publuca")" 
    echo "@ana:   $(../freechains --port=$PORTANA chain '#quiz' reps "$pubana")" 
    echo "@troll: $(../freechains --port=$PORTTROL chain '#quiz' reps "$pubtrol")"     
    echo "@arthur: $(../freechains --port=$PORTARTH chain '#quiz' reps "$pubarth")" 
}

# Força um nó a enviar suas atualizações para todos os outros
atualizar(){
    local original = $1
    echo "--> Sincronizando rede a partir da porta $original..."
    for PORT in "${PORTS[@]}"; do
        local target_port=$PORT
        if [ "$original" != "$PORT" ]; then
            ../freechains --port="$original" peer "localhost:$target_port" send $CHAIN
        fi
    done

# Posta uma mensagem e atualiza a rede
postar(){
    local port=$1
    local message=$2
    local private_key=$3
    
    local hash=$(../freechains --port="$port" chain '#quiz' post inline "$message" --sign="$private_key")
    atualizar "$port"
    echo "$hash"
}

# Curte uma postagem
curtir(){
    local port=$1
    local target_hash=$2
    local private_key=$3
    local reason=$4

    ../freechains --port="$port" chain '#quiz' like "$target_hash" --sign="$private_key" --why="$reason"
    atualizar "$port"
}

# Descurte uma postagem
descurtir(){
    local port=$1
    local target_hash=$2
    local private_key=$3
    local reason=$4

    ../freechains --port="$port" chain '#quiz' dislike "$target_hash" --sign="$private_key" --why="$reason"
    atualizar "$1"
}


# INÍCIO DA SIMULAÇÃO
#----------------------------------------------------------------

# ETAPA 1: INICIAR TODOS OS NÓS EM BACKGROUND
echo "ETAPA 1: Iniciando todos os nós..."
../freechains-host --port=$PORTCAR start /tmp/node-carla --no-tui > /dev/null 2>&1 &
../freechains-host --port=$PORTLUC start /tmp/node-lucas --no-tui > /dev/null 2>&1 &
../freechains-host --port=$PORTANA start /tmp/node-ana --no-tui > /dev/null 2>&1 &
../freechains-host --port=$PORTARTH start /tmp/node-arthur --no-tui > /dev/null 2>&1 &
../freechains-host --port=$PORTTROL start /tmp/node-troll --no-tui > /dev/null 2>&1 &
# Pausa crucial para dar tempo aos nós (processos Java) de inicializarem completamente
sleep 10
echo "====== Nós iniciados e estáveis ======"


# ETAPA 2: CRIAR CHAVES DE TODOS OS PARTICIPANTES
echo "ETAPA 2: Criando chaves públicas e privadas..."
read -r pubcar privcar < <(../freechains --port="$PORTCAR" keys pubpvt 'carla')
read -r publuca privluca < <(../freechains --port="$PORTLUC" keys pubpvt 'lucas')
read -r pubana privana < <(../freechains --port="$PORTANA" keys pubpvt 'ana')
read -r pubarth privarth < <(../freechains --port="$PORTARTH" keys pubpvt 'arthur')
read -r pubtrol privtrol < <(../freechains --port="$PORTTROL" keys pubpvt 'troll')
sleep 2


# ETAPA 3: CRIAÇÃO E SINCRONIZAÇÃO DA CHAIN
echo "ETAPA 3: Criando a chain com dois fundadores..."
# CORREÇÃO: As chaves públicas são passadas como DOIS argumentos separados.
../freechains --port="$PORTCAR" chains join '#quiz' "$pubcar" "$publuca"
../freechains --port="$PORTLUC" chains join '#quiz' "$pubcar" "$publuca"
sleep 5

echo "--> Sincronizando os fundadores (ponto crítico)..."
../freechains --port="$PORTCAR" peer "$PORTLUC" send '#quiz'
../freechains --port="$PORTLUC" peer "$PORTCAR" send '#quiz'
sleep 5

echo "--> Outros nós entram no canal confiando nos fundadores..."
../freechains --port="$PORTANA" chains join '#quiz' "$pubcar" "$publuca"
../freechains --port="$PORTTROL" chains join '#quiz' "$pubcar" "$publuca"
../freechains --port="$PORTARTH" chains join '#quiz' "$pubcar" "$publuca"
echo "--> Todos os nós entraram no canal."
sleep 3

echo "--> Sincronização final de toda a rede..."
for PORT in "${PORTS[@]}"; do
    atualizar "$PORT"
done
sleep 3


# ETAPA 4: INÍCIO DAS INTERAÇÕES
echo "ETAPA 4: Avançando no tempo e começando as interações..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1715000000 --port="$PORT" # 6/05/2024
done

echo "--- Reputação Inicial ---"
mostrar_reputacao
sleep 4

echo ">>> Carla posta a primeira pergunta..."
PT1=$(postar "$PORTCAR" 'Primeira pergunta: Qual é a capital da França?\nopcoes: A) Berlim B) Paris C) Roma D) Lisboa' "$privcar")
sleep 3

echo ">>> Arthur responde certo..."
RC1=$(postar "$PORTARTH" 'B) Paris' "$privarth")
sleep 3

echo ">>> Carla curte a resposta de Arthur..."
curtir "$PORTCAR" "$RC1" "$privcar" 'Parabéns Arthur, você acertou'
sleep 3

echo ">>> Lucas e Troll postam em seguida..."
PT2=$(postar "$PORTLUC" 'Qual o nome da capital do Brasil atualmente? Opções: A) Rio de Janeiro B)Fortaleza C)Brasília D)Porto Alegre' "$privluc")
PTROL=$(postar "$PORTTROL" 'Sua mãe!!!' "$privtrol")
sleep 3

echo ">>> Troll recebe descurtidas..."
descurtir "$PORTLUC" "$PTROL" "$privluc" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike'
descurtir "$PORTCAR" "$PTROL" "$privcar" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'
sleep 3

echo "--> Avançando uma semana no tempo..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1715605200 --port="$PORT" # 13/05/2024
done

echo "--- Reputação após uma semana ---"
mostrar_reputacao
sleep 3

echo ">>> Arthur posta uma pergunta de novato..."
PT3=$(postar "$PORTARTH" 'Sou novato, aqui vai minha primeira pergunta: Qual letra representa o número 5 em algaritmos Romanos?\nopcoes: A) I B) II C) V D) X' "$privarth")
sleep 3

echo ">>> Carla e Lucas curtem a pergunta de Arthur..."
curtir "$PORTCAR" "$PT3" "$privcar" 'Ótima pergunta, Arthur!'
sleep 3

echo ">>> Ana responde incorretamente..."
RESPPT3=$(postar "$PORTANA" 'Acho que é VI, sou nova aqui.' "$privana")
sleep 3

echo ">>> Ana recebe uma descurtida educativa..."
descurtir "$PORTCAR" "$RESPPT3" "$privcar" 'Sua resposta não é válida, mas vi que é uma novata. Ganhará deslike para fins de crescimento'
sleep 3

echo "--- Reputação ---"
mostrar_reputacao

echo "--> Avançando uma semana no tempo..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1716184633 --port="$PORT" # 20/05/2024
done

echo ">>> Carla posta uma pergunta..."
PT3=$(postar "$PORTCAR" 'Qual letra representa o número 3 em algaritmos Romanos?\nopcoes: A) I B) III C) V D) X' "$privcar")
sleep 3


echo ">>> Ana responde corretamente..."
RESPPT3=$(postar "$PORTANA" 'Acho que é B)III' "$privana")
sleep 3

PTROL2=$(postar "$PORTTROL" 'Sua mãe!!!' "$privtrol")
descurtir "$PORTCAR" "$PTROL2" "$privcar" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'
descurtir "$PORTLUC" "$PTROL2" "$privluca" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'

echo ">>> Ana recebe uma curtida..."
curtir "$PORTCAR" "$RESPPT3" "$privcar" 'Parabéns Ana!'
sleep 3

echo "--- Reputação ---"
mostrar_reputacao

echo "--> Avançando um mês no tempo..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1718863033 --port="$PORT" # 20/06/2024 (1º Mês)
done

echo ">>> Carla posta uma pergunta..."
PTCAR=$(postar "$PORTCAR" 'Qual é a capital do Brasil: A) Rio de Janeiro B) Paris C)Brasília D) Lisboa' "$privcar")
sleep 3

echo ">>> Arthur responde errado..."
RART=$(postar "$PORTARTH" 'B) Paris' "$privarth")
sleep 3

echo ">>> Ana responde certo..."
RANA=$(postar "$PORTANA" 'C)Brasília ' "$privana")
sleep 3

echo ">>> Carla curte a resposta de Ana..."
curtir "$PORTCAR" "$RANA" "$privcar" 'Parabéns Ana, você acertou'
sleep 3

mostrar_reputacao

echo "--> Avançando uma semana no tempo..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1719467833 --port="$PORT" # 27/06/2024 (uma semana depois)
done

echo ">>> Carla posta uma pergunta..."
PTCAR2=$(postar "$PORTCAR" 'Qual letra representa o número 10 em algaritmos Romanos?: A) I B) III C) V D) X' "$privcar")
sleep 3


echo ">>> Troll responde incorretamente..."
RESPPTCAR2=$(postar "$PORTTROL" 'Acho que é mané' "$privtrol")
sleep 3

descurtir "$PORTCAR" "$RESPPTCAR2" "$privcar" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'
descurtir "$PORTLUC" "$RESPPTCAR2" "$privluca" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'


echo ">>> Ana responde certo"

RESPPTANA=$(postar "$PORTANA" 'Letra D) X' "$privana")

echo ">>> Ana recebe uma curtida..."
curtir "$PORTCAR" "$RESPPTANA" "$privcar" 'Parabéns Ana!'
sleep 3

echo "--- Reputação ---"
mostrar_reputacao


echo "--> Avançando um mês no tempo..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1722059833 --port="$PORT" # 27/07/2024 (1º Mês)
done

echo ">>> Arthur posta uma pergunta..."
PTCAR2=$(postar "$PORTARTH" 'Qual é a capital de Portugal: A) Rio de Janeiro B) Paris C)Brasília D) Lisboa' "$privarth")
sleep 3

echo ">>> Ana responde errado..."
RANA4=$(postar "$PORTANA" 'B) Paris' "$privana")
sleep 3

echo ">>> Lucas responde certo..."
RLUC3=$(postar "$PORTLUC" 'D)Lisboa ' "$privluc")
sleep 3

echo ">>> Carla curte a resposta de Lucas..."
curtir "$PORTCAR" "$RLUC3" "$privcar" 'Parabéns Lucas, você acertou'
sleep 3

mostrar_reputacao

echo "--> Avançando uma semana no tempo..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1722664633 --port="$PORT" # 3/08/2024 (uma semana depois)
done

echo ">>> Carla posta uma pergunta..."
PTCAR5=$(postar "$PORTCAR" 'Qual letra representa o número 1 em algaritmos Romanos?: A) I B) III C) V D) X' "$privcar")
sleep 3


echo ">>> Troll responde incorretamente..."
RESPPTROL2=$(postar "$PORTTROL" 'Acho que é manézaço' "$privtrol")
sleep 3

descurtir "$PORTCAR" "$RESPPTROL2" "$privcar" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'
descurtir "$PORTLUC" "$RESPPTROL2" "$privluca" 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'


echo ">>> Ana responde certo"

RESPPTANA3=$(postar "$PORTANA" 'Letra A) I' "$privana")

echo ">>> Ana recebe uma curtida..."
curtir "$PORTCAR" "$RESPPTANA3" "$privcar" 'Parabéns Ana!'
sleep 3

echo "--- Reputação ---"
mostrar_reputacao

echo "--> Avançando mais um mês no tempo..."
for PORT in "${PORTS[@]}"; do
  ../freechains-host now 1725343033 --port="$PORT" # 3/09/2024 (3° Mês)
done

echo ">>> Arthur posta uma pergunta..."
PTLUC5=$(postar "$PORTLUC" 'Qual é a capital da Alemanha: A) Berlim B) Paris C)Brasília D) Lisboa' "$privluc")
sleep 3


echo ">>> Arthur responde certo..."
RLARTH5=$(postar "$PORTARTH" 'A)Berlim ' "$privarth")
sleep 3

echo ">>> Carla curte a resposta de Arthur..."
curtir "$PORTCAR" "$RLARTH5" "$privcar" 'Parabéns Arthur, você acertou'
sleep 3

mostrar_reputacao

echo "====== Finalizando a simulação======"

for PORT in "${PORTS[@]}"; do
  ../freechains-host stop --port=$PORT
  # Tempo para os hosts encerrarem
  sleep 3
done


echo "====== Simulação Concluída! ======"

# CORREÇÃO: A chave '}' extra que causava o erro de sintaxe foi removida daqui.
