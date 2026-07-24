"""Unit tests for Torneeka game logic."""
import pytest

import game_logic.torneeka as torneeka_module
from game_logic.torneeka import TorneekaGame


PLAYERS = [
    {'user_id': 1, 'position': 0, 'team': 0},
    {'user_id': 2, 'position': 1, 'team': 1},
    {'user_id': 3, 'position': 2, 'team': 0},
    {'user_id': 4, 'position': 3, 'team': 1},
]


@pytest.fixture(autouse=True)
def no_turn_delay(monkeypatch):
    monkeypatch.setattr(torneeka_module, 'TURN_DELAY_SECONDS', 0)


def _game() -> TorneekaGame:
    return TorneekaGame(room_id=1, players=PLAYERS)


def test_start_round_deals_five_cards_and_random_turn(monkeypatch):
    monkeypatch.setattr(torneeka_module.random, 'randrange', lambda size: 2)
    g = _game()
    state = g.start_round()

    assert state['game_type'] == 'torneeka'
    assert state['status'] == 'playing'
    assert state['current_turn'] == 2
    assert all(len(g.get_hand(pos)) == 5 for pos in range(4))


def test_same_rank_and_j_can_change_active_suit():
    g = _game()
    g.current_round = {
        'hands': {
            0: [{'suit': 'clubs', 'rank': '7'}, {'suit': 'clubs', 'rank': '8'}],
            1: [{'suit': 'hearts', 'rank': '7'}],
            2: [{'suit': 'spades', 'rank': 'J'}, {'suit': 'spades', 'rank': 'Q'}],
            3: [],
        },
        'draw_pile': [],
        'discard': [],
        'active_suit': None,
        'current_turn': 0,
        'turn_available_at': 0,
        'mg_target': None,
        'pending_draw': None,
        'status': 'playing',
        'winner_position': None,
    }
    g.state = 'playing'

    result = g.play_card(0, 'clubs', '7')
    assert 'error' not in result
    assert g.current_round['active_suit'] == 'clubs'

    result = g.play_card(2, 'spades', 'J')
    assert 'error' not in result
    assert g.current_round['active_suit'] == 'spades'


def test_mg_adds_three_cards_without_ending_match():
    g = _game()
    g.current_round = {
        'hands': {
            0: [{'suit': 'hearts', 'rank': '10'}],
            1: [{'suit': 'spades', 'rank': '8'}, {'suit': 'spades', 'rank': '9'}],
            2: [],
            3: [],
        },
        'draw_pile': [
            {'suit': 'clubs', 'rank': '7'},
            {'suit': 'clubs', 'rank': '8'},
            {'suit': 'clubs', 'rank': '9'},
        ],
        'discard': [{'position': 3, 'suit': 'hearts', 'rank': 'K'}],
        'active_suit': 'hearts',
        'current_turn': 1,
        'turn_available_at': 0,
        'mg_target': None,
        'pending_draw': None,
        'status': 'playing',
        'winner_position': None,
    }
    g.state = 'playing'

    result = g.play_card(1, 'spades', '8')
    assert result['mg_target']['position'] == 1

    result = g.call_mg(0)
    assert 'game_winner' not in result
    assert result['status'] == 'playing'
    assert len(g.get_hand(1)) == 4


def test_seven_and_nine_skip_next_player():
    g = _game()
    g.current_round = {
        'hands': {
            0: [{'suit': 'hearts', 'rank': '7'}, {'suit': 'clubs', 'rank': '8'}],
            1: [{'suit': 'hearts', 'rank': '8'}],
            2: [{'suit': 'hearts', 'rank': '9'}],
            3: [{'suit': 'hearts', 'rank': '10'}],
        },
        'draw_pile': [],
        'discard': [{'position': 3, 'suit': 'hearts', 'rank': 'K'}],
        'active_suit': 'hearts',
        'current_turn': 0,
        'turn_available_at': 0,
        'mg_target': None,
        'pending_draw': None,
        'status': 'playing',
        'winner_position': None,
    }
    g.state = 'playing'

    result = g.play_card(0, 'hearts', '7')
    assert 'error' not in result
    assert result['current_turn'] == 2
