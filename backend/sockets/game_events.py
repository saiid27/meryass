from flask_socketio import emit
from extensions import db, socketio
from models.user import User
from models.room import Room, RoomPlayer
from models.game import Game
from game_logic import bilt, torneeka
from .auth import auth_error, resolve_context
from .bot_player import schedule_bot_turns


# game:start is intentionally NOT exposed as a client event.
# The server triggers game start automatically via room_events._start_game().


@socketio.on('game:bid')
def on_bid(data):
    ctx = resolve_context(data, require_player=True)
    if ctx is None:
        return
    user, room, member = ctx

    if room.status != 'playing':
        auth_error('Game is not in progress')
        return

    action = data.get('action', '')
    suit = data.get('suit')

    session = _get_session(room.id)
    if not session:
        auth_error('No active game session')
        return

    result = session.place_bid(member.position, action, suit)
    if 'error' in result:
        emit('error', result)
        return

    emit('game:state_update', {'state': result}, to=room.code)

    # If bidding resolved, send updated private hands (phase-2 dealt)
    if result.get('status') == 'playing':
        _broadcast_hands(session, room.code)
    schedule_bot_turns(room.id, room.code)


@socketio.on('game:play_card')
def on_play_card(data):
    ctx = resolve_context(data, require_player=True)
    if ctx is None:
        return
    user, room, member = ctx

    if room.status != 'playing':
        auth_error('Game is not in progress')
        return

    suit = data.get('suit', '')
    rank = data.get('rank', '')

    session = _get_session(room.id)
    if not session:
        auth_error('No active game session')
        return

    result = session.play_card(member.position, suit, rank)
    if 'error' in result:
        emit('error', result)
        return

    if 'game_winner' in result:
        # Round or game ended
        emit('game:state_update', {'state': result.get('state', {})}, to=room.code)
        emit('game:round_result', {
            'result': result.get('round_result'),
            'game_winner': result.get('game_winner'),
        }, to=room.code)
        _record_round_played(room)

        if result['game_winner'] is not None:
            if room.game_type == 'torneeka':
                _record_torneeka_win(room, session, result['game_winner'])
            else:
                _finish_game(room, session, result['game_winner'])
                _remove_session(room)
        else:
            new_state = session.start_round()
            emit('game:new_round', {'state': new_state}, to=room.code)
            _broadcast_hands(session, room.code)
    else:
        emit('game:state_update', {'state': result}, to=room.code)
        # Send updated hand only to the player who just played
        hand = session.get_hand(member.position)
        if user.socket_id:
            emit('game:hand', {'hand': hand, 'position': member.position}, to=user.socket_id)

    if room.status == 'playing':
        schedule_bot_turns(room.id, room.code)


@socketio.on('game:declare')
def on_declare(data):
    ctx = resolve_context(data, require_player=True)
    if ctx is None:
        return
    user, room, member = ctx

    if room.status != 'playing':
        auth_error('Game is not in progress')
        return

    session = _get_session(room.id)
    if not session:
        auth_error('No active game session')
        return

    result = session.reveal_declarations(member.position)
    if 'error' in result:
        emit('error', result)
        return

    emit('game:declarations', {'position': member.position, **result}, to=room.code)


@socketio.on('game:mg')
def on_mg(data):
    ctx = resolve_context(data, require_player=True)
    if ctx is None:
        return
    _user, room, member = ctx

    if room.status != 'playing':
        auth_error('Game is not in progress')
        return

    session = _get_session(room.id)
    if not session:
        auth_error('No active game session')
        return

    result = session.call_mg(member.position)
    if 'error' in result:
        emit('error', result)
        return

    if 'game_winner' not in result:
        emit('game:state_update', {'state': result}, to=room.code)
        schedule_bot_turns(room.id, room.code)
        return

    emit('game:state_update', {'state': result.get('state', {})}, to=room.code)
    emit('game:round_result', {
        'result': result.get('round_result'),
        'game_winner': result.get('game_winner'),
    }, to=room.code)
    _record_round_played(room)

    if result['game_winner'] is not None:
        if room.game_type == 'torneeka':
            _record_torneeka_win(room, session, result['game_winner'])
        else:
            _finish_game(room, session, result['game_winner'])
            _remove_session(room)
    else:
        new_state = session.start_round()
        emit('game:new_round', {'state': new_state}, to=room.code)
        _broadcast_hands(session, room.code)
        schedule_bot_turns(room.id, room.code)


@socketio.on('game:next_round')
def on_next_round(data):
    ctx = resolve_context(data, require_player=True)
    if ctx is None:
        return
    _user, room, _member = ctx

    if room.status != 'playing':
        auth_error('Game is not in progress')
        return
    if room.game_type != 'torneeka':
        auth_error('Next round is only available for Torneeka')
        return

    session = torneeka.get_session(room.id)
    if not session:
        auth_error('No active game session')
        return
    if session.state != 'game_end':
        auth_error('Round is not finished')
        return

    new_state = session.start_round()
    emit('game:new_round', {'state': new_state}, to=room.code)
    _broadcast_hands(session, room.code)
    schedule_bot_turns(room.id, room.code)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _broadcast_hands(session, room_code: str) -> None:
    """Send each player their private hand."""
    for pos, player_info in session.players.items():
        u = User.query.get(player_info['user_id'])
        if u and u.socket_id:
            emit('game:hand', {
                'hand': session.get_hand(pos),
                'position': pos,
            }, to=u.socket_id)


def _get_session(room_id: int):
    return bilt.get_session(room_id) or torneeka.get_session(room_id)


def _remove_session(room: Room) -> None:
    if room.game_type == 'torneeka':
        torneeka.remove_session(room.id)
    else:
        bilt.remove_session(room.id)


def _record_round_played(room: Room) -> None:
    members = RoomPlayer.query.filter_by(room_id=room.id, is_spectator=False).all()
    for member in members:
        user = member.user
        if user and not user.is_bot:
            user.rounds_played = (user.rounds_played or 0) + 1
    db.session.commit()


def _record_torneeka_win(room: Room, session, winner_team: int) -> None:
    members = RoomPlayer.query.filter_by(room_id=room.id, is_spectator=False).all()
    for member in members:
        user = member.user
        if user and not user.is_bot:
            if member.team == winner_team:
                user.wins += 1
            else:
                user.losses += 1
            user.total_points += session.team_scores[member.team]
    db.session.commit()


def _finish_game(room: Room, session, winner_team: int) -> None:
    room.status = 'finished'
    game = Game.query.filter_by(room_id=room.id, status='active').first()
    if game:
        game.status = 'finished'
        game.team0_score = session.team_scores[0]
        game.team1_score = session.team_scores[1]
        game.winner_team = winner_team

    members = RoomPlayer.query.filter_by(room_id=room.id, is_spectator=False).all()
    for m in members:
        u = User.query.get(m.user_id)
        if u:
            if m.team == winner_team:
                u.wins += 1
            else:
                u.losses += 1
            u.total_points += session.team_scores[m.team]

    db.session.commit()
