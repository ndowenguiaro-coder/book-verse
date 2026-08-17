# Bibliothèque PDF — assemblage des 3 blocs

> **Mise à jour** : le site (`web_app/`) est maintenant servi directement par le backend FastAPI — un seul serveur à lancer, voir "Lancer le site" ci-dessous. L'app mobile Flutter (`flutter_app/`) reste disponible si besoin, mais n'est plus la voie principale.

## Bugs corrigés

**Lecteur PDF/TTS (Flutter)**
- Erreur de syntaxe fatale : `fontWeight: FontWeight: FontWeight.bold` (double affectation) → compilait pas du tout.
- Les vitesses TTS affichées ("0.5x", "1.0x"...) ne correspondaient pas aux valeurs réellement envoyées à `flutter_tts` (0.3, 0.5, 0.75, 1.0) → libellés recalés sur les vraies valeurs.
- Le document PDF entier était re-parsé à chaque appui sur le bouton lecture (au lieu d'être ouvert une fois) → coûteux sur les gros PDF.
- Aucun support du mode local : uniquement une URL réseau en dur → ajout du chargement depuis le cache local en priorité, et d'un bouton de téléchargement pour l'écoute hors-ligne.

**Page d'accueil (Flutter)**
- `Colors.slateGray` n'existe pas dans Flutter → `Colors.grey`.
- Genres et catégories codés en dur dans une liste statique → chargés dynamiquement depuis l'API (vraiment personnalisables).
- "Nouveautés" / "Les plus lus" / "Téléchargés" / "Favoris" étaient mélangés aux `Category` de la base de données, alors que ce sont des concepts différents (tri dynamique côté serveur vs état propre à l'appareil) → séparés en "sections intelligentes" traitées différemment.

**Backend (FastAPI)**
- `from sqlalchemy.ext.declarative import declarative_base` est déprécié en SQLAlchemy 2.x → `from sqlalchemy.orm import declarative_base`.
- Aucun middleware CORS → l'app Flutter (web ou mobile) ne pouvait pas appeler l'API depuis un autre host → `CORSMiddleware` ajouté.
- Aucune validation de `genre_id` / `category_id` à la création d'un livre → 404 explicite si absent.

## Ajouts pour répondre à la demande

- **Authentification JWT** : `POST /auth/register`, `POST /auth/login`, `GET /auth/me`. Mots de passe hachés avec bcrypt, jeton stocké côté app dans le stockage sécurisé (Keychain/Keystore via `flutter_secure_storage`), jamais en clair.
- **Favoris liés au compte** (et non plus à un `device_id` non authentifiable) : `POST/GET/DELETE /favorites/`, protégés par JWT.
- **Reprise de lecture** : `PUT/GET /books/{id}/progress` enregistre la dernière page lue par utilisateur ; le lecteur PDF saute automatiquement à cette page à l'ouverture.
- **Personnalisation** : endpoints `DELETE /genres/{id}` et `DELETE /categories/{id}` en plus du `POST` déjà présent → CRUD complet, gérable depuis l'app.
- **Disponibilité en ligne** : `GET /books/{id}/download` streame le PDF ; `sort_by=newest|popular` alimente les sections "Nouveautés" / "Les plus lus" (basées sur `created_at` et un nouveau champ `view_count`).
- **Lecture locale ou en ligne, audio ou non** : `LocalStorageService` met le PDF en cache sur l'appareil (bouton de téléchargement dans le lecteur) ; le TTS fonctionne indifféremment sur un PDF local ou téléchargé à la volée, page par page.

## Lancer le site (backend + web en un seul serveur)

Le site web (`web_app/`) est maintenant servi directement par le backend FastAPI : un seul processus à lancer, une seule URL, aucun souci de CORS.

```bash
cd backend
cp .env.example .env        # puis éditer .env : mettre un vrai JWT_SECRET
pip install -r requirements.txt
uvicorn main:app --reload
```

Ouvrir **http://127.0.0.1:8000/** → ça redirige automatiquement vers la connexion ou la bibliothèque.

Documentation interactive de l'API (utile pour déboguer) : http://127.0.0.1:8000/docs

Pages du site :
- `/login.html` — connexion / inscription
- `/library.html` — bibliothèque, filtres genres/catégories, sections Nouveautés/Populaires/Téléchargés/Favoris
- `/reader.html?id=<book_id>` — lecture PDF + audio, reprise à la dernière page lue
- `/admin.html` — **ajouter des genres, des catégories et publier des livres** (réservé aux utilisateurs connectés ; pour l'instant tout compte connecté peut publier — voir "Points à trancher")

Génération PDF côté navigateur : PDF.js (CDN). Lecture audio : Web Speech API du navigateur (Chrome/Edge/Safari ; support variable sur Firefox). Téléchargement hors-ligne : IndexedDB, propre à chaque navigateur/appareil.

### Premiers pas après le premier lancement

La base est vide au départ. Dans l'ordre :
1. Créer un compte sur `/login.html`.
2. Aller sur `/admin.html`, créer au moins un genre et une catégorie.
3. Publier un premier livre (PDF + couverture optionnelle).
4. Revenir sur `/library.html` : le livre apparaît, cliquable, lisible.

### Déploiement en production

Un seul service à héberger (Render, Railway, Fly.io, un VPS...) puisque backend et site sont désormais unifiés :
```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```
Variables à définir sur la plateforme d'hébergement : `JWT_SECRET` (obligatoire, valeur aléatoire longue). Le dossier `backend/uploads/` doit être sur un volume persistant (ou migré vers S3/GCS plus tard) : sans ça, les PDF publiés disparaissent à chaque redéploiement.

Si vous préférez héberger le site séparément (ex. Netlify) et l'API ailleurs, c'est toujours possible : éditez `web_app/js/config.js` pour y mettre l'URL complète de l'API, et gardez `allow_origins=["*"]` (déjà en place) côté backend.

## Lancer le backend seul (sans le site)

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
Documentation interactive : http://127.0.0.1:8000/docs

## Lancer l'app Flutter

```bash
cd flutter_app
flutter pub get
flutter run
```

Adapter `baseUrl` dans `lib/main.dart` selon la cible :
- Émulateur Android : `http://10.0.2.2:8000`
- Simulateur iOS / web : `http://127.0.0.1:8000`
- Appareil physique : IP locale de votre machine, ex. `http://192.168.1.20:8000`

## Configurer le secret JWT

Avant de déployer en production, définir une vraie valeur secrète (jamais celle par défaut) :
```bash
export JWT_SECRET="une-longue-chaine-aleatoire-et-privee"
```
Sans cette variable, le backend utilise une valeur par défaut non sécurisée — à ne jamais utiliser telle quelle en production.

## Points à trancher pour la suite
- **Rôles / permissions** : actuellement, tout utilisateur connecté peut publier un livre via `/admin.html` (pas de distinction admin/lecteur). Pour un vrai site public, ajouter un champ `is_admin` sur `User` et vérifier ce rôle sur les routes de création/suppression.
- Vérification d'email et réinitialisation de mot de passe (l'inscription/connexion de base est là, pas encore le flux complet).
- Connexions sociales (Google/Apple/Facebook) — nécessitent une configuration OAuth propre à chaque plateforme.
- Stockage des fichiers PDF (dossier local ici — passer à S3/GCS pour la prod, avec volume persistant en attendant).
- Voix TTS : Web Speech API utilise la voix du système/navigateur ; pour une vraie narration audio pré-enregistrée, le champ `audio_url` existe déjà côté modèle mais n'est pas encore branché dans le lecteur.
- Tout ce qui a été décrit comme vision produit (IA, marketplace auteurs, clubs de lecture, multi-plateforme, CI/CD, infra cloud...) reste à construire module par module — ce n'est pas réaliste en une seule passe, mais l'architecture actuelle (JWT, séparation genres/catégories/sections, cache local) est conçue pour l'accueillir progressivement sans tout casser.
