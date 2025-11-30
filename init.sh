#!/bin/bash

# JS Auto Deployer - Script d'initialisation complète pour le package DEB
# Version: 2.0.0
# Description: Automatise toutes les étapes d'initialisation pour créer un package DEB
#              Inclut : installation des dépendances, création de la structure,
#              et génération de tous les fichiers debian/

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\0333[0;32m'
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
AUTO_BUILD=false
NON_INTERACTIVE=false

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
    mkdir -p "${DEB_STRUCTURE_DIR}/usr/bin"
    print_success "usr/bin/ créé"

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

    # Détection automatique des informations du mainteneur
    print_info "Détection automatique des métadonnées du package..."
    
    # Détecter le nom et l'email depuis git
    GIT_NAME=$(git config user.name 2>/dev/null || echo "")
    GIT_EMAIL=$(git config user.email 2>/dev/null || echo "")
    GIT_REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
    
    # Extraire l'URL GitHub si possible
    if [[ "$GIT_REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
        GIT_USER="${BASH_REMATCH[1]}"
        GIT_REPO="${BASH_REMATCH[2]%.git}"
        DETECTED_HOMEPAGE="https://github.com/${GIT_USER}/${GIT_REPO}"
    else
        DETECTED_HOMEPAGE="https://github.com/MOUAFORandoll/js-auto-deployer.git"
    fi
    
    # Valeurs par défaut avec informations de l'auteur
    AUTHOR_NAME="MOUAFO RANDOLL"
    AUTHOR_EMAIL="hari.randoll@gmail.com"
    AUTHOR_HOMEPAGE="https://github.com/MOUAFORandoll/js-auto-deployer.git"
    
    # Valeurs par défaut intelligentes (détection depuis git ou utilisation des infos auteur)
    DEFAULT_NAME="${GIT_NAME:-"${AUTHOR_NAME}"}"
    DEFAULT_EMAIL="${GIT_EMAIL:-"${AUTHOR_EMAIL}"}"
    DEFAULT_HOMEPAGE="${DETECTED_HOMEPAGE:-"${AUTHOR_HOMEPAGE}"}"
    
    # Lire la version depuis package.json si disponible
    if [ -f "package.json" ]; then
        DETECTED_VERSION=$(grep -E '"version"' package.json | head -1 | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' 2>/dev/null || echo "")
    fi
    
    # Version par défaut si non trouvée
    DETECTED_VERSION="${DETECTED_VERSION:-"1.0.0"}"
    
    if [ "$NON_INTERACTIVE" = true ]; then
        # Mode non-interactif : utiliser les valeurs détectées
        MAINTAINER_NAME="${DEFAULT_NAME}"
        MAINTAINER_EMAIL="${DEFAULT_EMAIL}"
        HOMEPAGE="${DEFAULT_HOMEPAGE}"
        PACKAGE_VERSION="${DETECTED_VERSION}"
        print_info "Mode non-interactif : utilisation des valeurs détectées"
        print_info "  Mainteneur: ${MAINTAINER_NAME} <${MAINTAINER_EMAIL}>"
        print_info "  Homepage: ${HOMEPAGE}"
        print_info "  Version: ${PACKAGE_VERSION}"
    else
        # Mode interactif avec valeurs par défaut
        print_info "Configuration des métadonnées du package..."
        echo ""
        print_info "Valeurs détectées automatiquement :"
        echo "  Nom: ${DEFAULT_NAME}"
        echo "  Email: ${DEFAULT_EMAIL}"
        echo "  Homepage: ${DEFAULT_HOMEPAGE}"
        echo "  Version: ${DETECTED_VERSION}"
        echo ""
        
        read -p "Nom du mainteneur [${DEFAULT_NAME}]: " MAINTAINER_NAME
        MAINTAINER_NAME=${MAINTAINER_NAME:-"${DEFAULT_NAME}"}
        
        read -p "Email du mainteneur [${DEFAULT_EMAIL}]: " MAINTAINER_EMAIL
        MAINTAINER_EMAIL=${MAINTAINER_EMAIL:-"${DEFAULT_EMAIL}"}
        
        read -p "Homepage GitHub [${DEFAULT_HOMEPAGE}]: " HOMEPAGE
        HOMEPAGE=${HOMEPAGE:-"${DEFAULT_HOMEPAGE}"}
        
        read -p "Version du package [${DETECTED_VERSION}]: " PACKAGE_VERSION
        PACKAGE_VERSION=${PACKAGE_VERSION:-"${DETECTED_VERSION}"}
    fi
    
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
Copyright: ${CURRENT_YEAR} MOUAFO RANDOLL <hari.randoll@gmail.com>
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
	mkdir -p $(CURDIR)/debian/js-auto-deployer/usr/bin
	mkdir -p $(CURDIR)/debian/js-auto-deployer/var/log/js-auto-deployer

	# Copier les fichiers
	cp -r scripts $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp -r config $(CURDIR)/debian/js-auto-deployer/etc/js-auto-deployer/
	cp install.sh $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp configure.sh $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp README.md $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/
	cp QUICKSTART.md $(CURDIR)/debian/js-auto-deployer/opt/js-auto-deployer/

	# Créer les liens symboliques
	ln -s /opt/js-auto-deployer/scripts/deploy.sh $(CURDIR)/debian/js-auto-deployer/usr/bin/js-deploy
	ln -s /opt/js-auto-deployer/configure.sh $(CURDIR)/debian/js-auto-deployer/usr/bin/js-configure
	ln -s /opt/js-auto-deployer/scripts/status.sh $(CURDIR)/debian/js-auto-deployer/usr/bin/js-status
	ln -s /opt/js-auto-deployer/scripts/smtp.config.sh $(CURDIR)/debian/js-auto-deployer/usr/bin/js-setup-email
	ln -s /opt/js-auto-deployer/scripts/test-email.sh $(CURDIR)/debian/js-auto-deployer/usr/bin/js-test-email
	ln -s /opt/js-auto-deployer/scripts/uninstall.sh $(CURDIR)/debian/js-auto-deployer/usr/bin/js-uninstall

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

    # debian/compat (spécifie le niveau de compatibilité debhelper)
    print_info "Création de debian/compat..."
    echo "11" > "${DEB_STRUCTURE_DIR}/debian/compat"
    print_success "debian/compat créé"

    print_success "Tous les fichiers debian/ ont été créés"
}

# Copier les fichiers du projet dans la structure
copy_project_files() {
    print_step "Copie des fichiers du projet dans la structure DEB"
    
    print_info "Copie des fichiers nécessaires..."
    
    # Copier les scripts
    if [ -d "scripts" ]; then
        cp -r scripts "${DEB_STRUCTURE_DIR}/"
        chmod +x "${DEB_STRUCTURE_DIR}/scripts/"*.sh 2>/dev/null || true
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
            if [[ "$file" == *.sh ]]; then
                chmod +x "${DEB_STRUCTURE_DIR}/$file"
            fi
            print_success "$file copié"
        else
            print_warning "$file non trouvé"
        fi
    done
}

# Construire le package DEB
build_deb_package() {
    print_step "Construction du Package DEB"
    
    if ! command -v debuild &> /dev/null; then
        print_error "debuild n'est pas disponible"
        print_info "Installez avec: sudo apt-get install devscripts debhelper"
        return 1
    fi
    
    print_info "Construction du package dans ${DEB_STRUCTURE_DIR}..."
    
    cd "${DEB_STRUCTURE_DIR}"
    
    # Vérifier que debian/compat existe (nécessaire pour debhelper)
    if [ ! -f debian/compat ]; then
        print_warning "Fichier debian/compat manquant, création..."
        echo "11" > debian/compat
    fi
    
    # Nettoyer les anciens builds
    if [ -f debian/files ] || [ -d debian/js-auto-deployer ]; then
        print_info "Nettoyage des anciens builds..."
        rm -rf debian/js-auto-deployer debian/files debian/.debhelper 2>/dev/null || true
        # Ne pas lancer fakeroot debian/rules clean car cela peut échouer si debhelper n'est pas configuré
    fi
    
    # Créer le fichier .orig.tar.gz si nécessaire (requis par debuild)
    local orig_file="${BASE_DIR}/js-auto-deployer_${PACKAGE_VERSION}.orig.tar.gz"
    if [ ! -f "$orig_file" ]; then
        print_info "Création du fichier .orig.tar.gz..."
        cd "${BASE_DIR}"
        
        # Créer une copie temporaire sans le répertoire debian
        local temp_dir=$(mktemp -d)
        cp -r js-auto-deployer "$temp_dir/" 2>/dev/null || {
            print_warning "Impossible de créer .orig.tar.gz automatiquement"
            print_info "Continuez, debuild vous demandera de continuer"
        }
        
        if [ -d "$temp_dir/js-auto-deployer" ]; then
            rm -rf "$temp_dir/js-auto-deployer/debian" 2>/dev/null || true
            cd "$temp_dir"
            tar -czf "$orig_file" js-auto-deployer/ 2>/dev/null && {
                print_success "Fichier .orig.tar.gz créé"
            } || {
                print_warning "Échec de création du .orig.tar.gz, debuild continuera"
            }
            cd "${BASE_DIR}"
            rm -rf "$temp_dir"
        fi
    else
        print_info "Fichier .orig.tar.gz existe déjà"
    fi
    
    cd "${DEB_STRUCTURE_DIR}"
    
    # Construire le package
    print_info "Lancement de debuild (cela peut prendre quelques minutes)..."
    print_warning "Si debuild demande de continuer sans .orig, répondez 'y'"
    
    # Capturer la sortie
    local build_output="/tmp/debuild-$(date +%s).log"
    
    # Lancer debuild avec gestion automatique de la réponse
    # Utiliser yes pour répondre automatiquement à la question sur .orig
    print_info "Démarrage de la construction (cela peut prendre quelques minutes)..."
    
    # Lancer debuild et capturer le résultat correctement
    # Créer un pipe nommé pour capturer le code de retour
    set +e  # Désactiver set -e temporairement pour gérer l'erreur
    echo "y" | debuild -us -uc 2>&1 | tee "$build_output"
    BUILD_EXIT_CODE=${PIPESTATUS[0]}
    set -e  # Réactiver set -e
    
    # Toujours vérifier si un fichier .deb a été créé (même en cas d'erreur partielle)
    DEB_FILE=$(find "${BASE_DIR}" -maxdepth 1 -name "js-auto-deployer_*.deb" -type f 2>/dev/null | head -1)
    
    if [ -n "$DEB_FILE" ] && [ -f "$DEB_FILE" ]; then
        DEB_SIZE=$(du -h "$DEB_FILE" | cut -f1)
        if [ "$BUILD_EXIT_CODE" -eq 0 ]; then
            print_success "Package DEB construit avec succès !"
        else
            print_warning "Des erreurs ont été rencontrées mais un fichier .deb a été généré"
        fi
        print_success "Package créé: $(basename "$DEB_FILE") (${DEB_SIZE})"
        print_info "Emplacement: ${DEB_FILE}"
        return 0
    else
        print_error "Échec de la construction du package"
        if [ "$BUILD_EXIT_CODE" -ne 0 ]; then
            print_info "Code de retour: $BUILD_EXIT_CODE"
        fi
        print_info "Consultez les logs détaillés: $build_output"
        echo ""
        print_info "Solutions possibles:"
        print_info "  1. Vérifiez que le fichier debian/compat existe (doit contenir '11')"
        print_info "  2. Vérifiez les erreurs dans le log ci-dessus"
        print_info "  3. Essayez de construire manuellement:"
        print_info "     cd ${DEB_STRUCTURE_DIR}"
        print_info "     debuild -us -uc"
        return 1
    fi
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
    
    if [ "$AUTO_BUILD" = false ]; then
        echo -e "${CYAN}1.${NC} (Optionnel) Vérifiez et modifiez les fichiers debian/ si nécessaire"
        echo "   cd ${DEB_STRUCTURE_DIR}"
        echo "   nano debian/control  # Modifier les métadonnées"
        echo ""
        echo -e "${CYAN}2.${NC} Construisez le package DEB:"
        echo "   cd ${DEB_STRUCTURE_DIR}"
        echo "   debuild -us -uc  # Sans signature GPG"
        echo ""
        echo -e "${CYAN}3.${NC} Le paquet sera créé dans: ${BASE_DIR}/"
        echo "   js-auto-deployer_*.deb"
        echo ""
        echo -e "${CYAN}4.${NC} Consultez le GUIDE_APT_PUBLICATION.md pour:"
        echo "   - Créer un dépôt APT"
        echo "   - Configurer les clients"
        echo "   - Publier le package"
    else
        echo -e "${CYAN}✓${NC} Le package DEB a été construit automatiquement !"
        echo ""
        echo -e "${CYAN}Prochaines étapes:${NC}"
        echo "  1. Le fichier .deb est dans: ${BASE_DIR}/"
        echo "  2. Installez-le localement avec: sudo dpkg -i ${BASE_DIR}/js-auto-deployer_*.deb"
        echo "  3. Consultez GUIDE_APT_PUBLICATION.md pour créer un dépôt APT"
    fi
    echo ""
    print_success "✨ Initialisation complète terminée !"
}

# Afficher l'aide
show_help() {
    cat <<EOF
JS Auto Deployer - Script d'Initialisation DEB

Usage: $0 [OPTIONS]

OPTIONS:
    --skip-deps          Ignorer l'installation des dépendances système
    --skip-install       Ignorer les vérifications de permissions root
    --build              Construire automatiquement le package DEB après l'initialisation
    --non-interactive    Mode non-interactif (utilise les valeurs détectées automatiquement)
    --help               Afficher cette aide

DESCRIPTION:
    Ce script automatise toutes les étapes d'initialisation pour créer
    un package DEB de js-auto-deployer :
    
    1. Installation des outils de construction DEB
    2. Création de la structure de répertoires
    3. Génération de tous les fichiers debian/
    4. Copie des fichiers du projet

EXAMPLES:
    $0                           # Initialisation complète interactive
    $0 --build                   # Initialisation + construction automatique du package
    $0 --non-interactive --build # Mode automatique complet (sans questions)
    $0 --skip-deps               # Ignorer l'installation des dépendances
    sudo $0 --build              # Avec permissions root + construction automatique

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
            --build)
                AUTO_BUILD=true
                shift
                ;;
            --non-interactive)
                NON_INTERACTIVE=true
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
    
    # Construction automatique si demandée
    if [ "$AUTO_BUILD" = true ]; then
        build_deb_package
    fi
    
    show_summary
}

# Gestion des signaux
trap 'echo -e "\n${RED}Initialisation interrompue${NC}"; exit 130' INT TERM

# Exécution
main "$@"
