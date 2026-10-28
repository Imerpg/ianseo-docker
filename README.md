<p align="center">
  <img src="assets/logo.svg" width="400" alt="logo">
</p>

# Ianseo Docker

> **Une solution clé en main pour déployer Ianseo en 3 étapes, même sans compétences en informatique !**

Ianseo Docker est un outil qui installe automatiquement **Ianseo** (le logiciel de référence pour la gestion de compétitions de tir à l'arc) sur votre ordinateur, **sans aucune configuration manuelle**.

Tout fonctionne dans des conteneurs (des environnements isolés) grâce à Docker, ce qui garantit que votre ordinateur reste propre et que l'application fonctionne du premier coup.

> **En bref :** Docker s'occupe de l'installation, et Ianseo est prêt à l'emploi en quelques minutes.

> ⚠️ **Projet en évolution :** tout n'a pas été testé, en particulier l'installation automatique des
> modules Custom. Si quelque chose ne fonctionne pas, n'hésitez pas à
> [ouvrir une issue](https://github.com/Imerpg/ianseo-docker/issues) ou, mieux, à proposer
> une **pull request** avec votre correction. Toute contribution est la bienvenue !

---

## Table des matières

- [Prérequis](#prérequis)
- [Installation rapide (3 étapes)](#installation-rapide-3-étapes)
- [Première utilisation](#première-utilisation)
- [Mise à jour](#mise-à-jour)
- [Modules Custom (optionnel)](#modules-custom-optionnel)
- [Questions fréquentes (FAQ)](#questions-fréquentes-faq)
- [Dépannage](#dépannage)
- [Contribuer](#contribuer)
- [À propos d'Ianseo](#à-propos-dianseo)
- [Licence et crédits](#licence-et-crédits)

---

## Prérequis

### 🐳 Installer Docker

Docker est indispensable pour exécuter cet installateur.

#### Sur Windows 10/11

1. Téléchargez Docker Desktop depuis le [site officiel de Docker](https://www.docker.com/products/docker-desktop/).
2. Installez-le en suivant les instructions (conservez les options par défaut).
3. Redémarrez votre ordinateur si nécessaire.
4. Lancez Docker Desktop (attendez que le statut indique _Running_).

#### Sur macOS

1. Téléchargez Docker Desktop depuis le [site officiel de Docker](https://www.docker.com/products/docker-desktop/).
2. Installez l'application puis lancez-la.

#### Sur Linux (Ubuntu/Debian)

Ouvrez un terminal et exécutez :

```sh
sudo apt update && sudo apt install docker.io docker-compose-v2 -y
sudo systemctl enable --now docker
```

Pour vérifier que Docker est correctement installé, tapez :

```sh
docker --version
```

---

## Installation rapide (3 étapes)

### 1️⃣ Télécharger le projet

Ouvrez un terminal et exécutez :

```sh
git clone https://github.com/Imerpg/ianseo-docker.git ianseo-docker
cd ianseo-docker
```

_Si vous ne souhaitez pas utiliser Git :_

- Téléchargez l'archive ZIP du projet depuis GitHub.
- Décompressez-la dans le dossier de votre choix.
- Ouvrez un terminal dans ce dossier.

<img src="assets/download-from-github.png" width="400" alt="download-from-github">

### 2️⃣ Configurer (facultatif)

Le projet fonctionne directement avec les paramètres par défaut. Pour personnaliser la configuration :

1. Dupliquez le fichier d'exemple :

```sh
cp .env-prod .env
```

2. Éditez le fichier `.env` avec un éditeur de texte :
    - `IANSEO_VERSION` : Version d'Ianseo à installer (format : `AAAAMMJJ`, ex. : `20250210`).
    - `WEB_PORT` : Port d'accès web (par défaut : `80`).
    - `MYSQL_ROOT_PASSWORD` : Mot de passe administrateur de la base de données.
    - `MYSQL_DATABASE` : Nom de la base de données (par défaut : `ianseo`).
    - `MYSQL_USER` : Nom d'utilisateur de la base de données (par défaut : `ianseo`).
    - `MYSQL_PASSWORD` : Mot de passe utilisateur de la base de données.
    - `IANSEO_MODULES` : Modules Custom à installer (`all` par défaut, `none` pour aucun, ou le nom d'un seul module, ex. `GUIDE`). Voir [Modules Custom](#modules-custom-optionnel).
    - `IANSEO_MODULES_LANG` : Langue de l'installeur de modules (`en` ou `fr`).

> 🔐 **Sécurité :** Avant le premier démarrage, pensez à remplacer `MYSQL_ROOT_PASSWORD` et `MYSQL_PASSWORD` par des mots de passe forts.

### 3️⃣ Démarrer Ianseo

Dans le terminal, lancez (copier coller) :

```sh
docker compose up -d --build
```

Docker réalise automatiquement les opérations suivantes :

1. Téléchargement des composants d'Ianseo.
2. Initialisation de la base de données MySQL.
3. Installation des modules Custom (si activée).
4. Configuration automatique des services.
5. Démarrage de l'application.

_Durée estimée : de quelques secondes à 5 minutes selon l'ordinateur._

> ✅ **Mise à jour automatique :** Le système vérifie et applique automatiquement la dernière version d'Ianseo à chaque démarrage.

---

## Première utilisation

### Accéder à Ianseo

Une fois le démarrage terminé, ouvrez votre navigateur web à l'adresse suivante :

**[http://localhost/ianseo/](http://localhost/ianseo/)**

> 💡 _Note :_ N'oubliez pas d'inclure le `/` final dans l'URL.

---

## Mise à jour

Pour appliquer la dernière version d'Ianseo, exécutez la commande suivante (copier coller) :

```sh
docker compose down && docker compose up -d --build
```

---

## Modules Custom (optionnel)

Au premier démarrage, les modules du dépôt
[IanseoModules](https://github.com/Steph-Krs/IanseoModules) sont installés automatiquement
dans `Modules/Custom`.

> ⚠️ **Non testé à fond :** cette fonctionnalité est récente. Si un module pose problème, merci de
> le signaler ou de proposer une pull request.

- Pour choisir un seul module ou n'en installer aucun, modifiez `IANSEO_MODULES` dans le fichier `.env`.
- Les modules ne sont installés qu'une fois : ils ne sont pas écrasés aux redémarrages suivants.
- Ensuite, chaque module se met à jour depuis Ianseo : page d'administration du module →
  **Vérifier / Mettre à jour** (compte Root).
- Pour forcer une réinstallation complète depuis GitHub, supprimez le dossier
  `Modules/Custom/_shared` (ou réinitialisez l'installation) puis relancez
  `docker compose up -d --build`.
- Description de chaque module : [README du dépôt IanseoModules](https://github.com/Steph-Krs/IanseoModules#modules-disponibles).

---

## Questions fréquentes (FAQ)

### Q : Je reçois l'erreur « port already in use »

R : Le port `80` est déjà utilisé par une autre application. Modifiez la variable `WEB_PORT` dans le fichier `.env` :

```env
WEB_PORT=8080
```

Accédez ensuite à l'application via : [http://localhost:8080/ianseo/](http://localhost:8080/ianseo/)

### Q : Comment arrêter Ianseo ?

R : Dans le dossier du projet, exécutez (copier coller) :

```sh
docker compose down
```

### Q : Comment redémarrer Ianseo ?

R :
(copier coller)

```sh
docker compose restart
```

_(Ou `docker compose down && docker compose up -d --build` si vous souhaitez aussi reconstruire les conteneurs)._

### Q : Où sont stockées mes données ?

R : Les données de la base de données et les fichiers sont enregistrés dans des volumes Docker persistants. Elles restent conservées même après l'arrêt des conteneurs.

### Q : Comment réinitialiser complètement l'installation ?

R : ⚠️ **Attention : cette action supprime définitivement toutes vos données.**

```sh
docker compose down -v
docker compose up -d --build
```

---

## Dépannage

### Docker n'est pas reconnu ou ne répond pas

- **Windows / macOS :** Vérifiez que Docker Desktop est bien lancé et actif.
- **Linux :** Assurez-vous que votre utilisateur appartient au groupe `docker` :

```sh
sudo usermod -aG docker $USER
```

_Déconnectez-vous puis reconnectez-vous pour appliquer ce changement._

### L'accès à `http://localhost/ianseo/` échoue

1. Assurez-vous que le service Docker est en cours d'exécution.
2. Patientez 1 à 2 minutes après le lancement initial.
3. Vérifiez les journaux d'erreurs avec la commande : `docker compose logs -f`

### Un module Custom ne s'installe pas ou ne fonctionne pas

1. Consultez les journaux (`docker compose logs -f`) et cherchez les lignes `install_modules`.
2. Vérifiez que le conteneur a accès à Internet (GitHub).
3. Si le problème persiste, [ouvrez une issue](https://github.com/Imerpg/ianseo-docker/issues) en joignant les journaux.

---

## Contribuer

Tout n'a pas été testé : vos retours sont précieux. Si quelque chose ne fonctionne pas, vous pouvez :

1. **Forker** le dépôt sur GitHub.
2. Créer une branche et y faire votre correction.
3. Ouvrir une **pull request** en décrivant le problème et votre solution.

Pour un simple signalement, une [issue](https://github.com/Imerpg/ianseo-docker/issues) suffit.

---

## À propos d'Ianseo

### Qu'est-ce qu'Ianseo ?

Ianseo est le logiciel open source de référence pour l'organisation et la gestion des compétitions de tir à l'arc. Utilisé à l'échelle internationale, il est conforme aux règlements officiels de World Archery.

Fonctionnalités principales :

- Gestion des inscriptions et des tireurs
- Planification des départs et cibles
- Saisie et calcul automatique des scores
- Édition des résultats, classements et feuilles de marque

Site officiel : [ianseo.net](https://ianseo.net)

### Pourquoi utiliser cette version Docker ?

L'installation classique d'Ianseo nécessite l'administration d'un serveur web (Apache/Nginx), la configuration d'une base de données MySQL et la gestion de modules PHP. Cet installateur encapsule l'ensemble de ces dépendances pour un déploiement immédiat.

---

## Licence et crédits

Ce projet est distribué sous licence **GNU GPL v3.0**. Consultez le fichier `LICENSE` pour plus de détails.

### Crédits

- **Ianseo** : Développé par l'équipe Ianseo et soutenu par World Archery.
- **Ianseo Docker** : Proposé par [Imerpg](https://github.com/Imerpg) pour simplifier le déploiement.
- **Modules Custom** : [IanseoModules](https://github.com/Steph-Krs/IanseoModules) par @Steph-Krs.

_Note : Ce projet est une initiative indépendante et n'est ni affilié ni officiel auprès de l'équipe Ianseo ou de World Archery._
