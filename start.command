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
# NODE LOCAL
# --------------------------------------------------

echo "🔎 Verificando ambiente..."

RUNTIME_DIR="$PROJECT_DIR/.runtime"
NODE_DIR="$RUNTIME_DIR/node-v$NODE_VERSION"

if [ ! -x "$NODE_DIR/bin/node" ]; then
    ARCH="$(uname -m)"

    case "$ARCH" in
        arm64)
            NODE_ARCH="arm64"
            ;;
        x86_64)
            NODE_ARCH="x64"
            ;;
        *)
            echo "❌ Este Mac usa uma arquitetura não suportada: $ARCH"
            echo "Peça ajuda ao Leandro."
            echo ""
            read -p "Pressione Enter para fechar..."
            exit 1
            ;;
    esac

    NODE_PACKAGE="node-v$NODE_VERSION-darwin-$NODE_ARCH"
    NODE_URL="https://nodejs.org/dist/v$NODE_VERSION/$NODE_PACKAGE.tar.gz"
    TEMP_FILE="$RUNTIME_DIR/node.tar.gz"

    echo "📦 Preparando Node.js $NODE_VERSION..."
    echo "Isso acontece somente na primeira execução."
    echo ""

    mkdir -p "$RUNTIME_DIR"

    if ! curl -fL "$NODE_URL" -o "$TEMP_FILE"; then
        echo ""
        echo "❌ Não foi possível baixar o Node.js."
        echo "Verifique a conexão com a internet e tente novamente."
        echo ""
        read -p "Pressione Enter para fechar..."
        exit 1
    fi

    if ! tar -xzf "$TEMP_FILE" -C "$RUNTIME_DIR"; then
        rm -f "$TEMP_FILE"
        echo ""
        echo "❌ Não foi possível preparar o Node.js."
        echo "Peça ajuda ao Leandro."
        echo ""
        read -p "Pressione Enter para fechar..."
        exit 1
    fi

    rm -f "$TEMP_FILE"
    mv "$RUNTIME_DIR/$NODE_PACKAGE" "$NODE_DIR"

    echo "✅ Node.js preparado."
fi

export PATH="$NODE_DIR/bin:$PATH"

echo "✅ Node.js $(node -v)"
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