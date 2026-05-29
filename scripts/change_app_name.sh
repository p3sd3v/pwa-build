#!/bin/bash

# =============================================================================
# Script para alterar o nome do aplicativo em Android, iOS e macOS
# =============================================================================
# Uso: ./change_app_name.sh <nome_do_app>
#      APPNAME="Meu App" ./change_app_name.sh
#
# Parâmetros:
#   nome_do_app   Nome do aplicativo (ex: "Meu App" ou "MeuApp")
#                   Também aceita a variável de ambiente APPNAME (mesma do Android)
#
# Exemplos:
#   ./change_app_name.sh "Meu Aplicativo"
#   ./change_app_name.sh MeuApp
#   APPNAME="Meu App" ./change_app_name.sh
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Diretório raiz do projeto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Arquivos
ANDROID_MANIFEST="$PROJECT_ROOT/android/app/src/main/AndroidManifest.xml"
IOS_INFO_PLIST="$PROJECT_ROOT/ios/Runner/Info.plist"
IOS_APP_NAME_XCCONFIG="$PROJECT_ROOT/ios/Flutter/AppName.xcconfig"
MACOS_APP_INFO="$PROJECT_ROOT/macos/Runner/Configs/AppInfo.xcconfig"
ENV_PROD_FILE="$PROJECT_ROOT/envs/.env.prod"

# Funções de log
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCESSO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

# Escapa caracteres especiais para uso em sed
escape_for_sed() {
    echo "$1" | sed 's/[&/\]/\\&/g'
}

# Escapa aspas duplas para uso em arquivos xcconfig/plist
escape_for_double_quotes() {
    echo "$1" | sed 's/"/\\"/g'
}

# Função para exibir ajuda
show_help() {
    echo ""
    echo -e "${CYAN}=========================================="
    echo "  Alterar Nome do Aplicativo"
    echo -e "==========================================${NC}"
    echo ""
    echo "Uso: $0 <nome_do_app>"
    echo "     APPNAME=\"Meu App\" $0"
    echo ""
    echo "Parâmetros:"
    echo "  nome_do_app   Nome do aplicativo (ex: \"Meu App\")"
    echo "  APPNAME       Variável de ambiente alternativa (mesma usada no Android)"
    echo ""
    echo -e "${YELLOW}Exemplos:${NC}"
    echo "  $0 \"Meu Aplicativo\""
    echo "  $0 MeuApp"
    echo "  APPNAME=\"Meu App\" $0"
    echo ""
    echo "Este script altera o nome do app em:"
    echo "  - Android: APPNAME em envs/.env.prod (via @string/app_name no build)"
    echo "  - iOS: AppName.xcconfig (APP_DISPLAY_NAME) + Info.plist"
    echo "  - macOS: AppInfo.xcconfig (PRODUCT_NAME)"
    echo ""
}

# Função para exibir nomes atuais
show_current_names() {
    echo ""
    log_info "Nomes atuais:"
    
    # Android
    if [[ -f "$ANDROID_MANIFEST" ]]; then
        local android_label=$(grep -o 'android:label="[^"]*"' "$ANDROID_MANIFEST" | head -1 | sed 's/android:label="\([^"]*\)"/\1/')
        local android_env_name="N/A"
        if [[ -f "$ENV_PROD_FILE" ]]; then
            android_env_name=$(grep "^APPNAME=" "$ENV_PROD_FILE" 2>/dev/null | head -1 | sed "s/^APPNAME=//; s/^'//; s/'$//")
        fi
        echo -e "  ${BLUE}Android (label):${NC} $android_label"
        echo -e "  ${BLUE}Android (APPNAME):${NC} $android_env_name"
    fi
    
    # iOS
    if [[ -f "$IOS_APP_NAME_XCCONFIG" ]]; then
        local ios_display_name=$(grep "^APP_DISPLAY_NAME" "$IOS_APP_NAME_XCCONFIG" | sed 's/^APP_DISPLAY_NAME = //; s/^"\(.*\)"$/\1/')
        echo -e "  ${BLUE}iOS (Display):${NC} $ios_display_name"
    elif [[ -f "$IOS_INFO_PLIST" ]]; then
        local ios_display_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$IOS_INFO_PLIST" 2>/dev/null || echo "N/A")
        echo -e "  ${BLUE}iOS (Display):${NC} $ios_display_name"
    fi
    
    # macOS
    if [[ -f "$MACOS_APP_INFO" ]]; then
        local macos_name=$(grep "^PRODUCT_NAME" "$MACOS_APP_INFO" | sed 's/PRODUCT_NAME = //')
        echo -e "  ${BLUE}macOS:${NC} $macos_name"
    fi
    
    echo ""
}

# Atualiza ou adiciona variável em envs/.env.prod
update_env_var() {
    local var_name="$1"
    local var_value="$2"
    local env_file="$3"

    if [[ ! -f "$env_file" ]]; then
        touch "$env_file"
    fi

    if grep -q "^${var_name}=" "$env_file"; then
        sed -i '' "s|^${var_name}=.*|${var_name}='${var_value}'|" "$env_file"
    else
        # Garante quebra de linha antes de adicionar nova variável
        if [[ -s "$env_file" ]] && [[ -n "$(tail -c 1 "$env_file" 2>/dev/null)" ]]; then
            echo "" >> "$env_file"
        fi
        echo "${var_name}='${var_value}'" >> "$env_file"
    fi
}

# Função para alterar nome no Android
change_android_name() {
    local new_name="$1"
    
    log_info "Alterando nome no Android..."
    
    # Mantém @string/app_name no manifest (flavors leem APPNAME no build)
    if [[ -f "$ANDROID_MANIFEST" ]]; then
        if ! grep -q 'android:label="@string/app_name"' "$ANDROID_MANIFEST"; then
            local escaped_name
            escaped_name=$(escape_for_sed "$new_name")
            sed -i '' "s/android:label=\"[^\"]*\"/android:label=\"@string/app_name\"/" "$ANDROID_MANIFEST"
            log_info "AndroidManifest.xml restaurado para usar @string/app_name"
        fi
    else
        log_warning "Arquivo AndroidManifest.xml não encontrado"
    fi

    update_env_var "APPNAME" "$new_name" "$ENV_PROD_FILE"
    log_success "APPNAME atualizado em envs/.env.prod"
}

# Função para alterar nome no iOS
change_ios_name() {
    local new_name="$1"
    local escaped_name
    escaped_name=$(escape_for_double_quotes "$new_name")
    
    log_info "Alterando nome no iOS..."
    
    if [[ -f "$IOS_APP_NAME_XCCONFIG" ]]; then
        sed -i '' "s/^APP_DISPLAY_NAME = .*/APP_DISPLAY_NAME = \"${escaped_name}\"/" "$IOS_APP_NAME_XCCONFIG"
        log_success "AppName.xcconfig (iOS) atualizado"
    else
        log_warning "Arquivo AppName.xcconfig não encontrado"
    fi

    if [[ -f "$IOS_INFO_PLIST" ]]; then
        # Garante que Info.plist usa a variável de build (fonte de verdade no compile time)
        if ! grep -q '<string>\$(APP_DISPLAY_NAME)</string>' "$IOS_INFO_PLIST"; then
            /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName \"${escaped_name}\"" "$IOS_INFO_PLIST" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string \"${escaped_name}\"" "$IOS_INFO_PLIST"
            log_warning "Info.plist atualizado diretamente (recomendado: usar \$(APP_DISPLAY_NAME))"
        else
            log_success "Info.plist (iOS) usa \$(APP_DISPLAY_NAME) do xcconfig"
        fi
    else
        log_warning "Arquivo Info.plist (iOS) não encontrado"
    fi
}

# Função para alterar nome no macOS
change_macos_name() {
    local new_name="$1"
    local escaped_name
    escaped_name=$(escape_for_sed "$new_name")
    
    log_info "Alterando nome no macOS..."
    
    if [[ -f "$MACOS_APP_INFO" ]]; then
        sed -i '' "s/^PRODUCT_NAME = .*/PRODUCT_NAME = ${escaped_name}/" "$MACOS_APP_INFO"
        log_success "AppInfo.xcconfig (macOS) atualizado"
    else
        log_warning "Arquivo AppInfo.xcconfig não encontrado"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo -e "${CYAN}=========================================="
echo "  Alterar Nome do Aplicativo"
echo -e "==========================================${NC}"

# Aceita argumento ou variável APPNAME (mesma convenção do Android)
NEW_APP_NAME="${1:-$APPNAME}"

# Verificar se foi passado argumento
if [[ -z "$NEW_APP_NAME" ]]; then
    show_current_names
    show_help
    exit 1
fi

log_info "Novo nome do app: $NEW_APP_NAME"

# Mostrar nomes atuais
show_current_names

# Executar alterações
change_android_name "$NEW_APP_NAME"
change_ios_name "$NEW_APP_NAME"
change_macos_name "$NEW_APP_NAME"

echo ""
log_success "Nome do aplicativo alterado com sucesso!"

# Mostrar novos nomes
show_current_names

log_warning "Lembre-se de:"
echo "  1. Executar 'flutter clean' antes de compilar novamente"
echo "  2. O nome fica salvo em envs/.env.prod e ios/Flutter/AppName.xcconfig"
echo "  3. No Codemagic, defina APPNAME ou rode este script no pre-build"
echo "  4. Desinstale o app antigo do dispositivo antes de reinstalar"
echo ""
