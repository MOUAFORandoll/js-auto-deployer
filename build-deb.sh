#!/bin/bash

# Script de construction du paquet DEB pour js-auto-deployer
# Usage: ./build-deb.sh [version]

set -e

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
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

# Variables
PACKAGE_NAME="js-auto-deployer"
VERSION="${1:-1.0.0}"
DEB_VERSION="${VERSION}-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/deb-build"
DEB_DIR="$BUILD_DIR/$PACKAGE_NAME"

print_info "Construction du paquet DEB pour $PACKAGE_NAME v$VERSION"

# Vérifier les prérequis
check_dependencies() {
    print_info "Vérification des dépendances..."
    
    local missing=()
    for cmd in debuild debhelper dh-make; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Dépendances manquantes: ${missing[*]}"
        print_info "Installez-les avec: sudo apt-get install devscripts debhelper dh-make"
        exit 1
    fi
    
    print_success "Toutes les dépendances sont installées"
}

# Nettoyage
clean_build() {
    print_info "Nettoyage du répertoire de build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$DEB_DIR"
}

# Créer la structure DEB
create_deb_structure() {
    print_info "Création de la structure DEB..."
    
    mkdir -p "$DEB_DIR/debian"
    mkdir -p "$DEB_DIR/opt/js-auto-deployer"
    mkdir -p "$DEB_DIR/etc/js-auto-deployer/config"
    mkdir -p "$DEB_DIR/usr/local/bin"
    mkdir -p "$DEB_DIR/var/log/js-auto-deployer"
    
    print_success "Structure créée"
}

# Copier les fichiers
copy_files() {
    print_info "Copie des fichiers..."
    
    # Scripts
    cp -r "$SCRIPT_DIR/scripts" "$DEB_DIR/opt/js-auto-deployer/"
    cp "$SCRIPT_DIR/install.sh" "$DEB_DIR/opt/js-auto-deployer/"
    cp "$SCRIPT_DIR/configure.sh" "$DEB_DIR/opt/js-auto-deployer/"
    
    # Configuration
    if [ -d "$SCRIPT_DIR/config" ]; then
        cp -r "$SCRIPT_DIR/config"/* "$DEB_DIR/etc/js-auto-deployer/config/" 2>/dev/null || true
    fi
    
    # Documentation
    cp "$SCRIPT_DIR/README.md" "$DEB_DIR/opt/js-auto-deployer/" 2>/dev/null || true
    cp "$SCRIPT_DIR/QUICKSTART.md" "$DEB_DIR/opt/js-auto-deployer/" 2>/dev/null || true
    
    # Rendre les scripts exécutables
    chmod +x "$DEB_DIR/opt/js-auto-deployer"/*.sh
    chmod +x "$DEB_DIR/opt/js-auto-deployer/scripts"/*.sh
    
    print_success "Fichiers copiés"
}

# Créer les fichiers DEB
create_deb_files() {
    print_info "Création des fichiers DEB..."
    
    # control
    cat > "$DEB_DIR/debian/control" << EOF
Source: $PACKAGE_NAME
Section: admin
Priority: optional
Maintainer: JS Auto Deployer Team <deploy@example.com>
Build-Depends: debhelper (>= 11)
Standards-Version: 4.1.3
Homepage: https://github.com/js-auto-deployer/js-auto-deployer

Package: $PACKAGE_NAME
Architecture: all
Depends: \${misc:Depends}, 
         bash (>= 4.0),
         curl,
         wget,
         git,
         nodejs (>= 16.0),
         npm
Recommends: pm2, msmtp, msmtp-mta, mailutils
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

    # changelog
    cat > "$DEB_DIR/debian/changelog" << EOF
$PACKAGE_NAME ($DEB_VERSION) unstable; urgency=medium

  * Version $VERSION
  * Déploiement automatisé pour projets JavaScript/TypeScript
  * Support PM2, Git, notifications email

 -- JS Auto Deployer Team <deploy@example.com>  $(date -R)
EOF

    # copyright
    cat > "$DEB_DIR/debian/copyright" << 'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: js-auto-deployer
Source: https://github.com/js-auto-deployer/js-auto-deployer

Files: *
Copyright: 2024 JS Auto Deployer Team
License: MIT

License: MIT
 MIT License
 .
 Permission is hereby granted, free of charge, to any person obtaining
 a copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:
 .
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 .
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
EOF

    # rules
    cat > "$DEB_DIR/debian/rules" << 'EOF'
#!/usr/bin/make -f

%:
	dh $@

override_dh_auto_install:
	# Les fichiers sont déjà en place
	@echo "Fichiers déjà installés"

override_dh_installdocs:
	dh_installdocs README.md QUICKSTART.md GUIDE_APT_PUBLICATION.md
EOF
    chmod +x "$DEB_DIR/debian/rules"

    # postinst
    cat > "$DEB_DIR/debian/postinst" << 'EOF'
#!/bin/bash
set -e

echo "Configuration de js-auto-deployer..."

# Créer les répertoires nécessaires
mkdir -p /var/log/js-auto-deployer
chmod 755 /var/log/js-auto-deployer

# Créer les liens symboliques
ln -sf /opt/js-auto-deployer/scripts/deploy.sh /usr/local/bin/js-deploy
ln -sf /opt/js-auto-deployer/configure.sh /usr/local/bin/js-configure
ln -sf /opt/js-auto-deployer/scripts/status.sh /usr/local/bin/js-status
ln -sf /opt/js-auto-deployer/scripts/smtp.config.sh /usr/local/bin/js-setup-email
ln -sf /opt/js-auto-deployer/scripts/test-email.sh /usr/local/bin/js-test-email
ln -sf /opt/js-auto-deployer/scripts/uninstall.sh /usr/local/bin/js-uninstall

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
    chmod +x "$DEB_DIR/debian/postinst"

    # postrm
    cat > "$DEB_DIR/debian/postrm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "purge" ]; then
    # Supprimer les fichiers de configuration si purge
    if [ -d /etc/js-auto-deployer ]; then
        rm -rf /etc/js-auto-deployer
    fi
    if [ -d /var/log/js-auto-deployer ]; then
        rm -rf /var/log/js-auto-deployer
    fi
    # Supprimer les liens symboliques
    rm -f /usr/local/bin/js-deploy
    rm -f /usr/local/bin/js-configure
    rm -f /usr/local/bin/js-status
    rm -f /usr/local/bin/js-setup-email
    rm -f /usr/local/bin/js-test-email
    rm -f /usr/local/bin/js-uninstall
fi
EOF
    chmod +x "$DEB_DIR/debian/postrm"

    # prerm
    cat > "$DEB_DIR/debian/prerm" << 'EOF'
#!/bin/bash
set -e

# Script pré-suppression (optionnel)
EOF
    chmod +x "$DEB_DIR/debian/prerm"

    print_success "Fichiers DEB créés"
}

# Construire le paquet
build_package() {
    print_info "Construction du paquet DEB..."
    
    cd "$DEB_DIR"
    
    # Construire sans signature (ajoutez -kKEY_ID pour signer)
    debuild -us -uc
    
    cd "$SCRIPT_DIR"
    
    # Trouver le paquet créé
    DEB_FILE=$(find "$BUILD_DIR" -name "${PACKAGE_NAME}_${DEB_VERSION}_all.deb" | head -1)
    
    if [ -n "$DEB_FILE" ]; then
        print_success "Paquet créé: $DEB_FILE"
        
        # Afficher les informations
        print_info "Informations du paquet:"
        dpkg-deb -I "$DEB_FILE" | head -20
        
        # Copier dans le répertoire courant
        cp "$DEB_FILE" "$SCRIPT_DIR/"
        print_success "Paquet copié dans: $SCRIPT_DIR/$(basename "$DEB_FILE")"
    else
        print_error "Paquet non trouvé"
        exit 1
    fi
}

# Fonction principale
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}     Construction du Paquet DEB              ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_dependencies
    clean_build
    create_deb_structure
    copy_files
    create_deb_files
    build_package
    
    echo ""
    print_success "✅ Construction terminée avec succès!"
    echo ""
    print_info "Pour publier le paquet:"
    echo "  1. Consultez GUIDE_APT_PUBLICATION.md"
    echo "  2. Ajoutez le paquet à votre dépôt APT"
    echo ""
}

# Exécution
main "$@"

