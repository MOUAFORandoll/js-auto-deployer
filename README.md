# JS Auto Deployer

Package de déploiement automatisé pour projets JavaScript/TypeScript - Vue.js, React, Angular, Node.js, NestJS, etc.

## 🎯 Objectif

Déploiement automatique et professionnel de vos applications web JavaScript/TypeScript avec PM2, avec un minimum de configuration.

## ✨ Fonctionnalités

- 🚀 **Déploiement automatique** multi-projets avec PM2
- 🔄 **Git integration** avec détection des changements
- 📦 **Support multi-frameworks** (Vue.js, React, Angular, Node.js, NestJS, etc.)
- 📧 **Notifications email** avec rapports HTML détaillés
- 🔧 **Configuration par projet** simple et intuitive
- 📊 **Monitoring intégré** avec statut en temps réel
- 🛡️ **Gestion d'erreurs** robuste avec rollback
- 🔍 **Logs centralisés** avec rotation automatique

## 🚀 Installation Rapide

### Prérequis

- Serveur Linux (Ubuntu/Debian recommandé)
- Node.js 16+ et npm
- Git
- Accès sudo

### Installation

```bash
# Télécharger et installer
wget https://votre-serveur.com/js-auto-deployer-v1.0.tar.gz
tar -xzf js-auto-deployer-v1.0.tar.gz
cd js-auto-deployer
sudo ./install.sh

# Configuration rapide
sudo cp /etc/js-auto-deployer/config/projects/my-project.yml.template /etc/js-auto-deployer/config/projects/mon-app.yml
sudo nano /etc/js-auto-deployer/config/projects/mon-app.yml

# Premier déploiement
sudo js-deploy
```

## 📖 Guide Complet

### 1. Structure de Configuration

#### Configuration Générale (`/etc/js-auto-deployer/config/deploy.yml`)

```yaml
# Configuration email
email:
  enabled: true
  to: "admin@votredomaine.com"
  from: "deploy@votredomaine.com"
  smtp_host: "mail.votredomaine.com"
  smtp_port: 465
  smtp_user: "deploy@votredomaine.com"
  smtp_pass: "votre_mot_de_passe"

# Configuration Slack (optionnel)
slack:
  enabled: false
  webhook_url: ""

# Configuration générale
general:
  log_level: "INFO"
  max_log_size: "10M"
  www_dir: "/var/www"
  log_dir: "/var/log/js-deploy"
```

#### Configuration par Projet (`/etc/js-auto-deployer/config/projects/my-app.yml`)

```yaml
# Configuration du projet
project:
  name: "mon-app"
  description: "Ma super application Vue.js"

# Dépôt Git
repository:
  path: "/var/www/mon-app"
  branch: "main"
  git_url: "https://github.com/user/mon-app.git"

# Processus PM2
process:
  name: "mon-app"
  instances: 1
  exec_mode: "fork"
  max_memory_restart: "500M"

# Scripts de déploiement
scripts:
  # Commande de build (optionnel)
  build: "npm install && npm run build"

  # Commande de démarrage
  start: |
    # Vue.js/React SPA
    pm2 serve dist 3000 --name mon-app --spa

    # Ou API Node.js
    # PORT=3001 pm2 start dist/main.js --name mon-app

    # Ou application avec serveur dev
    # PORT=3002 pm2 start npm --name mon-app -- start

# Notifications
notifications:
  email: true
  slack: false

# Métadonnées
enabled: true
auto_deploy: true
health_check_url: "http://localhost:3000/health"
```

### 2. Types de Projets Supportés

#### Vue.js/React SPA

```yaml
project:
  name: "vue-frontend"
  description: "Interface utilisateur Vue.js"

scripts:
  build: "npm install && npm run build"
  start: "pm2 serve dist 3000 --name vue-frontend --spa"
```

#### API Node.js/NestJS

```yaml
project:
  name: "api-backend"
  description: "API REST Node.js"

scripts:
  build: "npm install && npm run build"
  start: "PORT=3001 pm2 start dist/main.js --name api-backend"
```

#### Application Angular

```yaml
project:
  name: "angular-app"
  description: "Application Angular"

scripts:
  build: "npm install && npm run build"
  start: "pm2 serve dist/angular-app 3002 --name angular-app --spa"
```

#### Microservice Node.js

```yaml
project:
  name: "microservice"
  description: "Microservice Node.js"

scripts:
  build: "" # Pas de build nécessaire
  start: "PORT=3003 pm2 start src/index.js --name microservice"
```

### 3. Commandes Principales

```bash
# Déploiement
sudo js-deploy                    # Tous les projets
sudo js-deploy mon-app           # Projet spécifique
sudo js-deploy --dry-run         # Simulation
sudo js-deploy --list            # Lister les projets

# Monitoring
js-status                        # Statut complet
js-status mon-app               # Statut d'un projet
pm2 status                           # Statut PM2
pm2 logs mon-app                     # Logs d'un projet

# Configuration
js-configure                  # Éditer la config générale
js-configure                  # Ajouter un projet
js-deploy --list                 # Lister les projets
# Supprimer manuellement le fichier YAML du projet mon-app       # Supprimer un projet

# Maintenance
# Sauvegarde manuelle recommandée                       # Sauvegarder les configs
# Restauration manuelle recommandée                      # Restaurer les configs
# Nettoyage manuel des logs                   # Nettoyer les anciens logs
```

### 4. Exemple Complet de Workflow

#### 1. Premier Setup

```bash
# Installation
sudo ./install.sh

# Configuration email
sudo js-setup-email

# Créer un projet Vue.js
sudo js-configure \
  --name "dashboard" \
  --type "vue" \
  --path "/var/www/dashboard" \
  --port 3000
```

#### 2. Déploiement Quotidien

```bash
# Vérifier le statut
js-status

# Déployer les changements
sudo js-deploy

# Surveiller les logs
pm2 logs dashboard
```

#### 3. Gestion des Incidents

```bash
# Voir les erreurs
js-status --errors

# Redémarrer un projet
pm2 restart dashboard

# Voir les logs d'erreur
pm2 logs dashboard --err
```

## 🔧 Configuration Avancée

### Variables d'Environnement par Projet

```yaml
project:
  name: "api"
  env:
    NODE_ENV: "production"
    DATABASE_URL: "postgresql://..."
    JWT_SECRET: "your-secret"

process:
  env:
    PORT: "3001"
```

### Hooks de Déploiement

```yaml
scripts:
  pre_deploy: |
    echo "Préparation du déploiement..."
    npm run test

  post_deploy: |
    echo "Déploiement terminé"
    curl -X POST https://api.monitoring.com/webhook
```

### Health Checks

```yaml
health_check:
  enabled: true
  url: "http://localhost:3001/health"
  timeout: 30
  retries: 3
  interval: 60
```

### Déploiement Conditionnel

```yaml
deploy:
  conditions:
    - branch: "main"
      environment: "production"
    - branch: "develop"
      environment: "staging"
```

## 📊 Monitoring et Observabilité

### Métriques Disponibles

- Statut des processus PM2
- Utilisation mémoire et CPU
- Temps de réponse des health checks
- Historique des déploiements
- Logs d'erreur centralisés

### Rapports Automatiques

- Rapport HTML après chaque déploiement
- Statistiques de performance
- Alertes en cas d'échec
- Historique des versions

### Intégrations

```yaml
# Webhook personnalisé
webhook:
  url: "https://hooks.slack.com/services/..."
  events: ["deploy_success", "deploy_failure"]
```

## 🛠️ Développement et Extension

### Ajouter un Nouveau Framework

1. Créer un template dans `/etc/js-auto-deployer/templates/`
2. Ajouter la logique dans `scripts/deploy.sh`
3. Documenter dans ce README

### API Interne

Le package expose des fonctions utilitaires :

```bash
source /etc/js-auto-deployer/scripts/utils.sh

# Fonctions disponibles
fastpay_log "Message"
fastpay_notify "Succès" "good"
fastpay_health_check "http://localhost:3000"
```

## 🔒 Sécurité

- Fichiers de configuration avec permissions restrictives
- Logs sans mots de passe
- Validation des entrées utilisateur
- Timeout sur les opérations critiques

## 🐛 Dépannage

### Problèmes Courants

#### Échec de Build

```bash
# Vérifier les logs
sudo js-deploy --debug mon-app

# Tester manuellement
cd /var/www/mon-app
npm install
npm run build
```

#### PM2 ne démarre pas

```bash
# Vérifier la configuration
pm2 show mon-app

# Redémarrer
pm2 delete mon-app
sudo js-deploy mon-app
```

#### Emails non envoyés

```bash
# Tester SMTP
js-test-email

# Vérifier les logs
sudo tail -f /var/log/js-deploy/msmtp.log
```

### Logs Utiles

```bash
# Logs de déploiement
sudo tail -f /var/log/js-deploy/deploy-$(date +%Y%m%d).log

# Logs PM2
pm2 logs --lines 50

# Logs système
sudo journalctl -u js-auto-deployer -f
```

## 📈 Roadmap

- [ ] Interface web de gestion
- [ ] Déploiement par webhook Git
- [ ] Intégration Docker
- [ ] Métriques Prometheus
- [ ] Sauvegarde automatique des bases de données
- [ ] Déploiement blue-green
- [ ] Rollback automatique
- [ ] Tests d'intégration

## 🤝 Contribution

1. Fork le repository
2. Créer une branche feature
3. Commit les changements
4. Push et créer une Pull Request

## 📄 Licence

MIT License - voir LICENSE pour plus de détails.

---

**Développé avec ❤️ pour simplifier vos déploiements JavaScript/TypeScript**
