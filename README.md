# 🎯 Ianseo-Install

> **Déploiement simple, rapide et 100 % Dockerisé d'Ianseo.**  
> Conservez un ordinateur hôte propre sans dépendances locales à installer.

---

## 📋 Prochaines évolutions (Roadmap)

- [x] Automatiser le lancement de la mise à jour Ianseo (`getFile` → `doUpdate` → suivi de progression via `getInfo`), sans passer par l'interface web des modules.
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
| `DB_HOST`             | Hôte de la base de données                | `ianseo-install-db-1`       |
| `IANSEO_UPDATE_USER`  | (Optionnel) Utilisateur pour la mise à jour automatique autre que PRODUCTION | —              |
| `IANSEO_UPDATE_PASS`  | (Optionnel) Mot de passe pour la mise à jour automatique autre que PRODUCTION | —             |

> 📝 **Sécurité** : Changez impérativement les identifiants MySQL avant toute utilisation en production.

---

## 🚀 Démarrage

```bash
cp .env-prod .env # ou modifiez .env selon vos besoins
docker compose up -d --build
```

---

## 🔄 Fonctionnement de l'installation automatisée

Le conteneur Web utilise un script d'entrée (`web/web_prep.sh`) qui automatise l'intégralité du déploiement.

1. **Téléchargement & extraction**
   Télécharge automatiquement la version d'Ianseo spécifiée par `IANSEO_VERSION` depuis les serveurs officiels et l'extrait dans :
   `/var/www/html/ianseo/`

2. **Attente de la base de données**
   Boucle de vérification (30 s max) jusqu'à ce que le conteneur MySQL soit prêt à accepter des connexions.

3. **Configuration réseau & accès**
   Génère automatiquement les fichiers de configuration (`config.php`, `Common/config.inc.php`) avec les identifiants de la base de données et les paramètres de limites mémoire/temps d'exécution PHP requis.

4. **Initialisation de la base**
   Détecte si la base de données est vierge et importe le schéma SQL initial :
   `Install/install.sql`

5. **Mise à jour automatique d'Ianseo**
   Une fois Apache démarré, le script interroge l'API interne de mise à jour d'Ianseo (`getFile` → `doUpdate`) et suit la progression via `getInfo`. En cas d'échec (par exemple session non authentifiée), le conteneur continue de fonctionner normalement et l'erreur est journalisée.

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

### ⚠️ Fins de ligne des scripts (Windows)

Si vous éditez les scripts `.sh` depuis Windows, assureurez-vous qu'ils conservent des fins de ligne **LF** (et non CRLF), sans quoi le conteneur échouera au démarrage avec `exec: no such file or directory`. Le dépôt applique la normalisation via `.gitattributes`.

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

Ce projet est distribué sous licence **GNU General Public License v3.0** — voir le fichier `LICENSE`.

Il fournit un installateur automatisé Docker pour **Ianseo**, qu'il télécharge, déploie et met à jour depuis le site officiel :  
🔗 [https://ianseo.net](https://ianseo.net)

> **Ianseo** est un logiciel libre distribué sous licence **GNU GPLv3** par son équipe de développement et **World Archery Europe**. Ianseo et ses auteurs restent titulaires de l'ensemble des droits sur le logiciel original ; ce dépôt ne fait que l'installer et l'accompagner d'outils de déploiement. Il n'est ni affilié à, ni avalisé par Ianseo ou World Archery.