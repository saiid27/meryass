# Meryas — Jeu de cartes en ligne

## Démarrage rapide

### Backend (Flask)
```bash
cd backend
python -m venv venv
source venv/bin/activate      # Windows: venv\Scripts\activate
pip install -r requirements.txt
python app.py
```
Le serveur démarre sur **http://localhost:5000**

### Frontend (Flutter)
```bash
cd frontend
flutter pub get
flutter run
```

## Architecture

```
meriass/
├── backend/
│   ├── app.py              # Point d'entrée Flask + SocketIO
│   ├── config.py           # Configuration
│   ├── extensions.py       # db, jwt, bcrypt, socketio
│   ├── models/             # User, Room, RoomPlayer, Game, GameRound
│   ├── routes/             # REST API: auth, users, rooms
│   ├── sockets/            # WebSocket: room_events, game_events
│   └── game_logic/         # Logique Bilt: deck, bilt.py
└── frontend/
    └── lib/
        ├── main.dart
        ├── models/         # UserModel, RoomModel, CardModel, GameStateModel
        ├── providers/      # AuthProvider, RoomProvider, GameProvider
        ├── screens/        # auth, lobby, game, profile
        ├── services/       # ApiService, SocketService, StorageService
        ├── widgets/        # PlayingCard, CardBack
        └── theme/          # AppTheme (vert foncé + or)

## API REST

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | /api/auth/register | Inscription |
| POST | /api/auth/login | Connexion |
| GET | /api/auth/me | Profil connecté |
| GET | /api/users/:id | Profil public |
| PUT | /api/users/profile | Modifier profil |
| POST | /api/users/avatar | Changer avatar |
| GET | /api/users/leaderboard | Classement |
| GET | /api/rooms/ | Liste des salles |
| POST | /api/rooms/ | Créer une salle |
| GET | /api/rooms/:code | Détails salle |
| POST | /api/rooms/:code/join | Rejoindre |
| POST | /api/rooms/:code/leave | Quitter |

## WebSocket Events

### Client → Serveur
- `room:join` — Rejoindre une salle (token, room_code)
- `room:leave` — Quitter
- `room:ready` — Marquer prêt
- `game:start` — Démarrer la partie
- `game:bid` — Enchérir (action: pass/take/sans_atout, suit?)
- `game:play_card` — Jouer une carte (suit, rank)
- `game:declare` — Annoncer ses déclarations

### Serveur → Client
- `room:state` — État de la salle (tous)
- `room:player_ready` — Joueur prêt (tous)
- `room:start_game` — Partie commence (tous)
- `game:started` — Partie démarrée (tous)
- `game:hand` — Cartes privées (joueur uniquement)
- `game:state_update` — État public du jeu (tous)
- `game:round_result` — Résultat du tour (tous)
- `game:new_round` — Nouveau tour (tous)
- `game:declarations` — Déclarations annoncées (tous)
```
