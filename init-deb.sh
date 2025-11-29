#!/bin/bash

# Script d'initialisation de la structure DEB pour js-auto-deployer
# Ce script crée la structure de répertoires nécessaire pour construire un paquet DEB
# Usage: ./init-deb.sh

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEB_ROOT="$SCRIPT_DIR/deb-structure"

print_info "Initialisation de la structure DEB pour $PACKAGE_NAME"

# Fonction pour créer la structure complète
create_structure() {
    print_info "Création de la structure de répertoires..."
    
    # Nettoyer si existe déjà
    if [ -d "$DEB_ROOT" ]; then
        print_warning "Le répertoire $DEB_ROOT existe déjà"
        read -p "Voulez-vous le supprimer et recommencer ? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$DEB_ROOT"
            print_success "Ancien répertoire supprimé"
        else
            print_info "Conservation de la structure existante"
            return 0
        fi
    fi
    
    # Créer la structure complète
    mkdir -p "$DEB_ROOT/$PACKAGE_NAME/debian"
    mkdir -p "$DEB_ROOT/$PACKAGE_NAME/etc/$PACKAGE_NAME/config"
    mkdir -p "$DEB_ROOT/$PACKAGE_NAME/opt/$PACKAGE_NAME"
    mkdir -p "$DEB_ROOT/$PACKAGE_NAME/usr/local/bin"
    mkdir -p "$DEB_ROOT/$PACKAGE_NAME/var/log/$PACKAGE_NAME"
    
    print_success "Structure de répertoires créée"
}

# Créer les fichiers de base dans debian/
create_debian_files() {
    print_info "Création des fichiers DEB de base..."
    
    local debian_dir="$DEB_ROOT/$PACKAGE_NAME/debian"
    
    # Créer les fichiers vides avec des commentaires
    cat > "$debian_dir/changelog" << 'EOF'
# Fichier changelog pour le paquet DEB
# Format: package (version) distribution; urgency=urgency
# Exemple:
# js-auto-deployer (1.0.0-1) unstable; urgency=medium
#
#   * Version initiale
#
# -- Maintainer <email@example.com>  Mon, 01 Jan 2024 12:00:00 +0000
EOF

    cat > "$debian_dir/control" << 'EOF'
# Fichier control pour le paquet DEB
# Définit les métadonnées du paquet
# Voir: https://www.debian.org/doc/debian-policy/ch-controlfields.html
EOF

    cat > "$debian_dir/copyright" << 'EOF'
# Fichier copyright pour le paquet DEB
# Définit les informations de licence et copyright
# Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
EOF

    cat > "$debian_dir/rules" << 'EOF'
#!/usr/bin/make -f

# Fichier rules pour la construction du paquet DEB
# Contient les règles de construction Makefile
# Voir: https://www.debian.org/doc/debian-policy/ch-source.html#s-debianrules
EOF
    chmod +x "$debian_dir/rules"

    cat > "$debian_dir/postinst" << 'EOF'
#!/bin/bash
# Script post-installation
# Exécuté après l'installation du paquet
# Voir: https://www.debian.org/doc/debian-policy/ch-maintainerscripts.html
set -e

echo "Configuration de js-auto-deployer..."
EOF
    chmod +x "$debian_dir/postinst"

    cat > "$debian_dir/postrm" << 'EOF'
#!/bin/bash
# Script post-suppression
# Exécuté après la suppression du paquet
set -e

# Actions de nettoyage si nécessaire
EOF
    chmod +x "$debian_dir/postrm"

    cat > "$debian_dir/prerm" << 'EOF'
#!/bin/bash
# Script pré-suppression
# Exécuté avant la suppression du paquet
set -e

# Actions de préparation si nécessaire
EOF
    chmod +x "$debian_dir/prerm"

    cat > "$debian_dir/$PACKAGE_NAME.install" << 'EOF'
# Fichier .install pour spécifier les fichiers à installer
# Format: source destination
# Exemple:
# opt/js-auto-deployer/* /opt/js-auto-deployer/
# etc/js-auto-deployer/* /etc/js-auto-deployer/
EOF

    print_success "Fichiers DEB de base créés"
}

# Créer un fichier README dans la structure
create_readme() {
    print_info "Création du README de la structure..."
    
    cat > "$DEB_ROOT/README.md" << 'EOF'
# Structure DEB pour js-auto-deployer

Cette structure a été générée par le script `init-deb.sh`.

## Structure

```
js-auto-deployer/
├── debian/                    # Fichiers de construction DEB
│   ├── changelog              # Historique des versions
│   ├── control                # Métadonnées du paquet
│   ├── copyright              # Informations de licence
│   ├── rules                  # Règles de construction
│   ├── postinst               # Script post-installation
│   ├── postrm                 # Script post-suppression
│   ├── prerm                  # Script pré-suppression
│   └── js-auto-deployer.install  # Fichiers à installer
├── etc/                       # Fichiers de configuration système
│   └── js-auto-deployer/
│       └── config/            # Configuration
├── opt/                       # Logiciels optionnels
│   └── js-auto-deployer/     # Fichiers du package
├── usr/                       # Fichiers utilisateur
│   └── local/
│       └── bin/               # Commandes binaires
└── var/                       # Données variables
    └── log/
        └── js-auto-deployer/  # Logs
```

## Prochaines étapes

1. Copier les fichiers du package dans `opt/js-auto-deployer/`
2. Remplir les fichiers dans `debian/` avec les informations appropriées
3. Utiliser `build-deb.sh` pour construire le paquet
4. Suivre le guide `GUIDE_APT_PUBLICATION.md` pour publier

## Références

- [Debian Packaging Guide](https://www.debian.org/doc/manuals/packaging-tutorial/)
- [Debian Policy Manual](https://www.debian.org/doc/debian-policy/)
EOF

    print_success "README créé"
}

# Afficher un résumé
show_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}     Structure DEB Initialisée avec Succès    ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    print_success "Structure créée dans: $DEB_ROOT"
    echo ""
    echo -e "${BLUE}📁 Structure créée:${NC}"
    tree -L 3 "$DEB_ROOT" 2>/dev/null || find "$DEB_ROOT" -type d | sed 's|[^/]*/| |g'
    echo ""
    
    print_info "Prochaines étapes:"
    echo "  1. Copier les fichiers du package dans: $DEB_ROOT/$PACKAGE_NAME/opt/$PACKAGE_NAME/"
    echo "  2. Remplir les fichiers dans: $DEB_ROOT/$PACKAGE_NAME/debian/"
    echo "  3. Utiliser build-deb.sh pour construire le paquet"
    echo "  4. Consulter GUIDE_APT_PUBLICATION.md pour la publication"
    echo ""
}

# Fonction principale
main() {
    echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   Initialisation Structure DEB                 ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    
    create_structure
    create_debian_files
    create_readme
    show_summary
    
    print_success "✅ Initialisation terminée!"
}

# Vérifier si tree est disponible
if ! command -v tree &> /dev/null; then
    print_warning "La commande 'tree' n'est pas disponible. L'affichage sera simplifié."
fi

# Exécution
main "$@"

