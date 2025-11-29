#!/bin/bash

# JS Auto Deployer - Désinstalleur
# Version: 1.0.0
# Description: Désinstallation propre du package JS Auto Deployer

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${RED}════════════════════════════════════════${NC}"
    echo -e "${RED} $1${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}\n"
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

# Variables
CONFIG_DIR="/etc/js-auto-deployer"
LOG_DIR="/var/log/js-auto-deployer"
BIN_DIR="/usr/local/bin"
INSTALL_DIR="/opt/js-auto-deployer"

# Vérification des permissions root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then 
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

# Confirmation de désinstallation
confirm_uninstall() {
    print_header "JS Auto Deployer - Désinstallation"
    
    echo -e "${RED}ATTENTION: Cette opération va supprimer:${NC}"
    echo "  • Tous les scripts et fichiers du package"
    echo "  • Les configurations (${CONFIG_DIR})"
    echo "  • Les logs de déploiement (${LOG_DIR})"
    echo "  • Les commandes système (${BIN_DIR}/js-*)"
    echo ""
    echo -e "${YELLOW}Les applications PM2 continueront de fonctionner${NC}"
    echo ""
    
    read -p "Êtes-vous sûr de vouloir désinstaller JS Auto Deployer ? [y/N]: " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Désinstallation annulée"
        exit 0
    fi
    
    read -p "Voulez-vous également arrêter les processus PM2 ? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        STOP_PM2=true
        print_info "Les processus PM2 seront arrêtés"
    else
        STOP_PM2=false
        print_info "Les processus PM2 continueront de fonctionner"
    fi
}

# Arrêt des processus PM2
stop_pm2_processes() {
    if [ "$STOP_PM2" = true ]; then
        print_info "Arrêt des processus PM2 gérés par JS Auto Deployer..."
        
        # Arrêter les processus depuis les fichiers YAML de projets
        if [ -d "$CONFIG_DIR/config/projects" ]; then
            for project_file in "$CONFIG_DIR/config/projects"/*.yml; do
                if [ -f "$project_file" ]; then
                    local process_name=$(grep -E "^process:" -A 3 "$project_file" | grep "name:" | sed 's/.*name:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "")
                    if [ -n "$process_name" ] && pm2 delete "$process_name" 2>/dev/null; then
                        print_success "Processus arrêté: $process_name"
                    fi
                fi
            done
            pm2 save 2>/dev/null || true
        fi
    fi
}

# Suppression des liens symboliques
remove_symlinks() {
    print_info "Suppression des liens symboliques..."
    
    local commands=(
        "js-deploy"
        "js-setup-email"
        "js-test-email"
        "js-status"
        "js-configure"
        "js-uninstall"
    )
    
    for cmd in "${commands[@]}"; do
        if [ -L "$BIN_DIR/$cmd" ]; then
            rm -f "$BIN_DIR/$cmd"
            print_success "Lien supprimé: $cmd"
        fi
    done
}

# Suppression des répertoires
remove_directories() {
    print_info "Suppression des répertoires..."
    
    local dirs=(
        "$INSTALL_DIR"
        "$CONFIG_DIR"
        "$LOG_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            print_success "Répertoire supprimé: $dir"
        fi
    done
}

# Désinstallation des dépendances (optionnelle)
remove_dependencies() {
    print_warning "Désinstallation des dépendances système..."
    echo ""
    echo "Note: Les dépendances suivantes peuvent être utilisées par d'autres applications:"
    echo "  • PM2 (process manager)"
    echo "  • msmtp (client email)"
    echo "  • Node.js et npm"
    echo ""
    
    read -p "Voulez-vous désinstaller ces dépendances ? [y/N]: " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Détection du système d'exploitation
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            
            case "$OS" in
                *"Ubuntu"*|*"Debian"*|*"Mint"*)
                    apt-get remove -y msmtp msmtp-mta mailutils 2>/dev/null || true
                    ;;
                *"CentOS"*|*"Red Hat"*|*"Fedora"*)
                    yum remove -y msmtp mailx 2>/dev/null || true
                    ;;
            esac
        fi
        
        print_info "Note: PM2 et Node.js ne sont pas supprimés car ils peuvent être utilisés par d'autres applications"
    else
        print_info "Dépendances conservées"
    fi
}

# Nettoyage des logs système
clean_system_logs() {
    print_info "Nettoyage des fichiers de logs système..."
    
    # Suppression des logs msmtp
    if [ -f /var/log/msmtp.log ]; then
        rm -f /var/log/msmtp.log
        print_success "Log msmtp supprimé: /var/log/msmtp.log"
    fi
    
    # Suppression de la configuration msmtp
    if [ -f /etc/msmtprc ]; then
        rm -f /etc/msmtprc
        print_success "Configuration msmtp supprimée: /etc/msmtprc"
    fi
}

# Rapport final
show_uninstall_report() {
    print_header "✅ Désinstallation Terminée"
    
    echo -e "${GREEN}JS Auto Deployer a été complètement désinstallé !${NC}"
    echo ""
    echo -e "${BLUE}Éléments supprimés:${NC}"
    echo "  • Scripts et fichiers du package"
    echo "  • Configurations"
    echo "  • Logs de déploiement"
    echo "  • Liens symboliques des commandes"
    echo ""
    
    if [ "$STOP_PM2" = true ]; then
        echo -e "${YELLOW}Processus PM2 arrêtés:${NC}"
        echo "  • Tous les processus gérés par JS Auto Deployer"
        echo "  • Utilisez 'pm2 status' pour vérifier"
        echo ""
    else
        echo -e "${BLUE}Processus PM2:${NC}"
        echo "  • Continuers de fonctionner"
        echo "  • Gérez-les manuellement avec PM2"
        echo ""
    fi
    
    echo -e "${BLUE}Pour réinstaller:${NC}"
    echo "  1. Téléchargez le package: js-auto-deployer-v*.tar.gz"
    echo "  2. Extrayez: tar -xzf js-auto-deployer-v*.tar.gz"
    echo "  3. Installez: sudo ./install.sh"
    echo ""
}

# Fonction principale
main() {
    confirm_uninstall
    stop_pm2_processes
    remove_symlinks
    remove_directories
    clean_system_logs
    remove_dependencies
    show_uninstall_report
}

# Gestion des signaux
trap 'echo -e "\n${RED}Désinstallation interrompue${NC}"; exit 130' INT TERM

# Exécution
main "$@"