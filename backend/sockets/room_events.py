from flask import request
from flask_socketio import join_room, leave_room, emit
from extensions import db, socketio
from models.user import User
from models.room import Room, RoomPlayer
from models.game import Game
from dev_bots import auto_fill_public_room
from .auth import get_user_from_token, auth_error, resolve_context


@socketio.on('room:join')
def on_room_join(data):
    ctx = resolve_context(data, require_player=False)
    if ctx is None:
        return
    user, room, member = ctx

    join_room(room.code)
    players_q = room.players.all()
    players = [p.to_dict() for p in players_q]
    emit('room:state', {'room': room.to_dict(), 'players': players}, to=room.code)

    # Bots may have filled the room after the human became ready. Re-check on
    # every socket join so an already-ready room cannot remain stuck waiting.
    _start_if_ready(room, players_q)


@socketio.on('room:leave')
def on_room_leave(data):
    ctx = resolve_context(data, require_player=False)
    if ctx is None:
        return
    user, room, member = ctx

    _remove_member(room, member, user)
    leave_room(room.code)

    players = [p.to_dict() for p in room.players.all()]
    emit('room:state', {'room': room.to_dict(), 'players': players}, to=room.code)
    emit('room:player_left', {'user_id': user.id}, to=room.code)


@socketio.on('room:ready')
def on_player_ready(data):
    ctx = resolve_context(data, require_player=True)
    if ctx is None:
        return
    user, room, member = ctx

    if room.status != 'waiting':
        auth_error('Room is not waiting for players')
        return

    member.is_ready = True
    db.session.commit()

    players_q = room.players.all()
    players = [p.to_dict() for p in players_q]
    emit('room:player_ready', {'user_id': user.id, 'players': players}, to=room.code)

    _start_if_ready(room, players_q)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _start_if_ready(room: Room, players: list[RoomPlayer]) -> None:
    non_spectators = [player for player in players if not player.is_spectator]
    if len(non_spectators) == 4 and all(player.is_ready for player in non_spectators):
        _start_game(room, room.code)

def _remove_member(room: Room, member: RoomPlayer, user: User) -> None:
    """Delete the RoomPlayer and free the position."""
    db.session.delete(member)
    db.session.flush()
    auto_fill_public_room(room)
    db.session.commit()


def _start_game(room: Room, room_code: str) -> None:
    """
    Server-driven game start — called once when all 4 players are ready.
    Guarded against double-start by checking room.status.
    """
    # Double-start guard (concurrent ready events)
    db.session.refresh(room)
    if room.status != 'waiting':
        return

    # Extra check: exactly 4 non-spectator players
    members = RoomPlayer.query.filter_by(room_id=room.id, is_spectator=False).all()
    if len(members) != 4:
        return

    # Guard: no existing active game for this room
    existing_game = Game.query.filter_by(room_id=room.id, status='active').first()
    if existing_game:
        return

    from game_logic.bilt import create_session, get_session
    if get_session(room.id):
        return   # session already exists

    players = [{'user_id': m.user_id, 'position': m.position, 'team': m.team} for m in members]
    session = create_session(room.id, players)

    room.status = 'playing'
    game = Game(room_id=room.id, game_type=room.game_type)
    db.session.add(game)
    db.session.commit()

    public_state = session.start_round()
    emit('game:started', {'state': public_state}, to=room_code)

    # Send private hands
    for pos, player_info in session.players.items():
        u = User.query.get(player_info['user_id'])
        if u and u.socket_id:
            emit('game:hand', {'hand': session.get_hand(pos), 'position': pos}, to=u.socket_id)

    from .bot_player import schedule_bot_turns
    schedule_bot_turns(room.id, room_code)


@socketio.on('disconnect')
def on_disconnect():
    user = User.query.filter_by(socket_id=request.sid).first()
    if user:
        user.is_online = False
        user.socket_id = None
        db.session.commit()
