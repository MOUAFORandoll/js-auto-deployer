#!/bin/bash

# JS Auto Deployer - Configuration Interactive
# Version: 2.0.0
# Description: Assistant de configuration pour une expérience utilisateur facile

set -e

# Configuration
readonly CONFIG_DIR="/etc/js-auto-deployer/config"
readonly PROJECTS_DIR="$CONFIG_DIR/projects"
readonly DEPLOY_CONFIG="$CONFIG_DIR/deploy.yml"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Variables pour la configuration
CONFIG_EMAIL_ENABLED="false"
CONFIG_EMAIL_TO=""
CONFIG_EMAIL_FROM=""
CONFIG_EMAIL_SMTP_HOST=""
CONFIG_EMAIL_SMTP_PORT="465"
CONFIG_EMAIL_SMTP_USER=""
CONFIG_EMAIL_SMTP_PASS=""

# Fonctions d'affichage
print_header() {
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}          🎯 Configuration JS Auto Deployer        ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════╝${NC}\n"
}

print_step() {
    echo -e "${BLUE}📋 Étape $1:${NC} $2"
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
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Vérification des permissions root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then 
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        exit 1
    fi
}

# Vérification de l'installation
check_installation() {
    if [ ! -d "$CONFIG_DIR" ]; then
        print_error "JS Auto Deployer n'est pas installé."
        print_info "Installez-le d'abord avec: sudo ./install.sh"
        exit 1
    fi
    print_success "Installation détectée"
}

# Menu principal
show_main_menu() {
    print_header
    
    echo "Bienvenue dans l'assistant de configuration de JS Auto Deployer !"
    echo ""
    echo "Que souhaitez-vous configurer ?"
    echo ""
    echo "1) 🚀 Créer un nouveau projet"
    echo "2) ⚙️  Configurer les notifications email (optionnel)"
    echo "3) 📊 Voir le statut des projets"
    echo "4) 📝 Éditer la configuration générale"
    echo "5) 🧪 Tester la configuration"
    echo "6) 📖 Afficher l'aide"
    echo "7) ❌ Quitter"
    echo ""
    
    read -p "Choisissez une option [1-7]: " choice
    
    case $choice in
        1)
            create_new_project
            ;;
        2)
            configure_email
            ;;
        3)
            show_projects_status
            ;;
        4)
            edit_general_config
            ;;
        5)
            test_configuration
            ;;
        6)
            show_help
            ;;
        7)
            print_info "Au revoir !"
            exit 0
            ;;
        *)
            print_error "Option invalide"
            sleep 1
            show_main_menu
            ;;
    esac
}

# Création d'un nouveau projet
create_new_project() {
    print_step "1" "Création d'un nouveau projet"
    
    # Sélection du type de projet
    echo ""
    echo "Quel type de projet souhaitez-vous créer ?"
    echo "1) Vue.js (SPA)"
    echo "2) React (SPA)"
    echo "3) Angular (SPA)"
    echo "4) Node.js API"
    echo "5) NestJS API"
    echo "6) Projet personnalisé"
    echo ""
    
    read -p "Choisissez le type [1-6]: " project_type
    
    case $project_type in
        1) PROJECT_TEMPLATE="vue-app.yml.template" ;;
        2) PROJECT_TEMPLATE="react-app.yml.template" ;;
        3) PROJECT_TEMPLATE="angular-app.yml.template" ;;
        4) PROJECT_TEMPLATE="nodejs-api.yml.template" ;;
        5) PROJECT_TEMPLATE="nestjs-api.yml.template" ;;
        6) PROJECT_TEMPLATE="generic.yml.template" ;;
        *)
            print_error "Type de projet invalide"
            return 1
            ;;
    esac
    
    # Nom du projet
    echo ""
    read -p "Nom du projet (ex: dashboard, api, frontend): " project_name
    
    # Validation du nom
    if [ -z "$project_name" ] || [ "$project_name" != "$(echo "$project_name" | sed 's/[^a-zA-Z0-9_-]//g')" ]; then
        print_error "Nom de projet invalide. Utilisez uniquement des lettres, chiffres, tirets et underscores."
        return 1
    fi
    
    # Chemin du projet
    echo ""
    read -p "Chemin du projet [ /var/www/$project_name ]: " project_path
    project_path=${project_path:-"/var/www/$project_name"}
    
    # Port
    echo ""
    read -p "Port à utiliser [3000]: " project_port
    project_port=${project_port:-3000}
    
    # Confirmation
    echo ""
    echo -e "${CYAN}Résumé de la configuration:${NC}"
    echo "  • Type: $(basename "$PROJECT_TEMPLATE" .yml.template)"
    echo "  • Nom: $project_name"
    echo "  • Chemin: $project_path"
    echo "  • Port: $project_port"
    echo ""
    
    read -p "Confirmer la création ? [y/N]: " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_info "Création annulée"
        return 0
    fi
    
    # Création du projet
    create_project_from_template "$PROJECT_TEMPLATE" "$project_name" "$project_path" "$project_port"
}

# Création du projet depuis un template
create_project_from_template() {
    local template="$1"
    local name="$2"
    local path="$3"
    local port="$4"
    
    local template_file="$PROJECTS_DIR/$template"
    local project_file="$PROJECTS_DIR/${name}.yml"
    
    if [ ! -f "$template_file" ]; then
        print_error "Template non trouvé: $template_file"
        return 1
    fi
    
    # Copie et personnalisation du template
    cp "$template_file" "$project_file"
    
    # Remplacement des variables
    sed -i "s|name: \"[^\"]*\"|name: \"$name\"|g" "$project_file"
    sed -i "s|path: \"/var/www/[^\"]*\"|path: \"$path\"|g" "$project_file"
    sed -i "s|port: [0-9]*|port: $port|g" "$project_file"
    
    # Créer le répertoire du projet si nécessaire
    mkdir -p "$path"
    
    print_success "Projet créé: $project_file"
    print_info "Vous pouvez maintenant éditer le fichier pour personnaliser la configuration"
    print_info "Éditeur: sudo nano $project_file"
    
    # Demander si l'utilisateur veut l'ouvrir
    read -p "Ouvrir l'éditeur pour personnaliser ? [y/N]: " edit_now
    if [[ $edit_now =~ ^[Yy]$ ]]; then
        editor="${EDITOR:-nano}"
        sudo "$editor" "$project_file"
    fi
}

# Configuration email (optionnelle)
configure_email() {
    print_step "2" "Configuration des notifications email (optionnel)"
    
    echo ""
    echo "Les notifications email sont optionnelles. Vous pouvez les configurer maintenant"
    echo "ou plus tard avec la commande: sudo js-deploy --setup-email"
    echo ""
    
    read -p "Configurer les notifications email maintenant ? [y/N]: " setup_email
    
    if [[ ! $setup_email =~ ^[Yy]$ ]]; then
        print_info "Configuration email ignorée. Vous pourrez la configurer plus tard."
        return 0
    fi
    
    # Configuration interactive
    echo ""
    print_info "Configuration SMTP:"
    read -p "Email destinataire (pour recevoir les notifications): " email_to
    read -p "Email expéditeur: " email_from
    read -p "Serveur SMTP [mail.votredomaine.com]: " smtp_host
    smtp_host=${smtp_host:-"mail.votredomaine.com"}
    read -p "Port SMTP [465]: " smtp_port
    smtp_port=${smtp_port:-465}
    read -p "Utilisateur SMTP: " smtp_user
    read -s -p "Mot de passe SMTP: " smtp_pass
    echo ""
    
    # Validation basique
    if [ -z "$email_to" ] || [ -z "$email_from" ] || [ -z "$smtp_user" ] || [ -z "$smtp_pass" ]; then
        print_error "Informations incomplètes. Configuration annulée."
        return 1
    fi
    
    # Mise à jour de la configuration
    update_email_config "$email_to" "$email_from" "$smtp_host" "$smtp_port" "$smtp_user" "$smtp_pass"
    
    print_success "Configuration email mise à jour"
    
    # Test optionnel
    read -p "Tester la configuration email maintenant ? [y/N]: " test_email
    if [[ $test_email =~ ^[Yy]$ ]]; then
        test_email_configuration "$email_to"
    fi
}

# Mise à jour de la configuration email
update_email_config() {
    local to="$1" from="$2" host="$3" port="$4" user="$5" pass="$6"
    
    # Créer le fichier de configuration générale s'il n'existe pas
    if [ ! -f "$DEPLOY_CONFIG" ]; then
        cp "$CONFIG_DIR/deploy.yml.template" "$DEPLOY_CONFIG"
    fi
    
    # Mise à jour des valeurs
    sed -i "s/enabled: false/enabled: true/g" "$DEPLOY_CONFIG"
    sed -i "s|to: \".*\"|to: \"$to\"|g" "$DEPLOY_CONFIG"
    sed -i "s|from: \".*\"|from: \"$from\"|g" "$DEPLOY_CONFIG"
    sed -i "s|smtp_host: \".*\"|smtp_host: \"$host\"|g" "$DEPLOY_CONFIG"
    sed -i "s/smtp_port: [0-9]*/smtp_port: $port/g" "$DEPLOY_CONFIG"
    sed -i "s|smtp_user: \".*\"|smtp_user: \"$user\"|g" "$DEPLOY_CONFIG"
    sed -i "s|smtp_pass: \".*\"|smtp_pass: \"$pass\"|g" "$DEPLOY_CONFIG"
    
    # Sécurisation
    chmod 600 "$DEPLOY_CONFIG"
}

# Test de la configuration email
test_email_configuration() {
    local test_email="$1"
    
    print_info "Envoi d'un email de test..."
    
    # Test avec le script intégré
    if [ -f "$CONFIG_DIR/scripts/test-email.sh" ]; then
        sudo "$CONFIG_DIR/scripts/test-email.sh"
    else
        print_warning "Script de test non trouvé"
    fi
}

# Affichage du statut des projets
show_projects_status() {
    print_step "3" "Statut des projets"
    
    if [ ! -d "$PROJECTS_DIR" ] || [ -z "$(ls -A "$PROJECTS_DIR"/*.yml 2>/dev/null)" ]; then
        print_warning "Aucun projet configuré"
        return 0
    fi
    
    echo ""
    echo "Projets configurés:"
    echo ""
    
    for project_file in "$PROJECTS_DIR"/*.yml; do
        if [ -f "$project_file" ]; then
            local project_name=$(basename "$project_file" .yml)
            local project_title=$(grep "^project:" -A 3 "$project_file" | grep "name:" | cut -d'"' -f2 2>/dev/null || echo "$project_name")
            local project_desc=$(grep "description:" "$project_file" | cut -d'"' -f2 2>/dev/null || echo "")
            local project_enabled=$(grep "enabled:" "$project_file" | awk '{print $2}' 2>/dev/null || echo "true")
            
            echo -e "${GREEN}📁 $project_title${NC}"
            echo "   Fichier: $(basename "$project_file")"
            echo "   Description: $project_desc"
            echo "   Statut: $([ "$project_enabled" = "true" ] && echo "✅ Activé" || echo "❌ Désactivé")"
            echo ""
        fi
    done
    
    # Statut PM2 si disponible
    if command -v pm2 &> /dev/null; then
        print_info "Processus PM2:"
        pm2 list
    fi
}

# Édition de la configuration générale
edit_general_config() {
    print_step "4" "Configuration générale"
    
    local editor="${EDITOR:-nano}"
    
    if [ ! -f "$DEPLOY_CONFIG" ]; then
        cp "$CONFIG_DIR/deploy.yml.template" "$DEPLOY_CONFIG"
    fi
    
    print_info "Ouverture de l'éditeur: $DEPLOY_CONFIG"
    sudo "$editor" "$DEPLOY_CONFIG"
    
    print_success "Configuration sauvegardée"
}

# Test de la configuration
test_configuration() {
    print_step "5" "Test de la configuration"
    
    echo ""
    print_info "Vérification de la configuration..."
    
    # Test de la configuration générale
    if [ -f "$DEPLOY_CONFIG" ]; then
        print_success "Configuration générale: OK"
    else
        print_error "Configuration générale: MANQUANTE"
    fi
    
    # Test des projets
    if [ -d "$PROJECTS_DIR" ] && [ -n "$(ls -A "$PROJECTS_DIR"/*.yml 2>/dev/null)" ]; then
        local project_count=$(ls "$PROJECTS_DIR"/*.yml | wc -l)
        print_success "Projets configurés: $project_count"
    else
        print_warning "Aucun projet configuré"
    fi
    
    # Test des commandes
    if command -v js-deploy &> /dev/null; then
        print_success "Commande js-deploy: OK"
    else
        print_error "Commande js-deploy: NON TROUVÉE"
    fi
    
    # Test PM2
    if command -v pm2 &> /dev/null; then
        local pm2_version=$(pm2 --version)
        print_success "PM2: $pm2_version"
    else
        print_warning "PM2: NON INSTALLÉ"
    fi
    
    echo ""
    print_info "Pour un test complet, exécutez: sudo js-deploy --dry-run"
}

# Affichage de l'aide
show_help() {
    print_step "6" "Aide"
    
    cat <<EOF
╔═══════════════════════════════════════════════════════════╗
║                    🚀 JS Auto Deployer - Aide             ║
╚═══════════════════════════════════════════════════════════╝

📋 COMMANDES PRINCIPALES:
  js-deploy                    # Déployer tous les projets
  js-deploy mon-projet         # Déployer un projet spécifique
  js-deploy --list            # Lister les projets
  js-deploy --status          # Voir le statut
  js-deploy --dry-run         # Simulation sans exécution

⚙️  CONFIGURATION:
  Configuration générale: /etc/js-auto-deployer/config/deploy.yml
  Projets: /etc/js-auto-deployer/config/projects/*.yml

🔧 ASSISTANTS:
  sudo js-configure           # Configuration interactive (ce script)
  sudo js-deploy --setup-email # Configuration email
  sudo js-deploy --install-deps # Installer dépendances

📊 MONITORING:
  pm2 status                  # Statut PM2
  pm2 logs nom-projet         # Logs d'un projet
  pm2 restart nom-projet      # Redémarrer un projet

📚 DOCUMENTATION:
  README.md                   # Guide complet
  QUICKSTART.md              # Démarrage rapide

Pour plus d'aide: js-deploy --help
EOF
}

# Fonction principale
main() {
    check_root
    check_installation
    show_main_menu
}

# Gestion des signaux
trap 'echo -e "\n${RED}Configuration interrompue${NC}"; exit 130' INT TERM

# Exécution
main "$@"