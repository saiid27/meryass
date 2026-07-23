"""
In-memory game-state manager for Bilt (Baloot).
One BiltGame instance per active room, stored in game_sessions.

Rules implemented
-----------------
- 32-card deck (7–A × 4 suits), 8 cards per player.
- Phase-1 deal: 3 then 2 cards each (counter-clockwise). remaining[0] shown as
  turned card (preview only — stays in remaining so phase-2 gets exactly 12).
- Bidding: all four players choose pass / to / sans.
  `take <suit>` and `sans_atout` are accepted as legacy aliases.
  Four passes → redeal.
- Phase-2 deal: 3 more cards each after bid accepted (total 8 per player).
- Playing: trick-taking, 8 tricks per round.
  - Players may throw off-suit; MG can challenge a missed lead suit.
  - Trump J and 9 are the two strongest trump cards.
- Declarations (announced once per player per round): Bella (K+Q of trump, 20pts),
  Suite-3 (20pts), Suite-4+ (50pts).
- Scoring uses 26 points for both to and sans rounds.
  Bidding team needs ≥82 raw hokm points or ≥66 raw sans points to win the
  round; failure → other team gets the round score.
  Cot (8/8 tricks) doubles total points. Match won at 100 game-points.
"""

import time
from typing import Optional
from .deck import (
    VALID_SUITS, VALID_RANKS, VALID_ACTIONS,
    create_deck, deal_cards, deal_remaining,
    card_value, resolve_trick, detect_declarations,
)

TURN_DELAY_SECONDS = 5
WIN_THRESHOLD_HOKM      = 82   # out of 162 card-trick points
WIN_THRESHOLD_SANS_ATOUT = 66   # out of 130 card-trick points (no trump J/9 bonus)
MATCH_WIN_SCORE = 100
BID_STRENGTH = {
    'treve': 1,
    'kerew': 2,
    'kere': 3,
    'pik': 4,
    'sans': 5,
    'to': 6,
}
BID_SUITS = {
    'pik': 'spades',
    'kere': 'hearts',
    'kerew': 'diamonds',
    'treve': 'clubs',
}


class BiltGame:
    def __init__(self, room_id, players):
        """
        players: list of {'user_id': int, 'position': int, 'team': int}
        """
        self.room_id = room_id
        self.players = {p['position']: p for p in players}
        self.dealer_position = 0
        self.current_round: Optional[dict] = None
        self.team_scores: dict[int, int] = {0: 0, 1: 0}
        self.last_bid_choices: dict[int, str] = {}
        self.bid_choices_visible_until = 0
        self.state = 'idle'

    # ------------------------------------------------------------------
    # Round lifecycle
    # ------------------------------------------------------------------

    def start_round(self) -> dict:
        deck = create_deck()
        hands, remaining = deal_cards(deck)
        # remaining[0] is shown as the "turned card" during bidding.
        # It is NOT removed — phase-2 deals all 12 remaining cards.
        turned_card = remaining[0]

        self.current_round = {
            'dealer': self.dealer_position,
            'hands': hands,
            'remaining': remaining,          # 12 cards including turned_card
            'turned_card': turned_card,
            'mode': None,                    # 'hokm' | 'sans_atout'
            'trump_suit': None,
            'bidding_player': (self.dealer_position + 1) % 4,
            'bid_choices': {},
            'accepted_bid': None,
            'bidding_team': None,
            'bidding_user_id': None,
            'tricks': [],
            'current_trick': [],
            'mg_target': None,
            'trick_counts': {0: 0, 1: 0},
            'current_turn': None,
            'declared_positions': set(),     # tracks who already declared
            'team_declarations': {0: 0, 1: 0},
            'all_declarations': {},
            'status': 'bidding',
        }
        self.state = 'bidding'
        return self._public_state()

    # ------------------------------------------------------------------
    # Bidding
    # ------------------------------------------------------------------

    def place_bid(self, position: int, action: str, suit: Optional[str] = None) -> dict:
        err = self._validate_bid(position, action, suit)
        if err:
            return {'error': err}

        r = self.current_round
        action = self._normalize_bid_action(action)

        r['bid_choices'][position] = {
            'action': action,
            'suit': suit,
        }
        if action != 'pass' and self._is_higher_bid(action, r['accepted_bid']):
            r['accepted_bid'] = {
                'position': position,
                'action': action,
                'suit': suit,
            }

        if len(r['bid_choices']) < 4:
            r['bidding_player'] = self._next_bidding_player(position)
            return self._public_state()

        self._remember_bid_choices(r['bid_choices'])
        accepted = r['accepted_bid']
        if accepted is None:
            r['status'] = 'redeal_pending'
            r['bidding_player'] = None
            self.state = 'redeal_pending'
            return self._public_state()

        position = accepted['position']
        action = accepted['action']
        suit = accepted.get('suit')

        if action == 'to':
            r['mode'] = 'hokm'
            r['trump_suit'] = suit or r['turned_card']['suit']
        elif action == 'sans':
            r['mode'] = 'sans_atout'
            r['trump_suit'] = None
        else:
            r['mode'] = 'hokm'
            r['trump_suit'] = BID_SUITS[action]

        r['bidding_team'] = self.players[position]['team']
        r['bidding_user_id'] = self.players[position]['user_id']

        # Phase-2 deal — remaining has exactly 12 cards
        r['hands'] = deal_remaining(r['hands'], r['remaining'])

        # Pre-compute declarations for all players
        for pos in self.players:
            r['all_declarations'][pos] = detect_declarations(
                r['hands'][pos], r['trump_suit'], r['mode']
            )

        r['status'] = 'playing'
        r['current_turn'] = (self.dealer_position + 1) % 4
        r['turn_available_at'] = time.time()
        self.state = 'playing'
        return self._public_state()

    def _validate_bid(self, position: int, action: str, suit: Optional[str]) -> Optional[str]:
        r = self.current_round
        if not r or r['status'] != 'bidding':
            return 'Not in bidding phase'
        if position != r['bidding_player']:
            return 'Not your turn to bid'
        if position in r['bid_choices']:
            return 'Bid already submitted'
        if action not in VALID_ACTIONS:
            return f'Invalid action: {action}'
        normalized_action = self._normalize_bid_action(action)
        if (
            normalized_action != 'pass'
            and not self._is_higher_bid(normalized_action, r.get('accepted_bid'))
        ):
            return 'Bid must be higher than the current bid'
        if action == 'take' and suit is None:
            return 'Invalid suit: None'
        if normalized_action == 'to' and suit is not None and suit not in VALID_SUITS:
            return f'Invalid suit: {suit}'
        return None

    def _remember_bid_choices(self, choices: dict) -> None:
        self.last_bid_choices = {
            position: choice['action'] for position, choice in choices.items()
        }
        self.bid_choices_visible_until = time.time() + 60

    def _normalize_bid_action(self, action: str) -> str:
        if action in {'take', 'to'}:
            return 'to'
        if action in {'sans_atout', 'sans', 'san'}:
            return 'sans'
        return action

    def _is_higher_bid(self, action: str, accepted_bid: Optional[dict]) -> bool:
        if accepted_bid is None:
            return action in BID_STRENGTH
        return BID_STRENGTH.get(action, 0) > BID_STRENGTH.get(accepted_bid['action'], 0)

    def _next_bidding_player(self, position: int) -> Optional[int]:
        r = self.current_round
        for offset in range(1, 5):
            candidate = (position + offset) % 4
            if candidate not in r['bid_choices']:
                return candidate
        return None

    def complete_pending_redeal(self) -> Optional[dict]:
        if self.current_round and self.current_round['status'] == 'redeal_pending':
            return self.start_round()
        return None

    # ------------------------------------------------------------------
    # Playing cards
    # ------------------------------------------------------------------

    def play_card(self, position: int, suit: str, rank: str) -> dict:
        err = self._validate_play(position, suit, rank)
        if err:
            return {'error': err}

        r = self.current_round
        hand = r['hands'][position]
        card = next(c for c in hand if c['suit'] == suit and c['rank'] == rank)
        lead_suit = r['current_trick'][0]['suit'] if r['current_trick'] else None
        mg_valid = bool(
            lead_suit
            and suit != lead_suit
            and any(c['suit'] == lead_suit for c in hand)
        )

        hand.remove(card)
        r['current_trick'].append({'position': position, 'suit': suit, 'rank': rank})
        r['mg_target'] = None
        if lead_suit is not None:
            r['mg_target'] = {
                'position': position,
                'team': self.players[position]['team'],
                'suit': suit,
                'rank': rank,
                'lead_suit': lead_suit,
                'valid': mg_valid,
            }

        if len(r['current_trick']) == 4:
            return self._resolve_current_trick()

        r['current_turn'] = (position + 1) % 4
        r['turn_available_at'] = time.time() + TURN_DELAY_SECONDS
        return self._public_state()

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
        hand = r['hands'][position]
        if not any(c['suit'] == suit and c['rank'] == rank for c in hand):
            return 'Card not in hand'
        return None

    def call_mg(self, challenger_position: int) -> dict:
        r = self.current_round
        if not r or r['status'] != 'playing':
            return {'error': 'Not in playing phase'}

        target = r.get('mg_target')
        if not target:
            return {'error': 'No MG target'}
        if challenger_position == target['position']:
            return {'error': 'Cannot call MG on yourself'}

        challenger_team = self.players[challenger_position]['team']
        target_team = target['team']
        winning_team = challenger_team if target['valid'] else target_team
        losing_team = 1 - winning_team
        round_points = self._round_score_total(r['mode'])
        awarded = {winning_team: round_points, losing_team: 0}

        for team, pts in awarded.items():
            self.team_scores[team] += pts

        r['status'] = 'finished'
        r['team_trick_pts'] = self._team_trick_points(r)
        r['team_decl_pts'] = dict(r['team_declarations'])
        r['awarded'] = awarded
        r['cot_team'] = None
        r['mg_result'] = {
            'challenger_position': challenger_position,
            'target_position': target['position'],
            'target_team': target_team,
            'valid': target['valid'],
            'winning_team': winning_team,
        }
        r['mg_target'] = None

        winner = next(
            (team for team, score in self.team_scores.items() if score >= MATCH_WIN_SCORE),
            None
        )

        if winner is not None:
            self.state = 'game_end'
        else:
            self.dealer_position = (self.dealer_position + 1) % 4
            self.state = 'round_end'

        return {
            'state': self._public_state(),
            'round_result': self._serializable_round_result(r),
            'game_winner': winner,
        }

    def _is_legal_play(self, position: int, suit: str) -> bool:
        r = self.current_round
        hand = r['hands'][position]
        trick = r['current_trick']

        if not trick:
            return True  # leading — any card

        lead_suit = trick[0]['suit']
        trump_suit = r['trump_suit']
        mode = r['mode']
        has_lead = any(c['suit'] == lead_suit for c in hand)

        if mode == 'sans_atout':
            return suit == lead_suit if has_lead else True

        # hokm mode
        if suit == lead_suit:
            return True
        if has_lead:
            return False  # must follow suit

        # Can't follow — must play trump if available
        has_trump = any(c['suit'] == trump_suit for c in hand)
        if not has_trump:
            return True
        return suit == trump_suit

    # ------------------------------------------------------------------
    # Declarations
    # ------------------------------------------------------------------

    def reveal_declarations(self, position: int) -> dict:
        r = self.current_round
        if not r:
            return {'error': 'No active round'}
        if r['status'] != 'playing':
            return {'error': 'Declarations only allowed during playing phase'}
        if position in r['declared_positions']:
            return {'error': 'Already declared this round'}

        r['declared_positions'].add(position)
        decls = r['all_declarations'].get(position, [])
        team = self.players[position]['team']
        total = sum(d['points'] for d in decls)
        r['team_declarations'][team] += total
        return {'declarations': decls, 'total': total}

    # ------------------------------------------------------------------
    # Trick resolution
    # ------------------------------------------------------------------

    def _resolve_current_trick(self) -> dict:
        r = self.current_round
        trick_cards = r['current_trick']
        winner_pos = resolve_trick(trick_cards, r['trump_suit'], r['mode'])
        winner_team = self.players[winner_pos]['team']

        points = sum(
            card_value({'suit': c['suit'], 'rank': c['rank']}, r['trump_suit'], r['mode'])
            for c in trick_cards
        )
        trick_number = len(r['tricks']) + 1
        if trick_number == 8:
            points += 10  # last-trick bonus

        r['tricks'].append({
            'number': trick_number,
            'cards': trick_cards[:],
            'winner_position': winner_pos,
            'winner_team': winner_team,
            'points': points,
        })
        r['trick_counts'][winner_team] += 1
        r['current_trick'] = []

        if trick_number == 8:
            return self._finish_round()

        r['current_turn'] = winner_pos
        r['turn_available_at'] = time.time() + TURN_DELAY_SECONDS
        return self._public_state()

    # ------------------------------------------------------------------
    # Round / match scoring
    # ------------------------------------------------------------------

    def _finish_round(self) -> dict:
        r = self.current_round

        # ── Step 1: separate trick-card points from declaration points ──────
        # WIN_THRESHOLD is checked against trick points ONLY.
        team_trick_pts = self._team_trick_points(r)

        team_decl_pts: dict[int, int] = dict(r['team_declarations'])  # {0:…, 1:…}

        bidding_team = r['bidding_team']
        other_team   = 1 - bidding_team

        # ── Step 2: cot detection ────────────────────────────────────────────
        cot_team = None
        if r['trick_counts'][bidding_team] == 8:
            cot_team = bidding_team
        elif r['trick_counts'][other_team] == 8:
            cot_team = other_team

        card_total = sum(team_trick_pts.values())   # 162 in hokm, 130 in sans_atout
        round_total = self._round_score_total(r['mode'])

        # ── Step 3: determine awarded points ────────────────────────────────
        threshold = (WIN_THRESHOLD_SANS_ATOUT
                     if r['mode'] == 'sans_atout'
                     else WIN_THRESHOLD_HOKM)

        if cot_team is not None:
            # Cot doubles the base round. Declarations are tracked separately
            # until their specific conditions are added.
            if cot_team == bidding_team:
                awarded = {
                    bidding_team: round_total * 2,
                    other_team:   0,
                }
            else:
                awarded = {
                    bidding_team: 0,
                    other_team:   round_total * 2,
                }
        elif team_trick_pts[bidding_team] >= threshold:
            # Normal win: split the 26 base points according to raw trick points.
            bidding_points = self._score_units(team_trick_pts[bidding_team], card_total)
            awarded = {
                bidding_team: bidding_points,
                other_team:   round_total - bidding_points,
            }
        else:
            # Bidding team fails: gets 0 (declarations forfeited).
            # Other team gets the full base round score.
            awarded = {
                bidding_team: 0,
                other_team:   round_total,
            }

        for team, pts in awarded.items():
            self.team_scores[team] += pts

        r['status']         = 'finished'
        r['team_trick_pts'] = team_trick_pts
        r['team_decl_pts']  = team_decl_pts
        r['awarded']        = awarded
        r['cot_team']       = cot_team

        winner = next(
            (team for team, score in self.team_scores.items() if score >= MATCH_WIN_SCORE),
            None
        )

        if winner is not None:
            self.state = 'game_end'
        else:
            self.dealer_position = (self.dealer_position + 1) % 4
            self.state = 'round_end'

        return {
            'state': self._public_state(),
            'round_result': self._serializable_round_result(r),
            'game_winner': winner,
        }

    def _serializable_round_result(self, r: dict) -> dict:
        """Return the round result with only JSON-serializable fields."""
        return {
            'dealer':          r['dealer'],
            'mode':            r['mode'],
            'trump_suit':      r['trump_suit'],
            'bidding_team':    r['bidding_team'],
            'trick_counts':    {str(k): v for k, v in r['trick_counts'].items()},
            'team_trick_pts':  {str(k): v for k, v in r['team_trick_pts'].items()},
            'team_decl_pts':   {str(k): v for k, v in r['team_decl_pts'].items()},
            'team_scores':     {str(k): v for k, v in self.team_scores.items()},
            'awarded':         {str(k): v for k, v in r['awarded'].items()},
            'cot_team':        r.get('cot_team'),
            'mg_result':       r.get('mg_result'),
            'status':          r['status'],
        }

    def _score_units(self, raw_points: int, raw_total: int) -> int:
        """Convert raw card points to the 26-point round scale."""
        if raw_total <= 0:
            return 0
        return max(0, min(26, (raw_points * 52 + raw_total) // (2 * raw_total)))

    def _round_score_total(self, mode: str) -> int:
        return 26

    def _team_trick_points(self, r: dict) -> dict[int, int]:
        team_trick_pts: dict[int, int] = {0: 0, 1: 0}
        for trick in r['tricks']:
            team_trick_pts[trick['winner_team']] += trick['points']
        return team_trick_pts

    # ------------------------------------------------------------------
    # Public state (broadcast-safe — no private hand data)
    # ------------------------------------------------------------------

    def _public_state(self) -> dict:
        r = self.current_round
        base: dict = {
            'room_id': self.room_id,
            'state': self.state,
            'team_scores': self.team_scores,
        }
        if not r:
            return base
        base.update({
            'dealer': r['dealer'],
            'mode': r['mode'],
            'trump_suit': r['trump_suit'],
            'bidding_player': r.get('bidding_player'),
            'bid_choices': self._visible_bid_choices(r),
            'bidding_team': r.get('bidding_team'),
            'turned_card': r.get('turned_card'),
            'current_turn': r.get('current_turn'),
            'turn_available_at': r.get('turn_available_at'),
            'current_trick': r.get('current_trick', []),
            'mg_target': self._public_mg_target(r),
            'tricks_played': len(r['tricks']),
            'trick_counts': r.get('trick_counts'),
            'status': r['status'],
            'hand_sizes': {pos: len(h) for pos, h in r['hands'].items()},
        })
        return base

    def _visible_bid_choices(self, r: dict) -> dict[int, str]:
        if r.get('status') == 'bidding':
            return {
                pos: choice['action'] for pos, choice in r.get('bid_choices', {}).items()
            }
        if time.time() <= self.bid_choices_visible_until:
            return self.last_bid_choices
        return {}

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

    def get_hand(self, position: int) -> list:
        if self.current_round:
            return self.current_round['hands'].get(position, [])
        return []


# ---------------------------------------------------------------------------
# Global in-memory session store:  room_id (int) → BiltGame
# ---------------------------------------------------------------------------
game_sessions: dict[int, BiltGame] = {}


def get_session(room_id: int) -> Optional['BiltGame']:
    return game_sessions.get(room_id)


def create_session(room_id: int, players: list) -> BiltGame:
    session = BiltGame(room_id, players)
    game_sessions[room_id] = session
    return session


def remove_session(room_id: int) -> None:
    game_sessions.pop(room_id, None)
