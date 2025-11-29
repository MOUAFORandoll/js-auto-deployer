#!/bin/bash

# JS Auto Deployer - Status
# Version: 1.0.0
# Description: Affichage du statut des applications et du système

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_DIR="/etc/js-auto-deployer"
PROJECTS_DIR="$CONFIG_DIR/config/projects"
LOG_DIR="/var/log/js-auto-deployer"

print_header() {
    echo -e "\n${PURPLE}════════════════════════════════════════${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════${NC}\n"
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

print_debug() {
    echo -e "${CYAN}🐛 $1${NC}"
}

# Informations système
show_system_info() {
    print_header "🖥️  Informations Système"
    
    echo -e "${BLUE}Hostname:${NC} $(hostname)"
    echo -e "${BLUE}Uptime:${NC} $(uptime -p)"
    echo -e "${BLUE}Charge:${NC} $(uptime | awk -F'load average:' '{print $2}')"
    echo -e "${BLUE}Mémoire:${NC} $(free -h | awk 'NR==2{printf "%.1f%% (%s/%s)", $3*100/$2, $3, $2}')"
    echo -e "${BLUE}Disque:${NC} $(df -h / | awk 'NR==2{printf "%s (%s/%s - %s)", $5, $3, $2, $6}')"
    echo -e "${BLUE}Utilisateur:${NC} $(whoami)"
    echo -e "${BLUE}Node.js:${NC} $(node --version 2>/dev/null || echo "Non installé")"
    echo -e "${BLUE}NPM:${NC} $(npm --version 2>/dev/null || echo "Non installé")"
    echo -e "${BLUE}PM2:${NC} $(pm2 --version 2>/dev/null || echo "Non installé")"
}

# Statut des services
show_services_status() {
    print_header "🔧 Statut des Services"
    
    # PM2
    if command -v pm2 &> /dev/null; then
        local pm2_processes=$(pm2 jlist 2>/dev/null | jq '. | length' 2>/dev/null || echo "0")
        echo -e "${BLUE}PM2:${NC} $([ "$pm2_processes" -gt 0 ] && print_success "Actif ($pm2_processes processus)" || print_warning "Aucun processus")"
    else
        print_error "PM2 non installé"
    fi
    
    # msmtp
    if command -v msmtp &> /dev/null; then
        print_success "msmtp installé"
    else
        print_warning "msmtp non installé"
    fi
    
    # Git
    if command -v git &> /dev/null; then
        local git_version=$(git --version | cut -d' ' -f3)
        print_success "Git $git_version"
    else
        print_error "Git non installé"
    fi
}

# Statut des projets
show_projects_status() {
    print_header "📦 Statut des Projets"
    
    local projects_dir="$CONFIG_DIR/config/projects"
    
    if [ ! -d "$projects_dir" ]; then
        print_warning "Répertoire de projets non trouvé: $projects_dir"
        return 0
    fi
    
    local project_count=0
    
    # Parcourir les fichiers YAML de projets
    for project_file in "$projects_dir"/*.yml; do
        if [ ! -f "$project_file" ]; then
            continue
        fi
        
        project_count=$((project_count + 1))
        local project_name=$(basename "$project_file" .yml)
        
        # Extraire les informations du projet depuis le YAML
        local project_title=$(grep -E "^project:" -A 3 "$project_file" | grep "name:" | sed 's/.*name:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "$project_name")
        local repo_path=$(grep -E "^repository:" -A 3 "$project_file" | grep "path:" | sed 's/.*path:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "")
        local process_name=$(grep -E "^process:" -A 3 "$project_file" | grep "name:" | sed 's/.*name:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "$project_name")
        local enabled=$(grep -E "^metadata:" -A 3 "$project_file" | grep "enabled:" | awk '{print $2}' 2>/dev/null || echo "true")
        
        echo -e "\n${GREEN}📁 $project_title${NC}"
        echo -e "  ${BLUE}Fichier:${NC} $project_name.yml"
        echo -e "  ${BLUE}Processus:${NC} ${process_name:-N/A}"
        echo -e "  ${BLUE}Chemin:${NC} ${repo_path:-N/A}"
        echo -e "  ${BLUE}Activé:${NC} $([ "$enabled" = "true" ] && echo "✅" || echo "❌")"
        
        # Vérifier le statut PM2
        if [ -n "$process_name" ]; then
            if command -v pm2 &> /dev/null && pm2 jlist 2>/dev/null | grep -q "\"name\":\"$process_name\""; then
                local status=$(pm2 jlist 2>/dev/null | jq -r ".[] | select(.name == \"$process_name\") | .pm2_env.status" 2>/dev/null || echo "unknown")
                case $status in
                    "online")
                        print_success "Statut PM2: $status"
                        ;;
                    "stopped"|"errored")
                        print_error "Statut PM2: $status"
                        ;;
                    *)
                        print_warning "Statut PM2: $status"
                        ;;
                esac
            else
                print_warning "Processus PM2 non démarré"
            fi
        fi
        
        # Vérifier l'accès au répertoire
        if [ -n "$repo_path" ] && [ -d "$repo_path" ]; then
            print_success "Répertoire accessible"
            
            # Vérifier si c'est un dépôt git
            if [ -d "$repo_path/.git" ]; then
                local branch=$(cd "$repo_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
                echo -e "  ${BLUE}Branche Git:${NC} $branch"
                
                # Vérifier les changements
                if cd "$repo_path" && ! git diff --quiet 2>/dev/null; then
                    print_warning "Changements locaux non commités"
                elif cd "$repo_path" && ! git diff --quiet HEAD..origin/"$branch" 2>/dev/null; then
                    print_info "Nouvelles modifications disponibles"
                else
                    print_success "Dossier à jour"
                fi
            else
                print_warning "Pas un dépôt Git"
            fi
        elif [ -n "$repo_path" ]; then
            print_error "Répertoire introuvable: $repo_path"
        fi
    done
    
    if [ $project_count -eq 0 ]; then
        print_warning "Aucun projet configuré"
    fi
}

# Statut des logs
show_logs_status() {
    print_header "📋 Statut des Logs"
    
    if [ ! -d "$LOG_DIR" ]; then
        print_warning "Répertoire de logs non trouvé: $LOG_DIR"
        return 0
    fi
    
    local log_files=$(find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | wc -l)
    local report_files=$(find "$LOG_DIR" -name "deploy-report-*.html" -type f 2>/dev/null | wc -l)
    
    echo -e "${BLUE}Fichiers de log:${NC} $log_files"
    echo -e "${BLUE}Rapports HTML:${NC} $report_files"
    
    if [ $log_files -gt 0 ]; then
        echo -e "\n${CYAN}Derniers logs:${NC}"
        find "$LOG_DIR" -name "*.log" -type f -exec ls -la {} \; | sort -k6,7 | tail -5 | while read -r line; do
            echo "  $line"
        done
    fi
    
    if [ $report_files -gt 0 ]; then
        echo -e "\n${CYAN}Derniers rapports:${NC}"
        find "$LOG_DIR" -name "deploy-report-*.html" -type f -exec ls -la {} \; | sort -k6,7 | tail -3 | while read -r line; do
            echo "  $line"
        done
    fi
}

# Statut de la configuration
show_config_status() {
    print_header "⚙️  Statut de la Configuration"
    
    local config_file="$CONFIG_DIR/config/deploy.yml"
    local projects_dir="$CONFIG_DIR/config/projects"
    
    # Configuration générale
    if [ -f "$config_file" ]; then
        print_success "Configuration générale: $config_file"
        
        # Extraire les informations depuis le YAML
        local email_enabled=$(grep -E "^email:" -A 5 "$config_file" | grep "enabled:" | awk '{print $2}' 2>/dev/null || echo "false")
        local email_to=$(grep -E "^email:" -A 5 "$config_file" | grep "to:" | sed 's/.*to:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "")
        local email_from=$(grep -E "^email:" -A 5 "$config_file" | grep "from:" | sed 's/.*from:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "")
        local slack_enabled=$(grep -E "^slack:" -A 5 "$config_file" | grep "enabled:" | awk '{print $2}' 2>/dev/null || echo "false")
        local slack_webhook=$(grep -E "^slack:" -A 5 "$config_file" | grep "webhook_url:" | sed 's/.*webhook_url:\s*"\(.*\)".*/\1/' 2>/dev/null || echo "")
        
        echo -e "  ${BLUE}Email activé:${NC} $email_enabled"
        echo -e "  ${BLUE}Email destinataire:${NC} ${email_to:-Non configuré}"
        echo -e "  ${BLUE}Email expéditeur:${NC} ${email_from:-Non configuré}"
        echo -e "  ${BLUE}Slack activé:${NC} $slack_enabled"
        echo -e "  ${BLUE}Slack webhook:${NC} ${slack_webhook:+Configuré} ${slack_webhook:--}"
    else
        print_error "Configuration générale non trouvée: $config_file"
        print_info "Créez le fichier depuis le template: cp $CONFIG_DIR/config/deploy.yml.template $config_file"
    fi
    
    # Configuration des projets
    if [ -d "$projects_dir" ]; then
        local project_count=$(ls "$projects_dir"/*.yml 2>/dev/null | wc -l)
        print_success "Configuration des projets: $projects_dir ($project_count projet(s))"
    else
        print_warning "Répertoire de projets non trouvé: $projects_dir"
        print_info "Créez des projets avec: sudo js-configure"
    fi
}

# Commandes rapides
show_quick_commands() {
    print_header "⚡ Commandes Rapides"
    
    echo -e "${CYAN}Déploiement:${NC}"
    echo "  js-deploy                   # Déployer tous les projets"
    echo "  js-deploy mon-app           # Déployer un projet spécifique"
    echo ""
    echo -e "${CYAN}Monitoring:${NC}"
    echo "  pm2 status                  # Statut des processus"
    echo "  pm2 logs                    # Logs en temps réel"
    echo "  js-status --verbose         # Statut détaillé"
    echo ""
    echo -e "${CYAN}Configuration:${NC}"
    echo "  js-setup-email               # Configurer SMTP"
    echo "  js-test-email               # Tester les emails"
    echo "  js-deploy --list            # Lister les projets"
    echo ""
    echo -e "${CYAN}Logs:${NC}"
    echo "  tail -f $LOG_DIR/deploy-*.log    # Logs de déploiement"
    echo "  ls -la $LOG_DIR/                # Tous les logs"
}

# Statut détaillé
show_verbose_status() {
    print_header "📊 Statut Détaillé"
    
    show_system_info
    show_services_status
    show_projects_status
    show_logs_status
    show_config_status
    show_quick_commands
}

# Affichage de l'aide
show_help() {
    cat <<EOF
JS Auto Deployer - Status

Usage: js-status [OPTIONS]

OPTIONS:
    --system         Informations système uniquement
    --services       Statut des services uniquement
    --projects       Statut des projets uniquement
    --logs           Statut des logs uniquement
    --config         Statut de la configuration uniquement
    --verbose        Statut complet (défaut)
    --quick-commands Afficher les commandes rapides
    --help           Afficher cette aide

EXAMPLES:
    js-status
    js-status --projects
    js-status --verbose
EOF
}

# Fonction principale
main() {
    local option="${1:---verbose}"
    
    case $option in
        --system)
            show_system_info
            ;;
        --services)
            show_services_status
            ;;
        --projects)
            show_projects_status
            ;;
        --logs)
            show_logs_status
            ;;
        --config)
            show_config_status
            ;;
        --quick-commands)
            show_quick_commands
            ;;
        --verbose)
            show_verbose_status
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Option inconnue: $option"
            show_help
            exit 1
            ;;
    esac
}

# Exécution
main "$@"