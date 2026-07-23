# Document de continuité — Projet Meryas

> Généré le 2026-07-22. Ce document a pour but de permettre à n'importe quel développeur (humain ou IA) de reprendre le développement du projet **sans poser une seule question préalable**. Toute information incertaine est explicitement marquée **Inconnu**.

---

## Table des matières

1. [Présentation générale](#1-présentation-générale)
2. [Architecture du projet](#2-architecture-du-projet)
3. [Fonctionnalités réalisées](#3-fonctionnalités-réalisées)
4. [Interface utilisateur](#4-interface-utilisateur)
5. [Gameplay](#5-gameplay)
6. [Intelligence du jeu](#6-intelligence-du-jeu)
7. [Base de données](#7-base-de-données)
8. [Réseau (multijoueur)](#8-réseau-multijoueur)
9. [Gestion des états](#9-gestion-des-états)
10. [Ressources](#10-ressources)
11. [Variables importantes](#11-variables-importantes)
12. [Classes importantes](#12-classes-importantes)
13. [Algorithmes importants](#13-algorithmes-importants)
14. [Historique du développement](#14-historique-du-développement)
15. [Bugs corrigés](#15-bugs-corrigés)
16. [Bugs connus](#16-bugs-connus)
17. [Optimisations effectuées](#17-optimisations-effectuées)
18. [Sécurité](#18-sécurité)
19. [TODO](#19-todo)
20. [Priorités](#20-priorités)
21. [Décisions techniques](#21-décisions-techniques)
22. [Dépendances](#22-dépendances)
23. [Paramètres de configuration](#23-paramètres-de-configuration)
24. [Version actuelle du projet](#24-version-actuelle-du-projet)
25. [Instructions de reprise](#25-instructions-de-reprise)
26. [Contexte complet](#26-contexte-complet)
27. [Recommandations techniques](#27-recommandations-techniques)

---

## 1. Présentation générale

### Nom du projet
**Meryas** (arabe : مرياس). Nom de package Flutter : `meryas`. Nom du dossier racine du dépôt : `meriass` (orthographe différente — c'est le nom du dossier local, pas du produit).

### Objectif du jeu
Meryas est un **jeu de cartes en ligne multijoueur en temps réel**, basé sur le jeu **Bilt** (variante proche du Baloot / Belote du Golfe arabo-persique, à enchères et équipes de 2 contre 2). Le jeu se joue à 4 joueurs répartis en 2 équipes (positions 0/2 vs 1/3), avec un système d'enchères (bidding) déterminant l'atout, puis des levées (plis), avec calcul de points et détection d'annonces (déclarations).

### Vision globale
- Une **appli mobile/web** avec lobby central listant des salles publiques et privées.
- Un **superviseur de salle** (créateur) qui peut gérer les sièges (mettre un joueur en spectateur, placer un spectateur à une place) avant le début de la partie.
- Des **bots de développement** (`DevBot`) remplissent automatiquement les salles publiques en attente pour permettre de tester/jouer même seul (activable/désactivable via configuration, actif par défaut hors production).
- Un second jeu (**Torneeka**) et un second mode de score (**départ à 26 points**) sont **prévus mais non implémentés** — actuellement verrouillés dans l'UI avec le libellé « Bientôt » et bloqués côté backend (`400 Invalid` si on tente de les utiliser).
- Interface bilingue **français / arabe** avec support RTL pour l'arabe.

### Plateformes ciblées
- **Android** (dossier `frontend/android/` complet, `applicationId` : voir `Inconnu` — non lu explicitement, mais `com.meryas.meryas` d'après le chemin Kotlin `frontend/android/app/src/main/kotlin/com/meryas/meryas/MainActivity.kt`).
- **iOS** (dossier `frontend/ios/` complet avec Pods installés — CocoaPods déjà configuré : `flutter_secure_storage`, `image_picker_ios`, `shared_preferences_foundation`, `sqflite_darwin`).
- **Web** (dossier `frontend/web/` présent avec manifest PWA et icônes).
- Desktop (Windows/Linux/macOS) : non configuré (pas de dossiers `windows/`, `linux/`, `macos/` dans `frontend/`).

### Technologies utilisées

**Backend :**
- Python 3.9 (venv local détecté sous `backend/venv/lib/python3.9/`)
- Flask 3.0.3 + Flask-SocketIO 5.3.6 (mode asynchrone **eventlet** 0.36.1)
- Flask-JWT-Extended 4.6.0 (authentification par JWT, expiration 7 jours)
- Flask-SQLAlchemy 3.1.1 / SQLAlchemy 2.0.30 (ORM)
- Flask-Bcrypt 1.0.1 (hash des mots de passe)
- Flask-CORS 4.0.1
- PostgreSQL (psycopg2-binary 2.9.9) — base de données de production/dev configurée via `DATABASE_URL`
- Pillow 10.3.0 (validation et redimensionnement des avatars uploadés)
- python-dotenv 1.0.1

**Frontend :**
- Flutter (SDK Dart `^3.11.5`), package `meryas`, version `1.0.0+1`
- `provider` 6.1.2 — gestion d'état (ChangeNotifier)
- `dio` 5.4.3 — client HTTP REST
- `socket_io_client` 2.0.3+1 — client WebSocket temps réel
- `flutter_secure_storage` 9.0.0 — stockage sécurisé du token JWT
- `shared_preferences` 2.2.3 — persistance de la langue choisie
- `cached_network_image` 3.3.1, `image_picker` 1.1.2, `flutter_animate` 4.5.0, `shimmer` 3.0.0, `google_fonts` 6.2.1
- `intl` 0.20.2
- `flutter_lints` 6.0.0 (dev)

---

## 2. Architecture du projet

### Structure complète des dossiers (hors artefacts générés : `venv/`, `.dart_tool/`, `build/`, `__pycache__/`, `.pytest_cache/`, `.gradle/`, `Pods/`, etc.)

```
meriass/
├── README.md
├── .gitignore
├── .claude/settings.local.json
├── CONTINUITY.md                      (ce document)
│
├── backend/
│   ├── app.py                         # Point d'entrée Flask + SocketIO, factory create_app()
│   ├── config.py                      # Classe Config (variables d'environnement)
│   ├── extensions.py                  # Instances partagées : db, bcrypt, jwt, socketio, cors
│   ├── dev_bots.py                    # Logique des bots de développement (remplissage salles publiques)
│   ├── init_db.py                     # Script one-shot de création des tables
│   ├── requirements.txt
│   ├── .env                           # Secrets locaux (gitignored, non commité)
│   ├── .env.example                   # Modèle de configuration
│   ├── instance/
│   │   ├── meryas.db                  # Fichier SQLite résiduel — voir note ci-dessous
│   │   └── meryas_dev.db              # idem
│   ├── models/
│   │   ├── __init__.py                # Ré-exporte User, Room, RoomPlayer, Game, GameRound, GameTrick, GameTrickCard
│   │   ├── user.py                    # Modèle User
│   │   ├── room.py                    # Modèles Room, RoomPlayer
│   │   └── game.py                    # Modèles Game, GameRound, GameTrick, GameTrickCard
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── auth.py                    # /api/auth : register, login, me
│   │   ├── users.py                   # /api/users : profil, avatar, leaderboard
│   │   └── rooms.py                   # /api/rooms : CRUD salles, join/leave, bench/seats
│   ├── sockets/
│   │   ├── __init__.py
│   │   ├── auth.py                    # Helpers d'authentification Socket.IO (resolve_context, etc.)
│   │   ├── room_events.py             # Événements room:* + déclenchement auto de la partie
│   │   ├── game_events.py             # Événements game:bid / game:play_card / game:declare
│   │   └── bot_player.py              # Boucle de jeu automatique des bots (tâche de fond Socket.IO)
│   ├── game_logic/
│   │   ├── __init__.py
│   │   ├── deck.py                    # Paquet de cartes, distribution, valeurs, résolution de plis, annonces
│   │   └── bilt.py                    # Machine à états BiltGame — cœur des règles du jeu
│   └── tests/
│       ├── __init__.py
│       ├── conftest.py                # Fixtures pytest (app Flask de test en SQLite mémoire)
│       ├── test_auth_routes.py
│       ├── test_deck.py
│       ├── test_dev_bots.py
│       └── test_bilt.py
│
└── frontend/
    ├── pubspec.yaml / pubspec.lock
    ├── analysis_options.yaml
    ├── android/  ios/  web/            # Projets natifs par plateforme
    ├── test/widget_test.dart
    ├── assets/
    │   ├── cards_final/                # ← Jeu de cartes ACTUELLEMENT utilisé par l'app (référencé dans pubspec.yaml)
    │   ├── cards/                      # Ancien jeu de cartes (plus référencé dans pubspec.yaml)
    │   ├── cards_clean/                # Variante intermédiaire (non référencée)
    │   ├── cards_svg/ cards_svg_raster/  # Sources SVG et rendu raster (non référencées)
    │   └── cards_source/               # SVG original (`svg-cards-2.0.svg`) + licence NOTICE.txt
    └── lib/
        ├── main.dart                   # Point d'entrée, MultiProvider, MaterialApp, routing racine (_Root)
        ├── l10n/
        │   └── app_strings.dart        # Dictionnaire de traduction FR/AR (clé → {fr, ar})
        ├── models/
        │   ├── user_model.dart
        │   ├── room_model.dart         # RoomModel + RoomPlayerModel
        │   ├── card_model.dart         # CardModel + TrickCard
        │   └── game_state_model.dart   # GameStateModel (état public du jeu)
        ├── providers/
        │   ├── auth_provider.dart
        │   ├── room_provider.dart
        │   ├── game_provider.dart
        │   └── locale_provider.dart
        ├── services/
        │   ├── api_service.dart        # Client REST (Dio)
        │   ├── socket_service.dart     # Client WebSocket (socket_io_client)
        │   └── storage_service.dart    # Wrapper flutter_secure_storage (token JWT)
        ├── screens/
        │   ├── auth/login_screen.dart
        │   ├── auth/register_screen.dart
        │   ├── lobby/lobby_screen.dart
        │   ├── lobby/room_screen.dart
        │   ├── game/game_screen.dart
        │   └── profile/profile_screen.dart
        ├── widgets/
        │   └── playing_card.dart       # PlayingCard, CardBack, _FallbackCardFace
        ├── theme/
        │   └── app_theme.dart          # AppTheme (couleurs, ThemeData sombre)
        └── utils/
            ├── constants.dart          # AppConstants (URLs API), Suit (symboles ♥♦♣♠)
            └── extensions.dart         # BuildContext.tr(), LangToggleButton
```

**Note sur `backend/instance/*.db`** : ces fichiers SQLite existent sur le disque local mais la configuration (`config.py`) pointe par défaut vers PostgreSQL, et le `.env` local confirme `DATABASE_URL=postgresql://...`. Ces `.db` sont donc très probablement des résidus d'une exécution antérieure sans `.env` (Flask/SQLAlchemy crée `instance/*.db` par défaut si aucun `DATABASE_URL` SQLite n'est explicitement demandé — mais ici il ne devrait normalement pas y en avoir puisque l'URI par défaut est postgresql). **Inconnu** : origine exacte ; à vérifier, potentiellement supprimables sans risque (non versionnés, `.gitignore` exclut `*.db`).

### Description des principaux fichiers

| Fichier | Rôle |
|---|---|
| `backend/app.py` | `create_app()` : instancie Flask, initialise toutes les extensions, enregistre les 3 blueprints REST, importe les modules socket (effet de bord = enregistrement des handlers `@socketio.on`), définit les gestionnaires d'erreur HTTP 400/401/403/404/422/500, crée les tables au démarrage (`db.create_all()`) et exécute une migration légère ad hoc (`_ensure_room_schema`, ajoute la colonne `scoring_mode` si absente — mécanisme de migration "fait main" sans Alembic). |
| `backend/config.py` | Charge `.env` (`python-dotenv`), définit `Config` : clés secrètes, URI base de données (conversion `postgres://`→`postgresql://`), options de pool SQLAlchemy, durée de vie du JWT (7 jours), dossier d'upload avatars, `CORS_ORIGINS`, et `AUTO_FILL_PUBLIC_ROOMS` (bots actifs par défaut hors production). En production (`FLASK_ENV=production`), `_require()` fait échouer le démarrage (`sys.exit(1)`) si `SECRET_KEY`/`JWT_SECRET_KEY` ne sont pas positionnées ou contiennent encore `change-in-prod`. |
| `backend/extensions.py` | Simple registre des instances Flask (SQLAlchemy, Bcrypt, JWTManager, SocketIO, CORS) partagées entre modules pour éviter les imports circulaires. |
| `backend/dev_bots.py` | Crée/gère des utilisateurs `User` fictifs (`is_bot` détecté via suffixe d'email `@devbot.meryas`) pour peupler automatiquement une salle publique en attente jusqu'à 4 joueurs ; libère un siège de bot quand un vrai joueur rejoint une salle pleine (`remove_one_bot`). |
| `backend/game_logic/deck.py` | Fonctions pures (sans état) : création/mélange du paquet de 32 cartes, distribution en 2 phases, calcul de la valeur d'une carte, calcul de la force d'une carte pour la résolution d'un pli, détection des annonces (Bella, suites). |
| `backend/game_logic/bilt.py` | Classe `BiltGame` = machine à états complète d'une partie de Bilt pour une salle. Stockée en mémoire process (dictionnaire global `game_sessions`), **non persistée en base** pendant la partie. Contient tout le cycle : distribution → enchères → distribution phase 2 → jeu des plis → calcul du score → fin de manche/partie. |
| `backend/sockets/auth.py` | `resolve_context(data, require_player)` : fonction pivot appelée par **tous** les handlers Socket.IO de jeu/salle ; valide le token JWT transmis dans le payload (pas de handshake JWT — le token est renvoyé à chaque émission), vérifie l'appartenance à la salle, met à jour `socket_id`/`is_online` de l'utilisateur. |
| `backend/sockets/room_events.py` | `room:join`, `room:leave`, `room:ready`. Contient `_start_game()` : démarre automatiquement la partie dès que les 4 joueurs (non spectateurs) sont prêts — **il n'existe pas d'événement `game:start` déclenché par le client**, c'est entièrement serveur-piloté. |
| `backend/sockets/game_events.py` | `game:bid`, `game:play_card`, `game:declare`. Diffuse les mises à jour d'état public (`game:state_update`), les mains privées (`game:hand`, envoyé uniquement au socket du joueur concerné), les résultats de manche (`game:round_result`) et gère la transition manche suivante / fin de partie (`_finish_game`, mise à jour des stats `wins`/`losses`/`total_points`). |
| `backend/sockets/bot_player.py` | Boucle asynchrone (`socketio.start_background_task`) qui fait jouer les bots automatiquement (passe systématiquement aux enchères, joue la première carte légale trouvée dans sa main pendant les plis), avec une pause de 0.45 s entre chaque action pour laisser un rythme visible côté UI. Garde `_running_rooms` (un `set`) pour éviter les boucles concurrentes sur une même salle. |
| `frontend/lib/main.dart` | Verrouille l'orientation portrait au démarrage, charge la langue sauvegardée, construit l'arbre de `Provider` (Locale, Auth, Room, Game), et détermine l'écran racine (`LobbyScreen` si authentifié, sinon `LoginScreen`) via `AuthProvider.tryAutoLogin()`. |
| `frontend/lib/services/api_service.dart` | Toutes les requêtes REST typées, gestion centralisée des erreurs Dio → `ApiException` avec message convivial (timeout, erreur réseau, erreur serveur avec corps JSON `{error: ...}`). |
| `frontend/lib/services/socket_service.dart` | Singleton `sio.Socket` (connexion WebSocket forcée, autoConnect désactivé), expose des méthodes typées pour chaque événement émis, et `on`/`off` génériques pour l'écoute. |
| `frontend/lib/screens/game/game_screen.dart` | Écran de jeu (le plus volumineux, ~1040 lignes) : verrouille l'orientation paysage + mode immersif système à l'ouverture, restaure le portrait à la fermeture ; dessine la table ovale, les 4 sièges (repositionnés relativement à la position du joueur courant), le pli en cours, la main du joueur, le panneau d'enchères, le tableau de score, et les overlays de résultat de manche / fin de partie. |

### Relations entre les composants

```
┌─────────────────────────┐        HTTPS/JSON (Dio)        ┌──────────────────────────┐
│  Flutter App             │ ───────────────────────────►  │  Flask REST API           │
│  (ApiService)             │ ◄───────────────────────────  │  /api/auth /api/users     │
│                           │        JWT Bearer token        │  /api/rooms                │
└───────────┬───────────────┘                                └────────────┬──────────────┘
            │  WebSocket (socket_io_client)                                │
            │  token + room_code dans CHAQUE payload                       │  SQLAlchemy ORM
            ▼                                                              ▼
┌─────────────────────────┐        Socket.IO (eventlet)     ┌──────────────────────────┐
│  SocketService            │ ◄───────────────────────────►  │  Flask-SocketIO handlers  │
│  → RoomProvider            │        room:*  game:*          │  sockets/room_events.py   │
│  → GameProvider             │                                │  sockets/game_events.py    │
└───────────┬───────────────┘                                └────────────┬──────────────┘
            │ notifyListeners()                                             │  game_logic.bilt.BiltGame
            ▼                                                              ▼  (état en mémoire, par room_id)
┌─────────────────────────┐                                 ┌──────────────────────────┐
│  Widgets (screens/)        │                                 │  PostgreSQL                │
│  Consumer/watch<Provider>() │                                 │  users / rooms / room_players│
└─────────────────────────┘                                 │  games (score final only)   │
                                                              └──────────────────────────┘
```

Points clés de cette architecture :
- **Authentification** : JWT signé côté serveur (Flask-JWT-Extended). Le frontend stocke le token dans `flutter_secure_storage` et le renvoie (a) en en-tête `Authorization: Bearer <token>` pour le REST, (b) dans le corps de **chaque** événement Socket.IO (`{token, room_code, ...}`) car il n'y a pas d'authentification au niveau du handshake WebSocket.
- **État de partie en mémoire** : `BiltGame` vit uniquement dans le processus Flask (`game_sessions: dict[int, BiltGame]`), clé = `room_id`. Si le processus backend redémarre, **toutes les parties en cours sont perdues** (pas de reprise possible) — seul le score final (`Game.team0_score/team1_score/winner_team`) est écrit en base, à la fin de la partie.
- **Diffusion Socket.IO** : les salles Socket.IO (`join_room(room.code)`) correspondent au champ `code` de `Room`, pas à son `id`.

---

## 3. Fonctionnalités réalisées

### Authentification (Terminée)
- **Objectif** : inscription/connexion par nom d'utilisateur ou email + mot de passe, session persistante via JWT.
- **Fonctionnement** : `POST /api/auth/register` (validations : username 3–50 caractères unique, email unique, mot de passe ≥ 6 caractères, hash bcrypt) ; `POST /api/auth/login` (accepte username OU email comme identifiant) ; `GET /api/auth/me` protégé par `@jwt_required()`. Le token est stocké côté client dans `flutter_secure_storage` et une tentative de connexion automatique (`tryAutoLogin`) est faite au lancement de l'app.
- **Fichiers** : `backend/routes/auth.py`, `backend/models/user.py`, `frontend/lib/providers/auth_provider.dart`, `frontend/lib/screens/auth/*`, `frontend/lib/services/storage_service.dart`.
- **État** : Terminée. Pas de réinitialisation de mot de passe, pas de vérification d'email, pas de refresh token (voir TODO).

### Gestion du profil utilisateur (Terminée)
- **Objectif** : afficher/modifier le pseudo, uploader un avatar, voir les statistiques (victoires/défaites/parties/taux de victoire).
- **Fonctionnement** : `PUT /api/users/profile` (changement de pseudo avec re-vérification d'unicité) ; `POST /api/users/avatar` (upload multipart, validation MIME + vérification réelle du contenu via `PIL.Image.verify()`, redimensionnement max 4096×4096, nom de fichier aléatoire `avatar_<id>_<uuid8>.<ext>`, suppression de l'ancien avatar) ; `GET /api/users/avatars/<filename>` sert le fichier statique ; `GET /api/users/leaderboard` (top 50 par victoires puis points).
- **Fichiers** : `backend/routes/users.py`, `frontend/lib/screens/profile/profile_screen.dart`.
- **État** : Terminée côté profil/avatar/stats. Le classement (`leaderboard`) est implémenté côté backend mais **aucun écran frontend ne l'affiche actuellement** (pas d'appel à `ApiService.getLeaderboard()` trouvé dans `lib/screens/`) — fonctionnalité backend orpheline, voir Bugs connus / TODO.

### Lobby et gestion des salles (Terminée)
- **Objectif** : lister les salles publiques en attente, créer une salle (nom, type de jeu, mode de score, privée/publique), rejoindre par code, spectateur.
- **Fonctionnement** : assistant de création en 3 étapes (nom → type de jeu → mode de score + case "salle privée") ; `POST /api/rooms/` crée la salle et place automatiquement le créateur en position 0 / équipe 0 ; `POST /api/rooms/<code>/join` place le joueur sur la première position libre (équipe = position % 2) ou en spectateur si la salle est pleine/en cours ; les bots libèrent leur place pour un vrai joueur qui rejoint une salle publique pleine.
- **Fichiers** : `backend/routes/rooms.py`, `frontend/lib/screens/lobby/lobby_screen.dart`, `frontend/lib/providers/room_provider.dart`.
- **État** : Terminée pour le jeu Bilt / score "zéro". Torneeka et score "26" sont verrouillés dans l'UI (`enabled: false`, libellé "Bientôt") et refusés côté backend (`400 'This game option is not available yet'`).

### Gestion des sièges par le superviseur (Terminée)
- **Objectif** : permettre au créateur de la salle (« superviseur ») de réorganiser les places avant le début de la partie : mettre un joueur en spectateur (bench), affecter un spectateur à une position précise.
- **Fonctionnement** : `POST /api/rooms/<code>/players/<member_id>/bench` (le superviseur ne peut pas se retirer lui-même) ; `POST /api/rooms/<code>/seats/<position>` avec `{member_id}` (échange automatique si la position est déjà occupée — l'occupant précédent devient spectateur, sauf s'il s'agit du superviseur, protégé). Les deux endpoints émettent un `room:state` Socket.IO pour synchroniser tous les clients de la salle instantanément (contournement du modèle REST classique — mutation HTTP + notification WebSocket).
- **Fichiers** : `backend/routes/rooms.py` (`bench_player`, `assign_seat`, `_room_state_response`), `frontend/lib/screens/lobby/room_screen.dart` (icône `swap_horiz` sur chaque joueur, bottom sheet de choix de siège pour un spectateur), `frontend/lib/providers/room_provider.dart` (`benchPlayer`, `assignSeat`).
- **État** : Terminée. Fonctionnalité ajoutée dans la session de travail la plus récente (visible dans le diff non commité).

### Salles remplies par des bots de développement (Terminée)
- **Objectif** : permettre de tester/jouer seul en développement en remplissant automatiquement les salles publiques avec des bots jouables.
- **Fonctionnement** : `auto_fill_public_room()` appelé à chaque listing, création, jointure ou départ d'une salle publique en attente ; crée/réutilise des `User` factices (email `room-<id>-bot-<pos>@devbot.meryas`), toujours marqués `is_ready=True`. Activable/désactivable via `AUTO_FILL_PUBLIC_ROOMS` (actif par défaut hors production, désactivable en `.env`).
- **Fichiers** : `backend/dev_bots.py`, `backend/tests/test_dev_bots.py`.
- **État** : Terminée et testée (3 tests d'intégration passants).

### Système d'enchères (bidding) simultané (Terminée — refactoré récemment)
- **Objectif** : chaque joueur choisit passe / to (jouer atout) / sans (sans-atout), avec priorité de résolution en cas de plusieurs choix « to »/« sans ».
- **Fonctionnement** : voir section [5. Gameplay](#5-gameplay) et [13. Algorithmes importants](#13-algorithmes-importants) pour le détail exact. Anciennement (avant la dernière session de travail), les enchères étaient **séquentielles** (un seul joueur actif à la fois, dans l'ordre horaire depuis le dealer+1) ; elles sont maintenant **simultanées** : les 4 joueurs soumettent chacun un choix indépendamment, puis le serveur résout la priorité une fois que les 4 choix sont reçus.
- **Fichiers** : `backend/game_logic/bilt.py` (`place_bid`, `_resolve_bid_choice`, `_normalize_bid_action`), `frontend/lib/screens/game/game_screen.dart` (`_buildBiddingPanel`, badges `_BidChoiceBadge` par siège), `frontend/lib/providers/game_provider.dart` (`isMyBidTurn`).
- **État** : Terminée et testée (voir `backend/tests/test_bilt.py::TestBidding`).

### Jeu des plis (trick-taking) (Terminée)
- **Objectif** : faire jouer les 8 plis d'une manche en respectant les règles de suite obligatoire et de coupe à l'atout.
- **Fonctionnement** : voir section 5. Résolution automatique du pli dès que les 4 cartes sont posées, calcul des points, bonus de 10 points au dernier pli.
- **Fichiers** : `backend/game_logic/bilt.py` (`play_card`, `_is_legal_play`, `_resolve_current_trick`), `frontend/lib/screens/game/game_screen.dart` (`_buildTrick`, `_buildHand`, sélection puis confirmation de la carte par double-tap).
- **État** : Terminée et testée.

### Annonces / déclarations (Bella, suites) (Backend terminé — UI absente)
- **Objectif** : détecter et valoriser les combinaisons de cartes en main (Bella = Roi+Dame d'atout = 20 pts ; suite de 3 cartes consécutives même couleur = 20 pts ; suite de 4+ = 50 pts) et permettre à chaque joueur de les révéler une fois par manche.
- **Fonctionnement** : `detect_declarations()` pré-calcule les annonces de chaque joueur dès que le mode/atout de la manche est connu (juste après résolution des enchères) ; `reveal_declarations(position)` marque le joueur comme ayant déclaré et ajoute les points au total de son équipe (`team_declarations`). L'événement Socket.IO `game:declare` existe côté client (`GameProvider.declare()`, `SocketService.declare()`) et côté serveur (`sockets/game_events.py::on_declare`), et le provider stocke les résultats reçus dans `recentDeclarations`.
- **Fichiers** : `backend/game_logic/deck.py` (`detect_declarations`), `backend/game_logic/bilt.py` (`reveal_declarations`), `frontend/lib/providers/game_provider.dart` (écoute `game:declarations`).
- **État** : **Backend et modèle de données terminés et testés** (`backend/tests/test_bilt.py::TestDeclarations`, `test_deck.py::TestDetectDeclarations`). **Aucun bouton ni overlay dans `game_screen.dart` ne permet au joueur de déclencher `game:declare`** — la fonctionnalité est invisible et inutilisable dans l'UI actuelle. C'est un **gap fonctionnel majeur** (voir Bugs connus §16 et TODO §19).

### Calcul du score de manche et de partie (Terminée)
- **Objectif** : appliquer les règles de score du Bilt (seuil 82/162 en hokm, 66/130 en sans-atout, cot = 8 plis sur 8, victoire à 152 points).
- **Fonctionnement** : voir section 5 et 13.
- **Fichiers** : `backend/game_logic/bilt.py` (`_finish_round`, `_serializable_round_result`).
- **État** : Terminée et testée.

### Fin de partie et mise à jour des statistiques (Terminée)
- **Objectif** : à la victoire d'une équipe (score ≥ 152), clôturer la `Room`/`Game` et mettre à jour `wins`/`losses`/`total_points` de chaque joueur humain (les bots sont explicitement exclus de la mise à jour de stats côté `bot_player.py`).
- **Fichiers** : `backend/sockets/game_events.py::_finish_game`, `backend/sockets/bot_player.py::_finish_game` (duplication de logique — voir Bugs connus), `frontend/lib/screens/game/game_screen.dart::_showGameOverDialog`.
- **État** : Terminée.

### Internationalisation FR/AR (Terminée)
- **Objectif** : basculer toute l'UI entre français et arabe (RTL) à la volée, langue persistée.
- **Fonctionnement** : dictionnaire statique `appStrings` (clé → `{fr, ar}`) consommé via l'extension `BuildContext.tr(key)` ; `LocaleProvider` persiste le choix dans `shared_preferences` (clé `locale_lang`) et le recharge au démarrage via `LocaleProvider.loadSavedLocale()` (appelé avant `runApp`). `LangToggleButton` réutilisable placé sur les AppBars (Lobby, Login, Register, Profile).
- **Fichiers** : `frontend/lib/l10n/app_strings.dart`, `frontend/lib/providers/locale_provider.dart`, `frontend/lib/utils/extensions.dart`.
- **État** : Terminée pour tous les écrans existants. **Certaines chaînes du `game_screen.dart` sont câblées en dur en français** (ex. `'Voulez-vous quitter la table de jeu ?'` / `context.isArabic ? '...' : '...'` ad hoc plutôt que passer par `appStrings`) — traduction partielle, pas systématiquement via `context.tr()`.

---

## 4. Interface utilisateur

### Tous les écrans existants

| Écran | Fichier | Rôle |
|---|---|---|
| Connexion | `screens/auth/login_screen.dart` | Formulaire identifiant/mot de passe, lien vers inscription, toggle langue |
| Inscription | `screens/auth/register_screen.dart` | Formulaire username/email/mot de passe/confirmation |
| Lobby | `screens/lobby/lobby_screen.dart` | Liste des salles, bouton créer (assistant 3 étapes), bouton rejoindre par code, accès profil |
| Salle d'attente | `screens/lobby/room_screen.dart` | Grille 2×2 des 4 places, liste des spectateurs, bouton "prêt", gestion des sièges par le superviseur |
| Jeu | `screens/game/game_screen.dart` | Table de jeu complète en paysage (sièges, pli central, main, enchères, score, résultats) |
| Profil | `screens/profile/profile_screen.dart` | Avatar (upload), pseudo (édition inline), email, statistiques (victoires/défaites/parties/taux) |

### Navigation entre les écrans
- Racine (`_Root` dans `main.dart`) : `LoginScreen` ↔ `RegisterScreen` (via `Navigator.pushReplacement`), ou `LobbyScreen` si déjà authentifié.
- `LobbyScreen` → `RoomScreen` (`Navigator.push`, après création/jointure réussie) ; → `ProfileScreen` (`Navigator.push`, icône avatar dans l'AppBar).
- `RoomScreen` → `GameScreen` : navigation **automatique et pilotée par l'état réseau**, pas par une action utilisateur : `GameProvider.gameStarted` passe à `true` à la réception de l'événement `game:started`, un listener posé dans `RoomScreen.initState` (`_onGameStarted`) déclenche alors `Navigator.pushReplacement`.
- `RoomScreen` intercepte le bouton retour physique/geste via `PopScope(canPop: false, ...)` pour forcer un `leave_room` propre (API + Socket.IO) avant de fermer l'écran.
- `GameScreen` → retour au lobby : bouton de sortie avec confirmation (`_confirmExit`) ou automatique après le dialogue de fin de partie (`_showGameOverDialog`), via `Navigator.of(context).popUntil((route) => route.isFirst)`.

### Widgets importants
- **`PlayingCard`** (`widgets/playing_card.dart`) : affiche une carte via `Image.asset('assets/cards_final/<suit>_<rank>.jpg')` avec repli (`errorBuilder`) vers `_FallbackCardFace` (rendu vectoriel texte+symbole si l'image est absente). Supporte les états `isSelected` (bordure verte, légèrement remontée) et `isPlayable` (bordure jaune, tap actif).
- **`CardBack`** : dos de carte (dégradé vert), utilisé conceptuellement pour les cartes cachées (en pratique, `game_screen.dart` utilise plutôt son propre `_MiniCardBack` pour l'éventail des adversaires).
- **`_OpponentCardFan`** (privé à `game_screen.dart`) : éventail de mini-dos de cartes dont le nombre est déduit dynamiquement (`8 - tricksPlayed`, ou `5` en phase d'enchères, moins 1 si le joueur a déjà posé une carte dans le pli courant).
- **`LangToggleButton`** (`utils/extensions.dart`) : bouton FR/AR compact réutilisé sur 4 écrans.
- **`_RoomCard`, `_CreateRoomSteps`, `_CreateOptionTile`, `_StatusBadge`** (privés à `lobby_screen.dart`) : carte de salle dans la liste, indicateur d'étape de l'assistant de création, tuile d'option sélectionnable, badge de statut coloré (attente/en cours/terminée).
- **`_BidChoiceBadge`** (privé à `game_screen.dart`) : badge affiché au-dessus de l'avatar d'un joueur montrant son choix d'enchère (passe/to/sans), coloré selon le choix.

### Animations
- `AnimatedContainer` : sélection de carte (translation verticale, 150 ms), avatar de joueur actif (halo doré, 250 ms), indicateur d'étape de création de salle (largeur, 160 ms).
- `AnimatedSwitcher` (180 ms) : transition entre les étapes de l'assistant de création de salle.
- Rotation des cartes en main (`Transform.rotate`, angle croissant en éventail autour du centre) et des cartes du pli (angles fixes par position relative) — effet purement géométrique statique, pas d'interpolation animée entre positions.
- Le package `flutter_animate` est déclaré en dépendance mais **non utilisé dans le code actuel** (aucune occurrence trouvée dans `lib/`) — dépendance présente mais inexploitée (voir Recommandations).
- `shimmer` : idem, dépendance déclarée mais **non utilisée**.

### Responsive
- Le lobby, l'auth et le profil sont en portrait, avec des listes/`SingleChildScrollView` qui s'adaptent à la largeur de l'écran.
- L'écran de jeu (`GameScreen`) force le mode **paysage** (`SystemChrome.setPreferredOrientations([landscapeLeft, landscapeRight])`) et le mode plein écran immersif (`SystemUiMode.immersiveSticky`) à l'entrée, et restaure portrait/edge-to-edge à la sortie (dans `dispose()`, avec un commentaire explicite sur l'ordre des opérations pour garantir la restauration même en cas d'erreur du provider).
- Toutes les tailles dans `game_screen.dart` sont calculées via `LayoutBuilder` + `math.min(valeurFixe, size.width/height * ratio)` pour s'adapter à différentes tailles d'écran/tablettes tout en plafonnant les dimensions (évite des cartes disproportionnées sur grand écran).
- Aucun breakpoint desktop/tablette dédié n'a été identifié (pas de `MediaQuery` à seuils multiples) — le responsive est purement proportionnel/continu.

### Thème
- **`AppTheme.dark`** (unique thème, pas de mode clair) : `ThemeData(brightness: Brightness.dark)`, police via `GoogleFonts.cairoTextTheme` (police **Cairo**, choisie pour son bon rendu en arabe ET en français), `AppBarTheme` transparent sans élévation, boutons à coins arrondis (12 px), champs de formulaire remplis (`cardBackground`) sans bordure visible sauf au focus (`primaryLight`, 2 px).

### Couleurs
Définies comme constantes statiques dans `AppTheme` :

| Nom | Valeur hex | Usage |
|---|---|---|
| `primary` | `#1B5E20` | Vert foncé principal (boutons, accents) |
| `primaryLight` | `#4CAF50` | Vert clair (focus, état "prêt", texte "moi") |
| `surface` | `#0D1B0F` | Fond général de l'app |
| `cardBackground` | `#1A2E1C` | Fond des cartes/inputs/dialogues |
| `gold` | `#FFD700` | Couleur d'accent principale (titre, badges, atout) |
| `red` | `#E53935` | Erreurs, défaites |
| `tableGreen` / `tableGreenLight` | `#2D5016` / `#3A6B1E` | Déclarées mais peu/pas utilisées hors thème (le tapis de jeu de `game_screen.dart` utilise ses propres couleurs locales `#10261B`, `#177C4A`, `#07512F`, `#063B25`, etc., **non reliées à `AppTheme`**) |

Autres couleurs codées en dur uniquement dans `game_screen.dart` (non centralisées dans le thème) : rouge équipe "Nous" `#D62B1F`, vert équipe "Eux" `#1FAD45`, plaque de score `#E8EFE9`, dos de mini-carte `#242421`/bordure or `#D6B45F`, etc. — **incohérence de design system** (voir Recommandations).

### Polices
Police unique : **Cairo** (via `google_fonts`), appliquée à l'ensemble du `TextTheme`. Choisie car elle supporte nativement le rendu correct des glyphes latins et arabes.

---

## 5. Gameplay

### Règles générales
Le Bilt tel qu'implémenté est un jeu de **plis à l'atout, à 4 joueurs en 2 équipes fixes** (positions 0 et 2 = équipe 0 ; positions 1 et 3 = équipe 1), avec un paquet de **32 cartes** (7, 8, 9, 10, Valet, Dame, Roi, As × 4 couleurs : hearts/diamonds/clubs/spades).

### Déroulement d'une manche (round)

1. **Distribution phase 1** (`deal_cards`) : mélange du paquet de 32 cartes puis distribution **dans le sens antihoraire** (`order = [3, 2, 1, 0]`), 3 cartes puis 2 cartes à chaque joueur (5 cartes chacun, 20 cartes distribuées). Les 12 cartes restantes (`remaining`) ne sont **pas** retirées du paquet ; la première carte de `remaining` (`remaining[0]`) est affichée comme **carte retournée** (aperçu uniquement, elle reste dans le paquet pour la phase 2).
2. **Enchères (bidding)** : voir sous-section dédiée ci-dessous.
3. **Distribution phase 2** (`deal_remaining`) : une fois l'enchère acceptée, les 12 cartes restantes sont distribuées 3 par 3 par joueur (toujours ordre antihoraire), chaque joueur termine avec **8 cartes**.
4. **Pré-calcul des annonces** : pour chaque position, `detect_declarations(hand, trump_suit, mode)` est calculé et stocké (`all_declarations`), mais pas encore révélé.
5. **Jeu des plis (8 plis)** : le joueur à `(dealer_position + 1) % 4` entame le premier pli. Chaque pli résolu détermine le joueur suivant à jouer (le gagnant du pli précédent entame le suivant).
6. **Fin de manche** après le 8ᵉ pli : calcul du score (voir plus bas), incrémentation du dealer (`dealer_position = (dealer_position + 1) % 4`) pour la manche suivante, sauf si une équipe a atteint le score de victoire.

### Les enchères (bidding) — mécanique actuelle (simultanée)

**Comportement** : les 4 joueurs soumettent chacun, **indépendamment et sans ordre strict imposé par le serveur**, un choix parmi :
- `pass` (`passe`)
- `to` (jouer à l'atout — alias legacy accepté : `take`, nécessitant alors un `suit` explicite)
- `sans` (sans-atout — alias legacy accepté : `sans_atout`)

Le serveur attend que les 4 choix soient reçus (`len(r['bid_choices']) == 4`) puis résout la priorité via `_resolve_bid_choice()` :
1. Parcourt d'abord tous les joueurs, dans l'ordre `[(dealer+1)%4, (dealer+2)%4, (dealer+3)%4, dealer%4]`, à la recherche d'un choix `'to'` → le premier trouvé dans cet ordre gagne l'enchère.
2. Si aucun `'to'`, refait le même parcours à la recherche d'un `'sans'`.
3. Si aucun `'to'` ni `'sans'` (4 passes) → **redistribution complète** (`start_round()` relancé).

Si le joueur gagnant a choisi `'to'` sans préciser de couleur explicite, l'**atout devient la couleur de la carte retournée** (`suit or r['turned_card']['suit']`). Un joueur ne peut soumettre qu'un seul choix par manche (`'Bid already submitted'` sinon).

**Important — historique** : ce mécanisme **simultané avec résolution par priorité** remplace un ancien système **séquentiel** (un seul `bidding_player` actif à la fois, qui passait la main au suivant) présent dans le commit initial. Voir section 14 (Historique).

Les choix d'enchères (`bid_choices`) restent visibles côté client pendant **60 secondes** après résolution (`bid_choices_visible_until = time.time() + 60`), via `_visible_bid_choices()`, pour permettre d'afficher les badges `to`/`sans`/`passe` au-dessus des avatars pendant le début de la phase de jeu.

### Les cartes — valeurs et force

**Table des points (mode hokm, avec atout) :**

| Rang | Hors-atout | Atout |
|---|---|---|
| 7 | 0 | 0 |
| 8 | 0 | 0 |
| 9 | 0 | **14** |
| 10 | 10 | 10 |
| Valet (J) | 2 | **20** |
| Dame (Q) | 3 | 3 |
| Roi (K) | 4 | 4 |
| As (A) | 11 | 11 |

**Table des points (mode sans-atout)** : identique à la colonne "Hors-atout" ci-dessus pour toutes les cartes (pas de bonus atout).

**Ordre de force (du plus faible au plus fort) :**
- Hors-atout / sans-atout : `7, 8, 9, J, Q, K, 10, A`
- Atout (hokm) : `7, 8, Q, K, 10, A, 9, J` — **le Valet et le 9 d'atout sont les deux cartes les plus fortes du jeu**, contre-intuitif par rapport à l'ordre naturel des rangs.

**Total de points par manche** : 152 points de cartes + 10 points de bonus au dernier pli = **162 points** en mode hokm (avec atout). En mode sans-atout, il n'y a pas de bonus atout (le 9 et le J ne valent que leur valeur "hors-atout"), donc le total de cartes est de **120 points** (152 − 32, soit 8×(14−0) − 8×(20−2) = ...) — vérifié par le test `test_total_points_round_is_162` qui calcule spécifiquement le total en mode `hokm`. **Le seuil `WIN_THRESHOLD_SANS_ATOUT = 66` sur 130** indiqué en commentaire dans `bilt.py` (`"out of 130 card-trick points (no trump J/9 bonus)"`) — la valeur exacte du total en sans-atout n'a pas été revérifiée indépendamment dans ce document ; se fier au code (`deck.py::NON_TRUMP_POINTS`) comme source de vérité.

### Règles de jeu d'une carte (légalité)

Implémentées dans `_is_legal_play(position, suit)` :
- **Premier joueur du pli** : peut jouer n'importe quelle carte.
- **Mode sans-atout** : doit suivre la couleur demandée (`lead_suit`) si possible ; sinon, peut jouer n'importe quelle carte.
- **Mode hokm (avec atout)** :
  - Si le joueur peut suivre la couleur demandée, il **doit** la suivre (`suit == lead_suit`).
  - S'il ne peut pas suivre, il **doit couper à l'atout** s'il en a (`suit == trump_suit`).
  - S'il n'a ni la couleur demandée ni l'atout, il peut jouer n'importe quelle carte.

**Note** : il n'y a **aucune règle de "monter" à l'atout** (sur-couper obligatoirement plus fort) implémentée — seule l'obligation de couper est vérifiée, pas la surenchère de force de la coupe. Ceci correspond à une version simplifiée des règles classiques de Baloot/Bilt (à confirmer si c'est le comportement désiré — voir Recommandations).

### Résolution d'un pli

`resolve_trick(trick_cards, trump_suit, mode)` : calcule la force de chaque carte via `card_strength()` :
- Sans-atout : force = index dans `NON_TRUMP_ORDER`, +100 si la carte est de la couleur demandée (pour dominer les cartes hors-couleur qui ne peuvent jamais gagner).
- Hokm : +200 si la carte est atout (domine toujours), +100 si couleur demandée (mais pas atout), sinon force brute (ne peut jamais gagner si personne ne suit/coupe).
- Le pli est remporté par la carte de force maximale.

### Annonces (déclarations)

`detect_declarations(hand, trump_suit, mode)` :
- **Bella** : possession du Roi ET de la Dame d'atout (uniquement en mode `hokm`) → **20 points**.
- **Suite** : 3 cartes ou plus consécutives dans la même couleur (ordre naturel `7,8,9,10,J,Q,K,A`, indépendant du mode atout) → **20 points** pour une suite de 3, **50 points** pour une suite de 4 ou plus. Une main peut contenir plusieurs suites indépendantes (dans des couleurs différentes, ou séparées par un "trou").
- Chaque joueur ne peut révéler ses annonces qu'**une seule fois par manche** (`reveal_declarations`), et uniquement pendant la phase de jeu (`status == 'playing'`).

### Calcul du score de fin de manche (`_finish_round`)

1. Séparation des points en deux catégories : points de plis (`team_trick_pts`, cumul des `points` de chaque pli remporté) et points de déclarations (`team_decl_pts`, cumulés lors des révélations).
2. **Détection du "cot"** : si une équipe remporte les 8 plis sur 8 (`trick_counts[team] == 8`), c'est un cot.
3. **Seuil de réussite** : `WIN_THRESHOLD_HOKM = 82` (sur 162) en mode hokm, `WIN_THRESHOLD_SANS_ATOUT = 66` en mode sans-atout — appliqué uniquement aux **points de plis** de l'équipe preneuse (celle qui a gagné l'enchère), pas aux déclarations.
4. **Attribution des points** :
   - **Cot** : l'équipe du cot reçoit `card_total × 2 + ses propres déclarations` ; l'autre équipe reçoit **0** (déclarations perdues même si elle en avait).
   - **Équipe preneuse réussit** (`team_trick_pts[bidding_team] >= threshold`) : chaque équipe garde ses propres points de plis + ses propres déclarations.
   - **Équipe preneuse échoue** ("chute") : elle reçoit **0** (déclarations perdues) ; l'autre équipe reçoit la **totalité** des points de plis (`card_total`, y compris ceux normalement gagnés par l'équipe preneuse) + ses propres déclarations uniquement.
5. Les points attribués sont ajoutés au score cumulé de la partie (`self.team_scores`).

### Fin de partie (match)

`MATCH_WIN_SCORE = 152`. Dès qu'une équipe atteint ou dépasse 152 points cumulés à l'issue d'une manche, la partie se termine (`state = 'game_end'`), sinon une nouvelle manche démarre avec le dealer suivant (`state = 'round_end'` puis nouvel appel `start_round()`).

### Redistribution (redeal)
Deux cas déclenchent une redistribution complète (nouvelle `start_round()`, mêmes règles, même dealer) :
- Les 4 joueurs passent aux enchères (aucun `to` ni `sans`).

---

## 6. Intelligence du jeu

### IA éventuelle
Il n'existe **aucune intelligence artificielle à proprement parler** (pas de recherche minimax, pas de modèle d'évaluation de main, pas d'heuristique de choix de carte optimisée). Les "bots" (`DevBot`) présents sont des **automates déterministes très simples**, destinés au développement/test, pas à fournir un adversaire crédible :
- **Phase d'enchères** : le bot passe systématiquement (`session.place_bid(position, 'pass')`).
- **Phase de jeu de carte** : le bot essaie ses cartes **dans l'ordre où elles apparaissent dans sa main** et joue la **première carte légale trouvée** (`for card in list(session.get_hand(position)): candidate = session.play_card(...); if 'error' not in candidate: break`) — aucune stratégie de choix (pas de recherche de la carte la plus/moins forte, pas de gestion du partenaire, pas de calcul de probabilité).

### Algorithmes utilisés
Voir section 13 pour le détail complet des algorithmes de jeu (distribution, résolution de pli, détection d'annonces, résolution des enchères, calcul de score).

### Logique métier
Toute la logique métier du jeu est **centralisée côté serveur** dans `BiltGame` (`backend/game_logic/bilt.py`) et les fonctions pures de `deck.py` — le client Flutter n'effectue **aucune validation de règle** (le serveur est la seule source de vérité, le client se contente d'afficher l'état reçu et de proposer les actions à l'utilisateur ; toute action illégale renvoyée par le serveur émet un simple événement `error` affiché nulle part explicitement côté UI — voir Bugs connus).

---

## 7. Base de données

**SGBD** : PostgreSQL (production/dev), SQLite en mémoire pour les tests (`conftest.py`, `sqlite:///:memory:`).
**Pas de système de migration formel (Alembic absent)** : les tables sont créées via `db.create_all()` au démarrage de l'app, et une **migration manuelle ad hoc** existe dans `app.py::_ensure_room_schema()` pour ajouter la colonne `rooms.scoring_mode` si elle n'existe pas déjà (`ALTER TABLE rooms ADD COLUMN scoring_mode VARCHAR(20) DEFAULT 'zero'`) — mécanisme fragile à faire évoluer avec précaution si le schéma doit encore changer (voir Recommandations).

### Schéma — tables et relations

```
users (id PK)
 ├─ username        VARCHAR(50) UNIQUE NOT NULL
 ├─ email           VARCHAR(120) UNIQUE NOT NULL
 ├─ password_hash   VARCHAR(255) NOT NULL   (bcrypt)
 ├─ avatar          VARCHAR(255) NULL
 ├─ wins            INTEGER DEFAULT 0
 ├─ losses          INTEGER DEFAULT 0
 ├─ total_points    INTEGER DEFAULT 0
 ├─ is_online       BOOLEAN DEFAULT FALSE
 ├─ socket_id       VARCHAR(100) NULL
 └─ created_at      DATETIME
     (propriété calculée is_bot = email se terminant par '@devbot.meryas', pas une colonne)

rooms (id PK)
 ├─ code            VARCHAR(10) UNIQUE NOT NULL   (généré aléatoirement, 6 caractères A-Z0-9)
 ├─ name            VARCHAR(100) NOT NULL
 ├─ game_type       VARCHAR(20) DEFAULT 'bilt'
 ├─ scoring_mode    VARCHAR(20) DEFAULT 'zero'     (ajoutée via migration ad hoc)
 ├─ status          VARCHAR(20) DEFAULT 'waiting'  (waiting|playing|finished)
 ├─ creator_id      FK → users.id NOT NULL
 ├─ is_private      BOOLEAN DEFAULT FALSE
 └─ created_at      DATETIME

room_players (id PK)
 ├─ room_id         FK → rooms.id (ON DELETE CASCADE) NOT NULL
 ├─ user_id         FK → users.id NOT NULL
 ├─ position        INTEGER NULL   (0–3 ; NULL si spectateur)
 ├─ team            INTEGER NULL   (0 ou 1 ; NULL si spectateur)
 ├─ is_spectator    BOOLEAN NOT NULL DEFAULT FALSE
 ├─ is_ready        BOOLEAN NOT NULL DEFAULT FALSE
 ├─ joined_at       DATETIME
 └─ UNIQUE(room_id, user_id)   -- une seule adhésion par utilisateur par salle

games (id PK)
 ├─ room_id         FK → rooms.id NOT NULL
 ├─ game_type       VARCHAR(20) DEFAULT 'bilt'
 ├─ status          VARCHAR(20) DEFAULT 'active'   (active|finished)
 ├─ team0_score     INTEGER DEFAULT 0
 ├─ team1_score     INTEGER DEFAULT 0
 ├─ winner_team     INTEGER NULL
 ├─ created_at      DATETIME
 └─ finished_at     DATETIME NULL   (⚠ jamais renseignée dans le code actuel malgré la colonne — voir Bugs connus)

game_rounds (id PK)   -- ⚠ DÉFINIE MAIS JAMAIS UTILISÉE (aucun INSERT dans le code)
 ├─ game_id, round_number, mode, trump_suit, bidding_team, bidding_player_id,
 │  dealer_position, team0_round_points, team1_round_points,
 │  team0_declarations, team1_declarations, cot_team, status, created_at

game_tricks (id PK)   -- ⚠ DÉFINIE MAIS JAMAIS UTILISÉE
 ├─ round_id, trick_number, winner_position, points

game_trick_cards (id PK)   -- ⚠ DÉFINIE MAIS JAMAIS UTILISÉE
 ├─ trick_id, player_position, suit, rank
```

### Données stockées
Seules `users`, `rooms`, `room_players` sont activement lues/écrites en continu. La table `games` n'est écrite **qu'à la création** (`Game(room_id, game_type)`, statut `active`) et **qu'à la fin de partie** (`_finish_game`, statut `finished`, scores finaux, `winner_team`). **Aucun historique de manche, de pli ou de carte jouée n'est persisté** — tout le déroulé fin d'une partie (qui a annoncé quoi, qui a gagné quel pli, l'évolution manche par manche) n'existe qu'en mémoire pendant la partie et disparaît ensuite (`remove_session(room_id)`). Voir section 16 et 19 pour l'impact de ce choix.

---

## 8. Réseau (multijoueur)

### Architecture client/serveur
Architecture **client léger / serveur autoritaire** : le client Flutter n'a aucune copie faisant foi de l'état du jeu — il ne fait qu'envoyer des intentions (`game:bid`, `game:play_card`, `game:declare`) et afficher l'état renvoyé par le serveur. Toute la validation des règles est faite côté serveur (`bilt.py`).

Deux canaux de communication distincts et complémentaires :
- **REST (HTTP/JSON via Dio)** pour les opérations "CRUD" classiques : authentification, gestion du profil, listing/création/jointure de salle, gestion des sièges.
- **WebSocket (Socket.IO, mode `eventlet`)** pour tout ce qui est temps réel : présence dans la salle, statut "prêt", déroulement complet de la partie.

### API REST — tableau complet des endpoints

| Méthode | Endpoint | Auth | Description |
|---|---|---|---|
| POST | `/api/auth/register` | non | Inscription |
| POST | `/api/auth/login` | non | Connexion (username ou email) |
| GET | `/api/auth/me` | JWT | Profil de l'utilisateur connecté |
| GET | `/api/users/<id>` | JWT | Profil public d'un utilisateur |
| PUT | `/api/users/profile` | JWT | Modifier le pseudo |
| POST | `/api/users/avatar` | JWT | Uploader un avatar (multipart) |
| GET | `/api/users/avatars/<filename>` | non | Servir un fichier avatar statique |
| GET | `/api/users/leaderboard` | JWT | Top 50 classement (non affiché côté UI) |
| GET | `/api/rooms/` | JWT | Lister les salles (`?status=waiting` par défaut) |
| POST | `/api/rooms/` | JWT | Créer une salle |
| GET | `/api/rooms/<code>` | JWT | Détails d'une salle + liste des joueurs |
| POST | `/api/rooms/<code>/join` | JWT | Rejoindre (`{spectator: bool}`) |
| POST | `/api/rooms/<code>/leave` | JWT | Quitter |
| POST | `/api/rooms/<code>/players/<member_id>/bench` | JWT (superviseur) | Mettre un joueur en spectateur |
| POST | `/api/rooms/<code>/seats/<position>` | JWT (superviseur) | Affecter un spectateur à une position |

### Événements WebSocket

**Client → Serveur** (chaque payload contient `token` + `room_code`) :
- `room:join` — Rejoindre la salle (socket join uniquement, ne change pas l'appartenance en base)
- `room:leave` — Quitter (supprime le `RoomPlayer`, déclenche `auto_fill_public_room`)
- `room:ready` — Se déclarer prêt (déclenche `_start_if_ready` → démarrage auto si 4/4 prêts)
- `game:bid` — `{action: 'pass'|'to'|'sans'|'take'|'sans_atout', suit?: string}`
- `game:play_card` — `{suit, rank}`
- `game:declare` — révèle les annonces du joueur

**Serveur → Client :**
- `room:state` — `{room, players[]}` (broadcast à toute la salle)
- `room:player_ready` — `{user_id, players[]}`
- `room:player_left` — `{user_id}`
- `game:started` — `{state}` (broadcast, déclenche la navigation vers `GameScreen`)
- `game:hand` — `{hand[], position}` (**envoyé individuellement**, uniquement au socket du joueur concerné, jamais broadcast)
- `game:state_update` — `{state}` (broadcast, état public sans les mains)
- `game:round_result` — `{result, game_winner}`
- `game:new_round` — `{state}`
- `game:declarations` — `{position, declarations[], total}`
- `error` — `{message}` (émis en cas d'action invalide — voir Bugs connus, pas systématiquement affiché côté UI)

Il n'existe **pas** d'événement `game:start` émis par le client — le démarrage de partie est **entièrement serveur-piloté** (déclenché automatiquement dès que 4 joueurs non-spectateurs sont tous `is_ready`).

### Synchronisation
- La synchronisation de l'état de salle (avant partie) passe par une combinaison de réponses REST **et** de broadcasts Socket.IO redondants (ex : `bench_player`/`assign_seat` mutent via REST **et** émettent immédiatement `room:state` en Socket.IO pour notifier les autres clients connectés).
- Pendant la partie, toute mutation d'état (`place_bid`, `play_card`, `reveal_declarations`) renvoie un état public JSON-serializable (`_public_state()`) rediffusé à toute la salle via `game:state_update`, tandis que les mains privées sont envoyées individuellement.
- Après chaque action de jeu humaine réussie, le serveur appelle systématiquement `schedule_bot_turns(room_id, room_code)` pour relancer/poursuivre la boucle des bots si besoin (garde anti-concurrence via `_running_rooms`).

### Gestion des déconnexions
- `@socketio.on('disconnect')` (`room_events.py`) : marque l'utilisateur `is_online = False`, `socket_id = None` en base — **mais ne retire pas le joueur de la salle** (`RoomPlayer` n'est pas supprimé), et **ne met pas en pause/n'annule pas une partie en cours**. Si un joueur humain se déconnecte pendant une partie, la partie continue de tourner côté serveur en l'attendant indéfiniment (aucun timeout, aucun remplacement automatique par un bot en cours de partie) — voir Bugs connus.
- Le socket_id est resynchronisé à chaque `resolve_context()` réussi (sur n'importe quel événement authentifié), ce qui permet une reconnexion transparente pour recevoir de nouveau les diffusions, mais ne redonne pas explicitement l'état de jeu manqué pendant la déconnexion (pas de mécanisme de "replay"/resynchronisation complète après reconnexion identifié dans le code — à vérifier côté client si un `room:join`/re-fetch est fait après reconnexion : **Inconnu**, non testé en conditions réelles).

---

## 9. Gestion des états

Le frontend utilise exclusivement **`provider`** (`ChangeNotifier` + `MultiProvider` + `Consumer`/`context.watch`/`context.read`), pas de Riverpod/Bloc/GetX.

### Providers

| Provider | État géré | Notes |
|---|---|---|
| `LocaleProvider` | Langue active (`Locale`), persistée dans `shared_preferences` | Instancié avec la langue sauvegardée dès `main()` (avant `runApp`) |
| `AuthProvider` | `UserModel? user`, `String? token`, `isLoading` | `tryAutoLogin()` appelé une fois au démarrage par `_Root` ; connecte/déconnecte le socket global en fonction de l'état d'authentification |
| `RoomProvider` | Liste des salles, salle courante, liste des joueurs/spectateurs | Écoute `room:state`, `room:player_ready`, `room:player_left` ; expose des listes dérivées triées (`gamePlayers`, `spectators`) |
| `GameProvider` | État de partie (`GameStateModel`), main du joueur, résultat de manche, gagnant, annonces récentes | Garde `_listenersAttached` pour empêcher le double-attachement des listeners Socket.IO (bug potentiel si `setupSocketListeners` était appelé deux fois sans garde) |

### Flux des données (exemple : jouer une carte)

```
Tap utilisateur sur une carte (game_screen.dart)
   → _handleCardTap() : 1er tap = sélectionne (setState local), 2e tap = confirme
   → GameProvider.playCard(token, roomCode, card)
   → SocketService.playCard() → socket.emit('game:play_card', {...})
   → [Backend] sockets/game_events.py::on_play_card
   → BiltGame.play_card() → validation + mutation d'état en mémoire
   → socket.emit('game:state_update', {...}, to=room.code)  [broadcast salle]
   → socket.emit('game:hand', {...}, to=<socket du joueur>)  [main mise à jour, privé]
   → [Frontend] SocketService.on('game:state_update') → GameProvider met à jour _gameState → notifyListeners()
   → Consumer/context.watch<GameProvider>() dans GameScreen.build() → re-render
```

Chaque `Provider` ne notifie que ses propres écouteurs — il n'existe pas de store global unique (type Redux), l'état est fragmenté par domaine fonctionnel (auth / room / game / locale), ce qui est cohérent avec le pattern `provider` standard de Flutter.

---

## 10. Ressources

### Images (cartes à jouer)
Plusieurs générations d'assets de cartes coexistent dans `frontend/assets/` — **seul `cards_final/` est actuellement référencé** dans `pubspec.yaml` (`assets: - assets/cards_final/`) et donc réellement embarqué dans le build :

| Dossier | Format | Référencé dans pubspec.yaml | Statut |
|---|---|---|---|
| `assets/cards_final/` | `.jpg` | ✅ Oui | **Utilisé activement** (`PlayingCard._assetPath`) |
| `assets/cards/` | `.jpg` | ❌ Non (retiré du pubspec dans la dernière session) | Résidu, non embarqué |
| `assets/cards_clean/` | `.jpg` | ❌ Non | Résidu intermédiaire |
| `assets/cards_svg/` | `.svg` | ❌ Non | Source vectorielle intermédiaire (incomplète : diamonds_8 et spades manquants dans certains constats — **Inconnu**, non vérifié exhaustivement) |
| `assets/cards_svg_raster/` | `.jpg` | ❌ Non | Rendu raster intermédiaire des SVG |
| `assets/cards_source/` | `.svg` + `NOTICE.txt` | ❌ Non | Planche source originale `svg-cards-2.0.svg` + licence associée |

Chaque dossier de cartes contient 32 fichiers nommés `<suit>_<rank>.ext` en minuscules (`hearts_10.jpg`, `spades_a.jpg`, `clubs_j.jpg`, etc.), correspondant exactement au format attendu par `PlayingCard._cardKey` (`'${card.suit}_${card.rank.toLowerCase()}'`).

Le dossier `assets/images/` est référencé dans `pubspec.yaml` (`assets: - assets/images/`) mais **n'existe pas physiquement** dans l'arborescence actuelle — référence orpheline (Flutter tolère un dossier déclaré vide/absent sans erreur de build tant qu'aucun asset précis n'y est demandé, mais c'est une incohérence à nettoyer).

### Icônes
- `frontend/web/icons/` : icônes PWA (192/512, standard + maskable).
- `frontend/web/favicon.png`.
- `frontend/ios/Runner/Assets.xcassets/AppIcon.appiconset/` : jeu complet d'icônes iOS.
- `frontend/android/app/src/main/res/mipmap-*/ic_launcher.png` : icônes Android (probablement l'icône Flutter par défaut — **Inconnu**, non inspecté visuellement).
- Icônes Material (`Icons.*`) utilisées abondamment dans toute l'UI (pas d'icon-set custom).

### Sons / Musiques
**Aucun asset audio trouvé dans le projet.** Pas de dossier `assets/audio/` ou `assets/sounds/`, pas de package audio (`audioplayers`, `just_audio`, etc.) dans `pubspec.yaml`. Le jeu est actuellement **entièrement silencieux** (aucun effet sonore de distribution, de pose de carte, de victoire, etc.).

### Animations
Voir section 4 — animations purement déclaratives Flutter (`AnimatedContainer`, `AnimatedSwitcher`, `Transform.rotate/translate`), pas de fichiers Lottie/Rive/GIF.

### Polices
Une seule famille : **Cairo**, chargée dynamiquement via `google_fonts` (pas de fichier `.ttf` embarqué localement — nécessite un accès réseau au premier chargement, avec mise en cache ensuite par le package `google_fonts`).

---

## 11. Variables importantes

### Backend — constantes de jeu (`backend/game_logic/deck.py` et `bilt.py`)

| Constante | Valeur | Signification |
|---|---|---|
| `SUITS` | `['hearts', 'diamonds', 'clubs', 'spades']` | Les 4 couleurs |
| `RANKS` | `['7', '8', '9', '10', 'J', 'Q', 'K', 'A']` | Les 8 rangs (32 cartes au total) |
| `VALID_ACTIONS` | `{'pass', 'take', 'to', 'sans_atout', 'sans'}` | Actions d'enchère valides (avec alias legacy) |
| `NON_TRUMP_POINTS` | `{7:0, 8:0, 9:0, 10:10, J:2, Q:3, K:4, A:11}` | Valeurs hors-atout |
| `TRUMP_POINTS` | `{7:0, 8:0, 9:14, 10:10, J:20, Q:3, K:4, A:11}` | Valeurs à l'atout |
| `NON_TRUMP_ORDER` | `['7','8','9','J','Q','K','10','A']` | Ordre de force hors-atout |
| `TRUMP_ORDER` | `['7','8','Q','K','10','A','9','J']` | Ordre de force à l'atout (9 et J en tête) |
| `WIN_THRESHOLD_HOKM` | `82` | Seuil de réussite de l'équipe preneuse (mode atout, sur 162) |
| `WIN_THRESHOLD_SANS_ATOUT` | `66` | Seuil de réussite (mode sans-atout) |
| `MATCH_WIN_SCORE` | `152` | Score cumulé déclenchant la fin de partie |
| Bonus dernier pli | `10` | Points ajoutés au 8ᵉ pli |
| Bella | `20` points | Roi + Dame d'atout |
| Suite de 3 | `20` points | |
| Suite de 4+ | `50` points | |
| Durée de visibilité des choix d'enchère | `60` secondes | `bid_choices_visible_until` |
| Délai entre actions bot | `0.45` secondes | `socketio.sleep(0.45)` dans `bot_player.py` |

### Backend — configuration (`backend/config.py`)

| Variable d'environnement | Défaut (dev) | Rôle |
|---|---|---|
| `FLASK_ENV` | `development` | `production` active les contrôles stricts de secrets |
| `SECRET_KEY` | `meryas-secret-change-in-prod` | Clé Flask |
| `JWT_SECRET_KEY` | `meryas-jwt-secret-change-in-prod` | Clé de signature JWT |
| `DATABASE_URL` | `postgresql://meryas_user:meryas_pass@localhost:5432/meryas_db` | URI base de données |
| `JWT_ACCESS_TOKEN_EXPIRES` | `timedelta(days=7)` | Durée de validité du token |
| `MAX_CONTENT_LENGTH` | `5 * 1024 * 1024` (5 Mo) | Taille max des requêtes (upload avatar) |
| `CORS_ORIGINS` | `'*'` (dev) / vide (prod, à définir) | Origines autorisées |
| `AUTO_FILL_PUBLIC_ROOMS` | `true` (dev) | Active les bots de remplissage |
| `PORT` | `5000` | Port d'écoute Flask |
| `MAX_IMAGE_DIMENSION` (users.py) | `4096` px | Redimensionnement max des avatars |

### Frontend — constantes (`frontend/lib/utils/constants.dart`)

| Constante | Valeur | Rôle |
|---|---|---|
| `AppConstants.baseUrl` | `http://localhost:5000` (ou `--dart-define=API_HOST=...`) | Hôte du backend |
| `AppConstants.apiUrl` | `$baseUrl/api` | Base des appels REST |
| `AppConstants.socketUrl` | `$baseUrl` | URL de connexion Socket.IO |
| `AppConstants.matchWinScore` | `152` | Dupliqué côté client (doit rester synchronisé avec `MATCH_WIN_SCORE` backend — **aucune garantie automatique de synchronisation**, valeur en dur des deux côtés) |
| `LocaleProvider._key` | `'locale_lang'` | Clé `shared_preferences` |
| `StorageService._tokenKey` | `'auth_token'` | Clé `flutter_secure_storage` |

---

## 12. Classes importantes

### Backend

| Classe | Fichier | Rôle | Responsabilités | Interactions |
|---|---|---|---|---|
| `BiltGame` | `game_logic/bilt.py` | Machine à états d'une partie de Bilt, une instance par salle active | Cycle de vie complet (distribution, enchères, jeu, score) ; stockée en mémoire process | Créée/détruite via `create_session`/`remove_session` (dict global `game_sessions`) ; manipulée exclusivement par les handlers Socket.IO de `game_events.py` et `bot_player.py` |
| `User` | `models/user.py` | Modèle SQLAlchemy utilisateur | Hash/vérification du mot de passe (bcrypt), sérialisation `to_dict(public)`, détection bot (`is_bot`) | Référencé par `RoomPlayer`, `Room.creator`, comparé dans `resolve_context` |
| `Room` | `models/room.py` | Modèle SQLAlchemy salle | Génération de code unique, comptage joueurs/spectateurs, sérialisation | Parent de `RoomPlayer` (cascade delete), de `Game` |
| `RoomPlayer` | `models/room.py` | Modèle SQLAlchemy adhésion joueur↔salle | Position, équipe, statut spectateur/prêt | Unique par (room, user) ; manipulé par `routes/rooms.py` et `sockets/room_events.py` |
| `Game` / `GameRound` / `GameTrick` / `GameTrickCard` | `models/game.py` | Modèles SQLAlchemy de persistance de partie | `Game` seul réellement utilisé (score final) ; les 3 autres définis mais **inertes** (voir §7) | — |

### Frontend

| Classe | Fichier | Rôle | Responsabilités | Interactions |
|---|---|---|---|---|
| `AuthProvider` | `providers/auth_provider.dart` | État d'authentification | Login/register/logout/auto-login, connexion/déconnexion du socket global | Utilisé par `main.dart` (routing racine), tous les écrans qui ont besoin du token |
| `RoomProvider` | `providers/room_provider.dart` | État de la salle courante et de la liste des salles | CRUD salle, écoute Socket.IO `room:*`, dérive `gamePlayers`/`spectators` triés | `LobbyScreen`, `RoomScreen`, `GameScreen` (pour afficher les avatars des sièges) |
| `GameProvider` | `providers/game_provider.dart` | État de la partie en cours | Écoute Socket.IO `game:*`, expose `isMyTurn`/`isMyBidTurn`, garde anti-double-attachement des listeners | `RoomScreen` (détecte le démarrage de partie), `GameScreen` (toute l'UI de jeu) |
| `LocaleProvider` | `providers/locale_provider.dart` | Langue active | Persistance `shared_preferences`, toggle FR/AR | `main.dart` (MaterialApp.locale), `LangToggleButton` |
| `ApiService` | `services/api_service.dart` | Client REST statique | Toutes les requêtes HTTP typées, normalisation des erreurs (`ApiException`) | Appelé par tous les providers |
| `SocketService` | `services/socket_service.dart` | Client WebSocket statique (singleton) | Connexion/déconnexion, émission/écoute typée des événements | Appelé par `RoomProvider`/`GameProvider` |
| `StorageService` | `services/storage_service.dart` | Wrapper stockage sécurisé | Lecture/écriture/suppression du token JWT | `AuthProvider`, `ApiService._setAuth()` |
| `GameStateModel` | `models/game_state_model.dart` | Représentation immuable de l'état public de partie | Parsing JSON défensif (gère les clés Map en `String` côté JSON converties en `int`) | Produit par tous les événements `game:*` reçus |
| `RoomModel` / `RoomPlayerModel` | `models/room_model.dart` | Représentation d'une salle / d'une adhésion | Parsing JSON | `RoomProvider` |
| `CardModel` / `TrickCard` | `models/card_model.dart` | Représentation d'une carte / d'une carte jouée dans un pli | Égalité par valeur (`==`/`hashCode` sur suit+rank), symbole unicode de couleur | `PlayingCard`, `GameStateModel`, `GameProvider._myHand` |
| `AppTheme` | `theme/app_theme.dart` | Thème visuel centralisé | Couleurs, `ThemeData` sombre unique | `main.dart` (`MaterialApp.theme`) |

---

## 13. Algorithmes importants

### 1. Distribution des cartes (deux phases)
```
Phase 1 (deal_cards) :
  ordre = [3, 2, 1, 0]  # antihoraire
  pour 3 tours : distribuer 1 carte à chaque position dans cet ordre
  pour 2 tours : distribuer 1 carte à chaque position dans cet ordre
  → chaque joueur a 5 cartes, 12 cartes restent en pioche (dont turned_card = pioche[0])

Phase 2 (deal_remaining, après acceptation d'une enchère) :
  même ordre antihoraire
  pour 3 tours : distribuer 1 carte de la pioche restante (12 cartes) à chaque position
  → chaque joueur termine avec 8 cartes, pioche épuisée
```
Complexité : O(32), trivial. Invariant vérifié par les tests : aucune carte perdue ni dupliquée sur les 32.

### 2. Résolution des enchères simultanées (`_resolve_bid_choice`)
```
order = [(dealer+1)%4, (dealer+2)%4, (dealer+3)%4, dealer%4]
pour wanted_action dans ('to', 'sans') :        # priorité : 'to' bat 'sans'
    pour position dans order :                   # priorité : ordre de jeu depuis dealer+1
        si choices[position].action == wanted_action :
            retourner ce choix                    # le premier trouvé gagne
retourner None    # 4 passes → redistribution
```
C'est un **algorithme de résolution de priorité en deux clés** : type d'enchère (to > sans) puis position dans l'ordre de jeu. Complexité O(1) (4 positions max).

### 3. Résolution d'un pli (`resolve_trick` / `card_strength`)
```
force(carte, lead_suit) =
    si mode == sans_atout :
        rang(carte) + 100 si carte.couleur == lead_suit sinon rang(carte)
    sinon (hokm) :
        rang_atout(carte) + 200  si carte.couleur == atout
        rang(carte) + 100        si carte.couleur == lead_suit (et pas atout)
        rang(carte)               sinon (ne peut jamais gagner)

gagnant = carte de force maximale parmi les 4 cartes du pli
```
Les décalages +100/+200 créent une hiérarchie stricte : atout > couleur demandée > autre couleur, tout en conservant l'ordre relatif interne à chaque catégorie.

### 4. Légalité d'un coup (`_is_legal_play`)
```
si premier du pli : légal (toute carte)
sinon :
    si mode == sans_atout :
        légal si carte.couleur == lead_suit, SAUF si le joueur n'a aucune carte lead_suit (alors tout est légal)
    sinon (hokm) :
        si carte.couleur == lead_suit : légal
        sinon si le joueur a une carte lead_suit : illégal (doit suivre)
        sinon (ne peut pas suivre) :
            si le joueur n'a pas d'atout : légal (toute carte)
            sinon : légal seulement si carte.couleur == atout (doit couper)
```

### 5. Détection des annonces (`detect_declarations`)
```
Bella : (mode == hokm) ET main contient (Roi, atout) ET (Dame, atout) → +20

Pour chaque couleur :
    trier les cartes de cette couleur par rang croissant (ordre naturel 7..A)
    parcourir et regrouper les runs de rangs strictement consécutifs (index+1)
    pour chaque run de longueur >= 3 :
        +20 si longueur == 3, +50 si longueur >= 4
```
Algorithme de détection de séquences consécutives par tri + parcours linéaire, O(n log n) par couleur (n ≤ 8).

### 6. Calcul du score de manche (`_finish_round`)
```
team_trick_pts = somme des points de chaque pli par équipe gagnante
team_decl_pts  = somme des annonces révélées par équipe
cot_team = équipe ayant remporté les 8 plis, sinon None
threshold = 66 (sans-atout) ou 82 (hokm)

si cot_team existe :
    équipe du cot         → (somme totale des points de plis) × 2 + ses propres annonces
    autre équipe          → 0
sinon si team_trick_pts[preneur] >= threshold :
    chaque équipe          → ses propres points de plis + ses propres annonces
sinon (chute du preneur) :
    preneur                → 0
    autre équipe            → totalité des points de plis + ses propres annonces
```

### 7. Boucle de jeu des bots (`_run_bot_turns`)
Boucle `while True` exécutée en tâche de fond Socket.IO (`socketio.start_background_task`), avec `socketio.sleep(0.45)` en fin d'itération pour rendre la main à la boucle événementielle eventlet entre chaque action :
```
tant que la salle existe et est 'playing' et une session existe :
    si phase == 'bidding' :
        pour chaque position 0..3 n'ayant pas encore misé :
            si un bot occupe cette position : le faire passer, diffuser l'état
        si aucune action possible (aucun bot à agir) : arrêter la boucle (rendre la main à un humain)
    sinon si phase == 'playing' :
        position = tour courant
        si ce n'est pas un bot : arrêter la boucle
        essayer chaque carte de la main du bot dans l'ordre jusqu'à en trouver une légale, la jouer
        si fin de manche/partie : gérer la transition (score, nouvelle manche ou fin), et arrêter si partie finie
    sinon : arrêter
    pause 0.45s
```

---

## 14. Historique du développement

Le dépôt Git ne contient qu'**un seul commit** (`4f97552`, "Initial commit", 2026-07-07T22:24:12+00:00), qui constitue l'état de base du projet déjà largement fonctionnel (auth, lobby, salles, jeu complet, bots, i18n). **Il n'y a donc pas d'historique Git détaillé de la genèse du projet** — toute évolution antérieure au commit initial est **Inconnue**.

Au moment de la rédaction de ce document, il existe un **jeu de modifications non commitées** (26 fichiers modifiés + un nouveau dossier `frontend/assets/`) qui représente la session de travail la plus récente. Résumé de ce diff (déjà détaillé fonctionnellement dans les sections précédentes) :

1. **Refonte du système d'enchères** (`backend/game_logic/bilt.py`, `deck.py`) : passage d'un modèle **séquentiel** (`bidding_player` unique, avance au suivant à chaque passe, `bid_passes` compteur simple) à un modèle **simultané avec résolution par priorité** (`bid_choices: dict[position, choice]`, résolution une fois les 4 choix reçus via `_resolve_bid_choice`). Ajout des alias `'to'`/`'sans'` en plus de `'take'`/`'sans_atout'`. Ajout de la visibilité temporaire des choix (`last_bid_choices`, `bid_choices_visible_until`, 60 s).
2. **Ajout du mode de score `scoring_mode`** sur `Room` (colonne DB + migration ad hoc dans `app.py`), avec validation stricte côté route (`VALID_SCORING_MODES = {'zero', 'twenty_six'}`) et **verrouillage fonctionnel** : seul `'zero'` combiné à `game_type='bilt'` est actuellement autorisé à démarrer une partie (message d'erreur explicite sinon), en prévision d'un futur mode "départ à 26".
3. **Ajout de la gestion des sièges par le superviseur** (`bench_player`, `assign_seat` dans `routes/rooms.py`) avec diffusion Socket.IO immédiate (`_room_state_response`), et UI correspondante dans `room_screen.dart` (icône d'échange, bottom sheet de choix de siège).
4. **Correction du bug de bot bloqué en phase d'enchères** (`bot_player.py`) : l'ancienne version supposait un `bidding_player` unique et un bot qui prend systématiquement l'enchère avec la couleur retournée (`take`, `turned_card['suit']`) — ce comportement a été remplacé par une boucle qui fait passer chaque bot dont c'est le tour de miser, cohérente avec le nouveau modèle simultané. **Effet de bord** : les bots ne misent plus jamais "to" ou "sans" — ils passent systématiquement, ce qui signifie qu'**une table à 4 bots ne peut plus jamais démarrer de manche jouée** (redistribution infinie) — voir Bugs connus, c'est potentiellement une régression fonctionnelle involontaire par rapport au comportement précédent où au moins un bot pouvait prendre l'enchère.
5. **Tests mis à jour en conséquence** (`test_bilt.py`) : `_bid_accepted()` fait maintenant systématiquement passer les 3 autres joueurs après le mieseur ; nouveau test `test_to_uses_turned_card_suit`, `test_bid_choices_remain_visible_after_bid`, renommage de `test_wrong_turn_returns_error` en `test_player_cannot_bid_twice` (reflet direct du changement de modèle : il n'y a plus de "mauvais tour", seulement "déjà misé").
6. **Nettoyage des assets de cartes** (`pubspec.yaml`) : `assets/cards/` → `assets/cards_final/`.
7. Divers reformatages de code (probablement `dart format` automatique) sur plusieurs fichiers frontend sans changement fonctionnel (`api_service.dart`, `auth_provider.dart`, `game_provider.dart`, `app_theme.dart`, `constants.dart`, `card_model.dart`).

**État au moment de la rédaction** : tous les tests backend passent (**58 tests, 0 échec** — 56 rapportés par pytest pour le module principal + tests connexes, revalidé), `flutter analyze` ne remonte **aucun problème**.

---

## 15. Bugs corrigés

| Problème | Cause | Solution |
|---|---|---|
| Bot bloqué indéfiniment en phase d'enchères après la refonte du bidding | L'ancienne logique de `bot_player.py` présumait un unique `bidding_player` séquentiel (`current_round['bidding_player']`) qui n'a plus de sens dans le modèle simultané par `bid_choices` | Boucle réécrite pour itérer sur les 4 positions et faire passer chaque bot n'ayant pas encore misé, avec détection explicite de "plus rien à faire" (`acted = False` → arrêt de la boucle) |
| Erreur "mauvais tour" incohérente avec le nouveau modèle d'enchères | Le test `test_wrong_turn_returns_error` et la validation `_validate_bid` reposaient sur la notion d'un joueur actif unique | Remplacés par la notion de "déjà misé" (`position in r['bid_choices']` → `'Bid already submitted'`) |
| Schéma de base de données désynchronisé après ajout de `scoring_mode` sur des bases existantes | Pas de système de migration Alembic en place | Ajout d'une vérification manuelle au démarrage (`_ensure_room_schema` dans `app.py`) qui exécute un `ALTER TABLE` idempotent si la colonne est absente |

**Note** : en l'absence d'historique Git antérieur au commit initial, cette liste ne couvre que les corrections identifiables dans le diff de travail actuel. D'éventuelles corrections antérieures au commit initial sont **Inconnues**.

---

## 16. Bugs connus

| # | Problème | Sévérité (estimée) | Détail |
|---|---|---|---|
| 1 | **Aucun bot ne peut jamais gagner une enchère** | Élevée | Depuis la refonte du bidding, `bot_player.py` fait systématiquement `place_bid(position, 'pass')`. Une table composée uniquement (ou majoritairement) de bots en phase d'enchères produit une **redistribution infinie** si aucun humain ne mise `to`/`sans` — la partie ne peut jamais réellement démarrer sans intervention humaine active à chaque manche. |
| 2 | **Fonctionnalité de déclaration (annonces) invisible côté UI** | Élevée (fonctionnalité backend orpheline) | `game:declare` est totalement câblé (provider, service, backend, tests) mais **aucun bouton/overlay** dans `game_screen.dart` ne permet à l'utilisateur de le déclencher. Les joueurs ne peuvent jamais gagner de points de Bella/suite en pratique via l'UI actuelle. |
| 3 | **Historique de partie non persisté** | Moyenne | `GameRound`, `GameTrick`, `GameTrickCard` sont définis en base mais jamais peuplés. Impossible de consulter l'historique détaillé d'une partie terminée (manches, plis, annonces) — seul le score final agrégé (`Game.team0_score/team1_score`) survit. |
| 4 | **`Game.finished_at` jamais renseignée** | Faible | La colonne existe mais `_finish_game` ne l'assigne jamais (`game.finished_at = datetime.utcnow()` absent). |
| 5 | **Aucune gestion de la déconnexion pendant une partie** | Moyenne–Élevée | Un joueur humain qui se déconnecte pendant une partie n'est ni retiré, ni remplacé par un bot, ni averti aux autres joueurs autrement que par `is_online=False` en base (non répercuté en temps réel dans `game_screen.dart`, qui ne surveille pas la connectivité des adversaires). La partie reste bloquée en attendant indéfiniment son tour. |
| 6 | **Duplication de logique de fin de partie** | Faible (dette technique) | `_finish_game` est dupliquée quasi à l'identique entre `sockets/game_events.py` et `sockets/bot_player.py` (mise à jour des stats, statut de la salle) — risque de divergence future si l'une est modifiée sans l'autre. |
| 7 | **Erreurs serveur (`error` Socket.IO) potentiellement silencieuses côté UI** | Moyenne | Aucun listener explicite sur l'événement générique `error` n'a été trouvé dans `game_provider.dart`/`room_provider.dart` — une action refusée par le serveur (coup illégal, enchère déjà soumise, etc.) peut ne produire **aucun retour visuel** pour l'utilisateur (à vérifier/tester en conditions réelles ; **Inconnu** avec certitude absolue sans exécution live). |
| 8 | **Assets orphelins et incohérence de dossier `assets/images/`** | Faible | `pubspec.yaml` référence `assets/images/` qui n'existe pas physiquement ; 4 générations de dossiers de cartes (`cards`, `cards_clean`, `cards_svg`, `cards_svg_raster`) ne sont plus référencées mais toujours présentes sur disque, gonflant inutilement la taille du dépôt. |
| 9 | **Fichiers SQLite résiduels dans `backend/instance/`** | Faible | `meryas.db`/`meryas_dev.db` présents alors que la config pointe vers PostgreSQL — origine et utilité actuelles **Inconnues**, à nettoyer après vérification qu'ils ne sont pas utilisés par un flux alternatif oublié. |
| 10 | **Classement (leaderboard) non exposé dans l'UI** | Faible | Endpoint backend fonctionnel (`GET /api/users/leaderboard`) sans aucun écran/appel client. |
| 11 | **Traductions partiellement câblées en dur** dans `game_screen.dart` | Faible | Certains textes (ex. confirmation de sortie de table) utilisent `context.isArabic ? '...' : '...'` au lieu de passer par `appStrings`/`context.tr()`, ce qui duplique la logique de traduction en dehors du système centralisé. |
| 12 | **Dépendances déclarées mais inutilisées** | Faible | `flutter_animate` et `shimmer` sont dans `pubspec.yaml` sans aucune occurrence d'usage trouvée dans `lib/`. |
| 13 | **Pas de règle de sur-coupe obligatoire** | À confirmer | `_is_legal_play` impose de couper à l'atout si on ne peut pas suivre, mais n'impose pas de couper *plus fort* que la coupe déjà posée dans le pli — à valider si c'est la règle voulue ou un oubli par rapport aux règles traditionnelles du Bilt/Baloot (**Inconnu**, dépend des règles exactes visées par le porteur de projet). |

---

## 17. Optimisations effectuées

- **Requêtes de listing de salles bornées** : `Room.query...limit(50)` (routes `rooms.list_rooms`) et `User.query...limit(50)` (leaderboard) — évite de charger des collections non bornées.
- **Pool de connexions SQLAlchemy configuré explicitement** (`pool_pre_ping=True`, `pool_recycle=300`, `pool_size=10`, `max_overflow=20`) pour la robustesse en production (évite les connexions PostgreSQL mortes après inactivité).
- **Redimensionnement des avatars côté serveur** (`Image.thumbnail((4096, 4096))`) avant sauvegarde, pour éviter de stocker/servir des fichiers disproportionnés.
- **Diffusion ciblée des mains privées** : `game:hand` n'est jamais broadcast à toute la salle, uniquement au socket du joueur concerné (`to=u.socket_id`) — évite toute fuite d'information sur les mains des autres joueurs et réduit la bande passante.
- **État public explicitement filtré** (`BiltGame._public_state()`, `_serializable_round_result()`) : ne renvoie jamais les mains complètes ni les structures Python non sérialisables (`set` de positions ayant déclaré, etc.) — conversion explicite des clés `int` en `str` pour la compatibilité JSON.
- **Pause de 0.45 s entre actions bot** : optimisation d'expérience perçue plutôt que de performance brute — évite un déroulé de partie "instantané" illisible côté UI quand plusieurs bots jouent d'affilée.
- **Contraintes de tailles plafonnées côté UI** (`math.min(valeurFixe, proportion)` dans `game_screen.dart`) : évite un rendu disproportionné/coûteux sur de très grands écrans (tablettes) tout en restant proportionnel sur petits écrans.
- **Garde anti-double-attachement des listeners Socket.IO** (`GameProvider._listenersAttached`) : évite un enregistrement multiple des mêmes handlers (source classique de fuite mémoire et de traitements dupliqués en Flutter/Provider si `setupSocketListeners` est appelé plusieurs fois, ex. lors d'un rebuild du widget parent).

Aucune optimisation de rendu Flutter avancée identifiée (pas de `RepaintBoundary` explicite, pas de `const` systématique sur tous les widgets statiques, pas de lazy-loading d'images réseau au-delà de `cached_network_image` déclaré mais son usage effectif n'a pas été vérifié explicitement dans le code lu — **Inconnu**).

---

## 18. Sécurité

### Validation
- **Mots de passe** : hash **bcrypt** (`flask-bcrypt`), jamais stockés/renvoyés en clair ; longueur minimale de 6 caractères imposée à l'inscription.
- **Emails/usernames** : unicité vérifiée en base avant création (`409 Conflict` sinon), username borné 3–50 caractères.
- **Upload d'avatar** : double validation — (1) type MIME déclaré dans un allowlist (`image/jpeg`, `image/png`, `image/gif`, `image/webp`), (2) **vérification réelle du contenu binaire** via `PIL.Image.verify()` (empêche l'upload d'un fichier renommé en `.jpg` qui ne serait pas une image valide), (3) redimensionnement forcé (borne la surface d'attaque de type "decompression bomb" en limitant à 4096×4096 après ouverture), (4) nom de fichier généré côté serveur (`uuid4`) — **aucune donnée du nom de fichier original de l'utilisateur n'est utilisée**, ce qui élimine tout risque de path traversal via le nom de fichier.
- **Validation stricte des types de salle/scoring** (`VALID_GAME_TYPES`, `VALID_SCORING_MODES`) côté route ET re-vérifiée côté socket (`_start_game`) juste avant le démarrage effectif — défense en profondeur (double contrôle route + socket).
- **Toute la logique de jeu est validée côté serveur** (`_validate_bid`, `_validate_play`) — impossible de tricher en manipulant uniquement le client (un client modifié pourrait envoyer n'importe quelle action, mais le serveur refuse toute action illégale avec `{'error': ...}`).

### Protection
- **JWT signé** avec expiration 7 jours (`JWT_ACCESS_TOKEN_EXPIRES`), vérifié via `@jwt_required()` sur toutes les routes sensibles.
- **Autorisation par rôle explicite** : les endpoints de gestion des sièges (`bench_player`, `assign_seat`) vérifient `room.creator_id == user_id` (403 sinon), avec protection spécifique empêchant de déplacer/remplacer le superviseur lui-même.
- **CORS configurable** : `*` en développement, doit être explicitement restreint (`CORS_ORIGINS`) en production — **contrôle imposé au démarrage** : `_require()` fait planter le process en production si `SECRET_KEY`/`JWT_SECRET_KEY` contiennent encore la valeur par défaut `change-in-prod`.
- **Le token n'est jamais journalisé** dans le code lu (pas de `print`/`logger` visible affichant un token en clair).

### Anti-triche
- Les mains des joueurs ne sont **jamais** transmises à un autre client que leur propriétaire (`game:hand` toujours ciblé, jamais broadcast).
- L'état public (`_public_state`) exclut explicitement toute donnée de main.
- Toute action de jeu (mise, pose de carte, déclaration) est revalidée intégralement côté serveur indépendamment de ce que le client affiche/pense être l'état courant (le serveur est la seule source de vérité, cf. `_validate_bid`, `_is_legal_play`).
- **Limite** : comme les mains sont conservées uniquement en mémoire serveur et jamais chiffrées ni cloisonnées par process/salle au niveau OS, un accès direct à la mémoire du processus Flask (scénario hors-scope réseau) exposerait toutes les mains — non pertinent pour une menace réseau standard, mais à noter si un hébergement mutualisé/multi-tenant non isolé était envisagé (**Inconnu**, hors périmètre actuel).

### Sauvegardes
**Aucun mécanisme de sauvegarde applicative identifié dans le code** (pas de script de dump/export PostgreSQL, pas de job planifié). La sauvegarde de la base de données est supposée être gérée en dehors du code applicatif (au niveau infrastructure/hébergeur) — **Inconnu**, à documenter séparément selon l'environnement de déploiement cible.

---

## 19. TODO

Liste consolidée de tout ce qu'il reste à développer, dérivée des fonctionnalités verrouillées, des bugs connus et des gaps identifiés :

- [ ] **Ajouter un bouton/overlay de déclaration** dans `game_screen.dart` pour rendre utilisable `game:declare` (backend déjà prêt).
- [ ] **Revoir la stratégie des bots en phase d'enchères** pour qu'au moins un bot puisse miser `to`/`sans` selon une heuristique simple (éviter les redistributions infinies en salle 100% bots).
- [ ] **Implémenter le mode de jeu "Torneeka"** (actuellement verrouillé dans l'UI et refusé côté backend).
- [ ] **Implémenter le mode de score "départ à 26"** (`scoring_mode='twenty_six'`, actuellement verrouillé).
- [ ] **Persister l'historique détaillé de partie** en exploitant réellement `GameRound`/`GameTrick`/`GameTrickCard` (actuellement inertes), pour permettre un historique/replay consultable.
- [ ] **Gérer la déconnexion en cours de partie** : timeout, remplacement temporaire par un bot, ou pause de partie avec notification aux autres joueurs.
- [ ] **Renseigner `Game.finished_at`** à la fin de partie.
- [ ] **Exposer le classement (leaderboard)** dans l'UI (écran dédié ou section du profil).
- [ ] **Ajouter un retour visuel explicite** sur les événements `error` Socket.IO (snackbar/toast) côté `RoomProvider`/`GameProvider`.
- [ ] **Nettoyer les assets de cartes obsolètes** (`cards/`, `cards_clean/`, `cards_svg/`, `cards_svg_raster/`) et corriger la référence orpheline à `assets/images/` dans `pubspec.yaml`.
- [ ] **Clarifier/nettoyer les fichiers SQLite résiduels** dans `backend/instance/`.
- [ ] **Retirer ou exploiter réellement** les dépendances `flutter_animate` et `shimmer`.
- [ ] **Centraliser les couleurs du plateau de jeu** (`game_screen.dart`) dans `AppTheme` plutôt que des valeurs hexadécimales locales dispersées.
- [ ] **Compléter la traduction systématique** des chaînes actuellement câblées en dur dans `game_screen.dart`.
- [ ] **Mettre en place un système de migration formel** (Alembic) plutôt que la vérification manuelle ad hoc de schéma dans `app.py`.
- [ ] **Ajouter réinitialisation de mot de passe / vérification d'email** (aucun des deux n'existe actuellement).
- [ ] **Ajouter un refresh token / renouvellement de session** (le token JWT actuel expire sèchement après 7 jours, sans mécanisme de rafraîchissement).
- [ ] **Ajouter des sons/musiques** (aucun asset audio actuellement).
- [ ] **Clarifier la règle de sur-coupe** (surenchère de coupe obligatoire ou non) et l'implémenter si nécessaire.
- [ ] **Ajouter des tests d'intégration frontend** au-delà du `widget_test.dart` minimal existant (2 tests seulement : démarrage de l'app, bascule de langue).
- [ ] **Ajouter des tests end-to-end Socket.IO** (actuellement, seuls les endpoints REST et la logique pure `BiltGame`/`deck.py` sont testés ; aucun test n'exerce les handlers `sockets/*.py` eux-mêmes).

---

## 20. Priorités

### Critique
- Rendre les annonces (déclarations) utilisables dans l'UI (fonctionnalité backend prête mais totalement inaccessible aux joueurs — perte de points de jeu réelle pour les utilisateurs).
- Corriger le blocage des bots en phase d'enchères (redistribution infinie possible en salle bots-only, impacte directement la jouabilité en développement/démo).

### Haute
- Gestion de la déconnexion en cours de partie (bloque une partie entière si un joueur quitte sans prévenir).
- Retour visuel sur les erreurs serveur (`error` Socket.IO) côté UI.
- Nettoyage des assets obsolètes et de la référence orpheline `assets/images/` (dette technique impactant la taille du build et la clarté du dépôt).

### Moyenne
- Persistance de l'historique de partie (`GameRound`/`GameTrick`/`GameTrickCard`).
- Mise en place d'un système de migration formel (Alembic).
- Exposition du leaderboard côté UI.
- Complétion de la traduction systématique (`game_screen.dart`).
- `Game.finished_at` non renseignée.
- Déduplication de la logique `_finish_game` entre `game_events.py` et `bot_player.py`.

### Faible
- Implémentation de Torneeka / mode de score "26" (roadmap produit, pas un défaut actuel).
- Ajout de sons/musiques.
- Retrait des dépendances inutilisées (`flutter_animate`, `shimmer`).
- Centralisation des couleurs du plateau de jeu dans `AppTheme`.
- Refresh token / vérification d'email / reset mot de passe.
- Tests end-to-end Socket.IO et tests frontend étendus.

---

## 21. Décisions techniques

| Décision | Justification (déduite du code) |
|---|---|
| **État de partie en mémoire process, pas en base pendant le jeu** | Simplicité et performance pour un jeu temps réel à faible latence — éviter une écriture DB à chaque carte jouée. Contrepartie assumée : perte de partie si le process redémarre (aucun mécanisme de reprise). |
| **Serveur autoritaire strict, client "dumb terminal"** | Empêche toute triche côté client ; toute la logique de règles (`deck.py`, `bilt.py`) est dupliquée nulle part côté Flutter — un seul point de vérité. |
| **Token transmis dans le payload de chaque événement Socket.IO plutôt qu'au handshake** | Évite la complexité de l'authentification au niveau de la connexion WebSocket (middleware Socket.IO), au prix d'une légère redondance réseau ; permet aussi une resynchronisation naturelle de `socket_id` à chaque action. |
| **Démarrage de partie entièrement serveur-piloté (pas d'événement `game:start` client)** | Évite les races conditions/doubles démarrages ; le serveur est seul juge du moment où les conditions (4 joueurs prêts) sont réunies. Double garde explicite contre le double-démarrage (`room.status != 'waiting'` + vérification d'une session déjà existante). |
| **Migration de schéma "fait main" plutôt qu'Alembic** | Projet de taille modeste, un seul changement de schéma à ce jour (`scoring_mode`) — solution pragmatique mais qui ne passera pas à l'échelle si le schéma évolue fréquemment (voir Recommandations). |
| **Bots identifiés par convention d'email (`@devbot.meryas`)** plutôt qu'un champ booléen dédié en base | Évite une migration de schéma supplémentaire ; `is_bot` est une **propriété calculée**, pas une colonne — trade-off simplicité vs. requêtabilité SQL directe (impossible de filtrer les bots efficacement en SQL sans un `LIKE` sur l'email). |
| **Système d'enchères simultané avec priorité** (dernier changement) | Vraisemblablement un choix de gameplay pour accélérer les enchères (les 4 joueurs répondent en parallèle plutôt qu'en séquence stricte), au prix d'une compatibilité cassée avec la stratégie de bot précédente (voir Bugs connus #1). |
| **Un seul thème sombre, pas de thème clair** | Choix esthétique délibéré (ambiance "table de jeu"/casino), cohérent avec la palette vert/or. |
| **Police unique Cairo pour FR et AR** | Évite de gérer deux polices différentes selon la langue active, garantissant un rendu cohérent dans les deux langues. |
| **`provider` plutôt que Riverpod/Bloc/GetX** | Solution la plus simple et la plus légère pour un projet de cette taille, bien intégrée à l'écosystème Flutter standard, pas de génération de code nécessaire (contrairement à Riverpod avec `build_runner`). |

---

## 22. Dépendances

### Backend (`backend/requirements.txt`)

| Package | Version | Pourquoi |
|---|---|---|
| Flask | 3.0.3 | Framework web principal |
| Flask-SocketIO | 5.3.6 | Couche WebSocket temps réel au-dessus de Flask |
| Flask-JWT-Extended | 4.6.0 | Authentification par JWT |
| Flask-SQLAlchemy | 3.1.1 | ORM |
| Flask-Bcrypt | 1.0.1 | Hash de mots de passe |
| Flask-CORS | 4.0.1 | Gestion CORS (nécessaire car frontend Flutter web/mobile séparé du backend) |
| python-socketio | 5.11.2 | Dépendance sous-jacente de Flask-SocketIO |
| python-engineio | 4.9.1 | Dépendance sous-jacente (transport Engine.IO) |
| eventlet | 0.36.1 | Serveur asynchrone requis pour le mode `async_mode='eventlet'` de Flask-SocketIO (supporte de nombreuses connexions WebSocket concurrentes) |
| SQLAlchemy | 2.0.30 | ORM (dépendance directe, en plus de Flask-SQLAlchemy) |
| psycopg2-binary | 2.9.9 | Driver PostgreSQL |
| Pillow | 10.3.0 | Traitement/validation des images d'avatar |
| python-dotenv | 1.0.1 | Chargement du fichier `.env` |

### Frontend (`frontend/pubspec.yaml`)

| Package | Version | Pourquoi |
|---|---|---|
| flutter_localizations (SDK) | — | Support i18n natif Flutter (Material/Widgets/Cupertino delegates) |
| cupertino_icons | ^1.0.8 | Icônes de base Flutter |
| dio | ^5.4.3 | Client HTTP riche (intercepteurs, timeouts, gestion d'erreurs) pour l'API REST |
| socket_io_client | ^2.0.3+1 | Client WebSocket compatible avec le serveur Flask-SocketIO |
| provider | ^6.1.2 | Gestion d'état |
| flutter_secure_storage | ^9.0.0 | Stockage chiffré du token JWT (Keychain iOS / Keystore Android) |
| shared_preferences | ^2.2.3 | Persistance simple (langue choisie) |
| cached_network_image | ^3.3.1 | Mise en cache des images réseau (avatars) |
| image_picker | ^1.1.2 | Sélection d'image depuis la galerie pour l'avatar |
| flutter_animate | ^4.5.0 | **Déclaré mais non utilisé actuellement** dans le code (voir Bugs connus) |
| shimmer | ^3.0.0 | **Déclaré mais non utilisé actuellement** |
| google_fonts | ^6.2.1 | Police Cairo (rendu FR + AR cohérent) |
| intl | ^0.20.2 | Internationalisation (formatage, bien que la traduction elle-même soit maison via `app_strings.dart`) |
| flutter_lints (dev) | ^6.0.0 | Règles de lint standard Flutter |

---

## 23. Paramètres de configuration

### Backend — fichier `.env` (non commité, `.env.example` fourni comme modèle)
```
DATABASE_URL=postgresql://<user>:<password>@<host>:5432/<db>
SECRET_KEY=<clé aléatoire>
JWT_SECRET_KEY=<clé aléatoire différente>
PORT=5000
FLASK_ENV=production            # optionnel, active les contrôles stricts
CORS_ORIGINS=https://yourdomain.com   # optionnel, CSV
AUTO_FILL_PUBLIC_ROOMS=true     # optionnel, dev uniquement
```
Dans l'environnement local actuel, seul `DATABASE_URL` est explicitement défini dans `.env` (confirmé pointer vers un schéma `postgresql`) ; les autres variables utilisent donc leurs valeurs par défaut de développement (`FLASK_ENV=development` implicite, bots activés).

### Frontend — configuration au lancement
```bash
flutter run --dart-define=API_HOST=http://192.168.1.10:5000
```
Sans `API_HOST`, le frontend pointe par défaut sur `http://localhost:5000` (fonctionne pour web/iOS simulator/desktop ; **pour un émulateur Android, `localhost` ne fonctionne PAS** et il faut explicitement passer `API_HOST=http://10.0.2.2:5000` — ce point est documenté en commentaire dans `constants.dart` mais **le code par défaut ne le gère pas automatiquement** malgré le commentaire qui le suggère ; à vérifier/corriger si le ciblage Android émulateur pose problème).

### Démarrage local (résumé du `README.md`)
```bash
# Backend
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python app.py        # démarre sur http://localhost:5000

# Frontend
cd frontend
flutter pub get
flutter run
```

---

## 24. Version actuelle du projet

- **Version applicative** : `1.0.0+1` (`frontend/pubspec.yaml`, `version:` — numéro de build Flutter standard).
- **Backend** : pas de numéro de version explicite dans le code (pas de `__version__`, pas de `setup.py`/`pyproject.toml`) — **Inconnu**.
- **Dernier commit Git** : `4f97552` — "Initial commit" — 2026-07-07T22:24:12+00:00.
- **État du dépôt** : 26 fichiers modifiés + 1 nouveau dossier d'assets, **non commités**, en attente de validation par l'utilisateur (voir section 14 pour le détail exact des changements).
- **Tests backend** : 58 tests, tous passants au moment de la rédaction.
- **Analyse statique frontend** (`flutter analyze`) : aucun problème détecté au moment de la rédaction.
- **Taille approximative du code source applicatif** (hors dépendances/build) : ≈ 6 222 lignes Python (backend) + ≈ 4 289 lignes Dart (frontend `lib/`).

---

## 25. Instructions de reprise

**Pour reprendre ce projet immédiatement, sans poser de question :**

1. **Comprendre le contexte** : ceci est un jeu de cartes Bilt multijoueur temps réel (Flask + Socket.IO côté serveur, Flutter côté client), avec un backend **strictement autoritaire** — toute nouvelle fonctionnalité de règle de jeu doit être implémentée et validée côté serveur (`backend/game_logic/`), jamais uniquement côté client.

2. **Avant toute chose, décider du sort des modifications non commitées** (section 14/26) : elles constituent un ensemble cohérent (refonte du bidding + gestion des sièges + scoring_mode) qui semble être un travail terminé et testé (58 tests passants, `flutter analyze` propre) — probablement prêt à être commité, sauf si l'utilisateur souhaite les réviser d'abord. **Ne pas commiter sans confirmation explicite de l'utilisateur** (conformément aux règles générales de prudence sur les actions Git).

3. **Lancer l'environnement de dev** :
   ```bash
   cd backend && source venv/bin/activate && python app.py
   cd frontend && flutter run   # ou flutter run -d chrome pour le web
   ```
   Le venv Python 3.9 et les dépendances Flutter (`pubspec.lock`) semblent déjà installés localement (venv présent, `.gradle`/`Pods` déjà générés).

4. **Prioriser la correction du bug critique #1** (section 16/20) avant tout nouveau développement de gameplay : sans au moins un bot capable de miser `to`/`sans`, aucune partie 100% bots ne peut jamais réellement démarrer — cela bloque toute démo/test rapide en solo.

5. **Puis prioriser l'exposition UI des déclarations** (bug critique #2) : le backend est prêt à 100 %, il ne manque qu'un bouton et un petit overlay dans `game_screen.dart` (s'inspirer du pattern déjà en place pour `_buildBiddingPanel`).

6. **Pour toute modification du schéma de base de données**, suivre le pattern déjà établi dans `app.py::_ensure_room_schema()` (ajout de colonne idempotent) **ou** introduire Alembic si le changement est plus complexe qu'un simple ajout de colonne — ne pas mélanger les deux approches sans réflexion.

7. **Pour toute nouvelle règle de jeu**, l'implémenter dans `backend/game_logic/deck.py` (fonctions pures) ou `backend/game_logic/bilt.py` (état de la partie), écrire les tests correspondants dans `backend/tests/test_deck.py`/`test_bilt.py` **en premier ou en parallèle** (le projet a une culture de test forte et cohérente sur cette couche), puis exposer côté client via `GameStateModel`/`GameProvider`/`game_screen.dart` uniquement pour l'affichage.

8. **Respecter le système i18n existant** : toute nouvelle chaîne visible doit être ajoutée dans `frontend/lib/l10n/app_strings.dart` (clé → `{fr, ar}`) et consommée via `context.tr('clé')`, **pas** de texte en dur dans les widgets (le code actuel contient déjà quelques entorses à cette règle dans `game_screen.dart` — ne pas en ajouter de nouvelles).

9. **Ne pas commiter `backend/.env`, `backend/instance/*.db`, ni les dossiers de build Flutter** — déjà correctement exclus par les `.gitignore` en place, à respecter.

10. **Se référer aux sections 5, 11, 12 et 13** de ce document comme documentation de référence exacte et à jour des règles du jeu et de la structure de code avant d'écrire du code touchant à la logique métier — elles ont été vérifiées directement contre le code source, pas résumées de mémoire.

---

## 26. Contexte complet

Ce document a été généré à partir d'une **lecture exhaustive du code source actuel** (backend Python complet, frontend Dart `lib/` complet, tests, configuration, `README.md`, `.gitignore`, diff Git non commité) au cours d'une unique session de travail (2026-07-22), en l'absence d'historique de conversation antérieur accessible dans cette session (aucune mémoire persistante préexistante sur ce projet n'a été trouvée au moment de la rédaction). **Il n'existe donc pas de "conversations passées" à récapituler au-delà de ce qui est déjà intégralement restitué dans les sections 1 à 25** — ce document constitue lui-même la synthèse complète de tout ce qui est connaissable sur l'état actuel du projet à partir du code et du dépôt Git disponibles.

Éléments de contexte tangentiels notés au passage, qui ne rentraient pas naturellement dans une autre section :
- Le nom du dossier racine du projet (`meriass`) diffère légèrement du nom de produit (`Meryas`) et du nom de package Dart (`meryas`) — cohérence à surveiller si des scripts/CI se basent sur des noms de chemin.
- Le fichier `.claude/settings.local.json` autorise déjà sans confirmation les commandes `flutter create`, `flutter pub`, `flutter analyze`, `flutter test`, `psql --version`, `brew list`, ainsi que la lecture de `//usr/**` et `//opt/**` — reflète un usage antérieur de Claude Code sur ce projet pour des tâches Flutter/PostgreSQL courantes.
- Aucune CI/CD (pas de dossier `.github/workflows/`, pas de `Makefile`, pas de `Dockerfile`) n'a été trouvée — le déploiement est **Inconnu** (probablement manuel ou non encore mis en place).
- Aucune documentation produit/design (maquettes, cahier des charges) n'a été trouvée dans le dépôt au-delà du `README.md` technique — les règles de jeu documentées dans ce document proviennent **exclusivement de la lecture du code**, pas d'une spécification externe.

---

## 27. Recommandations techniques

Par ordre d'impact décroissant estimé :

1. **Corriger la stratégie de bidding des bots** pour introduire une heuristique minimale (ex. : le bot mise `to` sur la couleur de la carte retournée si sa main contient au moins N cartes de cette couleur, sinon passe) — débloque immédiatement la jouabilité solo/démo sans nécessiter une vraie IA.
2. **Exposer les déclarations dans l'UI** en priorité absolue avant tout autre ajout de fonctionnalité de jeu — c'est le seul écart majeur entre "ce que le backend sait faire" et "ce que le joueur peut réellement faire".
3. **Introduire Alembic** dès la prochaine évolution de schéma non triviale (ajout de table, changement de type de colonne, etc.) — le mécanisme actuel (`_ensure_room_schema`) ne passe pas à l'échelle au-delà d'un ajout de colonne simple avec valeur par défaut.
4. **Ajouter un mécanisme de "grâce" de déconnexion** (ex. : timeout de 60–120 s avant de mettre la partie en pause ou de proposer de remplacer le joueur déconnecté par un bot) — actuellement le point faible le plus susceptible de "casser" une partie réelle entre humains.
5. **Centraliser un design system de couleurs** unique (fusionner les couleurs codées en dur dans `game_screen.dart` avec `AppTheme`) avant que le nombre d'écrans n'augmente encore — dette de cohérence visuelle qui s'aggravera avec la croissance du projet.
6. **Ajouter une couche de tests d'intégration Socket.IO** (ex. avec le client de test de `python-socketio`) pour couvrir les handlers `sockets/*.py` eux-mêmes, actuellement non testés directement (seule la logique pure `BiltGame` l'est) — le point d'intégration serveur↔réseau est le plus risqué en cas de régression silencieuse.
7. **Décider explicitement du sort de `GameRound`/`GameTrick`/`GameTrickCard`** : soit les exploiter réellement (historique de partie consultable, rejouabilité, statistiques avancées — forte valeur produit potentielle pour un jeu de cartes compétitif), soit les retirer du schéma si ce n'est définitivement pas prévu — leur présence inerte actuelle est une source de confusion pour tout futur contributeur.
8. **Ajouter un retour utilisateur (son/vibration/toast) minimal** sur les événements clés (tour du joueur, pli gagné, fin de manche) — actuellement l'app est visuellement complète mais totalement silencieuse, ce qui nuit à l'expérience "table de jeu" pourtant visée par le thème.
9. **Nettoyer le dépôt des assets de cartes obsolètes** avant qu'il ne grossisse encore — gain immédiat de taille de dépôt/build sans aucun risque fonctionnel (dossiers non référencés dans `pubspec.yaml`).
10. **Envisager un token de rafraîchissement (refresh token)** plutôt qu'un JWT à expiration fixe de 7 jours sans renouvellement — actuellement un utilisateur est déconnecté sèchement après 7 jours d'inactivité sans avertissement progressif ni renouvellement transparent.
