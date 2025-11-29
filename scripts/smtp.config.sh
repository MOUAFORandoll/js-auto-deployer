#!/bin/bash

# JS Auto Deployer - Configuration SMTP
# Version: 1.0.0
# Description: Assistant de configuration SMTP pour les notifications email

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_NAME="js-setup-email"
CONFIG_DIR="/etc/js-auto-deployer"
CONFIG_FILE="$CONFIG_DIR/config/deploy.yml"

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
}

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

# Vérification des permissions root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then 
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

# Détection du système d'exploitation
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        print_info "Système détecté: $OS"
    fi
}

# Installation de msmtp
install_msmtp() {
    print_info "Installation de msmtp..."
    
    case "$OS" in
        *"Ubuntu"*|*"Debian"*|*"Mint"*)
            apt-get update -qq
            apt-get install -y msmtp msmtp-mta ca-certificates mailutils
            ;;
        *"CentOS"*|*"Red Hat"*|*"Fedora"*)
            yum install -y msmtp mailx
            ;;
        *)
            print_error "Système non supporté. Installez msmtp manuellement."
            exit 1
            ;;
    esac
    
    print_success "msmtp installé"
}

# Configuration interactive
interactive_config() {
    print_header "Configuration SMTP Interactive"
    
    # Email de destination
    echo -n "Email de destination pour les notifications: "
    read -r DEPLOY_EMAIL_TO
    
    # Email d'expéditeur
    echo -n "Email d'expéditeur [deploy@votredomaine.com]: "
    read -r DEPLOY_EMAIL_FROM
    DEPLOY_EMAIL_FROM=${DEPLOY_EMAIL_FROM:-"deploy@votredomaine.com"}
    
    # Serveur SMTP
    echo -n "Serveur SMTP [mail.votredomaine.com]: "
    read -r SMTP_HOST
    SMTP_HOST=${SMTP_HOST:-"mail.votredomaine.com"}
    
    # Port SMTP
    echo -n "Port SMTP [465]: "
    read -r SMTP_PORT
    SMTP_PORT=${SMTP_PORT:-"465"}
    
    # Utilisateur SMTP
    echo -n "Utilisateur SMTP: "
    read -r SMTP_USER
    
    # Mot de passe SMTP
    echo -n "Mot de passe SMTP: "
    read -rs SMTP_PASS
    echo ""
    
    # Test de l'email
    echo -n "Email pour le test [same as destination]: "
    read -r TEST_EMAIL
    TEST_EMAIL=${TEST_EMAIL:-$DEPLOY_EMAIL_TO}
}

# Création de la configuration msmtp
create_msmtp_config() {
    print_info "Création de la configuration msmtp..."
    
    # Backup de la config existante
    if [ -f /etc/msmtprc ]; then
        local backup_name="/etc/msmtprc.backup.$(date +%Y%m%d-%H%M%S)"
        cp /etc/msmtprc "$backup_name"
        print_success "Configuration existante sauvegardée: $backup_name"
    fi
    
    # Création de la nouvelle configuration
    cat > /etc/msmtprc << EOF
# Configuration SMTP pour JS Auto Deployer
defaults
logfile /var/log/msmtp.log

account js-auto-deployer
host $SMTP_HOST
port $SMTP_PORT
from $DEPLOY_EMAIL_FROM
user $SMTP_USER
password $SMTP_PASS
auth on
tls on
tls_starttls off
tls_certcheck off

account default : js-auto-deployer
EOF
    
    # Sécurisation
    chmod 600 /etc/msmtprc
    chown root:root /etc/msmtprc
    
    # Créer le fichier de log
    touch /var/log/msmtp.log
    chmod 666 /var/log/msmtp.log
    
    # Liens symboliques
    ln -sf /usr/bin/msmtp /usr/sbin/sendmail 2>/dev/null || true
    ln -sf /usr/bin/msmtp /usr/bin/sendmail 2>/dev/null || true
    
    print_success "Configuration msmtp créée"
}

# Mise à jour de la configuration JS Auto
update_js_auto_deployer_config() {
    print_info "Mise à jour de la configuration JS Auto Deployer..."
    
    # Créer le fichier de configuration s'il n'existe pas
    if [ ! -f "$CONFIG_FILE" ]; then
        if [ -f "$CONFIG_DIR/config/deploy.yml.template" ]; then
            cp "$CONFIG_DIR/config/deploy.yml.template" "$CONFIG_FILE"
        else
            print_error "Template de configuration non trouvé"
            exit 1
        fi
    fi
    
    # Mise à jour du fichier YAML
    sed -i "s/enabled: false/enabled: true/g" "$CONFIG_FILE"
    sed -i "s|to: \".*\"|to: \"$DEPLOY_EMAIL_TO\"|g" "$CONFIG_FILE"
    sed -i "s|from: \".*\"|from: \"$DEPLOY_EMAIL_FROM\"|g" "$CONFIG_FILE"
    sed -i "s|smtp_host: \".*\"|smtp_host: \"$SMTP_HOST\"|g" "$CONFIG_FILE"
    sed -i "s/smtp_port: [0-9]*/smtp_port: $SMTP_PORT/g" "$CONFIG_FILE"
    sed -i "s|smtp_user: \".*\"|smtp_user: \"$SMTP_USER\"|g" "$CONFIG_FILE"
    sed -i "s|smtp_pass: \".*\"|smtp_pass: \"$SMTP_PASS\"|g" "$CONFIG_FILE"
    
    chmod 600 "$CONFIG_FILE"
    print_success "Configuration JS Auto mise à jour"
}

# Test de la configuration
test_configuration() {
    print_info "Test de la configuration SMTP..."
    
    # Vider le log
    > /var/log/msmtp.log
    
    print_info "Envoi d'un email de test à $TEST_EMAIL..."
    
    # Test avec msmtp directement
    local test_result
    test_result=$(echo -e "Subject: [JS Auto Deployer] Test Configuration SMTP\n\n<h1>✅ Configuration SMTP Réussie</h1><p>Votre serveur SMTP est correctement configuré pour JS Auto Deployer.</p><p><strong>Serveur:</strong> $SMTP_HOST<br><strong>Port:</strong> $SMTP_PORT</p><p><em>Test effectué le: $(date)</em></p>" | msmtp "$TEST_EMAIL" 2>&1)
    
    if [ $? -eq 0 ]; then
        print_success "Email de test envoyé avec succès !"
        print_info "Vérifiez votre boîte mail : $TEST_EMAIL"
    else
        print_error "Échec de l'envoi d'email de test"
        print_warning "Logs msmtp :"
        tail -10 /var/log/msmtp.log
        echo ""
        print_info "Erreur détaillée: $test_result"
    fi
}

# Affichage des informations de fin
show_completion_info() {
    print_header "✅ Configuration Terminée"
    echo -e "${GREEN}📧 Configuration SMTP terminée avec succès !${NC}"
    echo ""
    echo -e "${BLUE}📋 Résumé:${NC}"
    echo "  • msmtp installé et configuré"
    echo "  • Configuration SMTP : /etc/msmtprc"
    echo "  • Configuration JS Auto : $CONFIG_DIR/deploy.config"
    echo "  • Logs SMTP : /var/log/msmtp.log"
    echo ""
    echo -e "${BLUE}🔧 Commandes utiles:${NC}"
    echo "  • Test direct : echo 'Test' | msmtp votre-email@example.com"
    echo "  • Voir logs : tail -f /var/log/msmtp.log"
    echo "  • Test debug : echo 'Test' | msmtp --debug votre-email@example.com"
    echo ""
    echo -e "${BLUE}🚀 Prochaines étapes:${NC}"
    echo "  1. Configurez vos projets : sudo js-configure"
    echo "  2. Lancez le déploiement : sudo js-deploy"
    echo "  3. Testez les notifications : sudo js-test-email"
    echo ""
    echo -e "${GREEN}✨ Configuration SMTP prête !${NC}"
}

# Menu interactif
show_menu() {
    echo -e "${BLUE}JS Auto Deployer - Configuration SMTP${NC}"
    echo ""
    echo "Options disponibles :"
    echo "1) Configuration interactive (recommandé)"
    echo "2) Configuration rapide avec paramètres par défaut"
    echo "3) Test de la configuration existante"
    echo "4) Quitter"
    echo ""
    echo -n "Choisissez une option [1-4]: "
    read -r menu_choice
    
    case $menu_choice in
        1)
            interactive_config
            install_msmtp
            create_msmtp_config
            update_js_auto_deployer_config
            test_configuration
            show_completion_info
            ;;
        2)
            print_info "Configuration rapide..."
            DEPLOY_EMAIL_TO="admin@votredomaine.com"
            DEPLOY_EMAIL_FROM="deploy@votredomaine.com"
            SMTP_HOST="mail.votredomaine.com"
            SMTP_PORT="465"
            SMTP_USER="deploy@votredomaine.com"
            SMTP_PASS="password"
            TEST_EMAIL="$DEPLOY_EMAIL_TO"
            
            install_msmtp
            create_msmtp_config
            update_js_auto_deployer_config
            
            print_warning "Configuration rapide terminée. Modifiez manuellement :"
            echo "  • /etc/msmtprc - Configuration SMTP"
            echo "  • $CONFIG_DIR/deploy.config - Configuration JS Auto"
            ;;
        3)
            test_configuration
            ;;
        4)
            print_info "Au revoir !"
            exit 0
            ;;
        *)
            print_error "Option invalide"
            exit 1
            ;;
    esac
}

# Fonction principale
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}        🚀 JS Auto SMTP Configurator          ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    
    check_root
    detect_os
    
    # Si des arguments sont fournis, configuration automatique
    if [ $# -gt 0 ]; then
        DEPLOY_EMAIL_TO="$1"
        DEPLOY_EMAIL_FROM="${2:-$1}"
        SMTP_HOST="${3:-mail.votredomaine.com}"
        SMTP_PORT="${4:-465}"
        SMTP_USER="$1"
        SMTP_PASS="${5:-password}"
        TEST_EMAIL="${6:-$1}"
        
        install_msmtp
        create_msmtp_config
        update_fastpay_config
        test_configuration
    else
        show_menu
    fi
}

# Gestion des signaux
trap 'echo -e "\n${RED}Configuration interrompue${NC}"; exit 130' INT TERM

# Exécution
main "$@"