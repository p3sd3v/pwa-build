#!/bin/bash

# =============================================================================
# Script para gerar chave JKS de assinatura (Upload Keystore)
# =============================================================================
# Uso: ./generate_keystore.sh [opções]
#
# Opções:
#   --name <nome>       Nome do arquivo keystore (padrão: upload-keystore.jks)
#   --alias <alias>     Alias da chave (padrão: upload)
#   --pass <senha>      Senha da chave/store (se não fornecida, gera aleatória)
#   --cn <nome>         Nome e Sobrenome (CN)
#   --ou <unidade>      Unidade Organizacional (OU)
#   --o <org>           Organização (O)
#   --l <cidade>        Cidade/Localidade (L)
#   --st <estado>       Estado/Província (ST)
#   --c <pais>          Código do País (C)
#   --output <dir>      Diretório de saída (padrão: android/app ou atual)
#
# Exemplo:
#   ./generate_keystore.sh --name my-key.jks --alias my-alias --pass 123456
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Valores Padrão
KEYSTORE_NAME=""
ALIAS="upload"
PASSWORD=""
VALIDITY=10000
KEY_SIZE=2048
KEY_ALG="RSA"

# Inicializar variáveis do DNAME vazias
CN=""
OU=""
O=""
L=""
ST=""
C=""

# Diretório raiz
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_DIR="$PROJECT_ROOT/android/app"

# Se o diretório android/app não existir, usa o diretório atual como fallback inicial
if [ ! -d "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$PWD"
fi

# Parse de argumentos
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --name) KEYSTORE_NAME="$2"; shift ;;
        --alias) ALIAS="$2"; shift ;;
        --pass) PASSWORD="$2"; shift ;;
        --cn) CN="$2"; shift ;;
        --ou) OU="$2"; shift ;;
        --o) O="$2"; shift ;;
        --l) L="$2"; shift ;;
        --st) ST="$2"; shift ;;
        --c) C="$2"; shift ;;
        --output) OUTPUT_DIR="$2"; shift ;;
        *) echo "Opção desconhecida: $1"; exit 1 ;;
    esac
    shift
done

if [ -z "$KEYSTORE_NAME" ]; then
    KEYSTORE_NAME="${ALIAS}.jks"
fi

# Funções de log
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCESSO]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; }

# Verificar se keytool está instalado e openssl (opcional para senha)
if ! command -v keytool &> /dev/null; then
    log_error "keytool não encontrado. Por favor, instale o JDK."
    exit 1
fi

echo ""
echo -e "${CYAN}=========================================="
echo "  Gerador de Keystore Android (JKS)"
echo -e "==========================================${NC}"
echo ""

# Gerar senha se não fornecida
if [ -z "$PASSWORD" ]; then
    log_info "Nenhuma senha fornecida. Gerando senha segura aleatória..."
    if command -v openssl &> /dev/null; then
        # Gera 24 bytes -> ~32 chars base64
        PASSWORD=$(openssl rand -base64 24)
    else
        # Fallback se openssl não existir
        PASSWORD=$(date +%s%N | sha256sum | head -c 32)
    fi
    log_success "Senha gerada: $PASSWORD"
fi

# Construir DNAME
DNAME="CN=${CN:-Unknown}, OU=${OU:-Unknown}, O=${O:-Unknown}, L=${L:-Unknown}, ST=${ST:-Unknown}, C=${C:-Unknown}"

# Garantir diretório de saída
mkdir -p "$OUTPUT_DIR"

OUTPUT_FILE="$OUTPUT_DIR/$KEYSTORE_NAME"
INFO_FILE="$OUTPUT_DIR/${ALIAS}-info.md"

# Verificar se arquivo já existe
if [ -f "$OUTPUT_FILE" ]; then
    log_warning "O arquivo $OUTPUT_FILE já existe."
    if [ -t 0 ]; then
        read -p "Deseja sobrescrever? (y/N): " OVERWRITE
        if [[ "$OVERWRITE" != "y" && "$OVERWRITE" != "Y" ]]; then
            log_info "Operação cancelada."
            exit 0
        fi
        rm "$OUTPUT_FILE"
    else
        log_error "Arquivo já existe e input não interativo. Abortando."
        exit 1
    fi
fi

log_info "Gerando keystore em: $OUTPUT_FILE"
log_info "Alias: $ALIAS"
log_info "DNAME: $DNAME"

# Gerar a chave
keytool -genkeypair -v -keystore "$OUTPUT_FILE" \
    -alias "$ALIAS" \
    -keyalg "$KEY_ALG" \
    -keysize "$KEY_SIZE" \
    -validity "$VALIDITY" \
    -storepass "$PASSWORD" \
    -keypass "$PASSWORD" \
    -dname "$DNAME" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    log_success "Keystore gerada com sucesso!"
    
    # Extrair Fingerprints
    FINGERPRINTS=$(keytool -list -v -keystore "$OUTPUT_FILE" -alias "$ALIAS" -storepass "$PASSWORD")
    
    SHA1=$(echo "$FINGERPRINTS" | grep -Ei "SHA1:" | head -n 1 | sed 's/.*SHA1: //I')
    SHA256=$(echo "$FINGERPRINTS" | grep -Ei "SHA256:" | head -n 1 | sed 's/.*SHA256: //I')
    
    # Gerar arquivo MD com informações
    {
        echo "# Informações da Keystore Android"
        echo ""
        echo "Gerado em: $(date)"
        echo ""
        echo "## Arquivo"
        echo "- **Caminho:** \`$OUTPUT_FILE\`"
        echo "- **Nome:** \`$KEYSTORE_NAME\`"
        echo ""
        echo "## Credenciais"
        echo "- **Alias:** \`$ALIAS\`"
        echo "- **Store Password:** \`$PASSWORD\`"
        echo "- **Key Password:** \`$PASSWORD\`"
        echo ""
        echo "## Fingerprints (Assinaturas)"
        echo "Úteis para configuração de API Google, Firebase, Facebook Login, etc."
        echo ""
        echo "### SHA-1"
        echo "\`\`\`"
        echo "${SHA1:-Não encontrado}"
        echo "\`\`\`"
        echo ""
        echo "### SHA-256"
        echo "\`\`\`"
        echo "${SHA256:-Não encontrado}"
        echo "\`\`\`"
        echo ""
        echo "## Configuração key.properties"
        echo "Para usar no build do Flutter/Android, adicione ao arquivo \`android/key.properties\`:"
        echo ""
        echo "\`\`\`properties"
        echo "storePassword=$PASSWORD"
        echo "keyPassword=$PASSWORD"
        echo "keyAlias=$ALIAS"
        echo "storeFile=$KEYSTORE_NAME"
        echo "\`\`\`"
    } > "$INFO_FILE"

    log_success "Arquivo de informações gerado: $INFO_FILE"
    echo ""
    echo -e "${CYAN}Conteúdo do arquivo MD gerado:${NC}"
    cat "$INFO_FILE"
else
    log_error "Falha ao gerar a keystore."
    exit 1
fi
