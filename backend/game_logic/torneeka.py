"""In-memory game-state manager for Torneeka."""
import random
import time
from typing import Optional

from .deck import VALID_RANKS, VALID_SUITS, create_deck

TURN_DELAY_SECONDS = 1


class TorneekaGame:
    def __init__(self, room_id, players):
        self.room_id = room_id
        self.players = {p['position']: p for p in players}
        self.current_round: Optional[dict] = None
        self.team_scores: dict[int, int] = {0: 0, 1: 0}
        self.state = 'idle'

    def start_round(self) -> dict:
        deck = create_deck()
        hands = {position: [] for position in self.players}
        for _ in range(5):
            for position in sorted(self.players):
                hands[position].append(deck.pop())

        self.current_round = {
            'hands': hands,
            'draw_pile': deck,
            'discard': [],
            'active_suit': None,
            'current_turn': random.randrange(4),
            'turn_available_at': time.time(),
            'mg_target': None,
            'pending_draw': None,
            'status': 'playing',
            'winner_position': None,
        }
        self.state = 'playing'
        return self._public_state()

    def play_card(self, position: int, suit: str, rank: str) -> dict:
        err = self._validate_play(position, suit, rank)
        if err:
            return {'error': err}

        r = self.current_round
        hand = r['hands'][position]
        card = next(c for c in hand if c['suit'] == suit and c['rank'] == rank)
        top_card = r['discard'][-1] if r['discard'] else None
        active_suit = r.get('active_suit')
        legal_change = self._matches_table(card)
        mg_valid = bool(active_suit and card['suit'] != active_suit and not legal_change)

        pending = r.get('pending_draw')
        if pending and pending['position'] == position:
            if rank == 'A':
                r['pending_draw'] = {
                    'position': self._next_position(position),
                    'amount': pending['amount'] + 3,
                }
            else:
                self._draw_cards(position, pending['amount'])
                r['pending_draw'] = None
        elif rank == 'A':
            r['pending_draw'] = {
                'position': self._next_position(position),
                'amount': 3,
            }

        hand.remove(card)
        r['discard'].append({'position': position, 'suit': suit, 'rank': rank})
        r['active_suit'] = suit
        r['mg_target'] = None
        if mg_valid:
            r['mg_target'] = {
                'position': position,
                'team': self.players[position]['team'],
                'suit': suit,
                'rank': rank,
                'lead_suit': active_suit,
                'valid': True,
            }

        if not hand:
            r['status'] = 'finished'
            r['winner_position'] = position
            self.state = 'game_end'
            winner_team = self.players[position]['team']
            self.team_scores[winner_team] = 1
            return {
                'state': self._public_state(),
                'round_result': self._round_result(winner_team),
                'game_winner': winner_team,
            }

        skip = rank in {'7', '9'}
        r['current_turn'] = self._next_position(position, 2 if skip else 1)
        r['turn_available_at'] = time.time() + TURN_DELAY_SECONDS
        return self._public_state()

    def call_mg(self, challenger_position: int) -> dict:
        r = self.current_round
        if not r or r['status'] != 'playing':
            return {'error': 'Not in playing phase'}
        target = r.get('mg_target')
        if not target:
            return {'error': 'No MG target'}
        if challenger_position == target['position']:
            return {'error': 'Cannot call MG on yourself'}

        punished_position = target['position'] if target['valid'] else challenger_position
        self._draw_cards(punished_position, 3)
        r['mg_target'] = None
        return self._public_state()

    def get_hand(self, position: int) -> list:
        if self.current_round:
            return self.current_round['hands'].get(position, [])
        return []

    def _validate_play(self, position: int, suit: str, rank: str) -> Optional[str]:
        r = self.current_round
        if not r or r['status'] != 'playing':
            return 'Not in playing phase'
        if r['current_turn'] != position:
            return 'Not your turn'
        if time.time() < r.get('turn_available_at', 0):
            return 'Turn is not available yet'
        if suit not in VALID_SUITS:
            return f'Invalid suit: {suit}'
        if rank not in VALID_RANKS:
            return f'Invalid rank: {rank}'
        if not any(c['suit'] == suit and c['rank'] == rank for c in r['hands'][position]):
            return 'Card not in hand'
        return None

    def _is_legal_play(self, position: int, suit: str) -> bool:
        r = self.current_round
        if not r or not r['discard'] or not r.get('active_suit'):
            return True
        return suit == r['active_suit']

    def _matches_table(self, card: dict) -> bool:
        r = self.current_round
        if not r['discard']:
            return True
        top_card = r['discard'][-1]
        return (
            card['suit'] == r.get('active_suit')
            or card['rank'] == top_card['rank']
            or card['rank'] == 'J'
        )

    def _draw_cards(self, position: int, count: int) -> None:
        r = self.current_round
        for _ in range(count):
            if not r['draw_pile']:
                return
            r['hands'][position].append(r['draw_pile'].pop())

    def _next_position(self, position: int, step: int = 1) -> int:
        return (position + step) % 4

    def _round_result(self, winner_team: int) -> dict:
        return {
            'mode': 'torneeka',
            'bidding_team': winner_team,
            'team_scores': {str(k): v for k, v in self.team_scores.items()},
            'awarded': {str(winner_team): 1, str(1 - winner_team): 0},
            'winner_position': self.current_round.get('winner_position'),
            'status': 'finished',
        }

    def _public_state(self) -> dict:
        r = self.current_round
        base = {
            'room_id': self.room_id,
            'game_type': 'torneeka',
            'state': self.state,
            'team_scores': self.team_scores,
        }
        if not r:
            return base
        base.update({
            'mode': 'torneeka',
            'trump_suit': r.get('active_suit'),
            'current_turn': r.get('current_turn'),
            'turn_available_at': r.get('turn_available_at'),
            'current_trick': r['discard'][-1:] if r['discard'] else [],
            'mg_target': self._public_mg_target(r),
            'tricks_played': len(r['discard']),
            'trick_counts': {0: 0, 1: 0},
            'status': r['status'],
            'hand_sizes': {pos: len(h) for pos, h in r['hands'].items()},
        })
        return base

    def _public_mg_target(self, r: dict) -> Optional[dict]:
        target = r.get('mg_target')
        if not target:
            return None
        return {
            'position': target['position'],
            'team': target['team'],
            'suit': target['suit'],
            'rank': target['rank'],
            'lead_suit': target['lead_suit'],
        }


game_sessions: dict[int, TorneekaGame] = {}


def get_session(room_id: int) -> Optional[TorneekaGame]:
    return game_sessions.get(room_id)


def create_session(room_id: int, players: list) -> TorneekaGame:
    session = TorneekaGame(room_id, players)
    game_sessions[room_id] = session
    return session


def remove_session(room_id: int) -> None:
    game_sessions.pop(room_id, None)
