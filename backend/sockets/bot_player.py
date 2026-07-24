"""Small bot loop for development rooms."""
import random
import time
from typing import Optional

from flask import current_app

from extensions import db, socketio
from game_logic.bilt import BID_STRENGTH, BID_SUITS, get_session, remove_session
from game_logic.deck import NON_TRUMP_POINTS, TRUMP_POINTS, card_value
from models.game import Game
from models.room import Room, RoomPlayer
from models.user import User
from dev_bots import is_bot_user


_running_rooms = set()


def _bid_team(session, bid: Optional[dict]):
    if not bid:
        return None
    return session.players[bid['position']]['team']


def _available_regular_bids(accepted_bid: Optional[dict]) -> list[str]:
    current_strength = BID_STRENGTH.get(accepted_bid['action'], 0) if accepted_bid else 0
    return [
        action
        for action, strength in BID_STRENGTH.items()
        if strength > current_strength
    ]


def _hand_sans_points(hand: list[dict]) -> int:
    return sum(NON_TRUMP_POINTS[card['rank']] for card in hand)


def _hand_to_points(hand: list[dict], trump_suit: Optional[str]) -> int:
    return sum(
        TRUMP_POINTS[card['rank']]
        if trump_suit and card['suit'] == trump_suit
        else NON_TRUMP_POINTS[card['rank']]
        for card in hand
    )


def _suit_bid_score(hand: list[dict], suit: str) -> int:
    suited = [card for card in hand if card['suit'] == suit]
    return len(suited) * 4 + sum(NON_TRUMP_POINTS[card['rank']] for card in suited)


def _best_suit_bid(hand: list[dict]) -> tuple[str, int]:
    action, suit = max(
        BID_SUITS.items(),
        key=lambda item: _suit_bid_score(hand, item[1]),
    )
    return action, _suit_bid_score(hand, suit)


def _is_last_chance_without_bid(current_round: dict) -> bool:
    return current_round.get('accepted_bid') is None and len(current_round['bid_choices']) >= 3


def _choose_bot_bid(session, position: int) -> str:
    current_round = session.current_round
    accepted_bid = current_round.get('accepted_bid')
    if current_round.get('coins') is not None:
        return 'pass'

    hand = session.get_hand(position)
    bot_team = session.players[position]['team']
    bid_team = _bid_team(session, accepted_bid)

    if (
        accepted_bid
        and bot_team != bid_team
        and (_hand_sans_points(hand) >= 28 or random.random() < 0.18)
    ):
        return 'coins'

    available = _available_regular_bids(accepted_bid)
    if not available:
        return 'pass'

    if accepted_bid and bot_team == bid_team and random.random() < 0.85:
        return 'pass'

    candidates: list[tuple[str, int]] = []
    turned_suit = current_round['turned_card']['suit']
    to_points = _hand_to_points(hand, turned_suit)
    sans_points = _hand_sans_points(hand)
    best_suit_action, best_suit_points = _best_suit_bid(hand)

    if 'to' in available and to_points >= 35:
        candidates.append(('to', to_points + 10))
    if 'sans' in available and sans_points >= 27:
        candidates.append(('sans', sans_points + 6))
    if best_suit_action in available and best_suit_points >= 18:
        candidates.append((best_suit_action, best_suit_points))

    if not candidates and accepted_bid is None:
        if _is_last_chance_without_bid(current_round):
            candidates.append((best_suit_action, best_suit_points))
        elif best_suit_action in available and random.random() < 0.25:
            candidates.append((best_suit_action, best_suit_points))
        elif 'sans' in available and random.random() < 0.10:
            candidates.append(('sans', sans_points))

    if not candidates:
        return 'pass'

    candidates = [candidate for candidate in candidates if candidate[0] in available]
    if not candidates:
        return 'pass'
    candidates.sort(key=lambda item: (BID_STRENGTH[item[0]], item[1]), reverse=True)
    return candidates[0][0]


def _choose_bot_card(session, position: int) -> Optional[dict]:
    hand = list(session.get_hand(position))
    legal_cards = [
        card for card in hand
        if session._is_legal_play(position, card['suit'])
    ]
    choices = legal_cards or hand
    if not choices:
        return None

    current_round = session.current_round
    if not current_round['current_trick']:
        return max(
            choices,
            key=lambda card: card_value(
                card,
                current_round.get('trump_suit'),
                current_round.get('mode'),
            ),
        )

    return min(
        choices,
        key=lambda card: card_value(
            card,
            current_round.get('trump_suit'),
            current_round.get('mode'),
        ),
    )


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


def _record_round_played(room) -> None:
    members = RoomPlayer.query.filter_by(
        room_id=room.id,
        is_spectator=False,
    ).all()
    for member in members:
        user = member.user
        if user and not is_bot_user(user):
            user.rounds_played = (user.rounds_played or 0) + 1
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

                elif current_round['status'] == 'trick_pending':
                    wait_for = current_round.get('turn_available_at', 0) - time.time()
                    if wait_for > 0:
                        socketio.sleep(wait_for)
                    result = session.complete_pending_trick()
                    if result is None:
                        continue

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
                        _record_round_played(room)
                        if result['game_winner'] is not None:
                            _finish_game(room, session, result['game_winner'])
                            remove_session(room_id)
                            return

                        new_state = session.start_round()
                        socketio.emit('game:new_round', {'state': new_state}, to=room_code)
                        _broadcast_human_hands(session)

                elif current_round['status'] == 'bidding':
                    position = current_round.get('bidding_player')
                    if position is None or not _bot_at(room_id, position):
                        return

                    action = _choose_bot_bid(session, position)
                    result = session.place_bid(position, action)
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

                    card = _choose_bot_card(session, position)
                    if card is None:
                        return
                    result = session.play_card(position, card['suit'], card['rank'])
                    if 'error' in result:
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
                        _record_round_played(room)
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
