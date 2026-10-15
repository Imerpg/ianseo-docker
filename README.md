# 🎯 Ianseo-Install

> **Déploiement simple, rapide et 100 % Dockerisé d'Ianseo.**  
> Conservez un ordinateur hôte propre sans dépendances locales à installer.

---

## 📋 Prochaines évolutions (Roadmap)

- [ ] Mettre à jour Ianseo automatiquement dès le lancement pour éviter de devoir cliquer sur _"Mettre à jour Ianseo"_ dans les modules.
- [ ] Ajouter un tutoriel d'installation de Docker depuis le site officiel.
- [ ] Créer un script d'automatisation pour lancer `docker compose` en une seule commande.

---

## ℹ️ À propos d'Ianseo & d'Archery Nexus

> **Ianseo** est la solution _open source_ de référence pour la gestion des compétitions de tir à l'arc, en conformité avec les règlements de la **World Archery**. Bien qu'il demeure le logiciel le plus employé à l'échelle mondiale, sa conception datant de 2000 (en PHP et JavaScript natifs) le rend aujourd'hui obsolète sur les plans de l'UI/UX et des performances. Son manque d'ergonomie et sa prise en main laborieuse sont aujourd'hui largement décriés.
>
> 🔗 [Visiter le site officiel d'Ianseo](https://ianseo.net)

> Afin d'offrir une véritable alternative moderne, performante et ergonomique, j'ai initié le projet **Archery Nexus** :  
> 🔗 [Projet GitHub — Archery Nexus (Rust)](https://github.com/Imerpg/archery-nexus-rust)
>
> _En attendant le développement d'Archery Nexus, ce dépôt vise à faciliter et améliorer la prise en main d'Ianseo._

---

## ⚙️ Variables d’environnement

Copiez `.env-prod` en `.env` ou définissez ces variables dans votre environnement. Elles sont utilisées par `docker-compose` et le script de préparation.

| Variable              | Description                               | Exemple                     |
| :-------------------- | :---------------------------------------- | :-------------------------- |
| `IANSEO_VERSION`      | Version d’Ianseo à télécharger (AAAAMMJJ) | `20250210`                  |
| `WEB_PORT`            | Port hôte mappé vers le conteneur Apache  | `80`                        |
| `MYSQL_ROOT_PASSWORD` | Mot de passe du compte root MySQL         | `very_secure_root_password` |
| `MYSQL_DATABASE`      | Nom de la base créée                      | `ianseo`                    |
| `MYSQL_USER`          | Utilisateur MySQL pour Ianseo             | `ianseo`                    |
| `MYSQL_PASSWORD`      | Mot de passe de l’utilisateur ianseo      | _votre_mot_de_passe_        |

> 📝 **Sécurité** : Changez impérativement les identifiants MySQL avant toute utilisation en production.

---

## 🚀 Démarrage

```bash
cp .env-prod .env # ou modifiez .env selon vos besoins
docker compose up -d --build
```

---

## 🔄 Fonctionnement de l'installation automatisée

Le conteneur Web utilise un script d'entrée (`web/entrypoint.sh`) qui automatise l'intégralité du déploiement.

1. **Téléchargement & extraction**
   Télécharge automatiquement la version d'Ianseo spécifiée par `IANSEO_VERSION` depuis les serveurs officiels et l'extrait dans :
   `/var/www/html/ianseo/`

2. **Attente de la base de données**
   Boucle de vérification jusqu'à ce que le conteneur MySQL soit prêt à accepter des connexions.

3. **Configuration réseau & accès**
   Génère automatiquement le fichier `Common/config.inc.php` avec les identifiants de la base de données et les paramètres de limites mémoire/temps d'exécution PHP requis.

4. **Initialisation de la base**
   Détecte si la base de données est vierge et importe le schéma SQL initial :
   `Install/install.sql`

5. **Mise à jour automatique du schéma PHP**
   Exécute le script d'upgrade natif d'Ianseo (`Install/upgrade.php`) en ligne de commande pour aligner la base de données sur la version des fichiers de l'application. Cela évite le message d'avertissement de mise à jour manuelle au premier accès navigateur.

6. **Droits d'accès**
   Réapplique les permissions `www-data` sur l'ensemble des fichiers avant d'exécuter Apache.

---

## ⚠️ Warnings & Mises en garde

### ⚠️ Premier démarrage & volumes persistants

Si vous modifiez les scripts d'initialisation SQL ou la version d'Ianseo après un premier lancement, les modifications ne seront pas réappliquées automatiquement sur une base déjà créée.

Pour réinitialiser complètement l'environnement et relancer la procédure d'installation automatique, supprimez les volumes associés :

```bash
docker compose down -v
docker compose up --build -d
```

### ⚠️ Temps d'attente au premier lancement

Lors du premier démarrage, l'initialisation de MySQL et le téléchargement/décompression de l'archive Ianseo (environ 65 Mo) peuvent prendre entre **15 et 45 secondes** selon votre connexion réseau et vos performances disque.  
_Ne coupez pas le conteneur pendant cette étape._

### ⚠️ Nom de domaine / port dans l'URL

N'oubliez pas d'inclure le slash final dans l'URL :
`http://localhost/ianseo/`  
Sans ce slash, Apache peut tenter une redirection vers le port interne du conteneur selon votre configuration proxy/hôte.

---

## 🛠️ Bonnes pratiques

- N’incluez pas l’archive ZIP d’Ianseo dans l’image Docker : elle est récupérée à la volée et supprimée immédiatement après extraction.

### Déboguer ou inspecter les conteneurs

- **Conteneur Web** :
    ```bash
    docker exec -it ianseo-install-web-1 bash
    ```
- **Conteneur MySQL** :
    ```bash
    docker exec -it ianseo-install-db-1 bash
    ```

### Volumes persistants

Les volumes suivants conservent respectivement les fichiers de l'application et les tables MySQL :

- `web_volume` — Fichiers de l'application
- `db_volume` — Tables MySQL

---

## 📄 Licence & crédits

Ce projet fournit un installateur automatisé Docker pour Ianseo.

L’archive applicative est téléchargée directement depuis le site officiel :  
[https://ianseo.net](https://ianseo.net)
