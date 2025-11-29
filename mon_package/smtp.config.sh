#!/bin/bash
# Script d'installation automatique de la configuration SMTP pour JS Auto Deployer
# Serveur: mail89.lwspanel.com

set -e

echo "======================================"
echo "🚀 Configuration SMTP JS Auto Deployer"
echo "======================================"
echo ""

# Vérifier si exécuté en root
if [ "$(id -u)" -ne 0 ]; then 
  echo "❌ Ce script doit être exécuté en tant que root (sudo)"
  exit 1
fi

# 1. Installation de msmtp
echo "📦 Installation de msmtp..."
apt-get update -qq
apt-get install -y msmtp msmtp-mta ca-certificates mailutils

# 2. Backup de la config existante
if [ -f /etc/msmtprc ]; then
  echo "💾 Sauvegarde de la configuration existante..."
  cp /etc/msmtprc /etc/msmtprc.backup.$(date +%Y%m%d-%H%M%S)
fi

# 3. Création de la configuration SMTP
echo "⚙️  Création de /etc/msmtprc..."
cat > /etc/msmtprc << 'EOF'
# Configuration SMTP pour JS Auto Deployer
defaults
logfile /var/log/msmtp.log

account js-auto-deployer
host mail89.lwspanel.com
port 465
from deploy@votredomaine.com
user deploy@votredomaine.com
password YOUR_PASSWORD_HERE
auth on
tls on
tls_starttls off
tls_certcheck off

account default : js-auto-deployer
EOF

# 4. Sécurisation des fichiers
echo "🔒 Sécurisation des permissions..."
chmod 600 /etc/msmtprc
chown root:root /etc/msmtprc

# Créer le fichier de log avec bonnes permissions
touch /var/log/msmtp.log
chmod 666 /var/log/msmtp.log

# 5. Création des liens symboliques
echo "🔗 Configuration des liens symboliques..."
ln -sf /usr/bin/msmtp /usr/sbin/sendmail
ln -sf /usr/bin/msmtp /usr/bin/sendmail

# 6. Configuration du script de déploiement
echo "📝 Configuration du fichier de déploiement..."
CURRENT_DIR=$(pwd)

cat > "$CURRENT_DIR/deploy.config" << 'DEPLOYEOF'
# Configuration Email pour les notifications de déploiement JS Auto Deployer
DEPLOY_EMAIL_TO="admin@votredomaine.com"
DEPLOY_EMAIL_FROM="deploy@votredomaine.com"
DEPLOY_EMAIL_SUBJECT_PREFIX="[JS Auto Deployer]"

# SMTP Configuration
SMTP_ENABLED="true"

# Notification Slack (optionnel)
SLACK_WEBHOOK_URL=""
DEPLOYEOF

chmod 600 "$CURRENT_DIR/deploy.config"

echo ""
echo "======================================"
echo "✅ Configuration terminée !"
echo "======================================"
echo ""

# 7. Test direct avec msmtp (sans mail)
echo "🧪 Test de la configuration SMTP..."
echo ""

read -p "Entrez votre email pour recevoir un test (ou appuyez sur Entrée pour passer): " TEST_EMAIL

if [ -n "$TEST_EMAIL" ]; then
  echo "📤 Envoi d'un email de test à $TEST_EMAIL..."
  
  # Vider le log
  > /var/log/msmtp.log
  
  # Test avec msmtp directement
  echo -e "Subject: [JS Auto Deployer] Test Configuration SMTP\nContent-Type: text/html; charset=UTF-8\n\n<h1>✅ Configuration SMTP Réussie</h1><p>Votre serveur SMTP est correctement configuré pour JS Auto Deployer.</p><p><strong>Serveur:</strong> mail89.lwspanel.com<br><strong>Port:</strong> 465</p>" | msmtp "$TEST_EMAIL" 2>&1
  
  if [ $? -eq 0 ]; then
    echo "  ✅ Email envoyé avec succès !"
    echo "  📧 Vérifiez votre boîte mail : $TEST_EMAIL"
  else
    echo "  ❌ Échec de l'envoi"
    echo ""
    echo "Logs msmtp :"
    cat /var/log/msmtp.log
  fi
else
  echo "  ⏭️  Test d'envoi ignoré"
fi

echo ""
echo "======================================"
echo "📋 Résumé de la configuration"
echo "======================================"
echo "✅ msmtp installé et configuré"
echo "✅ Configuration SMTP : /etc/msmtprc"
echo "✅ Configuration deploy : $CURRENT_DIR/deploy.config"
echo "✅ Logs SMTP : /var/log/msmtp.log"
echo ""
echo "🔧 Commandes utiles:"
echo "  • Test direct : echo 'Test' | msmtp votre-email@example.com"
echo "  • Voir logs : tail -f /var/log/msmtp.log"
echo "  • Test debug : echo 'Test' | msmtp --debug votre-email@example.com"
echo ""
echo "🚀 Lancez maintenant : sudo ./deploy.sh"
echo ""
echo "======================================"
echo "✨ Configuration terminée !"
echo "======================================"