#!/bin/bash
set -e

#  Limpeza (caso esteja rodando de novo)
rm -rf /tmp/node-*

PORTTUT=8333
PORTCAR=8334
PORTLUC=8335
PORTANA=8336
PORTTROL=8337

PORTS=($PORTUT $PORTCAR $PORTLUC $PORTANA $PORTTROL)

atualizar(){ #atualiza os nós
    for PORT in $PORTS;do
    ../freechains --port=$1 peer $1 send '#quiz'
    done
}

postar(){ # posta e atualiza mensagem: -$1 port -$2 mensagem -$3 chave privada
    Hashe=$(../freechains --port=$1 chain '#quiz' post inline $2 --sign="$3")
    atualizar $1
    return $Hashe
}

curtir(){ # Curtir mensagem -$1 port -$2 hashdestino -$3 chave privada -$4 mensagem
    ../freechains --port=$1 chain '#quiz' like "$2" --sign="$3" --why=$4
    atualizar $1 
}

descurtir(){ # Descurtir mensagem -$1 port -$2 destino -$3 chave privada -$4 mensagem
    ../freechains --port=$1 chain '#quiz' dislike "$2" --sign="$3" --why=$4
    atualizar $1 
}

#  Inicia os nós com portas distintas
../freechains-host start /tmp/node-tutorial --port=$PORTTUT &
../freechains-host start /tmp/node-carla --port=$PORTCAR &                                             
../freechains-host start /tmp/node-lucas --port=$PORTLUC &
../freechains-host start /tmp/node-ana   --port=$PORTANA &
../freechains-host start /tmp/node-troll --port=$PORTTROL &
sleep 1

echo "====== Nós iniciados ======"


#  Todos entram no canal #quiz, tutorial é dono provisório do canal (ele fica lá até alguém ter bastante reputação para fazer esse papel e caso alguém queira voltar a postar na chain)

echo "========== criando chaves públicas e privadas======"

read -r pubtut privtut < <(../freechains --port=$PORTTUT keys pubpvt 'tutorial') #tutorial
read -r pubcar privcar < <(../freechains --port=$PORTCAR keys pubpvt 'carla') # Ativa
read -r publuca privluca < <(../freechains --port=$PORTLUC keys pubpvt 'lucas') # Ativo
read -r pubana privana < <(../freechains --port=$PORTANA keys pubpvt 'ana') #Newbie
read -r pubtrol privtrol < <(../freechains --port=$PORTTROL keys pubpvt 'troll') #troll

sleep 2

echo 'todos entrando no canal, primeiro o tutorial'

../freechains --port=8833 chains join '#quiz' $pubtut)
../freechains --port=8834 chains join '#quiz' $pubtut)
../freechains --port=8835 chains join '#quiz' $pubtut)
../freechains --port=8836 chains join '#quiz' $pubtut)
../freechains --port=8837 chains join '#quiz' $pubtut)


sleep 5
#

#  Simula passagem de tempo (mesmo timestamp para todos)
for PORT in $PORTS; do
  ../freechains-host now 1715000000 --port=$PORT # 6/05/2024
done

sleep 4

echo 'primeira pergunta'

# Tutorial posta a primeira pergunta
PT1=postar $PORTUT 'Sou o tutorial, farei as perguntas até vocês terem reputação para poder criarem as suas perguntas (0-3 de reputação, resposta. 4-6 criar perguntas, 7+ pode blockear pergunta não permitida, perguntar e responder e avaliar pergunta). Primeira pergunta: Qual é a capital da França?
opcoes: A) Berlim B) Paris C) Roma D) Lisboa' $privtut


sleep 5



echo 'Carla responde certo'


RC1=postar $PORTCAR 'B) Paris' $privcar


echo 'Ana ganha parabéns em forma de curtida'

curtir $PORTTUT $RC1 $privtut 'Parabéns Carla, você acertou'
 

for PORT in $PORTS; do
  ../freechains-host now 1715605200 --port=$PORT # 13/05/2024 Uma semana depois
done


PT2=postar $PORTTUT 'Qual o nome da capital do Brasil atualmente?  Opções: A) Rio de Janeiro B)Fortaleza C)Brasília D)Porto Alegre' $privtut

PTROL=postar $PORTTROL 'Sua mãe!!!' $privtrol

descurtir $PORTTUT $PTROL $privtut 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike'

descurtir $PORTCAR $PTROL $privcar 'Sua resposta não é válida e tem cunho pejorativo. Ganhará deslike também'


#  Mostra reputações
echo "==== Reputações ===="
echo "@carla:" $(../freechains --port=8334 chain '#quiz' reps "$pubcar")
echo "@lucas:" $(../freechains --port=8335 chain '#quiz 'reps "$publuca")
echo "@ana:"   $(../freechains --port=8336 chain '#quiz 'reps "$pubana")
echo "@troll:" $(../freechains --port=8337 chain '#quiz 'reps "$pubtrol")

