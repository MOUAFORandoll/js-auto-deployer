#!/bin/bash

# JS Auto Deployer - Script d'initialisation complète pour le package DEB
# Version: 2.0.0
# Description: Automatise toutes les étapes d'initialisation pour créer un package DEB
#              Inclut : installation des dépendances, création de la structure,
#              et génération de tous les fichiers debian/

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${PURPLE}════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════${NC}\n"
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

print_step() {
    echo -e "\n${CYAN}▶ $1${NC}"
}

# Variables
PACKAGE_NAME="js-auto-deployer"
BASE_DIR="$(pwd)"
DEB_STRUCTURE_DIR="${BASE_DIR}/${PACKAGE_NAME}"
SKIP_DEPS=false
SKIP_INSTALL=false

# Vérification des permissions root
check_root() {
    if [ "$(id -u)" -ne 0 ] && [ "$SKIP_INSTALL" = false ]; then
        print_warning "Certaines étapes nécessitent les permissions root"
        print_info "Le script continuera mais certaines installations seront ignorées"
        read -p "Continuer ? [y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Vérifier si on est dans le bon répertoire
check_directory() {
    if [ ! -f "README.md" ] && [ ! -f "GUIDE_APT_PUBLICATION.md" ]; then
        print_warning "Ce script devrait être exécuté depuis la racine du projet"
        read -p "Continuer quand même ? [y/N]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# ========================================
# ÉTAPE 1 : Préparation de l'Environnement
# ========================================
install_build_dependencies() {
    if [ "$SKIP_DEPS" = true ]; then
        print_info "Installation des dépendances ignorée (--skip-deps)"
        return 0
    fi

    print_step "Étape 1 : Préparation de l'Environnement"
    print_info "Installation des outils nécessaires pour la construction du package DEB..."

    if [ "$(id -u)" -ne 0 ]; then
        print_warning "Permissions root requises pour installer les dépendances"
        print_info "Exécutez manuellement :"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y build-essential devscripts debhelper dh-make fakeroot gnupg2 reprepro"
        return 0
    fi

    # Détection du système d'exploitation
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        print_error "Impossible de détecter le système d'exploitation"
        return 1
    fi

    case "$OS" in
        ubuntu|debian|mint)
            print_info "Mise à jour des paquets..."
            apt-get update -qq

            print_info "Installation des outils de construction DEB..."
            apt-get install -y \
                build-essential \
                devscripts \
                debhelper \
                dh-make \
                fakeroot \
                gnupg2 \
                reprepro \
                2>/dev/null || {
                print_warning "Certains paquets n'ont pas pu être installés"
                print_info "Continuez avec les outils disponibles"
            }
            print_success "Outils de construction installés"
            ;;
        *)
            print_warning "Système non supporté automatiquement: $OS"
            print_info "Installez manuellement : build-essential, devscripts, debhelper, dh-make, fakeroot, gnupg2, reprepro"
            ;;
    esac
}

# ========================================
# ÉTAPE 2 : Structure du Paquet DEB
# ========================================
create_deb_structure() {
    print_step "Étape 2 : Création de la Structure du Paquet DEB"
    
    # Créer le répertoire principal
    if [ -d "$DEB_STRUCTURE_DIR" ]; then
        print_warning "Le répertoire $DEB_STRUCTURE_DIR existe déjà"
        read -p "Voulez-vous le supprimer et le recréer ? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$DEB_STRUCTURE_DIR"
            print_info "Ancien répertoire supprimé"
        else
            print_info "Utilisation du répertoire existant"
        fi
    fi

    print_info "Création de la structure de répertoires..."

    # Structure debian/
    mkdir -p "${DEB_STRUCTURE_DIR}/debian"
    print_success "debian/ créé"

    # Structure etc/
    mkdir -p "${DEB_STRUCTURE_DIR}/etc/js-auto-deployer/config"
    print_success "etc/js-auto-deployer/config/ créé"

    # Structure opt/
    mkdir -p "${DEB_STRUCTURE_DIR}/opt/js-auto-deployer"
    print_success "opt/js-auto-deployer/ créé"

    # Structure usr/
    mkdir -p "${DEB_STRUCTURE_DIR}/usr/local/bin"
    print_success "usr/local/bin/ créé"

    # Structure var/
    mkdir -p "${DEB_STRUCTURE_DIR}/var/log/js-auto-deployer"
    print_success "var/log/js-auto-deployer/ créé"

    print_success "Structure de répertoires créée"
}

# ========================================
# ÉTAPE 3 : Création des Fichiers DEB
# ========================================
create_deb_files() {
    print_step "Étape 3 : Création des Fichiers DEB"

    # Demander les informations du mainteneur
    print_info "Configuration des métadonnées du package..."
    
    read -p "Nom du mainteneur [Votre Nom]: " MAINTAINER_NAME
    MAINTAINER_NAME=${MAINTAINER_NAME:-"Votre Nom"}
    
    read -p "Email du mainteneur [votre.email@example.com]: " MAINTAINER_EMAIL
    MAINTAINER_EMAIL=${MAINTAINER_EMAIL:-"votre.email@example.com"}
    
    read -p "Homepage GitHub [https://github.com/votre-org/js-auto-deployer]: " HOMEPAGE
    HOMEPAGE=${HOMEPAGE:-"https://github.com/votre-org/js-auto-deployer"}
    
    read -p "Version du package [1.0.0]: " PACKAGE_VERSION
    PACKAGE_VERSION=${PACKAGE_VERSION:-"1.0.0"}
    
    CURRENT_DATE=$(date -R)
    CURRENT_YEAR=$(date +%Y)

    print_info "Création des fichiers debian/..."

    # 3.3. debian/control
    print_info "Création de debian/control..."
    cat > "${DEB_STRUCTURE_DIR}/debian/control" << EOF
Source: js-auto-deployer
Section: admin
Priority: optional
Maintainer: ${MAINTAINER_NAME} <${MAINTAINER_EMAIL}>
Build-Depends: debhelper (>= 11)
Standards-Version: 4.1.3
Homepage: ${HOMEPAGE}

Package: js-auto-deployer
Architecture: all
Depends: \${misc:Depends},
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

    # 3.4. debian/changelog
    print_info "Création de debian/changelog..."
    cat > "${DEB_STRUCTURE_DIR}/debian/changelog" << EOF
js-auto-deployer (${PACKAGE_VERSION}-1) unstable; urgency=medium

  * Version initiale
  * Déploiement automatisé pour projets JavaScript/TypeScript
  * Support PM2, Git, notifications email

 -- ${MAINTAINER_NAME} <${MAINTAINER_EMAIL}>  ${CURRENT_DATE}
EOF
    print_success "debian/changelog créé"

    # 3.5. debian/copyright
    print_info "Création de debian/copyright..."
    cat > "${DEB_STRUCTURE_DIR}/debian/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: js-auto-deployer
Source: ${HOMEPAGE}

Files: *
Copyright: ${CURRENT_YEAR} ${MAINTAINER_NAME}
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
    print_success "debian/copyright créé"

    # 3.6. debian/rules
    print_info "Création de debian/rules..."
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

    # 3.7. debian/postinst
    print_info "Création de debian/postinst..."
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

    # 3.8. debian/postrm
    print_info "Création de debian/postrm..."
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
    print_info "Création de debian/prerm..."
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
    print_info "Création de debian/js-auto-deployer.install..."
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

    print_success "Tous les fichiers debian/ ont été créés"
}

# Copier les fichiers du projet dans la structure
copy_project_files() {
    print_step "Copie des fichiers du projet dans la structure DEB"
    
    print_info "Copie des fichiers nécessaires..."
    
    # Copier les scripts
    if [ -d "scripts" ]; then
        cp -r scripts "${DEB_STRUCTURE_DIR}/"
        print_success "Scripts copiés"
    else
        print_warning "Répertoire scripts/ non trouvé"
    fi
    
    # Copier la configuration
    if [ -d "config" ]; then
        cp -r config "${DEB_STRUCTURE_DIR}/"
        print_success "Configuration copiée"
    else
        print_warning "Répertoire config/ non trouvé"
    fi
    
    # Copier les fichiers principaux
    for file in install.sh configure.sh README.md QUICKSTART.md; do
        if [ -f "$file" ]; then
            cp "$file" "${DEB_STRUCTURE_DIR}/"
            print_success "$file copié"
        else
            print_warning "$file non trouvé"
        fi
    done
}

# Afficher le résumé final
show_summary() {
    print_header "✅ Initialisation Terminée avec Succès"
    
    echo -e "${GREEN}Structure de répertoires créée:${NC}"
    echo ""
    if command -v tree &> /dev/null; then
        tree -L 4 "${DEB_STRUCTURE_DIR}" 2>/dev/null || find "${DEB_STRUCTURE_DIR}" -type d | sed 's|[^/]*/| |g' | sort
    else
        find "${DEB_STRUCTURE_DIR}" -type d | sed 's|[^/]*/| |g' | sort
    fi
    echo ""
    
    print_info "Répertoire de structure: ${DEB_STRUCTURE_DIR}"
    echo ""
    
    print_header "📋 Prochaines Étapes"
    echo ""
    echo -e "${CYAN}1.${NC} Vérifiez et modifiez les fichiers debian/ si nécessaire"
    echo "   cd ${DEB_STRUCTURE_DIR}"
    echo "   nano debian/control  # Modifier les métadonnées"
    echo ""
    echo -e "${CYAN}2.${NC} Construisez le package DEB:"
    echo "   cd ${DEB_STRUCTURE_DIR}"
    echo "   debuild -us -uc  # Sans signature GPG"
    echo "   # ou"
    echo "   debuild -kYOUR_GPG_KEY_ID  # Avec signature GPG"
    echo ""
    echo -e "${CYAN}3.${NC} Le paquet sera créé dans: ${BASE_DIR}/"
    echo "   js-auto-deployer_*.deb"
    echo ""
    echo -e "${CYAN}4.${NC} Consultez le GUIDE_APT_PUBLICATION.md pour:"
    echo "   - Créer un dépôt APT"
    echo "   - Configurer les clients"
    echo "   - Publier le package"
    echo ""
    print_success "✨ Initialisation complète terminée !"
}

# Afficher l'aide
show_help() {
    cat <<EOF
JS Auto Deployer - Script d'Initialisation DEB

Usage: $0 [OPTIONS]

OPTIONS:
    --skip-deps       Ignorer l'installation des dépendances système
    --skip-install    Ignorer les vérifications de permissions root
    --help            Afficher cette aide

DESCRIPTION:
    Ce script automatise toutes les étapes d'initialisation pour créer
    un package DEB de js-auto-deployer :
    
    1. Installation des outils de construction DEB
    2. Création de la structure de répertoires
    3. Génération de tous les fichiers debian/
    4. Copie des fichiers du projet

EXAMPLES:
    $0                    # Initialisation complète
    $0 --skip-deps        # Ignorer l'installation des dépendances
    sudo $0               # Avec permissions root pour tout installer

Pour plus d'informations, consultez GUIDE_APT_PUBLICATION.md
EOF
}

# Fonction principale
main() {
    # Traitement des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-deps)
                SKIP_DEPS=true
                shift
                ;;
            --skip-install)
                SKIP_INSTALL=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done

    print_header "🚀 Initialisation Complète du Package DEB"
    print_info "JS Auto Deployer - Script d'Initialisation"
    echo ""
    
    check_directory
    check_root
    
    # Exécution des étapes
    install_build_dependencies
    create_deb_structure
    create_deb_files
    copy_project_files
    show_summary
}

# Gestion des signaux
trap 'echo -e "\n${RED}Initialisation interrompue${NC}"; exit 130' INT TERM

# Exécution
main "$@"
