#!/bin/bash

set -e

PATH="/root/.nvm/versions/node/v22.11.0/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ========================
# 📧 EMAIL CONFIGURATION
# ========================
# Chargement des variables d'environnement depuis le fichier de config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy.config"

if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "⚠️  Fichier de configuration non trouvé: $CONFIG_FILE"
  echo "Création du fichier de configuration..."
  cat > "$CONFIG_FILE" << 'EOF'
# Configuration Email pour les notifications de déploiement
DEPLOY_EMAIL_TO="hari.randoll@gmail.com"
DEPLOY_EMAIL_FROM="contact@fastpay.website"
DEPLOY_EMAIL_SUBJECT_PREFIX="[FastPay Deploy]"

# SMTP Configuration (pour mailx/sendmail)
# Si vous utilisez un SMTP externe, configurez postfix ou msmtp
SMTP_ENABLED="false"

# Notification Slack (optionnel)
SLACK_WEBHOOK_URL=""
EOF
  echo "✅ Fichier de configuration créé: $CONFIG_FILE"
  echo "⚠️  Veuillez le configurer avant de lancer le déploiement"
  exit 1
fi

# Variables globales pour le rapport
DEPLOY_START_TIME=$(date +%s)
DEPLOY_DATE=$(date "+%Y-%m-%d %H:%M:%S")
DEPLOY_LOG="/tmp/deploy-$(date +%Y%m%d-%H%M%S).log"
DEPLOY_RESULTS=()
DEPLOY_SUCCESS_COUNT=0
DEPLOY_FAILURE_COUNT=0
DEPLOY_SKIP_COUNT=0

# ========================
# 🔐 SSH AUTOLOAD
# ========================
eval "$(ssh-agent -s)" > /dev/null
if [ -f /root/.ssh/.keypass ]; then
  ssh-add /root/.ssh/id_ed25519 < /root/.ssh/.keypass > /dev/null 2>&1 || true
fi

# ========================
# 📧 Email Functions
# ========================
# ========================
# 📧 Email Functions
# ========================
send_email() {
  local subject="$1"
  local body="$2"
  local html_body="$3"
  
  if [ -z "$DEPLOY_EMAIL_TO" ]; then
    echo "⚠️  Aucune adresse email configurée"
    return 1
  fi
  
  # Utiliser msmtp directement (plus fiable que mail)
  if command -v msmtp &> /dev/null; then
    if [ -n "$html_body" ]; then
      # Envoyer en HTML avec msmtp
      (
        echo "Subject: $subject"
        echo "From: $DEPLOY_EMAIL_FROM"
        echo "To: $DEPLOY_EMAIL_TO"
        echo "Content-Type: text/html; charset=UTF-8"
        echo ""
        echo "$html_body"
      ) | msmtp "$DEPLOY_EMAIL_TO"
      
      if [ $? -eq 0 ]; then
        echo "✅ Email envoyé via 'msmtp'"
        return 0
      else
        echo "❌ Échec de l'envoi via msmtp"
        return 1
      fi
    else
      echo "$body" | msmtp "$DEPLOY_EMAIL_TO"
      echo "✅ Email envoyé via 'msmtp'"
      return 0
    fi
  fi
  
  # Fallback: Tentative d'envoi avec mail (mailutils)
  if command -v mail &> /dev/null; then
    if [ -n "$html_body" ]; then
      echo "$html_body" | mail -s "$subject" -a "Content-Type: text/html; charset=UTF-8" "$DEPLOY_EMAIL_TO"
    else
      echo "$body" | mail -s "$subject" "$DEPLOY_EMAIL_TO"
    fi
    echo "✅ Email envoyé via 'mail'"
    return 0
  fi
  
  # Si aucun outil n'est disponible
  echo "⚠️  Aucun outil d'envoi d'email disponible (msmtp, mail)"
  echo "📝 Rapport sauvegardé dans: $DEPLOY_LOG"
  return 1
}
send_slack_notification() {
  local message="$1"
  local color="$2"  # good, warning, danger
  
  if [ -z "$SLACK_WEBHOOK_URL" ]; then
    return 0
  fi
  
  local payload=$(cat <<EOF
{
  "attachments": [{
    "color": "$color",
    "text": "$message",
    "footer": "DeployBot",
    "ts": $(date +%s)
  }]
}
EOF
)
  
  curl -X POST -H 'Content-type: application/json' \
    --data "$payload" \
    "$SLACK_WEBHOOK_URL" 2>/dev/null || true
}

# ========================
# 🧩 Utility functions
# ========================
check_pm2_status() {
  local process_name="$1"
  if pm2 jlist | grep -q "\"name\":\"$process_name\""; then
    return 0
  else
    return 1
  fi
}

update_and_build() {
  local repo_path="$1"
  local process_name="$2"
  local build_cmd="$3"
  local start_cmd="$4"
  
  local project_start_time=$(date +%s)
  local status="SUCCESS"
  local message=""
  local changes_detected="Non"
  local action_taken="Aucune"

  echo "" | tee -a "$DEPLOY_LOG"
  echo "════════════════════════════════════════" | tee -a "$DEPLOY_LOG"
  echo "📦 Projet: $process_name" | tee -a "$DEPLOY_LOG"
  echo "📂 Chemin: $repo_path" | tee -a "$DEPLOY_LOG"
  echo "════════════════════════════════════════" | tee -a "$DEPLOY_LOG"

  # Vérifier si le répertoire existe
  if [ ! -d "$repo_path" ]; then
    status="ERROR"
    message="Répertoire introuvable: $repo_path"
    echo "❌ $message" | tee -a "$DEPLOY_LOG"
    DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
    DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
    return 1
  fi

  cd "$repo_path"

  # Détecter la branche actuelle
  local current_branch
  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  echo "🌿 Branche: $current_branch" | tee -a "$DEPLOY_LOG"

  # Fetch des changements
  if ! git fetch 2>&1 | tee -a "$DEPLOY_LOG"; then
    status="ERROR"
    message="Échec du git fetch"
    echo "❌ $message" | tee -a "$DEPLOY_LOG"
    DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
    DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
    return 1
  fi

  # Détecter les changements git
  local has_changes=false
  if ! git diff --quiet "$current_branch"..origin/"$current_branch" 2>/dev/null; then
    has_changes=true
    changes_detected="Oui"
    echo "📝 Changements détectés dans le dépôt Git" | tee -a "$DEPLOY_LOG"
  else
    echo "✅ Aucun changement Git détecté" | tee -a "$DEPLOY_LOG"
  fi

  # Vérifier le statut PM2
  local pm2_running=false
  if check_pm2_status "$process_name"; then
    pm2_running=true
    echo "✅ PM2 '$process_name' est en cours d'exécution" | tee -a "$DEPLOY_LOG"
  else
    echo "⚠️  PM2 '$process_name' n'est PAS en cours d'exécution" | tee -a "$DEPLOY_LOG"
  fi

  # ============================
  # CASE 1: PM2 NOT RUNNING
  # ============================
  if [ "$pm2_running" = false ]; then
    echo "🚀 PM2 non actif – pull, build & start..." | tee -a "$DEPLOY_LOG"
    action_taken="Démarrage initial"

    if ! git pull origin "$current_branch" 2>&1 | tee -a "$DEPLOY_LOG"; then
      status="ERROR"
      message="Échec du git pull"
      echo "❌ $message" | tee -a "$DEPLOY_LOG"
      DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
      DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
      return 1
    fi

    if ! eval "$build_cmd" 2>&1 | tee -a "$DEPLOY_LOG"; then
      status="ERROR"
      message="Échec du build"
      echo "❌ $message" | tee -a "$DEPLOY_LOG"
      DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
      DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
      return 1
    fi

    if ! eval "$start_cmd" 2>&1 | tee -a "$DEPLOY_LOG"; then
      status="ERROR"
      message="Échec du démarrage PM2"
      echo "❌ $message" | tee -a "$DEPLOY_LOG"
      DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
      DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
      return 1
    fi

    pm2 save
    message="Démarré avec succès"
    echo "✅ $message" | tee -a "$DEPLOY_LOG"
    
    local duration=$(($(date +%s) - project_start_time))
    DEPLOY_RESULTS+=("$process_name|$status|$message|$duration|$changes_detected|$action_taken")
    DEPLOY_SUCCESS_COUNT=$((DEPLOY_SUCCESS_COUNT + 1))
    return 0
  fi

  # ============================
  # CASE 2: PM2 RUNNING + GIT CHANGES
  # ============================
  if [ "$has_changes" = true ]; then
    echo "⬇️ Changements détectés – pull, rebuild & restart '$process_name'..." | tee -a "$DEPLOY_LOG"
    action_taken="Mise à jour et redémarrage"

    if ! git pull origin "$current_branch" 2>&1 | tee -a "$DEPLOY_LOG"; then
      status="ERROR"
      message="Échec du git pull"
      echo "❌ $message" | tee -a "$DEPLOY_LOG"
      DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
      DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
      return 1
    fi

    if ! eval "$build_cmd" 2>&1 | tee -a "$DEPLOY_LOG"; then
      status="ERROR"
      message="Échec du build"
      echo "❌ $message" | tee -a "$DEPLOY_LOG"
      DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
      DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
      return 1
    fi

    pm2 delete "$process_name" 2>&1 | tee -a "$DEPLOY_LOG" || true

    if ! eval "$start_cmd" 2>&1 | tee -a "$DEPLOY_LOG"; then
      status="ERROR"
      message="Échec du redémarrage PM2"
      echo "❌ $message" | tee -a "$DEPLOY_LOG"
      DEPLOY_RESULTS+=("$process_name|$status|$message|0|$changes_detected|$action_taken")
      DEPLOY_FAILURE_COUNT=$((DEPLOY_FAILURE_COUNT + 1))
      return 1
    fi

    pm2 save
    message="Mis à jour et redémarré avec succès"
    echo "✅ $message" | tee -a "$DEPLOY_LOG"
    
    local duration=$(($(date +%s) - project_start_time))
    DEPLOY_RESULTS+=("$process_name|$status|$message|$duration|$changes_detected|$action_taken")
    DEPLOY_SUCCESS_COUNT=$((DEPLOY_SUCCESS_COUNT + 1))
    return 0
  fi

  # ============================
  # CASE 3: PM2 RUNNING + NO CHANGES
  # ============================
  echo "✅ Aucun changement – rien à reconstruire pour $process_name" | tee -a "$DEPLOY_LOG"
  status="SKIPPED"
  message="Aucun changement détecté"
  action_taken="Aucune action"
  
  local duration=$(($(date +%s) - project_start_time))
  DEPLOY_RESULTS+=("$process_name|$status|$message|$duration|$changes_detected|$action_taken")
  DEPLOY_SKIP_COUNT=$((DEPLOY_SKIP_COUNT + 1))
}

# ========================
# 📊 Generate HTML Report
# ========================
generate_html_report() {
  local total_duration=$(($(date +%s) - DEPLOY_START_TIME))
  local overall_status="SUCCESS"
  local status_color="#28a745"
  local status_icon="✅"
  
  if [ $DEPLOY_FAILURE_COUNT -gt 0 ]; then
    overall_status="FAILED"
    status_color="#dc3545"
    status_icon="❌"
  elif [ $DEPLOY_SUCCESS_COUNT -eq 0 ] && [ $DEPLOY_SKIP_COUNT -gt 0 ]; then
    overall_status="NO CHANGES"
    status_color="#ffc107"
    status_icon="ℹ️"
  fi
  
  cat <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; background-color: #f5f5f5; margin: 0; padding: 20px; }
    .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); overflow: hidden; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
    .header h1 { margin: 0; font-size: 28px; }
    .header p { margin: 10px 0 0 0; opacity: 0.9; }
    .summary { display: flex; justify-content: space-around; padding: 20px; background: #f8f9fa; border-bottom: 1px solid #dee2e6; }
    .summary-item { text-align: center; }
    .summary-item .number { font-size: 32px; font-weight: bold; margin: 0; }
    .summary-item .label { font-size: 12px; color: #6c757d; text-transform: uppercase; margin: 5px 0 0 0; }
    .success { color: #28a745; }
    .warning { color: #ffc107; }
    .danger { color: #dc3545; }
    .content { padding: 20px; }
    .project { border: 1px solid #dee2e6; border-radius: 6px; padding: 15px; margin-bottom: 15px; }
    .project-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
    .project-name { font-weight: bold; font-size: 16px; }
    .status-badge { padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: bold; text-transform: uppercase; }
    .status-success { background: #d4edda; color: #155724; }
    .status-error { background: #f8d7da; color: #721c24; }
    .status-skipped { background: #fff3cd; color: #856404; }
    .project-details { font-size: 14px; color: #6c757d; line-height: 1.6; }
    .project-details div { margin: 5px 0; }
    .footer { background: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #6c757d; border-top: 1px solid #dee2e6; }
    table { width: 100%; border-collapse: collapse; margin-top: 10px; }
    th, td { padding: 8px; text-align: left; border-bottom: 1px solid #dee2e6; }
    th { background: #f8f9fa; font-weight: 600; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>$status_icon Rapport de Déploiement</h1>
      <p>$DEPLOY_DATE • Durée totale: ${total_duration}s</p>
    </div>
    
    <div class="summary">
      <div class="summary-item">
        <p class="number success">$DEPLOY_SUCCESS_COUNT</p>
        <p class="label">Succès</p>
      </div>
      <div class="summary-item">
        <p class="number danger">$DEPLOY_FAILURE_COUNT</p>
        <p class="label">Échecs</p>
      </div>
      <div class="summary-item">
        <p class="number warning">$DEPLOY_SKIP_COUNT</p>
        <p class="label">Ignorés</p>
      </div>
      <div class="summary-item">
        <p class="number">$((DEPLOY_SUCCESS_COUNT + DEPLOY_FAILURE_COUNT + DEPLOY_SKIP_COUNT))</p>
        <p class="label">Total</p>
      </div>
    </div>
    
    <div class="content">
      <h2>Détails des Projets</h2>
EOF

  for result in "${DEPLOY_RESULTS[@]}"; do
    IFS='|' read -r name status message duration changes action <<< "$result"
    
    local badge_class="status-success"
    local status_display="✅ Succès"
    case $status in
      ERROR)
        badge_class="status-error"
        status_display="❌ Échec"
        ;;
      SKIPPED)
        badge_class="status-skipped"
        status_display="ℹ️ Ignoré"
        ;;
    esac
    
    cat <<EOF
      <div class="project">
        <div class="project-header">
          <span class="project-name">$name</span>
          <span class="status-badge $badge_class">$status_display</span>
        </div>
        <div class="project-details">
          <div><strong>Message:</strong> $message</div>
          <div><strong>Durée:</strong> ${duration}s</div>
          <div><strong>Changements Git:</strong> $changes</div>
          <div><strong>Action:</strong> $action</div>
        </div>
      </div>
EOF
  done

  cat <<EOF
    </div>
    
    <div class="footer">
      <p><strong>Serveur:</strong> $(hostname) • <strong>Utilisateur:</strong> $(whoami)</p>
      <p>Log complet disponible: $DEPLOY_LOG</p>
    </div>
  </div>
</body>
</html>
EOF
}

# ========================
# 🚀 Deployments
# ========================
{
  echo "════════════════════════════════════════"
  echo "🚀 DÉBUT DU DÉPLOIEMENT"
  echo "════════════════════════════════════════"
  echo "📅 Date: $DEPLOY_DATE"
  echo "🖥️  Serveur: $(hostname)"
  echo "👤 Utilisateur: $(whoami)"
  echo "════════════════════════════════════════"
} | tee "$DEPLOY_LOG"

echo "" | tee -a "$DEPLOY_LOG"
echo "➡️ FastPay Dashboard" | tee -a "$DEPLOY_LOG"
update_and_build "/var/www/fastpay-dashboard" "fastpay-dashboard" \
"npm install && npm run build" \
"PORT=2001 pm2 start npm --name fastpay-dashboard -- start"

echo "" | tee -a "$DEPLOY_LOG"
echo "➡️ Payment Link (Vue SPA)" | tee -a "$DEPLOY_LOG"
update_and_build "/var/www/fastpay-payment-link" "fastpay-pay-app" \
"npm install && npm run build" \
"pm2 serve dist 2000 --name fastpay-pay-app --spa"

echo "" | tee -a "$DEPLOY_LOG"
echo "➡️ FastPay Main API" | tee -a "$DEPLOY_LOG"
update_and_build "/var/www/fastpay-main-api" "fastpay-all-apps" \
"npm install && npm run build" \
"pm2 start ecosystem.config.js"

echo "" | tee -a "$DEPLOY_LOG"
echo "➡️ Runner API" | tee -a "$DEPLOY_LOG"
update_and_build "/var/www/fastpay-runner-api" "fastpay-runner-api" \
"npm install && npm run build" \
"PORT=8084 pm2 start dist/main.js --name fastpay-runner-api"

echo "" | tee -a "$DEPLOY_LOG"
echo "➡️ Developer Docs (Nuxt SSR)" | tee -a "$DEPLOY_LOG"
update_and_build "/var/www/fastpay-developer-docs" "fastpay-developer-docs" \
"npm install && npm run build" \
"PORT=2002 pm2 start www/.output/server/index.mjs --name fastpay-developer-docs"

# ========================
# 📊 Final Status
# ========================
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
  echo ""
  echo "📊 Statut Final PM2:"
} | tee -a "$DEPLOY_LOG"

pm2 list | tee -a "$DEPLOY_LOG"

# ========================
# 📧 Send Notifications
# ========================
echo "" | tee -a "$DEPLOY_LOG"
echo "📧 Envoi des notifications..." | tee -a "$DEPLOY_LOG"

# Generate reports
HTML_REPORT=$(generate_html_report)

# Determine email subject
if [ $DEPLOY_FAILURE_COUNT -gt 0 ]; then
  EMAIL_SUBJECT="$DEPLOY_EMAIL_SUBJECT_PREFIX ❌ ÉCHEC - $DEPLOY_FAILURE_COUNT erreur(s)"
  SLACK_COLOR="danger"
elif [ $DEPLOY_SUCCESS_COUNT -gt 0 ]; then
  EMAIL_SUBJECT="$DEPLOY_EMAIL_SUBJECT_PREFIX ✅ SUCCÈS - $DEPLOY_SUCCESS_COUNT projet(s) déployé(s)"
  SLACK_COLOR="good"
else
  EMAIL_SUBJECT="$DEPLOY_EMAIL_SUBJECT_PREFIX ℹ️ Aucun changement détecté"
  SLACK_COLOR="warning"
fi

# Send email
send_email "$EMAIL_SUBJECT" "Voir le rapport HTML" "$HTML_REPORT"

# Send Slack notification
SLACK_MESSAGE="*Déploiement terminé*\n✅ Succès: $DEPLOY_SUCCESS_COUNT | ❌ Échecs: $DEPLOY_FAILURE_COUNT | ℹ️ Ignorés: $DEPLOY_SKIP_COUNT\nDurée: $(($(date +%s) - DEPLOY_START_TIME))s"
send_slack_notification "$SLACK_MESSAGE" "$SLACK_COLOR"

echo "✅ Déploiement terminé!" | tee -a "$DEPLOY_LOG"
echo "📝 Log complet: $DEPLOY_LOG" | tee -a "$DEPLOY_LOG"

# Exit with appropriate code
if [ $DEPLOY_FAILURE_COUNT -gt 0 ]; then
  exit 1
else
  exit 0
fi