#!/bin/bash

# JS Auto Deployer - Script d'initialisation de la structure DEB
# Version: 1.0.0
# Description: Crée la structure de répertoires pour le package DEB

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}\n"
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
PACKAGE_NAME="js-auto-deployer"
BASE_DIR="$(pwd)"
DEB_STRUCTURE_DIR="${BASE_DIR}/${PACKAGE_NAME}"

print_header "🚀 Initialisation de la structure DEB pour JS Auto Deployer"

# Vérifier si on est dans le bon répertoire
if [ ! -f "README.md" ] && [ ! -f "GUIDE_APT_PUBLICATION.md" ]; then
    print_warning "Ce script devrait être exécuté depuis la racine du projet"
    read -p "Continuer quand même ? [y/N]: " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Créer le répertoire principal
print_info "Création de la structure de répertoires..."

# Structure debian/
print_info "Création de debian/..."
mkdir -p "${DEB_STRUCTURE_DIR}/debian"
print_success "debian/ créé"

# Structure etc/
print_info "Création de etc/js-auto-deployer/config/..."
mkdir -p "${DEB_STRUCTURE_DIR}/etc/js-auto-deployer/config"
print_success "etc/js-auto-deployer/config/ créé"

# Structure opt/
print_info "Création de opt/js-auto-deployer/..."
mkdir -p "${DEB_STRUCTURE_DIR}/opt/js-auto-deployer"
print_success "opt/js-auto-deployer/ créé"

# Structure usr/
print_info "Création de usr/local/bin/..."
mkdir -p "${DEB_STRUCTURE_DIR}/usr/local/bin"
print_success "usr/local/bin/ créé"

# Structure var/
print_info "Création de var/log/js-auto-deployer/..."
mkdir -p "${DEB_STRUCTURE_DIR}/var/log/js-auto-deployer"
print_success "var/log/js-auto-deployer/ créé"

# Créer les fichiers debian/ vides avec des commentaires
print_info "Création des fichiers debian/..."

# debian/changelog
cat > "${DEB_STRUCTURE_DIR}/debian/changelog" << 'EOF'
js-auto-deployer (1.0.0-1) unstable; urgency=medium

  * Version initiale
  * Déploiement automatisé pour projets JavaScript/TypeScript
  * Support PM2, Git, notifications email

 -- Votre Nom <votre.email@example.com>  $(date -R)
EOF
print_success "debian/changelog créé"

# debian/control
cat > "${DEB_STRUCTURE_DIR}/debian/control" << 'EOF'
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
print_success "debian/control créé"

# debian/copyright
cat > "${DEB_STRUCTURE_DIR}/debian/copyright" << 'EOF'
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
print_success "debian/copyright créé"

# debian/rules
cat > "${DEB_STRUCTURE_DIR}/debian/rules" << 'EOF'
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
chmod +x "${DEB_STRUCTURE_DIR}/debian/rules"
print_success "debian/rules créé"

# debian/postinst
cat > "${DEB_STRUCTURE_DIR}/debian/postinst" << 'EOF'
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
chmod +x "${DEB_STRUCTURE_DIR}/debian/postinst"
print_success "debian/postinst créé"

# debian/postrm
cat > "${DEB_STRUCTURE_DIR}/debian/postrm" << 'EOF'
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
chmod +x "${DEB_STRUCTURE_DIR}/debian/postrm"
print_success "debian/postrm créé"

# debian/prerm
cat > "${DEB_STRUCTURE_DIR}/debian/prerm" << 'EOF'
#!/bin/bash
set -e

# Script pré-suppression
# Optionnel: arrêter les services avant désinstallation
# pm2 stop all 2>/dev/null || true
EOF
chmod +x "${DEB_STRUCTURE_DIR}/debian/prerm"
print_success "debian/prerm créé"

# debian/js-auto-deployer.install
cat > "${DEB_STRUCTURE_DIR}/debian/js-auto-deployer.install" << 'EOF'
# Liste des fichiers à installer
# Format: source destination

scripts/* /opt/js-auto-deployer/scripts/
config/* /etc/js-auto-deployer/config/
install.sh /opt/js-auto-deployer/
configure.sh /opt/js-auto-deployer/
README.md /opt/js-auto-deployer/
QUICKSTART.md /opt/js-auto-deployer/
EOF
print_success "debian/js-auto-deployer.install créé"

# Afficher la structure créée
print_header "✅ Structure créée avec succès"

echo -e "${GREEN}Structure de répertoires créée:${NC}"
echo ""
tree -L 4 "${DEB_STRUCTURE_DIR}" 2>/dev/null || find "${DEB_STRUCTURE_DIR}" -type d | sed 's|[^/]*/| |g' | sort
echo ""

print_info "Répertoire de structure: ${DEB_STRUCTURE_DIR}"
echo ""
print_info "Prochaines étapes:"
echo "  1. Copiez vos fichiers dans la structure appropriée"
echo "  2. Modifiez les fichiers debian/ selon vos besoins"
echo "  3. Construisez le package avec: debuild -us -uc"
echo ""
print_success "Initialisation terminée !"

