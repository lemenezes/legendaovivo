#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$PROJECT_DIR/app"

NODE_VERSION="22.22.1"
PORT="8081"
URL="http://localhost:$PORT"

clear

echo "======================================"
echo "          LEGENDA AO VIVO"
echo "======================================"
echo ""

# --------------------------------------------------
# NVM
# --------------------------------------------------

export NVM_DIR="$HOME/.nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    source "$NVM_DIR/nvm.sh"
else
    echo "❌ NVM não foi encontrado."
    echo ""
    echo "É necessário fazer a configuração inicial."
    echo "Peça ajuda ao Leandro."
    echo ""
    read -p "Pressione Enter para fechar..."
    exit 1
fi

# --------------------------------------------------
# NODE
# --------------------------------------------------

echo "🔎 Verificando ambiente..."

if ! nvm ls "$NODE_VERSION" 2>/dev/null | grep -q "$NODE_VERSION"; then
    echo "📦 Instalando Node.js $NODE_VERSION..."
    nvm install "$NODE_VERSION"
fi

nvm use "$NODE_VERSION" >/dev/null

echo "✅ Node.js $NODE_VERSION"
echo ""

# --------------------------------------------------
# PROJETO
# --------------------------------------------------

cd "$APP_DIR"

# Cria .env somente na primeira execução
if [ ! -f ".env" ]; then
    if [ -f ".env.sample" ]; then
        echo "⚙️ Criando configuração inicial..."
        cp .env.sample .env
        echo "✅ Configuração criada."
        echo ""
    fi
fi

# Instala dependências somente na primeira execução
if [ ! -d "node_modules" ]; then
    echo "📦 Primeira execução."
    echo "Instalando dependências..."
    echo "Isso pode demorar alguns minutos."
    echo ""

    if npm install; then
        echo ""
        echo "✅ Dependências instaladas."
    else
        echo ""
        echo "❌ Não foi possível instalar as dependências."
        echo "Peça ajuda ao Leandro."
        echo ""
        read -p "Pressione Enter para fechar..."
        exit 1
    fi
else
    echo "✅ Dependências prontas."
fi

echo ""

# --------------------------------------------------
# PORTA
# --------------------------------------------------

if lsof -nP -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
    echo "❌ O Legenda ao Vivo já parece estar aberto."
    echo ""
    echo "A porta $PORT já está sendo utilizada."
    echo "Feche a outra janela do Legenda ao Vivo e tente novamente."
    echo ""
    read -p "Pressione Enter para fechar..."
    exit 1
fi

# --------------------------------------------------
# ABRIR CHROME QUANDO O SERVIDOR ESTIVER PRONTO
# --------------------------------------------------

(
    echo "⏳ Aguardando o servidor..."

    until curl -s "$URL" >/dev/null 2>&1; do
        sleep 1
    done

    echo ""
    echo "✅ Legenda ao Vivo está pronto!"
    echo "🌐 $URL"
    echo ""
    echo "Abrindo Google Chrome..."

    open -a "Google Chrome" "$URL"
) &

# --------------------------------------------------
# INICIAR
# --------------------------------------------------

echo "======================================"
echo "🚀 Iniciando Legenda ao Vivo..."
echo "======================================"
echo ""
echo "🌐 Endereço: $URL"
echo ""
echo "O Chrome abrirá automaticamente."
echo "Para encerrar, pressione Control + C."
echo ""

LOG_FILE="/tmp/legendaovivo.log"

PORT=$PORT npm run dev > "$LOG_FILE" 2>&1