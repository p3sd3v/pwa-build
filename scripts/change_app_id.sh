#!/bin/bash

# =============================================================================
# Script para alterar o Package ID (Android) e Bundle ID (iOS/macOS)
# =============================================================================
# Uso: ./change_app_id.sh <novo_app_id>
# Exemplo: ./change_app_id.sh com.minhaempresa.meuapp
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
    local kotlin_base="$PROJECT_ROOT/android/app/src/main/kotlin"
    local java_base="$PROJECT_ROOT/android/app/src/main/java"
    
    log_info "Alterando Package ID no Android..."
    
    if [[ -f "$gradle_file" ]]; then
        # Obtém o package ID atual do build.gradle.kts
        local old_id=$(grep -o 'applicationId = "[^"]*"' "$gradle_file" | sed 's/applicationId = "\(.*\)"/\1/')
        
        if [[ -z "$old_id" ]]; then
            log_warning "Não foi possível detectar o applicationId atual"
            old_id="com.example.pwa_build"
        fi
        
        log_info "Package ID atual: $old_id"
        
        # Altera o namespace
        sed -i '' "s/namespace = \"[^\"]*\"/namespace = \"$new_id\"/" "$gradle_file"
        # Altera o applicationId
        sed -i '' "s/applicationId = \"[^\"]*\"/applicationId = \"$new_id\"/" "$gradle_file"
        log_success "Android build.gradle.kts atualizado"
        
        # Converte package ID para path (com.example.app -> com/example/app)
        local old_path="${old_id//.//}"
        local new_path="${new_id//.//}"
        
        # Atualiza MainActivity.kt (Kotlin)
        local kotlin_main_activity="$kotlin_base/$old_path/MainActivity.kt"
        if [[ -f "$kotlin_main_activity" ]]; then
            # Atualiza o package declaration no arquivo
            sed -i '' "s/^package $old_id$/package $new_id/" "$kotlin_main_activity"
            log_success "MainActivity.kt (Kotlin) - package declaration atualizado"
            
            # Cria nova estrutura de diretórios
            mkdir -p "$kotlin_base/$new_path"
            
            # Move o arquivo para a nova estrutura
            mv "$kotlin_main_activity" "$kotlin_base/$new_path/MainActivity.kt"
            log_success "MainActivity.kt movido para $kotlin_base/$new_path/"
            
            # Remove diretórios vazios antigos
            local old_dir="$kotlin_base/$old_path"
            while [[ "$old_dir" != "$kotlin_base" ]]; do
                if [[ -d "$old_dir" ]] && [[ -z "$(ls -A "$old_dir")" ]]; then
                    rmdir "$old_dir"
                fi
                old_dir=$(dirname "$old_dir")
            done
            log_success "Diretórios antigos removidos"
        else
            log_warning "MainActivity.kt (Kotlin) não encontrado em $kotlin_main_activity"
        fi
        
        # Atualiza MainActivity.java (Java) se existir
        local java_main_activity="$java_base/$old_path/MainActivity.java"
        if [[ -f "$java_main_activity" ]]; then
            # Atualiza o package declaration no arquivo
            sed -i '' "s/^package $old_id;$/package $new_id;/" "$java_main_activity"
            log_success "MainActivity.java - package declaration atualizado"
            
            # Cria nova estrutura de diretórios
            mkdir -p "$java_base/$new_path"
            
            # Move o arquivo para a nova estrutura
            mv "$java_main_activity" "$java_base/$new_path/MainActivity.java"
            log_success "MainActivity.java movido para $java_base/$new_path/"
            
            # Remove diretórios vazios antigos
            local old_dir="$java_base/$old_path"
            while [[ "$old_dir" != "$java_base" ]]; do
                if [[ -d "$old_dir" ]] && [[ -z "$(ls -A "$old_dir")" ]]; then
                    rmdir "$old_dir"
                fi
                old_dir=$(dirname "$old_dir")
            done
        fi
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
    echo "Uso: $0 <novo_app_id>"
    echo ""
    echo "Argumentos:"
    echo "  novo_app_id    O novo identificador da aplicação (ex: com.minhaempresa.meuapp)"
    echo ""
    echo "Exemplos:"
    echo "  $0 com.minhaempresa.meuaplicativo"
    echo "  $0 br.com.empresa.app"
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

# Validar formato do App ID
validate_app_id "$NEW_APP_ID"

log_info "Novo App ID: $NEW_APP_ID"
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

# Executar alterações
change_android_package_id "$NEW_APP_ID"
change_ios_bundle_id "$NEW_APP_ID"
change_macos_bundle_id "$NEW_APP_ID"

echo ""
log_success "Alteração concluída!"
echo ""

# Mostrar novos IDs
log_info "Novos IDs configurados:"
show_current_ids

log_warning "Lembre-se de:"
echo "  1. Executar 'flutter clean' antes de compilar novamente"
echo "  2. Para iOS/macOS, execute 'cd ios && pod install' (ou 'cd macos && pod install')"
echo "  3. Atualizar o 'package_name' no google-services.json (Android Firebase)"
echo "  4. Atualizar o 'BUNDLE_ID' no GoogleService-Info.plist (iOS Firebase)"
echo "  5. Ou re-configurar o Firebase com: flutterfire configure"
echo ""
