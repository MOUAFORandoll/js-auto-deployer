# Guide de Publication APT/DEB pour js-auto-deployer

Ce guide explique comment publier `js-auto-deployer` sur un dépôt APT pour le rendre accessible via `apt install` sur les systèmes Linux/Unix (Debian, Ubuntu, etc.).

## 📋 Prérequis

- Serveur avec accès root/sudo
- Outils de construction de paquets DEB installés
- Accès à un serveur de dépôt APT (ou création d'un nouveau dépôt)
- Clés GPG pour signer les paquets
- Serveur web pour héberger le dépôt

## 🚀 Démarrage Rapide

### Construction Automatique en Une Commande

Le script `init.sh` automatise **toutes** les étapes de création du package DEB :

```bash
# Construction complète automatique (recommandé)
sudo ./init.sh --build

# Mode non-interactif (détecte automatiquement les métadonnées depuis git)
sudo ./init.sh --non-interactive --build
```

Le script `init.sh` effectue automatiquement :

1. ✅ Installation des outils de construction DEB
2. ✅ **Détection automatique** des métadonnées :
   - Nom et email depuis `git config`
   - Version depuis `package.json`
   - Homepage depuis l'URL du dépôt git
3. ✅ Création de la structure de répertoires
4. ✅ Génération de tous les fichiers debian/
5. ✅ Copie des fichiers du projet
6. ✅ **Construction automatique du package DEB** (avec `--build`)

**Résultat :** Le fichier `.deb` est créé directement, prêt à être installé ou publié !

### Options du Script

```bash
# Initialisation seulement (sans construction)
sudo ./init.sh

# Construction automatique
sudo ./init.sh --build

# Mode non-interactif (utilise les valeurs détectées automatiquement)
sudo ./init.sh --non-interactive --build

# Sans installation des dépendances
./init.sh --skip-deps --build
```

**Note:** Si vous préférez faire l'initialisation manuellement, consultez les sections détaillées ci-dessous.

---

## 📝 Initialisation Manuelle (Optionnel)

<details>
<summary>Cliquez pour voir les étapes manuelles d'initialisation</summary>

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

Les fichiers debian/ sont générés automatiquement par `init.sh`. Pour une création manuelle, consultez le script `init.sh` comme référence.

</details>

---

## 4. Construction du Paquet DEB

> **💡 Astuce :** Si vous avez utilisé `./init.sh --build`, le package est déjà construit ! Passez à la section suivante.

### Construction Automatique (Recommandé)

Si vous n'avez pas utilisé `--build` lors de l'initialisation :

```bash
# Dans le répertoire js-auto-deployer créé par init.sh
cd js-auto-deployer
debuild -us -uc  # Sans signature GPG
```

### Construction Manuelle

```bash
# Construire le paquet
cd js-auto-deployer
debuild -us -uc

# Ou avec signature GPG
debuild -kYOUR_GPG_KEY_ID
```

Le paquet sera créé dans le répertoire parent : `js-auto-deployer_1.0.0-1_all.deb`

### Installation Locale (Test)

Après la construction, vous pouvez installer le package localement pour tester :

```bash
# Installer le package
sudo dpkg -i js-auto-deployer_*.deb

# Résoudre les dépendances manquantes si nécessaire
sudo apt-get install -f

# Vérifier l'installation
js-deploy --version
js-status
```

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
