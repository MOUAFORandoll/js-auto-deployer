# 🚀 JS Auto Deployer - Démarrage Ultra-Rapide

## Installation en 2 étapes simples

### 1. Installation Automatique ⚡

```bash
wget https://votre-serveur.com/js-auto-deployer-v2.0.tar.gz
tar -xzf js-auto-deployer-v2.0.tar.gz
cd js-auto-deployer
sudo ./install.sh
```

### 2. Configuration Guidée 🎯

```bash
# Assistant interactif (recommandé pour débutants)
sudo js-configure

# Configuration manuelle (pour utilisateurs avancés)
sudo cp /etc/js-auto-deployer/config/projects/vue-app.yml.template /etc/js-auto-deployer/config/projects/dashboard.yml
sudo nano /etc/js-auto-deployer/config/projects/dashboard.yml
```

## Premier Déploiement 🚀

```bash
sudo js-deploy
```

## Expérience Utilisateur Optimisée ✨

### Assistant Interactif `js-configure`

- **Menu visuel** avec options claires
- **Templates prédéfinis** pour chaque framework
- **Configuration step-by-step** avec validation
- **Test automatique** de la configuration

### Commandes Simples

```bash
js-deploy              # Déploiement de tous les projets
js-deploy mon-projet   # Déploiement d'un projet spécifique
js-configure           # Configuration interactive
js-status              # Statut des projets
```

## Templates Inclus 📦

### Frontend (SPA)

- **Vue.js** : `vue-app.yml.template`
- **React** : `react-app.yml.template`
- **Angular** : `angular-app.yml.template`

### Backend (API)

- **Node.js** : `nodejs-api.yml.template`
- **NestJS** : `nestjs-api.yml.template`
- **Générique** : `generic.yml.template`

## Configuration Email (Optionnelle) 📧

### Avec l'Assistant

```bash
sudo js-configure
# Choisir "2) Configurer les notifications email"
```

### Manuelle

```bash
sudo js-setup-email
```

### Test

```bash
sudo js-test-email
```

## Workflow Typique 👨‍💻

### 1. Installation (5 min)

```bash
sudo ./install.sh
```

### 2. Premier Projet (10 min)

```bash
sudo js-configure
# Choisir "1) Créer un nouveau projet"
# Suivre l'assistant interactif
```

### 3. Déploiement (2 min)

```bash
sudo js-deploy
```

### 4. Monitoring

```bash
js-status              # Statut global
pm2 logs mon-projet    # Logs d'un projet
pm2 status             # Statut PM2
```

## Dépannage Rapide 🔧

### Problème : "Command not found"

```bash
# Réinstaller les liens
sudo ln -sf /etc/js-auto-deployer/scripts/deploy.sh /usr/local/bin/js-deploy
```

### Problème : "No project configured"

```bash
# Créer un projet avec l'assistant
sudo js-configure
# Ou copier un template
sudo cp /etc/js-auto-deployer/config/projects/vue-app.yml.template /etc/js-auto-deployer/config/projects/mon-app.yml
```

### Problème : "PM2 not found"

```bash
# Installer les dépendances
sudo js-deploy --install-deps
```

## Fichiers Importants 📁

```bash
Configuration générale:     /etc/js-auto-deployer/config/deploy.yml
Projets:                    /etc/js-auto-deployer/config/projects/
Logs:                       /var/log/js-deploy/
Commandes:                  /usr/local/bin/js-*
```

## Support 📞

- **Documentation complète** : `README.md`
- **Configuration interactive** : `sudo js-configure`
- **Aide intégrée** : `js-deploy --help`
- **Test de configuration** : `sudo js-configure` → "5) Test configuration"

---

**🎯 Mission : Déploiement JavaScript/TypeScript en 15 minutes chrono !**
