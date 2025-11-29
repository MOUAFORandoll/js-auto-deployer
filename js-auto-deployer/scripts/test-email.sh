#!/bin/bash

# JS Auto Deployer - Test Email
# Version: 1.0.0
# Description: Script pour tester la configuration email

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_DIR="/etc/js-auto-deployer/config"

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Chargement de la configuration
load_config() {
    local config_file="$CONFIG_DIR/deploy.yml"
    
    if [ ! -f "$config_file" ]; then
        print_error "Fichier de configuration non trouvé: $config_file"
        print_info "Créez-le depuis le template: cp $CONFIG_DIR/deploy.yml.template $config_file"
        exit 1
    fi
    
    # Extraire les valeurs depuis le YAML
    DEPLOY_EMAIL_TO=$(grep -E "^email:" -A 5 "$config_file" | grep "to:" | sed 's/.*to:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "")
    DEPLOY_EMAIL_FROM=$(grep -E "^email:" -A 5 "$config_file" | grep "from:" | sed 's/.*from:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "")
    
    if [ -z "$DEPLOY_EMAIL_TO" ]; then
        print_error "Email destinataire non configuré dans $config_file"
        exit 1
    fi
}

# Test simple
test_simple() {
    print_info "Test simple d'envoi d'email..."
    
    if [ -z "$DEPLOY_EMAIL_TO" ]; then
        print_error "Aucun destinataire configuré"
        exit 1
    fi
    
    if ! command -v msmtp &> /dev/null; then
        print_error "msmtp n'est pas installé"
        exit 1
    fi
    
    echo "Test JS Auto Deployer - $(date)" | msmtp "$DEPLOY_EMAIL_TO"
    
    if [ $? -eq 0 ]; then
        print_success "Email de test envoyé avec succès à $DEPLOY_EMAIL_TO"
    else
        print_error "Échec de l'envoi d'email"
        exit 1
    fi
}

# Test avec rapport HTML
test_html() {
    print_info "Test d'envoi de rapport HTML..."
    
    local html_content='
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Test JS Auto Deployer</title>
</head>
<body>
    <h1 style="color: green;">✅ Test de Configuration Email</h1>
    <p>Votre configuration SMTP pour JS Auto Deployer fonctionne correctement !</p>
    <p><strong>Date du test:</strong> '"$(date)"'</p>
</body>
</html>'
    
    (
        echo "Subject: [JS Auto Deployer] Test de Configuration Email"
        echo "From: $DEPLOY_EMAIL_FROM"
        echo "To: $DEPLOY_EMAIL_TO"
        echo "Content-Type: text/html; charset=UTF-8"
        echo ""
        echo "$html_content"
    ) | msmtp "$DEPLOY_EMAIL_TO" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Email HTML envoyé avec succès"
    else
        print_error "Échec de l'envoi d'email HTML"
        exit 1
    fi
}

# Affichage de l'aide
show_help() {
    cat <<EOF
JS Auto Deployer - Test Email

Usage: js-test-email [OPTIONS]

OPTIONS:
    --simple        Test d'email simple (défaut)
    --html          Test avec rapport HTML
    --help          Afficher cette aide

EXAMPLES:
    js-test-email
    js-test-email --html
EOF
}

# Fonction principale
main() {
    local test_type="${1:---simple}"
    
    echo -e "${BLUE}JS Auto Deployer - Test Email${NC}"
    echo ""
    
    load_config
    
    case $test_type in
        --simple)
            test_simple
            ;;
        --html)
            test_html
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Option inconnue: $test_type"
            show_help
            exit 1
            ;;
    esac
}

# Exécution
main "$@"