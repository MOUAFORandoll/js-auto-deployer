#!/bin/bash

# JS Auto Deployer - Créateur de Package
# Version: 1.0.0
# Description: Script pour créer le package de distribution

set -e

# Variables
PACKAGE_NAME="js-auto-deployer"
PACKAGE_VERSION="1.0.0"
BUILD_DIR="build"
ARCHIVE_NAME="${PACKAGE_NAME}-v${PACKAGE_VERSION}"

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Nettoyage
clean_build() {
    print_info "Nettoyage du répertoire de build..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# Copie des fichiers
copy_files() {
    print_info "Copie des fichiers du package..."
    
    # Structure du package
    mkdir -p "$BUILD_DIR/$ARCHIVE_NAME"/{scripts,config/projects,docs}
    
    # Scripts principaux
    cp install.sh "$BUILD_DIR/$ARCHIVE_NAME/"
    cp configure.sh "$BUILD_DIR/$ARCHIVE_NAME/"
    cp create-package.sh "$BUILD_DIR/$ARCHIVE_NAME/"
    chmod +x "$BUILD_DIR/$ARCHIVE_NAME"/*.sh
    
    # Scripts dans scripts/
    if [ -d scripts ]; then
        cp scripts/*.sh "$BUILD_DIR/$ARCHIVE_NAME/scripts/" 2>/dev/null || true
        chmod +x "$BUILD_DIR/$ARCHIVE_NAME/scripts"/*.sh 2>/dev/null || true
    fi
    
    # Configuration
    if [ -d config ]; then
        cp config/*.template "$BUILD_DIR/$ARCHIVE_NAME/config/" 2>/dev/null || true
        if [ -d config/projects ]; then
            cp config/projects/*.template "$BUILD_DIR/$ARCHIVE_NAME/config/projects/" 2>/dev/null || true
        fi
    fi
    
    # Documentation
    cp README.md "$BUILD_DIR/$ARCHIVE_NAME/" 2>/dev/null || true
    cp QUICKSTART.md "$BUILD_DIR/$ARCHIVE_NAME/" 2>/dev/null || true
    
    # Fichier de version
    echo "$PACKAGE_VERSION" > "$BUILD_DIR/$ARCHIVE_NAME/VERSION"
    
    print_success "Fichiers copiés"
}

# Création de l'archive
create_archive() {
    print_info "Création de l'archive..."
    
    cd "$BUILD_DIR"
    tar -czf "${ARCHIVE_NAME}.tar.gz" "$ARCHIVE_NAME"
    
    # Création d'une checksum
    sha256sum "${ARCHIVE_NAME}.tar.gz" > "${ARCHIVE_NAME}.tar.gz.sha256"
    
    cd ..
    
    print_success "Archive créée: $BUILD_DIR/${ARCHIVE_NAME}.tar.gz"
}

# Vérification du package
verify_package() {
    print_info "Vérification du package..."
    
    # Vérifier la taille
    local size=$(du -h "$BUILD_DIR/${ARCHIVE_NAME}.tar.gz" | cut -f1)
    print_info "Taille du package: $size"
    
    # Vérifier le contenu
    print_info "Contenu du package:"
    tar -tzf "$BUILD_DIR/${ARCHIVE_NAME}.tar.gz" | head -20
    
    # Vérifier les permissions
    local errors=0
    
    # Vérifier les scripts exécutables
    local sh_files=$(tar -tzf "$BUILD_DIR/${ARCHIVE_NAME}.tar.gz" | grep "\.sh$" | head -10)
    for file in $sh_files; do
        if [[ "$file" == *.sh ]]; then
            print_info "Vérification: $file"
            if ! tar -tzf "$BUILD_DIR/${ARCHIVE_NAME}.tar.gz" | grep -q "$file"; then
                print_error "Script manquant: $file"
                ((errors++))
            fi
        fi
    done
    
    if [ $errors -eq 0 ]; then
        print_success "Vérification réussie"
    else
        print_error "$errors erreurs détectées"
        exit 1
    fi
}

# Affichage du rapport final
show_final_report() {
    print_success "Package créé avec succès !"
    echo ""
    echo -e "${BLUE}📦 Package:${NC} $BUILD_DIR/${ARCHIVE_NAME}.tar.gz"
    echo -e "${BLUE}🔐 Checksum:${NC} $BUILD_DIR/${ARCHIVE_NAME}.tar.gz.sha256"
    echo ""
    echo -e "${BLUE}📋 Instructions d'installation:${NC}"
    echo "  1. wget https://votre-serveur.com/${ARCHIVE_NAME}.tar.gz"
    echo "  2. tar -xzf ${ARCHIVE_NAME}.tar.gz"
    echo "  3. cd $ARCHIVE_NAME"
    echo "  4. sudo ./install.sh"
    echo ""
}

# Fonction principale
main() {
    echo -e "${BLUE}JS Auto Deployer - Créateur de Package v${PACKAGE_VERSION}${NC}"
    echo ""
    
    clean_build
    copy_files
    create_archive
    verify_package
    show_final_report
}

# Exécution
main "$@"