# Guide de Publication APT/DEB pour js-auto-deployer

Ce guide explique comment publier `js-auto-deployer` sur un dépôt APT pour le rendre accessible via `apt install` sur les systèmes Linux/Unix (Debian, Ubuntu, etc.).

## 📋 Prérequis

- Serveur avec accès root/sudo
- Outils de construction de paquets DEB installés
- Accès à un serveur de dépôt APT (ou création d'un nouveau dépôt)
- Clés GPG pour signer les paquets
- Serveur web pour héberger le dépôt

## 🚀 Étapes de Publication

### 1. Préparation de l'Environnement

```bash
# Installer les outils nécessaires
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    devscripts \
    debhelper \
    dh-make \
    fakeroot \
    gnupg2 \
    reprepro \
    apache2 \
    nginx
```

### 2. Structure du Paquet DEB

Créez la structure suivante dans votre répertoire de travail :

```
js-auto-deployer/
├── debian/
│   ├── changelog
│   ├── control
│   ├── copyright
│   ├── rules
│   ├── postinst
│   ├── postrm
│   ├── prerm
│   └── js-auto-deployer.install
├── etc/
│   └── js-auto-deployer/
│       └── config/
├── opt/
│   └── js-auto-deployer/
├── usr/
│   └── local/
│       └── bin/
└── var/
    └── log/
        └── js-auto-deployer/
```

### 3. Création des Fichiers DEB

#### 3.1. Créer le répertoire de travail

```bash
mkdir -p ~/deb-package/js-auto-deployer
cd ~/deb-package/js-auto-deployer
```

#### 3.2. Copier les fichiers du package

```bash
# Copier tous les fichiers du package
cp -r /chemin/vers/js-auto-deployer/* .

# Créer la structure DEB
mkdir -p debian
```

#### 3.3. Créer `debian/control`

```bash
cat > debian/control << 'EOF'
Source: js-auto-deployer
Section: admin
Priority: optional
Maintainer: Votre Nom <votre.email@example.com>
Build-Depends: debhelper (>= 11)
Standards-Version: 4.1.3
Homepage: https://github.com/votre-org/js-auto-deployer

Package: js-auto-deployer
Architecture: all
Depends: ${misc:Depends},
         bash (>= 4.0),
         curl,
         wget,
         git,
         nodejs (>= 16.0),
         npm,
         pm2
Recommends: msmtp, msmtp-mta, mailutils
Description: Déploiement automatisé pour projets JavaScript/TypeScript
 Package de déploiement automatisé pour projets JavaScript/TypeScript
 avec support pour Vue.js, React, Angular, Node.js, NestJS, etc.
 .
 Fonctionnalités:
  - Déploiement automatique multi-projets avec PM2
  - Intégration Git avec détection des changements
  - Support multi-frameworks
  - Notifications email avec rapports HTML
  - Configuration par projet simple et intuitive
  - Monitoring intégré avec statut en temps réel
EOF
```

#### 3.4. Créer `debian/changelog`

```bash
cat > debian/changelog << 'EOF'
js-auto-deployer (1.0.0-1) unstable; urgency=medium

  * Version initiale
  * Déploiement automatisé pour projets JavaScript/TypeScript
  * Support PM2, Git, notifications email

 -- Votre Nom <votre.email@example.com>  $(date -R)
EOF
```

#### 3.5. Créer `debian/copyright`

```bash
cat > debian/copyright << 'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: js-auto-deployer
Source: https://github.com/votre-org/js-auto-deployer

Files: *
Copyright: $(date +%Y) Votre Nom
License: MIT

License: MIT
 MIT License
 .
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files...
EOF
```

#### 3.6. Créer `debian/rules`

```bash
cat > debian/rules << 'EOF'
#!/usr/bin/make -f

%:
	dh $@

override_dh_auto_install:
	# Installer les fichiers dans le paquet
	mkdir -p $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer
	mkdir -p $(CURDIR)/debian/js-auto-deployer/etc/js-auto-deployer
	mkdir -p $(CURDIR)/debian/js-auto-deployer/usr/local/bin
	mkdir -p $(CURDIR)/debian/js-auto-deployer/var/log/js-auto-deployer

	# Copier les fichiers
	cp -r scripts $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp -r config $(CURDIR)/debian/js-auto-deployer/etc/js-auto-deployer/
	cp install.sh $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp configure.sh $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp README.md $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp QUICKSTART.md $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/

	# Créer les liens symboliques
	ln -s /opt/js-auto-deployer/scripts/deploy.sh $(CURDIR)/debian/js-auto-deployer/usr/local/bin/js-deploy
	ln -s /opt/js-auto-deployer/configure.sh $(CURDIR)/debian/js-auto-deployer/usr/local/bin/js-configure
	ln -s /opt/js-auto-deployer/scripts/status.sh $(CURDIR)/debian/js-auto-deployer/usr/local/bin/js-status
	ln -s /opt/js-auto-deployer/scripts/smtp.config.sh $(CURDIR)/debian/js-auto-deployer/usr/local/bin/js-setup-email
	ln -s /opt/js-auto-deployer/scripts/test-email.sh $(CURDIR)/debian/js-auto-deployer/usr/local/bin/js-test-email
	ln -s /opt/js-auto-deployer/scripts/uninstall.sh $(CURDIR)/debian/js-auto-deployer/usr/local/bin/js-uninstall

override_dh_installdocs:
	dh_installdocs README.md QUICKSTART.md
EOF

chmod +x debian/rules
```

#### 3.7. Créer `debian/postinst` (script post-installation)

```bash
cat > debian/postinst << 'EOF'
#!/bin/bash
set -e

# Script post-installation
echo "Configuration de js-auto-deployer..."

# Créer les répertoires nécessaires
mkdir -p /var/log/js-auto-deployer
chmod 755 /var/log/js-auto-deployer

# Créer le fichier de configuration s'il n'existe pas
if [ ! -f /etc/js-auto-deployer/config/deploy.yml ]; then
    if [ -f /etc/js-auto-deployer/config/deploy.yml.template ]; then
        cp /etc/js-auto-deployer/config/deploy.yml.template /etc/js-auto-deployer/config/deploy.yml
        chmod 600 /etc/js-auto-deployer/config/deploy.yml
    fi
fi

# Vérifier PM2
if ! command -v pm2 &> /dev/null; then
    echo "⚠️  PM2 n'est pas installé. Installez-le avec: npm install -g pm2"
fi

echo "✅ js-auto-deployer installé avec succès!"
echo ""
echo "Prochaines étapes:"
echo "  1. Configurez vos projets: sudo js-configure"
echo "  2. Lancez le déploiement: sudo js-deploy"
echo ""
EOF

chmod +x debian/postinst
```

#### 3.8. Créer `debian/postrm` (script post-suppression)

```bash
cat > debian/postrm << 'EOF'
#!/bin/bash
set -e

# Script post-suppression
if [ "$1" = "purge" ]; then
    # Supprimer les fichiers de configuration si purge
    if [ -d /etc/js-auto-deployer ]; then
        rm -rf /etc/js-auto-deployer
    fi
    if [ -d /var/log/js-auto-deployer ]; then
        rm -rf /var/log/js-auto-deployer
    fi
fi
EOF

chmod +x debian/postrm
```

### 4. Construction du Paquet DEB

```bash
# Construire le paquet
debuild -us -uc

# Ou avec signature GPG
debuild -kYOUR_GPG_KEY_ID
```

Le paquet sera créé dans le répertoire parent : `js-auto-deployer_1.0.0-1_all.deb`

### 5. Création d'un Dépôt APT

#### 5.1. Configuration du serveur de dépôt

```bash
# Installer reprepro
sudo apt-get install -y reprepro

# Créer la structure du dépôt
sudo mkdir -p /var/www/apt-repo/{conf,dists,pool}
cd /var/www/apt-repo
```

#### 5.2. Configuration de reprepro

```bash
cat > conf/distributions << 'EOF'
Origin: Votre Organisation
Label: JS Auto Deployer Repository
Codename: stable
Architectures: amd64 i386 all
Components: main
Description: Dépôt APT pour js-auto-deployer
SignWith: YOUR_GPG_KEY_ID
EOF

cat > conf/options << 'EOF'
verbose
basedir /var/www/apt-repo
EOF
```

#### 5.3. Ajouter le paquet au dépôt

```bash
# Ajouter le paquet
reprepro includedeb stable /chemin/vers/js-auto-deployer_1.0.0-1_all.deb

# Générer les métadonnées
reprepro export
```

#### 5.4. Configuration du serveur web

**Avec Apache:**

```bash
cat > /etc/apache2/sites-available/apt-repo.conf << 'EOF'
<VirtualHost *:80>
    ServerName apt.votredomaine.com
    DocumentRoot /var/www/apt-repo

    <Directory /var/www/apt-repo>
        Options Indexes FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

sudo a2ensite apt-repo
sudo systemctl reload apache2
```

**Avec Nginx:**

```bash
cat > /etc/nginx/sites-available/apt-repo << 'EOF'
server {
    listen 80;
    server_name apt.votredomaine.com;
    root /var/www/apt-repo;

    location / {
        autoindex on;
        try_files $uri $uri/ =404;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/apt-repo /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 6. Configuration des Clients

#### 6.1. Ajouter la clé GPG publique

```bash
# Sur le serveur de dépôt, exporter la clé publique
gpg --armor --export YOUR_GPG_KEY_ID > /var/www/apt-repo/public.key

# Sur les machines clientes
wget -qO - http://apt.votredomaine.com/public.key | sudo apt-key add -
```

#### 6.2. Ajouter le dépôt APT

```bash
# Créer le fichier sources.list
cat > /etc/apt/sources.list.d/js-auto-deployer.list << 'EOF'
deb http://apt.votredomaine.com stable main
EOF

# Ou avec HTTPS (recommandé)
cat > /etc/apt/sources.list.d/js-auto-deployer.list << 'EOF'
deb https://apt.votredomaine.com stable main
EOF
```

#### 6.3. Mettre à jour et installer

```bash
# Mettre à jour la liste des paquets
sudo apt-get update

# Installer js-auto-deployer
sudo apt-get install js-auto-deployer
```

### 7. Mise à Jour du Paquet

Pour publier une nouvelle version :

```bash
# 1. Mettre à jour debian/changelog
dch -i

# 2. Reconstruire le paquet
debuild -us -uc

# 3. Ajouter au dépôt
reprepro includedeb stable ../js-auto-deployer_1.0.1-1_all.deb

# 4. Les clients peuvent mettre à jour avec
sudo apt-get update && sudo apt-get upgrade js-auto-deployer
```

## 🔐 Sécurité

### Signature GPG

1. **Générer une clé GPG** (si vous n'en avez pas) :

```bash
gpg --gen-key
```

2. **Exporter la clé publique** :

```bash
gpg --armor --export YOUR_EMAIL > public.key
```

3. **Signer les paquets** :

```bash
debuild -kYOUR_GPG_KEY_ID
```

### HTTPS (Recommandé)

Configurez SSL/TLS pour votre dépôt :

```bash
# Avec Let's Encrypt
sudo apt-get install certbot
sudo certbot --nginx -d apt.votredomaine.com
```

## 📦 Structure du Dépôt Final

```
/var/www/apt-repo/
├── conf/
│   ├── distributions
│   └── options
├── dists/
│   └── stable/
│       └── main/
├── pool/
│   └── main/
│       └── j/
│           └── js-auto-deployer/
├── public.key
└── .htaccess (optionnel)
```

## 🚀 Automatisation avec GitHub Actions

Créez `.github/workflows/build-deb.yml` :

```yaml
name: Build DEB Package

on:
  release:
    types: [created]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y devscripts debhelper

      - name: Build DEB
        run: |
          debuild -us -uc

      - name: Upload artifact
        uses: actions/upload-artifact@v2
        with:
          name: deb-package
          path: ../*.deb
```

## 📝 Checklist de Publication

- [ ] Tous les fichiers sont présents dans le paquet
- [ ] Les permissions sont correctes
- [ ] Les scripts sont exécutables
- [ ] Le paquet est signé avec GPG
- [ ] Le dépôt APT est configuré
- [ ] Le serveur web est configuré
- [ ] La clé GPG publique est accessible
- [ ] Les clients peuvent ajouter le dépôt
- [ ] L'installation fonctionne avec `apt install`
- [ ] Les mises à jour fonctionnent avec `apt upgrade`

## 🆘 Dépannage

### Erreur: "GPG error: NO_PUBKEY"

```bash
# Importer la clé publique
wget -qO - http://apt.votredomaine.com/public.key | sudo apt-key add -
sudo apt-get update
```

### Erreur: "Package not found"

```bash
# Vérifier que le dépôt est bien ajouté
cat /etc/apt/sources.list.d/js-auto-deployer.list

# Vérifier la connexion
curl http://apt.votredomaine.com/dists/stable/Release
```

### Erreur lors de la construction

```bash
# Nettoyer et reconstruire
debuild clean
debuild -us -uc
```

## 📚 Ressources

- [Debian Packaging Guide](https://www.debian.org/doc/manuals/packaging-tutorial/)
- [reprepro Documentation](https://mirrorer.alioth.debian.org/)
- [Creating APT Repository](https://wiki.debian.org/HowToSetupADebianRepository)

---

**Note:** Remplacez tous les exemples de domaines, emails et noms par vos propres valeurs avant de publier.
