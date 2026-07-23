"""Small deterministic bot loop for development rooms."""
import time

from flask import current_app

from extensions import db, socketio
from game_logic.bilt import get_session, remove_session
from models.game import Game
from models.room import Room, RoomPlayer
from models.user import User
from dev_bots import is_bot_user


_running_rooms = set()


def schedule_bot_turns(room_id: int, room_code: str) -> None:
    """Run bot actions in the background until control returns to a person."""
    if room_id in _running_rooms:
        return
    app = current_app._get_current_object()
    _running_rooms.add(room_id)
    socketio.start_background_task(_run_bot_turns, app, room_id, room_code)


def _bot_at(room_id: int, position: int):
    member = RoomPlayer.query.filter_by(
        room_id=room_id,
        position=position,
        is_spectator=False,
    ).first()
    return member if member and is_bot_user(member.user) else None


def _broadcast_human_hands(session) -> None:
    for position, player_info in session.players.items():
        user = db.session.get(User, player_info['user_id'])
        if user and user.socket_id:
            socketio.emit(
                'game:hand',
                {'hand': session.get_hand(position), 'position': position},
                to=user.socket_id,
            )


def _finish_game(room, session, winner_team: int) -> None:
    room.status = 'finished'
    game = Game.query.filter_by(room_id=room.id, status='active').first()
    if game:
        game.status = 'finished'
        game.team0_score = session.team_scores[0]
        game.team1_score = session.team_scores[1]
        game.winner_team = winner_team

    members = RoomPlayer.query.filter_by(
        room_id=room.id,
        is_spectator=False,
    ).all()
    for member in members:
        user = member.user
        if user and not is_bot_user(user):
            if member.team == winner_team:
                user.wins += 1
            else:
                user.losses += 1
            user.total_points += session.team_scores[member.team]
    db.session.commit()


def _run_bot_turns(app, room_id: int, room_code: str) -> None:
    try:
        with app.app_context():
            while True:
                room = db.session.get(Room, room_id)
                session = get_session(room_id)
                if not room or room.status != 'playing' or not session:
                    return

                current_round = session.current_round
                if current_round['status'] == 'redeal_pending':
                    socketio.sleep(60)
                    new_state = session.complete_pending_redeal()
                    if new_state:
                        socketio.emit('game:new_round', {'state': new_state}, to=room_code)
                        _broadcast_human_hands(session)

                elif current_round['status'] == 'bidding':
                    position = current_round.get('bidding_player')
                    if position is None or not _bot_at(room_id, position):
                        return

                    result = session.place_bid(position, 'pass')
                    if 'error' in result:
                        return

                    socketio.emit('game:state_update', {'state': result}, to=room_code)

                    if result.get('status') == 'playing':
                        _broadcast_human_hands(session)

                elif current_round['status'] == 'playing':
                    position = current_round['current_turn']
                    if not _bot_at(room_id, position):
                        return
                    wait_for = current_round.get('turn_available_at', 0) - time.time()
                    if wait_for > 0:
                        socketio.sleep(wait_for)
                        continue

                    result = None
                    for card in list(session.get_hand(position)):
                        candidate = session.play_card(position, card['suit'], card['rank'])
                        if 'error' not in candidate:
                            result = candidate
                            break
                    if result is None:
                        return

                    if 'game_winner' not in result:
                        socketio.emit('game:state_update', {'state': result}, to=room_code)
                    else:
                        socketio.emit(
                            'game:state_update',
                            {'state': result.get('state', {})},
                            to=room_code,
                        )
                        socketio.emit(
                            'game:round_result',
                            {
                                'result': result.get('round_result'),
                                'game_winner': result.get('game_winner'),
                            },
                            to=room_code,
                        )
                        if result['game_winner'] is not None:
                            _finish_game(room, session, result['game_winner'])
                            remove_session(room_id)
                            return

                        new_state = session.start_round()
                        socketio.emit('game:new_round', {'state': new_state}, to=room_code)
                        _broadcast_human_hands(session)
                else:
                    return

                socketio.sleep(0.45)
    finally:
        _running_rooms.discard(room_id)
