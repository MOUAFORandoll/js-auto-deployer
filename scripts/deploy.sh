#!/bin/bash

# JS Auto Deployer - Script de Déploiement Principal
# Version: 2.0.0
# Description: Déploiement automatisé pour projets JavaScript/TypeScript avec PM2

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="js-deploy"
readonly SCRIPT_VERSION="2.0.0"
readonly CONFIG_DIR="/etc/js-auto-deployer/config"
readonly LOG_DIR="/var/log/js-auto-deployer"
readonly PROJECTS_DIR="$CONFIG_DIR/projects"
readonly DEPLOY_LOG="$LOG_DIR/deploy-$(date +%Y%m%d-%H%M%S).log"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Variables globales
declare -A CONFIG=()
declare -A PROJECT_CONFIG=()
DEPLOY_START_TIME=$(date +%s)
DEPLOY_SUCCESS_COUNT=0
DEPLOY_FAILURE_COUNT=0
DEPLOY_SKIP_COUNT=0

# Fonctions utilitaires pour l'affichage
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
    if [[ "${CONFIG[log_level]:-INFO}" == "DEBUG" ]]; then
        echo -e "${CYAN}🐛 $1${NC}"
    fi
}

# Fonctions utilitaires pour YAML
yaml_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"
    
    if [[ ! -f "$file" ]]; then
        echo "$default"
        return 1
    fi
    
    # Extraction simple de valeur YAML
    local value=$(grep -E "^${key}:" "$file" | head -1 | sed "s/^${key}:\s*//" | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//")
    
    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

yaml_get_multiline() {
    local file="$1"
    local key="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Extraction de contenu multiligne YAML
    awk -v key="$key" '
        BEGIN { in_multiline = 0; content = "" }
        $0 ~ "^" key ":" && $0 !~ ":.*\|" { next }
        $0 ~ "^" key ":\s*\|" { 
            in_multiline = 1
            sub(/^[^|]*\|/, "")
            next
        }
        in_multiline {
            if ($0 ~ /^[a-zA-Z_][a-zA-Z0-9_]*:\s*(#.*)?$/) { exit }
            if ($0 !~ /^\s*$/ && $0 !~ /^\s*#/) {
                content = content $0 "\n"
            }
        }
        END { 
            if (content != "") {
                print content
            }
        }
    ' "$file"
}

# Chargement de la configuration générale
load_config() {
    local config_file="$CONFIG_DIR/deploy.yml"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Fichier de configuration non trouvé: $config_file"
        print_info "Copiez le template: cp $CONFIG_DIR/deploy.yml.template $config_file"
        exit 1
    fi
    
    # Chargement des variables principales
    CONFIG[log_level]=$(yaml_get "$config_file" "general.log_level" "INFO")
    CONFIG[www_dir]=$(yaml_get "$config_file" "general.www_dir" "/var/www")
    CONFIG[log_dir]=$(yaml_get "$config_file" "general.log_dir" "/var/log/js-auto-deployer")
    CONFIG[deploy_timeout]=$(yaml_get "$config_file" "general.deploy_timeout" "600")
    
    # Configuration email
    CONFIG[email_enabled]=$(yaml_get "$config_file" "email.enabled" "false")
    CONFIG[email_to]=$(yaml_get "$config_file" "email.to" "")
    CONFIG[email_from]=$(yaml_get "$config_file" "email.from" "")
    
    # Configuration Slack
    CONFIG[slack_enabled]=$(yaml_get "$config_file" "slack.enabled" "false")
    CONFIG[slack_webhook]=$(yaml_get "$config_file" "slack.webhook_url" "")
    
    print_debug "Configuration chargée depuis: $config_file"
}

# Chargement de la configuration d'un projet
load_project_config() {
    local project_name="$1"
    local project_file="$PROJECTS_DIR/${project_name}.yml"
    
    if [[ ! -f "$project_file" ]]; then
        print_error "Configuration de projet non trouvée: $project_file"
        print_info "Templates disponibles:"
        ls -1 "$PROJECTS_DIR"/*.template 2>/dev/null | while read template; do
            echo "  - $(basename "$template" .template)"
        done
        exit 1
    fi
    
    # Chargement des informations du projet
    PROJECT_CONFIG[name]=$(yaml_get "$project_file" "project.name" "$project_name")
    PROJECT_CONFIG[description]=$(yaml_get "$project_file" "project.description" "")
    PROJECT_CONFIG[framework]=$(yaml_get "$project_file" "project.framework" "unknown")
    
    # Configuration Git
    PROJECT_CONFIG[repo_path]=$(yaml_get "$project_file" "repository.path" "")
    PROJECT_CONFIG[branch]=$(yaml_get "$project_file" "repository.branch" "main")
    PROJECT_CONFIG[git_url]=$(yaml_get "$project_file" "repository.git_url" "")
    
    # Configuration PM2
    PROJECT_CONFIG[process_name]=$(yaml_get "$project_file" "process.name" "$project_name")
    PROJECT_CONFIG[instances]=$(yaml_get "$project_file" "process.instances" "1")
    PROJECT_CONFIG[exec_mode]=$(yaml_get "$project_file" "process.exec_mode" "fork")
    PROJECT_CONFIG[max_memory]=$(yaml_get "$project_file" "process.max_memory_restart" "500M")
    
    # Scripts
    PROJECT_CONFIG[build_cmd]=$(yaml_get_multiline "$project_file" "scripts.build")
    PROJECT_CONFIG[start_cmd]=$(yaml_get_multiline "$project_file" "scripts.start")
    PROJECT_CONFIG[pre_deploy]=$(yaml_get_multiline "$project_file" "scripts.pre_deploy")
    PROJECT_CONFIG[post_deploy]=$(yaml_get_multiline "$project_file" "scripts.post_deploy")
    
    # Notifications
    PROJECT_CONFIG[email_notifications]=$(yaml_get "$project_file" "notifications.email" "true")
    PROJECT_CONFIG[enabled]=$(yaml_get "$project_file" "metadata.enabled" "true")
    
    # Health check
    PROJECT_CONFIG[health_check_enabled]=$(yaml_get "$project_file" "health_check.enabled" "true")
    PROJECT_CONFIG[health_check_url]=$(yaml_get "$project_file" "health_check.url" "")
    
    print_debug "Configuration du projet chargée: ${PROJECT_CONFIG[name]}"
}

# Vérification des prérequis
check_prerequisites() {
    print_info "Vérification des prérequis..."
    
    local missing_deps=()
    
    # Vérifier les commandes essentielles
    for cmd in git node npm pm2; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Dépendances manquantes: ${missing_deps[*]}"
        print_info "Installez les dépendances avec: sudo $SCRIPT_NAME --install-deps"
        exit 1
    fi
    
    print_success "Toutes les dépendances sont installées"
}

# Initialisation SSH
init_ssh() {
    if [[ -f /root/.ssh/.keypass ]]; then
        eval "$(ssh-agent -s)" > /dev/null
        ssh-add /root/.ssh/id_ed25519 < /root/.ssh/.keypass > /dev/null 2>&1 || true
        print_debug "Clé SSH chargée"
    fi
}

# Fonctions de notification
send_notification() {
    local event="$1"
    local project_name="$2"
    local message="$3"
    local status="$4"  # success, failure, info
    
    # Email
    if [[ "${CONFIG[email_enabled]}" == "true" ]] && [[ "${PROJECT_CONFIG[email_notifications]:-true}" == "true" ]]; then
        send_email "$event" "$project_name" "$message"
    fi
    
    # Slack
    if [[ "${CONFIG[slack_enabled]}" == "true" ]]; then
        send_slack "$event" "$project_name" "$message" "$status"
    fi
}

send_email() {
    local subject="$1"
    local project_name="$2"
    local message="$3"
    
    if ! command -v msmtp &> /dev/null; then
        print_debug "msmtp non disponible, email non envoyé"
        return 1
    fi
    
    local email_content="Déploiement JS Auto Deployer
Projet: $project_name
Message: $message
Date: $(date)
Serveur: $(hostname)
"
    
    echo "$email_content" | msmtp "${CONFIG[email_to]}" 2>/dev/null || print_debug "Échec d'envoi d'email"
}

send_slack() {
    local event="$1"
    local project_name="$2"
    local message="$3"
    local status="$4"
    
    if [[ -z "${CONFIG[slack_webhook]:-}" ]]; then
        return 0
    fi
    
    local color="good"
    case $status in
        failure) color="danger" ;;
        warning) color="warning" ;;
        *) color="good" ;;
    esac
    
    local payload=$(cat <<EOF
{
  "channel": "${CONFIG[slack_channel]:-}",
  "username": "JS Auto Deployer",
  "attachments": [{
    "color": "$color",
    "title": "$event - $project_name",
    "text": "$message",
    "footer": "JS Auto Deployer",
    "ts": $(date +%s)
  }]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
        --data "$payload" \
        "${CONFIG[slack_webhook]}" > /dev/null 2>&1 || true
    
    print_debug "Notification Slack envoyée"
}

# Utilitaires PM2
pm2_is_running() {
    local process_name="$1"
    pm2 jlist 2>/dev/null | grep -q "\"name\":\"$process_name\"" && return 0 || return 1
}

pm2_get_status() {
    local process_name="$1"
    pm2 jlist 2>/dev/null | jq -r ".[] | select(.name == \"$process_name\") | .pm2_env.status" 2>/dev/null || echo "unknown"
}

# Health check
health_check() {
    local url="$1"
    local timeout="${2:-30}"
    
    if [[ -z "$url" ]]; then
        return 0
    fi
    
    print_debug "Health check: $url"
    
    local response_code
    response_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    
    if [[ "$response_code" =~ ^[2-3][0-9][0-9]$ ]]; then
        print_success "Health check OK: $response_code"
        return 0
    else
        print_warning "Health check échoué: $response_code"
        return 1
    fi
}

# Déploiement d'un projet
deploy_project() {
    local project_name="$1"
    
    print_header "🚀 Déploiement: ${PROJECT_CONFIG[name]}"
    print_info "Framework: ${PROJECT_CONFIG[framework]}"
    print_info "Chemin: ${PROJECT_CONFIG[repo_path]}"
    print_info "Branche: ${PROJECT_CONFIG[branch]}"
    
    # Vérification des prérequis du projet
    if [[ "${PROJECT_CONFIG[enabled]:-true}" != "true" ]]; then
        print_info "Projet désactivé, ignoré"
        return 0
    fi
    
    local project_start_time=$(date +%s)
    local status="SUCCESS"
    local message=""
    local changes_detected="Non"
    local action_taken="Aucune"
    
    # Vérification du répertoire
    if [[ ! -d "${PROJECT_CONFIG[repo_path]}" ]]; then
        status="ERROR"
        message="Répertoire introuvable: ${PROJECT_CONFIG[repo_path]}"
        print_error "$message"
        send_notification "Déploiement échoué" "$project_name" "$message" "failure"
        DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
        return 1
    fi
    
    cd "${PROJECT_CONFIG[repo_path]}"
    
    # Exécution du script pré-déploiement
    if [[ -n "${PROJECT_CONFIG[pre_deploy]:-}" ]]; then
        print_info "Exécution du script pré-déploiement..."
        eval "${PROJECT_CONFIG[pre_deploy]}" || {
            print_warning "Script pré-déploiement échoué, continuation..."
        }
    fi
    
    # Gestion Git
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    print_info "Branche actuelle: $current_branch"
    
    # Fetch et détection des changements
    if ! git fetch 2>&1 | tee -a "$DEPLOY_LOG"; then
        status="ERROR"
        message="Échec du git fetch"
        print_error "$message"
        send_notification "Déploiement échoué" "$project_name" "$message" "failure"
        DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
        return 1
    fi
    
    # Détection des changements Git
    local target_branch="${PROJECT_CONFIG[branch]}"
    local has_changes=false
    
    if ! git diff --quiet "$current_branch"..origin/"$target_branch" 2>/dev/null; then
        has_changes=true
        changes_detected="Oui"
        print_info "📝 Changements détectés dans le dépôt Git"
    else
        print_info "✅ Aucun changement Git détecté"
    fi
    
    # Vérification PM2
    local pm2_running=false
    if pm2_is_running "${PROJECT_CONFIG[process_name]}"; then
        pm2_running=true
        local pm2_status=$(pm2_get_status "${PROJECT_CONFIG[process_name]}")
        print_success "PM2 '${PROJECT_CONFIG[process_name]}' en cours d'exécution ($pm2_status)"
    else
        print_warning "PM2 '${PROJECT_CONFIG[process_name]}' n'est PAS en cours d'exécution"
    fi
    
    # Logique de déploiement
    if [[ "$pm2_running" == false ]]; then
        print_info "🚀 PM2 non actif – pull, build & start..."
        action_taken="Démarrage initial"
        
        # Git pull
        if ! git pull origin "$target_branch" 2>&1 | tee -a "$DEPLOY_LOG"; then
            status="ERROR"
            message="Échec du git pull"
            print_error "$message"
            send_notification "Déploiement échoué" "$project_name" "$message" "failure"
            DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
            return 1
        fi
        
        # Build
        if [[ -n "${PROJECT_CONFIG[build_cmd]:-}" ]]; then
            if ! eval "${PROJECT_CONFIG[build_cmd]}" 2>&1 | tee -a "$DEPLOY_LOG"; then
                status="ERROR"
                message="Échec du build"
                print_error "$message"
                send_notification "Déploiement échoué" "$project_name" "$message" "failure"
                DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
                return 1
            fi
        fi
        
        # Démarrage PM2
        if [[ -n "${PROJECT_CONFIG[start_cmd]:-}" ]]; then
            if ! eval "${PROJECT_CONFIG[start_cmd]}" 2>&1 | tee -a "$DEPLOY_LOG"; then
                status="ERROR"
                message="Échec du démarrage PM2"
                print_error "$message"
                send_notification "Déploiement échoué" "$project_name" "$message" "failure"
                DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
                return 1
            fi
            
            pm2 save 2>/dev/null || true
        fi
        
        message="Démarré avec succès"
        print_success "$message"
        
    elif [[ "$has_changes" == true ]]; then
        print_info "⬇️ Changements détectés – pull, rebuild & restart..."
        action_taken="Mise à jour et redémarrage"
        
        # Git pull
        if ! git pull origin "$target_branch" 2>&1 | tee -a "$DEPLOY_LOG"; then
            status="ERROR"
            message="Échec du git pull"
            print_error "$message"
            send_notification "Déploiement échoué" "$project_name" "$message" "failure"
            DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
            return 1
        fi
        
        # Build
        if [[ -n "${PROJECT_CONFIG[build_cmd]:-}" ]]; then
            if ! eval "${PROJECT_CONFIG[build_cmd]}" 2>&1 | tee -a "$DEPLOY_LOG"; then
                status="ERROR"
                message="Échec du build"
                print_error "$message"
                send_notification "Déploiement échoué" "$project_name" "$message" "failure"
                DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
                return 1
            fi
        fi
        
        # Redémarrage PM2
        pm2 delete "${PROJECT_CONFIG[process_name]}" 2>&1 | tee -a "$DEPLOY_LOG" || true
        
        if [[ -n "${PROJECT_CONFIG[start_cmd]:-}" ]]; then
            if ! eval "${PROJECT_CONFIG[start_cmd]}" 2>&1 | tee -a "$DEPLOY_LOG"; then
                status="ERROR"
                message="Échec du redémarrage PM2"
                print_error "$message"
                send_notification "Déploiement échoué" "$project_name" "$message" "failure"
                DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
                return 1
            fi
            
            pm2 save 2>/dev/null || true
        fi
        
        message="Mis à jour et redémarré avec succès"
        print_success "$message"
        
    else
        print_success "✅ Aucun changement – projet à jour"
        status="SKIPPED"
        message="Aucun changement détecté"
        action_taken="Aucune action"
        DEPLOY_SKIP_COUNT=$((DEPLOY_SKIP_COUNT + 1))
    fi
    
    # Exécution du script post-déploiement
    if [[ -n "${PROJECT_CONFIG[post_deploy]:-}" ]] && [[ "$status" == "SUCCESS" ]]; then
        print_info "Exécution du script post-déploiement..."
        eval "${PROJECT_CONFIG[post_deploy]}" || {
            print_warning "Script post-déploiement échoué"
        }
    fi
    
    # Health check
    if [[ "${PROJECT_CONFIG[health_check_enabled]:-true}" == "true" ]] && [[ -n "${PROJECT_CONFIG[health_check_url]:-}" ]] && [[ "$status" == "SUCCESS" ]]; then
        if ! health_check "${PROJECT_CONFIG[health_check_url]}"; then
            message="$message (Health check échoué)"
            status="WARNING"
        fi
    fi
    
    local duration=$(($(date +%s) - project_start_time))
    
    # Notification de succès
    if [[ "$status" == "SUCCESS" ]]; then
        send_notification "Déploiement réussi" "$project_name" "Durée: ${duration}s" "success"
        DEPLOY_SUCCESS_COUNT=$((DEPLOY_SUCCESS_COUNT + 1))
    fi
    
    print_info "Durée: ${duration}s"
    return 0
}

# Liste des projets disponibles
list_projects() {
    print_header "📋 Projets Configurés"
    
    if [[ ! -d "$PROJECTS_DIR" ]]; then
        print_warning "Aucun projet configuré"
        return 0
    fi
    
    for project_file in "$PROJECTS_DIR"/*.yml; do
        if [[ -f "$project_file" ]]; then
            local project_name=$(basename "$project_file" .yml)
            local project_title=$(yaml_get "$project_file" "project.name" "$project_name")
            local project_desc=$(yaml_get "$project_file" "project.description" "")
            local project_enabled=$(yaml_get "$project_file" "metadata.enabled" "true")
            local repo_path=$(yaml_get "$project_file" "repository.path" "")
            
            echo -e "${GREEN}📁 $project_title${NC}"
            echo "   ${BLUE}Fichier:${NC} $project_name.yml"
            echo "   ${BLUE}Description:${NC} $project_desc"
            echo "   ${BLUE}Chemin:${NC} $repo_path"
            echo "   ${BLUE}Statut:${NC} $([ "$project_enabled" == "true" ] && echo "Activé" || echo "Désactivé")"
            echo ""
        fi
    done
}

# Installation des dépendances
install_dependencies() {
    print_header "📦 Installation des Dépendances"
    
    # Détection du système d'exploitation
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            ubuntu|debian|mint)
                apt-get update -qq
                apt-get install -y curl wget git build-essential
                ;;
            centos|rhel|fedora)
                yum install -y curl wget git gcc gcc-c++ make
                ;;
            *)
                print_warning "Système d'exploitation non supporté"
                exit 1
                ;;
        esac
    fi
    
    # Installation de Node.js (si nécessaire)
    if ! command -v node &> /dev/null; then
        print_info "Installation de Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
        apt-get install -y nodejs
    fi
    
    # Installation de PM2
    if ! command -v pm2 &> /dev/null; then
        print_info "Installation de PM2..."
        npm install -g pm2
        pm2 startup systemd -u root --hp /root &> /dev/null || true
    fi
    
    # Installation de msmtp
    if ! command -v msmtp &> /dev/null; then
        print_info "Installation de msmtp..."
        apt-get install -y msmtp msmtp-mta ca-certificates mailutils
    fi
    
    print_success "Dépendances installées avec succès"
}

# Affichage de l'aide
show_help() {
    cat <<EOF
JS Auto Deployer v$SCRIPT_VERSION

Usage: $SCRIPT_NAME [OPTIONS] [PROJET]

OPTIONS:
    -h, --help              Afficher cette aide
    -v, --version           Afficher la version
    -l, --list              Lister tous les projets configurés
    -s, --status [PROJET]   Afficher le statut (d'un projet ou tous)
    --install-deps          Installer les dépendances système
    --dry-run              Simulation sans exécution
    --debug                Mode debug verbeux
    --config               Afficher la configuration

ARGUMENTS:
    PROJET                  Nom du projet à déployer (optionnel)
                           Si aucun projet spécifié, tous les projets seront déployés

EXAMPLES:
    $SCRIPT_NAME                    # Déployer tous les projets
    $SCRIPT_NAME mon-app           # Déployer le projet 'mon-app'
    $SCRIPT_NAME --list            # Lister les projets
    $SCRIPT_NAME --status          # Statut de tous les projets
    $SCRIPT_NAME --install-deps    # Installer les dépendances

CONFIGURATION:
    Configuration générale: /etc/js-auto-deployer/config/deploy.yml
    Projets: /etc/js-auto-deployer/config/projects/*.yml
    Logs: /var/log/js-auto-deployer/

Pour plus d'informations: voir README.md
EOF
}

# Fonction principale
main() {
    local project_filter=""
    local dry_run=false
    
    # Traitement des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "JS Auto Deployer v$SCRIPT_VERSION"
                exit 0
                ;;
            -l|--list)
                load_config
                list_projects
                exit 0
                ;;
            --install-deps)
                install_dependencies
                exit 0
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --debug)
                CONFIG[log_level]="DEBUG"
                shift
                ;;
            -s|--status)
                if [[ -n "${2:-}" ]] && [[ "${2:-}" != -* ]]; then
                    load_config
                    load_project_config "$2"
                    show_project_status "$2"
                    exit 0
                else
                    load_config
                    show_all_status
                    exit 0
                fi
                ;;
            --config)
                show_config
                exit 0
                ;;
            -*)
                print_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
            *)
                project_filter="$1"
                shift
                ;;
        esac
    done
    
    # Initialisation
    load_config
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    print_header "🚀 JS Auto Deployer v$SCRIPT_VERSION"
    print_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    print_info "Serveur: $(hostname)"
    print_info "Utilisateur: $(whoami)"
    print_info "Log: $DEPLOY_LOG"
    
    if [[ "$dry_run" == true ]]; then
        print_warning "Mode simulation activé - Aucune action ne sera effectuée"
    fi
    
    # Démarrage du log
    {
        echo "════════════════════════════════════════"
        echo "🚀 DÉBUT DU DÉPLOIEMENT"
        echo "════════════════════════════════════════"
        echo "📅 Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "🖥️  Serveur: $(hostname)"
        echo "👤 Utilisateur: $(whoami)"
        echo "📝 Mode: $([ "$dry_run" == true ] && echo "Simulation" || echo "Production")"
        echo "════════════════════════════════════════"
    } | tee "$DEPLOY_LOG"
    
    # Vérification des prérequis
    check_prerequisites
    
    # Initialisation SSH
    init_ssh
    
    # Déploiement
    if [[ -n "$project_filter" ]]; then
        print_info "Déploiement du projet: $project_filter"
        load_project_config "$project_filter"
        
        if [[ "$dry_run" == false ]]; then
            deploy_project "$project_filter"
        else
            print_info "[SIMULATION] Déploiement de $project_filter"
        fi
    else
        print_info "Déploiement de tous les projets configurés"
        
        if [[ ! -d "$PROJECTS_DIR" ]]; then
            print_error "Aucun projet configuré dans $PROJECTS_DIR"
            print_info "Copiez un template: cp $PROJECTS_DIR/vue-app.yml.template $PROJECTS_DIR/mon-projet.yml"
            exit 1
        fi
        
        for project_file in "$PROJECTS_DIR"/*.yml; do
            if [[ -f "$project_file" ]]; then
                local project_name=$(basename "$project_file" .yml)
                
                if [[ "$dry_run" == false ]]; then
                    load_project_config "$project_name"
                    deploy_project "$project_name"
                else
                    print_info "[SIMULATION] Déploiement de $project_name"
                fi
            fi
        done
    fi
    
    # Rapport final
    print_header "📊 RÉSUMÉ DU DÉPLOIEMENT"
    print_success "Succès: $DEPLOY_SUCCESS_COUNT"
    print_error "Échecs: $DEPLOY_FAILURE_COUNT"
    print_warning "Ignorés: $DEPLOY_SKIP_COUNT"
    print_info "Durée totale: $(($(date +%s) - DEPLOY_START_TIME))s"
    
    {
        echo ""
        echo "════════════════════════════════════════"
        echo "📊 RÉSUMÉ DU DÉPLOIEMENT"
        echo "════════════════════════════════════════"
        echo "✅ Succès: $DEPLOY_SUCCESS_COUNT"
        echo "❌ Échecs: $DEPLOY_FAILURE_COUNT"
        echo "ℹ️  Ignorés: $DEPLOY_SKIP_COUNT"
        echo "⏱️  Durée totale: $(($(date +%s) - DEPLOY_START_TIME))s"
        echo "════════════════════════════════════════"
    } | tee -a "$DEPLOY_LOG"
    
    # Statut PM2
    {
        echo ""
        echo "📊 Statut Final PM2:"
    } | tee -a "$DEPLOY_LOG"
    
    pm2 list | tee -a "$DEPLOY_LOG"
    
    print_success "✅ Déploiement terminé!"
    print_info "📝 Log complet: $DEPLOY_LOG"
    
    # Code de sortie
    if [[ $DEPLOY_FAILURE_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Fonctions de statut
show_project_status() {
    local project_name="$1"
    
    print_header "📊 Statut du Projet: $project_name"
    
    local project_file="$PROJECTS_DIR/${project_name}.yml"
    if [[ ! -f "$project_file" ]]; then
        print_error "Projet non trouvé: $project_name"
        return 1
    fi
    
    local project_title=$(yaml_get "$project_file" "project.name" "$project_name")
    local project_desc=$(yaml_get "$project_file" "project.description" "")
    local repo_path=$(yaml_get "$project_file" "repository.path" "")
    local process_name=$(yaml_get "$project_file" "process.name" "$project_name")
    local enabled=$(yaml_get "$project_file" "metadata.enabled" "true")
    
    echo -e "${GREEN}📁 $project_title${NC}"
    echo "   ${BLUE}Description:${NC} $project_desc"
    echo "   ${BLUE}Chemin:${NC} $repo_path"
    echo "   ${BLUE}Processus PM2:${NC} $process_name"
    echo "   ${BLUE}Activé:${NC} $([ "$enabled" == "true" ] && echo "✅" || echo "❌")"
    
    # Statut PM2
    if command -v pm2 &> /dev/null; then
        if pm2_is_running "$process_name"; then
            local pm2_status=$(pm2_get_status "$process_name")
            print_success "PM2: $pm2_status"
        else
            print_warning "PM2: Arrêté"
        fi
    fi
    
    # Statut Git
    if [[ -d "$repo_path/.git" ]]; then
        cd "$repo_path"
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        local git_status=$(git status --porcelain 2>/dev/null | wc -l)
        echo "   ${BLUE}Git:${NC} branche=$current_branch, fichiers modifiés=$git_status"
    fi
}

show_all_status() {
    print_header "📊 Statut Global"
    
    # Informations système
    echo -e "${CYAN}🖥️  Système:${NC}"
    echo "   Hostname: $(hostname)"
    echo "   Uptime: $(uptime -p)"
    echo "   Node.js: $(node --version 2>/dev/null || echo "Non installé")"
    echo "   PM2: $(pm2 --version 2>/dev/null || echo "Non installé")"
    echo ""
    
    # Projets
    list_projects
}

show_config() {
    print_header "⚙️  Configuration"
    
    local config_file="$CONFIG_DIR/deploy.yml"
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration non trouvée: $config_file"
        return 1
    fi
    
    echo -e "${CYAN}📄 Fichier:${NC} $config_file"
    echo ""
    
    echo -e "${CYAN}📧 Email:${NC}"
    echo "   Activé: ${CONFIG[email_enabled]:-false}"
    echo "   Destinataire: ${CONFIG[email_to]:-Non configuré}"
    echo ""
    
    echo -e "${CYAN}📱 Slack:${NC}"
    echo "   Activé: ${CONFIG[slack_enabled]:-false}"
    echo "   Webhook: ${CONFIG[slack_webhook]:-Non configuré}"
    echo ""
    
    echo -e "${CYAN}📁 Répertoires:${NC}"
    echo "   WWW: ${CONFIG[www_dir]:-/var/www}"
    echo "   Logs: ${CONFIG[log_dir]:-/var/log/js-auto-deployer}"
    echo "   Config: $CONFIG_DIR"
}

# Gestion des signaux
trap 'echo -e "\n${RED}Déploiement interrompu${NC}"; exit 130' INT TERM

# Exécution principale
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi