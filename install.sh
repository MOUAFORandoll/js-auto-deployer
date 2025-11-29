#!/bin/bash

# JS Auto Deployer - Installateur Automatique
# Version: 1.0.0
# Description: Installation complète du système de déploiement JS Auto

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PACKAGE_NAME="JS Auto Deployer"
PACKAGE_VERSION="1.0.0"
INSTALL_DIR="/opt/js-auto-deployer"
CONFIG_DIR="/etc/js-auto-deployer"
BIN_DIR="/usr/local/bin"
LOG_DIR="/var/log/js-auto-deployer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}         🚀 $PACKAGE_NAME v$PACKAGE_VERSION           ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Fonction d'affichage avec couleur
print_status() {
    echo -e "${GREEN}[✅]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠️]${NC} $1"
}

print_error() {
    echo -e "${RED}[❌]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[ℹ️]${NC} $1"
}

# Vérification des permissions root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        echo "Usage: sudo $0"
        exit 1
    fi
    print_status "Permissions root vérifiées"
}

# Vérification du système d'exploitation
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        print_status "Système détecté: $OS $VER"
    else
        print_warning "Impossible de détecter le système d'exploitation"
    fi
}

# Vérification des dépendances système
check_dependencies() {
    print_info "Vérification des dépendances système..."
    
    local missing_deps=()
    
    # Vérifier les commandes essentielles
    local required_commands=("curl" "wget" "git" "node" "npm")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_warning "Dépendances manquantes: ${missing_deps[*]}"
        print_info "Installation des dépendances manquantes..."
        
        case "$OS" in
            *"Ubuntu"*|*"Debian"*|*"Mint"*)
                apt-get update -qq
                apt-get install -y curl wget git nodejs npm
                ;;
            *"CentOS"*|*"Red Hat"*|*"Fedora"*)
                yum install -y curl wget git nodejs npm
                ;;
            *)
                print_error "Système non supporté. Installez manuellement: ${missing_deps[*]}"
                exit 1
                ;;
        esac
    else
        print_status "Toutes les dépendances sont installées"
    fi
}

# Installation de PM2
install_pm2() {
    print_info "Installation/Vérification de PM2..."
    
    if ! command -v pm2 &> /dev/null; then
        npm install -g pm2
        print_status "PM2 installé avec succès"
    else
        local pm2_version=$(pm2 --version)
        print_status "PM2 déjà installé (version: $pm2_version)"
    fi
    
    # Configuration PM2 au démarrage
    pm2 startup systemd -u root --hp /root &> /dev/null || true
    pm2 save &> /dev/null || true
}

# Installation de msmtp pour les emails
install_msmtp() {
    print_info "Installation de msmtp pour les notifications email..."
    
    if ! command -v msmtp &> /dev/null; then
        case "$OS" in
            *"Ubuntu"*|*"Debian"*|*"Mint"*)
                apt-get install -y msmtp msmtp-mta ca-certificates mailutils
                ;;
            *"CentOS"*|*"Red Hat"*|*"Fedora"*)
                yum install -y msmtp mailx
                ;;
        esac
        print_status "msmtp installé avec succès"
    else
        print_status "msmtp déjà installé"
    fi
}

# Création de la structure de répertoires
create_directories() {
    print_info "Création de la structure de répertoires..."
    
    local dirs=(
        "$INSTALL_DIR"
        "$CONFIG_DIR"
        "$CONFIG_DIR/scripts"
        "$CONFIG_DIR/projects"
        "$LOG_DIR"
        "/var/www"
    )
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_status "Répertoire créé: $dir"
        else
            print_status "Répertoire existant: $dir"
        fi
    done
    
    # Permissions
    chown -R root:root "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"
    chmod -R 755 "$INSTALL_DIR" "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
}

# Installation des scripts
install_scripts() {
    print_info "Installation des scripts..."
    
    # Copier les scripts
    if [ -d "$SCRIPT_DIR/scripts" ]; then
        cp "$SCRIPT_DIR/scripts/"* "$CONFIG_DIR/scripts/" 2>/dev/null || true
        chmod +x "$CONFIG_DIR/scripts/"*.sh 2>/dev/null || true
    fi
    
    # Copier les templates de configuration
    if [ -d "$SCRIPT_DIR/../config" ]; then
        cp "$SCRIPT_DIR/../config/"*.template "$CONFIG_DIR/" 2>/dev/null || true
    fi
    
    # Créer les liens symboliques pour les commandes
    local commands=(
        "js-deploy:$CONFIG_DIR/scripts/deploy.sh"
        "js-configure:$SCRIPT_DIR/configure.sh"
        "js-setup-email:$CONFIG_DIR/scripts/smtp.config.sh"
        "js-test-email:$CONFIG_DIR/scripts/test-email.sh"
        "js-status:$CONFIG_DIR/scripts/status.sh"
        "js-uninstall:$CONFIG_DIR/scripts/uninstall.sh"
    )
    
    for cmd_link in "${commands[@]}"; do
        local cmd="${cmd_link%:*}"
        local script="${cmd_link#*:}"
        
        if [ -f "$script" ]; then
            ln -sf "$script" "$BIN_DIR/$cmd"
            print_status "Commande créée: $cmd"
        fi
    done
}

# Création des fichiers de configuration par défaut
create_config_files() {
    print_info "Création des fichiers de configuration..."
    
    # Configuration générale par défaut
    cat > "$CONFIG_DIR/deploy.config" << 'EOF'
# Configuration générale JS Auto Deployer
# Modifiez ces valeurs selon vos besoins

# Configuration Email
DEPLOY_EMAIL_TO="admin@votredomaine.com"
DEPLOY_EMAIL_FROM="deploy@votredomaine.com"
DEPLOY_EMAIL_SUBJECT_PREFIX="[Deploy]"

# Configuration SMTP
SMTP_ENABLED="false"
SMTP_HOST=""
SMTP_PORT="465"
SMTP_USER=""
SMTP_PASS=""

# Configuration Slack (optionnel)
SLACK_WEBHOOK_URL=""

# Configuration générale
LOG_LEVEL="INFO"
MAX_LOG_SIZE="10M"
BACKUP_RETENTION_DAYS="30"

# Répertoires
WWW_DIR="/var/www"
LOG_DIR="/var/log/js-auto-deployer"
EOF

    # Copier les templates de projets
    if [ -d "$SCRIPT_DIR/../config/projects" ]; then
        mkdir -p "$CONFIG_DIR/projects"
        cp "$SCRIPT_DIR/../config/projects"/*.template "$CONFIG_DIR/projects/" 2>/dev/null || true
        print_status "Templates de projets copiés"
    fi
    
    # Configuration des projets par défaut (template) - DEPRECATED, utiliser YAML
    cat > "$CONFIG_DIR/projects.config.template" << 'EOF'
# Configuration des projets à déployer
# Copiez ce fichier vers projects.config et modifiez selon vos besoins

# ========================================
# PROJET 1: Application Vue.js/React
# ========================================
PROJECT_NAME="mon-app"
REPO_PATH="/var/www/mon-app"
PROCESS_NAME="mon-app"
BUILD_CMD="npm install && npm run build"
START_CMD="pm2 serve dist 3000 --name mon-app --spa"
BRANCH="main"
EMAIL_NOTIFICATIONS="true"
ENABLED="true"

# ========================================
# PROJET 2: API Node.js
# ========================================
PROJECT_NAME="mon-api"
REPO_PATH="/var/www/mon-api"
PROCESS_NAME="mon-api"
BUILD_CMD="npm install && npm run build"
START_CMD="PORT=3001 pm2 start dist/main.js --name mon-api"
BRANCH="main"
EMAIL_NOTIFICATIONS="true"
ENABLED="true"

# ========================================
# PROJET 3: Dashboard
# ========================================
PROJECT_NAME="dashboard"
REPO_PATH="/var/www/dashboard"
PROCESS_NAME="dashboard"
BUILD_CMD="npm install && npm run build"
START_CMD="PORT=3002 pm2 start npm --name dashboard -- start"
BRANCH="develop"
EMAIL_NOTIFICATIONS="false"
ENABLED="false"
EOF

    # Créer le fichier projects.config vide au début (DEPRECATED)
    touch "$CONFIG_DIR/projects.config"
    
    # Créer le fichier deploy.yml depuis le template si nécessaire
    if [ ! -f "$CONFIG_DIR/deploy.yml" ] && [ -f "$CONFIG_DIR/deploy.yml.template" ]; then
        cp "$CONFIG_DIR/deploy.yml.template" "$CONFIG_DIR/deploy.yml"
        chmod 600 "$CONFIG_DIR/deploy.yml"
        print_status "Configuration deploy.yml créée depuis le template"
    fi
    
    chmod 600 "$CONFIG_DIR/deploy.config" 2>/dev/null || true
    chmod 600 "$CONFIG_DIR/projects.config" 2>/dev/null || true
    chmod 644 "$CONFIG_DIR/projects.config.template" 2>/dev/null || true
    
    print_status "Fichiers de configuration créés"
}

# Configuration des permissions
setup_permissions() {
    print_info "Configuration des permissions..."
    
    # Groupes et utilisateurs
    if ! getent group js-auto-deployer &> /dev/null; then
        groupadd js-auto-deployer
        print_status "Groupe 'js-auto-deployer' créé"
    fi
    
    # Permissions sur les répertoires
    chown -R root:root "$INSTALL_DIR" "$CONFIG_DIR"
    chown -R www-data:www-data "/var/www" 2>/dev/null || true
    
    # Permissions sur les scripts
    find "$CONFIG_DIR/scripts" -name "*.sh" -exec chmod 755 {} \;
    
    # Permissions sur les configs
    chmod 640 "$CONFIG_DIR"/*.config 2>/dev/null || true
    
    print_status "Permissions configurées"
}

# Test de l'installation
test_installation() {
    print_info "Test de l'installation..."
    
    local test_passed=true
    
    # Tester les commandes
    local commands=("js-deploy" "js-configure" "js-status" "js-setup-email" "js-test-email")
    for cmd in "${commands[@]}"; do
        if [ ! -L "$BIN_DIR/$cmd" ]; then
            print_error "Commande manquante: $cmd"
            test_passed=false
        fi
    done
    
    # Tester les répertoires
    local dirs=("$CONFIG_DIR" "$LOG_DIR")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            print_error "Répertoire manquant: $dir"
            test_passed=false
        fi
    done
    
    # Tester les fichiers de configuration
    local files=("$CONFIG_DIR/deploy.config" "$CONFIG_DIR/projects.config.template")
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Fichier manquant: $file"
            test_passed=false
        fi
    done
    
    if [ "$test_passed" = true ]; then
        print_status "Tous les tests réussis"
        return 0
    else
        print_error "Certains tests ont échoué"
        return 1
    fi
}

# Affichage du message de fin
show_completion_message() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}           🎉 Installation Terminée !           ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}📋 Prochaines étapes :${NC}"
    echo ""
    echo -e "${GREEN}🎉 Installation réussie !${NC}"
    echo ""
    echo -e "${BLUE}1.${NC} Configurez vos projets facilement :"
    echo -e "   sudo js-configure"
    echo "   (Assistant interactif pour créer et configurer vos projets)"
    echo ""
    echo -e "${BLUE}2.${NC} Ou configurez manuellement :"
    echo -e "   sudo cp $CONFIG_DIR/projects/vue-app.yml.template $CONFIG_DIR/projects/mon-projet.yml"
    echo -e "   sudo nano $CONFIG_DIR/projects/mon-projet.yml"
    echo ""
    echo -e "${BLUE}3.${NC} Configurez les notifications email (optionnel) :"
    echo -e "   sudo js-setup-email"
    echo ""
    echo -e "${BLUE}4.${NC} Lancez votre premier déploiement :"
    echo -e "   sudo js-deploy"
    echo ""
    echo -e "${BLUE}📖 Documentation complète :${NC}"
    echo -e "   README.md               # Guide détaillé"
    echo -e "   QUICKSTART.md          # Démarrage rapide"
    echo ""
    echo -e "${BLUE}⚡ Commandes principales :${NC}"
    echo -e "   js-deploy              # Déployer les projets"
    echo -e "   js-configure           # Configuration interactive"
    echo -e "   js-deploy --status     # Voir le statut"
    echo -e "   js-deploy --list       # Lister les projets"
    echo -e "   pm2 status             # Statut PM2"
    echo ""
}

# Fonction principale
main() {
    echo -e "${BLUE}Démarrage de l'installation de $PACKAGE_NAME...${NC}"
    echo ""
    
    check_root
    check_os
    check_dependencies
    install_pm2
    install_msmtp
    create_directories
    install_scripts
    create_config_files
    setup_permissions
    
    echo ""
    if test_installation; then
        show_completion_message
        exit 0
    else
        print_error "L'installation a échoué. Vérifiez les logs ci-dessus."
        exit 1
    fi
}

# Gestion des signaux
trap 'echo -e "\n${RED}Installation interrompue par l'\''utilisateur${NC}"; exit 130' INT TERM

# Exécution
main "$@"