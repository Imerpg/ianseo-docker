# Ianseo-Install - Installateur Docker pour Ianseo

> **Une solution clé en main pour déployer Ianseo en 3 étapes, même si vous ne connaissez rien à l'informatique !**

Ianseo-Install est un outil qui installe automatiquement **Ianseo** (le logiciel de gestion de compétitions de tir à l'arc le plus utilisé au monde) sur votre ordinateur, **sans avoir à configurer quoi que ce soit manuellement**.

Tout fonctionne dans des conteneurs (comme des boîtes virtuelles) grâce à Docker, ce qui garantit que votre ordinateur reste propre et que tout fonctionne du premier coup.

---

## Table des matières

- [Prerequis](#prerequis)
- [Installation rapide (3 étapes)](#installation-rapide)
- [Première utilisation](#première-utilisation)
- [Questions fréquentes (FAQ)](#questions-fréquentes)
- [Dépannage](#dépannage)
- [A propos d-Ianseo](#à-propos-dianseo)
- [Licence](#licence)

---

## Prerequis

### 1. Installer Docker

Docker est obligatoire pour faire fonctionner cet installateur.

#### Sur Windows 10/11
1. Téléchargez Docker Desktop depuis : https://www.docker.com/products/docker-desktop/
2. Installez-le en suivant les instructions (acceptez toutes les options par défaut)
3. Redémarrez votre ordinateur après l-installation
4. Lancez Docker Desktop (attendez qu-il soit Running)

#### Sur macOS
1. Téléchargez Docker Desktop depuis : https://www.docker.com/products/docker-desktop/
2. Installez-le
3. Lancez Docker Desktop

#### Sur Linux (Ubuntu/Debian)
Ouvrez un terminal et exécutez:
sudo apt update && sudo apt install docker.io docker-compose -y
sudo systemctl enable --now docker

Pour vérifier que Docker est installé:
Ouvrez un terminal et tapez:
docker --version
Si vous voyez Docker version 25.x.x, c'est bon.

---

## Installation rapide (3 étapes)

### Etape 1: Télécharger le projet

Ouvrez un terminal et exécutez:

git clone https://github.com/Imerpg/ianseo-installer.git ianseo-installer
cd ianseo-installer

Si vous ne savez pas utiliser git:
- Téléchargez le projet en ZIP depuis GitHub
- Décompressez-le dans un dossier de votre choix
- Ouvrez un terminal dans ce dossier

### Etape 2: Configurer (facultatif)

Le projet fonctionne avec des paramètres par défaut.

1. Copiez le fichier d-exemple:
cp .env-prod .env

2. Editez le fichier .env avec un éditeur de texte:
- IANSEO_VERSION: Version d-Ianseo à installer (format: AAAAMMJJ, ex: 20250210)
- WEB_PORT: Port pour accéder à Ianseo (par défaut: 80)
- MYSQL_ROOT_PASSWORD: MOT DE PASSE pour la base de données (à changer impérativement!)
- MYSQL_DATABASE: Nom de la base de données (par défaut: ianseo)
- MYSQL_USER: Utilisateur de la base de données (par défaut: ianseo)
- MYSQL_PASSWORD: Mot de passe de l-utilisateur (par défaut: ianseo)

IMPORTANT: Changez MYSQL_ROOT_PASSWORD et MYSQL_PASSWORD par des mots de passe FORTS et DIFFERENTS avant de démarrer.

### Etape 3: Démarrer Ianseo

Dans le terminal, exécutez:

docker compose up -d --build

Le système va:
1. Télécharger Ianseo automatiquement
2. Installer la base de données MySQL
3. Configurer tout automatiquement
4. Démarrer l-application
5. Mettre à jour Ianseo automatiquement (si une nouvelle version est disponible)

Durée estimée: Entre 30 secondes et 2 minutes (inclut la mise à jour automatique).
n
> ✅ **Mise à jour automatique incluse** : Aucune action nécessaire de votre part. Le système vérifie et installe automatiquement la dernière version d-Ianseo à chaque démarrage.

---

## Première utilisation

### Accéder à Ianseo

Une fois l-installation terminée:

1. Ouvrez votre navigateur (Chrome, Firefox, Edge, etc.)
2. Allez à l-adresse: http://localhost/ianseo/

Attention: N-oubliez pas le / à la fin de l-URL.

3. Vous devriez voir l-interface d-Ianseo

### Identifiants de connexion

Par défaut, Ianseo utilise:
- Utilisateur: admin
- Mot de passe: admin

(Ces identifiants sont ceux d-Ianseo par défaut, pas ceux de la base de données)

---

## Mise à jour

Pour mettre à jour Ianseo:

1. Arrêtez les conteneurs:
docker compose down

2. Modifiez la version dans .env:
IANSEO_VERSION=20260315

3. Redémarrez:
docker compose up -d --build

---

## Questions fréquentes (FAQ)

### Q: Je vois une erreur port already in use
R: Le port 80 est déjà utilisé. Changez le port dans .env:
WEB_PORT=8080
Puis accédez à http://localhost:8080/ianseo/

### Q: Comment arrêter Ianseo?
R: docker compose down

### Q: Comment redémarrer Ianseo?
R:
cd ianseo-installer
docker compose up -d

### Q: Où sont stockées mes données?
R: Vos données sont sauvegardées dans des volumes Docker. Elles persistent même après avoir arrêté les conteneurs.

### Q: Comment tout réinitialiser?
R: ATTENTION, cela effacera toutes vos données:
docker compose down -v
docker compose up -d --build

### Q: Je n-arrive pas à accéder à Ianseo
R: Vérifiez que:
1. Docker est bien lancé
2. Vous avez attendu assez longtemps (au moins 2 minutes)
3. Vous utilisez la bonne URL: http://localhost/ianseo/

---

## Dépannage

### Docker n-est pas reconnu
- Windows/macOS: Assurez-vous que Docker Desktop est lancé
- Linux: Vérifiez que vous êtes dans le groupe docker:
sudo usermod -aG docker $USER
Puis redémarrez votre session.

### Le téléchargement bloque
- Vérifiez votre connexion internet
- Assurez-vous qu-aucune restriction ne bloque ianseo.net
- Essayez une version plus ancienne dans .env

### Erreur de base de données
- Vérifiez les mots de passe dans .env
- Essayez: docker compose down -v && docker compose up -d --build

---

## A propos d-Ianseo

### Qu-est-ce qu-Ianseo?

Ianseo est le logiciel open source de référence pour la gestion des compétitions de tir à l-arc, utilisé dans le monde entier et conforme aux réglementations de World Archery.

Développé depuis 2000, Ianseo permet de:
- Gérer les inscriptions des archers
- Organiser les tours de compétition
- Calculer les scores automatiquement
- Générer des classements et rapports
- Respecter les règles officielles de World Archery

Site officiel: https://ianseo.net

### Pourquoi cet installateur?

L-installation manuelle d-Ianseo peut être complexe:
- Nécessite un serveur web (Apache/Nginx)
- Nécessite une base de données MySQL
- Configuration PHP spécifique
- Gestion des permissions

Notre solution: Tout est automatisé dans Docker.

### Et Archery Nexus?

Archery Nexus est un nouveau projet (en développement) qui vise à remplacer Ianseo par une solution moderne.
Projet GitHub: https://github.com/Imerpg/archery-nexus-rust

---

## Licence

Ce projet est open source sous licence GNU GPL v3.0.
Voir le fichier LICENSE pour les détails.

### Crédits

- Ianseo: Développé par l-equipe d-Ianseo et World Archery Europe
- Archery Nexus: Projet de modernisation en cours
- Cet installateur: Développé pour simplifier l-installation d-Ianseo

Important: Cet installateur n-est pas affilié à Ianseo ou World Archery.
