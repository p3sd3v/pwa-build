#!/bin/bash

# =============================================================================
# Script para alterar o Package ID (Android) e Bundle ID (iOS/macOS)
# =============================================================================
# Uso: ./change_app_id.sh <novo_app_id> [plataforma]
#
# Argumentos:
#   novo_app_id (Obrigatório): O novo ID do app (ex: com.empresa.app)
#   plataforma  (Opcional): android, ios, macos, all
#
# Exemplos:
#   ./scripts/change_app_id.sh com.minhaempresa.meuapp        # Prompt interativo
#   ./scripts/change_app_id.sh br.com.empresa.app android     # Apenas Android
#   ./scripts/change_app_id.sh br.com.empresa.app all         # Todas as plataformas
# =============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório raiz do projeto (um nível acima de scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Função para exibir mensagens
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

# Função para validar o formato do app ID
validate_app_id() {
    local app_id="$1"
    # Regex para validar formato: com.exemplo.app ou similar
    if [[ ! "$app_id" =~ ^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$ ]]; then
        log_error "Formato de App ID inválido: $app_id"
        log_info "Use o formato: com.empresa.app (ex: com.minhaempresa.meuaplicativo)"
        exit 1
    fi
}

# Função para alterar Android package ID
change_android_package_id() {
    local new_id="$1"
    local gradle_file="$PROJECT_ROOT/android/app/build.gradle.kts"
    
    log_info "Alterando Package ID no Android..."
    
    if [[ -f "$gradle_file" ]]; then
        # Altera o namespace
        sed -i '' "s/namespace = \"[^\"]*\"/namespace = \"$new_id\"/" "$gradle_file"
        # Altera o applicationId
        sed -i '' "s/applicationId = \"[^\"]*\"/applicationId = \"$new_id\"/" "$gradle_file"
        log_success "Android build.gradle.kts atualizado"
    else
        log_warning "Arquivo $gradle_file não encontrado"
    fi
}

# Função para alterar iOS bundle ID
change_ios_bundle_id() {
    local new_id="$1"
    local ios_project="$PROJECT_ROOT/ios/Runner.xcodeproj/project.pbxproj"
    
    log_info "Alterando Bundle ID no iOS..."
    
    if [[ -f "$ios_project" ]]; then
        # Altera PRODUCT_BUNDLE_IDENTIFIER para Runner
        sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = $new_id;/g" "$ios_project"
        
        # Altera PRODUCT_BUNDLE_IDENTIFIER para RunnerTests
        sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.[^.]*\.[^.]*\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = $new_id.RunnerTests;/g" "$ios_project"
        
        log_success "iOS project.pbxproj atualizado"
    else
        log_warning "Arquivo $ios_project não encontrado"
    fi
}

# Função para alterar macOS bundle ID
change_macos_bundle_id() {
    local new_id="$1"
    local macos_project="$PROJECT_ROOT/macos/Runner.xcodeproj/project.pbxproj"
    local macos_appinfo="$PROJECT_ROOT/macos/Runner/Configs/AppInfo.xcconfig"
    
    log_info "Alterando Bundle ID no macOS..."
    
    # Atualiza project.pbxproj
    if [[ -f "$macos_project" ]]; then
        sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.[^;]*;/PRODUCT_BUNDLE_IDENTIFIER = $new_id;/g" "$macos_project"
        sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = com\.[^.]*\.[^.]*\.RunnerTests;/PRODUCT_BUNDLE_IDENTIFIER = $new_id.RunnerTests;/g" "$macos_project"
        log_success "macOS project.pbxproj atualizado"
    else
        log_warning "Arquivo $macos_project não encontrado"
    fi
    
    # Atualiza AppInfo.xcconfig
    if [[ -f "$macos_appinfo" ]]; then
        sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $new_id/" "$macos_appinfo"
        log_success "macOS AppInfo.xcconfig atualizado"
    else
        log_warning "Arquivo $macos_appinfo não encontrado"
    fi
}

# Função para exibir o uso do script
show_usage() {
    echo ""
    echo "Uso: $0 <novo_app_id> [plataforma]"
    echo ""
    echo "Argumentos:"
    echo "  novo_app_id    O novo identificador da aplicação (ex: com.minhaempresa.meuapp)"
    echo "  plataforma     (Opcional) A plataforma a ser atualizada: android, ios, macos, all"
    echo ""
    echo "Exemplos:"
    echo "  $0 com.minhaempresa.meuaplicativo"
    echo "  $0 br.com.empresa.app android"
    echo "  $0 br.com.empresa.app all"
    echo ""
    echo "Este script altera:"
    echo "  - Android: namespace e applicationId em android/app/build.gradle.kts"
    echo "  - iOS: PRODUCT_BUNDLE_IDENTIFIER em ios/Runner.xcodeproj/project.pbxproj"
    echo "  - macOS: PRODUCT_BUNDLE_IDENTIFIER em macos/Runner.xcodeproj/project.pbxproj"
    echo "          e macos/Runner/Configs/AppInfo.xcconfig"
    echo ""
}

# Função para exibir IDs atuais
show_current_ids() {
    log_info "IDs atuais:"
    echo ""
    
    # Android
    local gradle_file="$PROJECT_ROOT/android/app/build.gradle.kts"
    if [[ -f "$gradle_file" ]]; then
        local android_id=$(grep -o 'applicationId = "[^"]*"' "$gradle_file" | sed 's/applicationId = "\(.*\)"/\1/')
        echo -e "  ${BLUE}Android:${NC} $android_id"
    fi
    
    # iOS
    local ios_project="$PROJECT_ROOT/ios/Runner.xcodeproj/project.pbxproj"
    if [[ -f "$ios_project" ]]; then
        local ios_id=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "$ios_project" | grep -v "RunnerTests" | head -1 | sed 's/.*= \([^;]*\);/\1/')
        echo -e "  ${BLUE}iOS:${NC} $ios_id"
    fi
    
    # macOS
    local macos_appinfo="$PROJECT_ROOT/macos/Runner/Configs/AppInfo.xcconfig"
    if [[ -f "$macos_appinfo" ]]; then
        local macos_id=$(grep "PRODUCT_BUNDLE_IDENTIFIER" "$macos_appinfo" | sed 's/PRODUCT_BUNDLE_IDENTIFIER = //')
        echo -e "  ${BLUE}macOS:${NC} $macos_id"
    fi
    
    echo ""
}

# Função para selecionar a plataforma interativamente
select_platform() {
    echo "Selecione a plataforma para alterar o ID:"
    echo "  1) Android"
    echo "  2) iOS"
    echo "  3) macOS"
    echo "  4) Todas (All)"
    echo ""
    read -p "Opção [1-4] (padrão: 4): " platform_opt
    
    case $platform_opt in
        1) PLATFORM="android" ;;
        2) PLATFORM="ios" ;;
        3) PLATFORM="macos" ;;
        4|"") PLATFORM="all" ;;
        *) 
            log_error "Opção inválida!"
            exit 1 
            ;;
    esac
}

# =============================================================================
# MAIN
# =============================================================================

echo ""
echo "=========================================="
echo "  Alterar Package ID / Bundle ID"
echo "=========================================="
echo ""

# Verificar se foi passado argumento
if [[ -z "$1" ]]; then
    show_current_ids
    show_usage
    exit 1
fi

NEW_APP_ID="$1"
PLATFORM="$2"

# Validar formato do App ID
validate_app_id "$NEW_APP_ID"

log_info "Novo App ID: $NEW_APP_ID"

# Se a plataforma não foi passada, perguntar
if [[ -z "$PLATFORM" ]]; then
    select_platform
fi

# Normalizar plataforma para lowercase
PLATFORM=$(echo "$PLATFORM" | tr '[:upper:]' '[:lower:]')

log_info "Plataforma selecionada: $PLATFORM"
echo ""

# Mostrar IDs atuais
show_current_ids

# Confirmar alteração
read -p "Deseja continuar com a alteração? (s/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    log_warning "Operação cancelada pelo usuário"
    exit 0
fi

echo ""

# Executar alterações conforme a plataforma
case "$PLATFORM" in
    android)
        change_android_package_id "$NEW_APP_ID"
        ;;
    ios)
        change_ios_bundle_id "$NEW_APP_ID"
        ;;
    mac|macos)
        change_macos_bundle_id "$NEW_APP_ID"
        ;;
    all|tudos|todos)
        change_android_package_id "$NEW_APP_ID"
        change_ios_bundle_id "$NEW_APP_ID"
        change_macos_bundle_id "$NEW_APP_ID"
        ;;
    *)
        log_error "Plataforma desconhecida: $PLATFORM"
        show_usage
        exit 1
        ;;
esac

echo ""
log_success "Alteração concluída!"
echo ""

# Mostrar novos IDs
log_info "Novos IDs configurados:"
show_current_ids

log_warning "Lembre-se de:"
echo "  1. Executar 'flutter clean' antes de compilar novamente"
echo "  2. Para iOS/macOS, execute 'cd ios && pod install' (ou 'cd macos && pod install')"
echo "  3. Atualizar configurações de Firebase, Google Services, etc., se aplicável"
echo ""
