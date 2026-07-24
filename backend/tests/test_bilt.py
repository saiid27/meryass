"""Unit tests for BiltGame — bilt.py game logic."""
import time
import pytest
import game_logic.bilt as bilt_module
from game_logic.bilt import BiltGame, MATCH_WIN_SCORE
from sockets.bot_player import _choose_bot_bid


PLAYERS = [
    {'user_id': 1, 'position': 0, 'team': 0},
    {'user_id': 2, 'position': 1, 'team': 1},
    {'user_id': 3, 'position': 2, 'team': 0},
    {'user_id': 4, 'position': 3, 'team': 1},
]


@pytest.fixture(autouse=True)
def no_turn_delay(monkeypatch):
    monkeypatch.setattr(bilt_module, 'TURN_DELAY_SECONDS', 0)


def _new_game() -> BiltGame:
    return BiltGame(room_id=1, players=PLAYERS)


def _started_round() -> BiltGame:
    g = _new_game()
    g.start_round()
    return g


def _bid_accepted(game: BiltGame = None, action='take', suit='hearts') -> BiltGame:
    """Accept a bid so the game moves to playing phase."""
    g = game or _started_round()
    r = g.current_round
    bidder = r['bidding_player']
    result = g.place_bid(bidder, action, suit)
    assert 'error' not in result, result
    while g.current_round['status'] == 'bidding':
        pos = g.current_round['bidding_player']
        result = g.place_bid(pos, 'pass')
        assert 'error' not in result, result
    return g


class TestStartRound:
    def test_each_player_has_5_cards_initially(self):
        g = _started_round()
        r = g.current_round
        for pos in range(4):
            assert len(r['hands'][pos]) == 5

    def test_remaining_has_12_cards(self):
        g = _started_round()
        assert len(g.current_round['remaining']) == 12

    def test_status_is_bidding(self):
        g = _started_round()
        assert g.current_round['status'] == 'bidding'

    def test_first_bidder_is_randomized(self, monkeypatch):
        monkeypatch.setattr(bilt_module.random, 'randrange', lambda size: 2)
        g = _started_round()
        assert g.current_round['bidding_player'] == 2

    def test_turned_card_is_in_remaining(self):
        g = _started_round()
        r = g.current_round
        assert r['turned_card'] == r['remaining'][0]


class TestBidding:
    def test_four_passes_restart_round(self):
        g = _started_round()
        r = g.current_round
        first_bidder = r['bidding_player']
        for i in range(4):
            pos = (first_bidder + i) % 4
            result = g.place_bid(pos, 'pass')
            assert 'error' not in result
        # After 4 passes choices remain visible before the delayed redeal.
        assert g.current_round['status'] == 'redeal_pending'
        assert g._public_state()['bid_choices'] == {
            first_bidder: 'pass',
            (first_bidder + 1) % 4: 'pass',
            (first_bidder + 2) % 4: 'pass',
            (first_bidder + 3) % 4: 'pass',
        }
        g.complete_pending_redeal()
        r2 = g.current_round
        assert r2['status'] == 'bidding'
        for pos in range(4):
            assert len(r2['hands'][pos]) == 5

    def test_player_cannot_bid_twice(self):
        g = _started_round()
        r = g.current_round
        bidder = r['bidding_player']
        result = g.place_bid(bidder, 'pass')
        assert 'error' not in result
        result = g.place_bid(bidder, 'to')
        assert 'error' in result

    def test_invalid_action_returns_error(self):
        g = _started_round()
        r = g.current_round
        result = g.place_bid(r['bidding_player'], 'bluff')
        assert 'error' in result

    def test_take_without_suit_returns_error(self):
        g = _started_round()
        r = g.current_round
        result = g.place_bid(r['bidding_player'], 'take', suit=None)
        assert 'error' in result

    def test_take_moves_to_playing(self):
        g = _bid_accepted()
        assert g.current_round['status'] == 'playing'

    def test_to_uses_turned_card_suit(self):
        g = _started_round()
        r = g.current_round
        turned_suit = r['turned_card']['suit']
        result = g.place_bid(r['bidding_player'], 'to')
        assert 'error' not in result
        while g.current_round['status'] == 'bidding':
            result = g.place_bid(g.current_round['bidding_player'], 'pass')
            assert 'error' not in result
        assert g.current_round['status'] == 'playing'
        assert g.current_round['mode'] == 'hokm'
        assert g.current_round['trump_suit'] == turned_suit

    def test_only_pass_after_to(self):
        g = _started_round()
        r = g.current_round
        result = g.place_bid(r['bidding_player'], 'to')
        assert 'error' not in result
        result = g.place_bid(g.current_round['bidding_player'], 'sans')
        assert result.get('error') == 'Bid must be higher than the current bid'

    def test_kere_can_only_be_overbid_by_higher_options(self):
        g = _started_round()
        result = g.place_bid(g.current_round['bidding_player'], 'kere')
        assert 'error' not in result

        result = g.place_bid(g.current_round['bidding_player'], 'kerew')
        assert result.get('error') == 'Bid must be higher than the current bid'

        result = g.place_bid(g.current_round['bidding_player'], 'pik')
        assert 'error' not in result
        assert g.current_round['accepted_bid']['action'] == 'pik'

    def test_suit_bid_uses_sans_order_and_sets_suit(self):
        g = _started_round()
        result = g.place_bid(g.current_round['bidding_player'], 'treve')
        assert 'error' not in result
        while g.current_round['status'] == 'bidding':
            result = g.place_bid(g.current_round['bidding_player'], 'pass')
            assert 'error' not in result
        assert g.current_round['mode'] == 'sans_atout'
        assert g.current_round['trump_suit'] == 'clubs'

    def test_coins_against_to_bid_and_blocks_more_bids(self):
        g = _started_round()
        bidder = g.current_round['bidding_player']
        result = g.place_bid(bidder, 'to')
        assert 'error' not in result

        result = g.place_bid(g.current_round['bidding_player'], 'coins')
        assert 'error' not in result
        result = g.place_bid(g.current_round['bidding_player'], 'to')
        assert result.get('error') == 'Only pass is available after coins'

    def test_coins_cannot_be_called_by_bidding_team_partner(self):
        g = _started_round()
        bidder = g.current_round['bidding_player']
        result = g.place_bid(bidder, 'kerew')
        assert 'error' not in result

        same_team = (bidder + 2) % 4
        while g.current_round['bidding_player'] != same_team:
            result = g.place_bid(g.current_round['bidding_player'], 'pass')
            assert 'error' not in result
        result = g.place_bid(same_team, 'coins')
        assert result.get('error') == 'Coins must be called by the opposing team'

    def test_coins_requires_an_accepted_bid(self):
        g = _started_round()
        bidder = g.current_round['bidding_player']
        result = g.place_bid(bidder, 'coins')
        assert result.get('error') == 'Coins is only available against an accepted bid'

    def test_coins_against_sans_bid_and_blocks_more_bids(self):
        g = _started_round()
        bidder = g.current_round['bidding_player']
        result = g.place_bid(bidder, 'sans')
        assert 'error' not in result

        result = g.place_bid(g.current_round['bidding_player'], 'coins')
        assert 'error' not in result
        assert g.current_round['coins']['position'] == (bidder + 1) % 4
        result = g.place_bid(g.current_round['bidding_player'], 'to')
        assert result.get('error') == 'Only pass is available after coins'

    @pytest.mark.parametrize('color_bid', ['pik', 'kere', 'kerew', 'treve'])
    def test_coins_allowed_against_every_color_bid(self, color_bid):
        g = _started_round()
        bidder = g.current_round['bidding_player']
        result = g.place_bid(bidder, color_bid)
        assert 'error' not in result

        result = g.place_bid(g.current_round['bidding_player'], 'coins')
        assert 'error' not in result
        assert g.current_round['coins']['position'] == (bidder + 1) % 4

    def test_bid_choices_remain_visible_after_bid(self):
        g = _bid_accepted(action='to', suit=None)
        public_state = g._public_state()
        assert public_state['status'] == 'playing'
        bid_position = g.current_round['accepted_bid']['position']
        assert public_state['bid_choices'][bid_position] == 'to'

    def test_eight_cards_each_after_bid(self):
        g = _bid_accepted()
        r = g.current_round
        for pos in range(4):
            assert len(r['hands'][pos]) == 8

    def test_no_card_lost_after_bid(self):
        g = _bid_accepted()
        r = g.current_round
        all_cards = [c for h in r['hands'].values() for c in h]
        assert len(all_cards) == 32
        pairs = [(c['suit'], c['rank']) for c in all_cards]
        assert len(pairs) == len(set(pairs))

    def test_sans_atout_no_trump(self):
        g = _started_round()
        r = g.current_round
        result = g.place_bid(r['bidding_player'], 'sans_atout')
        assert 'error' not in result
        while g.current_round['status'] == 'bidding':
            result = g.place_bid(g.current_round['bidding_player'], 'pass')
            assert 'error' not in result
        assert g.current_round['trump_suit'] is None
        assert g.current_round['mode'] == 'sans_atout'


class TestDeclarations:
    def test_declare_once_per_round(self):
        g = _bid_accepted()
        r = g.current_round
        pos = list(g.players.keys())[0]
        g.reveal_declarations(pos)
        result = g.reveal_declarations(pos)   # second call
        assert 'error' in result

    def test_declarations_reset_each_round(self):
        g = _bid_accepted()
        pos = list(g.players.keys())[0]
        g.reveal_declarations(pos)
        # Force a new round
        g.start_round()
        _bid_accepted(g)
        # Should be allowed again
        r2 = g.reveal_declarations(pos)
        assert 'error' not in r2

    def test_declare_outside_playing_phase_rejected(self):
        g = _started_round()   # still in bidding
        pos = g.current_round['bidding_player']
        result = g.reveal_declarations(pos)
        assert 'error' in result


class TestPlayCard:
    def test_turn_delay_is_three_seconds(self):
        assert bilt_module.DEFAULT_TURN_DELAY_SECONDS == 3

    def _pick_legal_card(self, hand, trick, trump_suit, mode):
        """Return the first card that is legal to play given trick state."""
        if not trick:
            return hand[0]
        lead_suit = trick[0]['suit']
        has_lead = any(c['suit'] == lead_suit for c in hand)
        if has_lead:
            return next(c for c in hand if c['suit'] == lead_suit)
        if mode != 'sans_atout' and trump_suit:
            has_trump = any(c['suit'] == trump_suit for c in hand)
            if has_trump:
                return next(c for c in hand if c['suit'] == trump_suit)
        return hand[0]

    def _first_trick(self, g: BiltGame):
        """Play through one complete trick with legal cards."""
        r = g.current_round
        starter = r['current_turn']
        for i in range(4):
            pos = (starter + i) % 4
            hand = r['hands'][pos]
            card = self._pick_legal_card(hand, r['current_trick'], r['trump_suit'], r['mode'])
            result = g.play_card(pos, card['suit'], card['rank'])
            if i < 3:
                assert 'error' not in result, f'pos={pos} card={card} error: {result}'
        assert result['status'] == 'trick_pending'
        result = g.complete_pending_trick()
        return result

    def test_wrong_turn_rejected(self):
        g = _bid_accepted()
        r = g.current_round
        wrong = (r['current_turn'] + 1) % 4
        hand = r['hands'][wrong]
        result = g.play_card(wrong, hand[0]['suit'], hand[0]['rank'])
        assert 'error' in result

    def test_card_not_in_hand_rejected(self):
        g = _bid_accepted()
        r = g.current_round
        pos = r['current_turn']
        hand = r['hands'][pos]
        # Find a (suit, rank) pair definitely absent from this hand
        all_cards = {(c['suit'], c['rank']) for c in hand}
        from game_logic.deck import VALID_SUITS, VALID_RANKS
        absent = next(
            (s, rk) for s in VALID_SUITS for rk in VALID_RANKS
            if (s, rk) not in all_cards
        )
        result = g.play_card(pos, absent[0], absent[1])
        assert 'error' in result

    def test_turn_delay_rejects_early_play(self):
        g = _bid_accepted()
        r = g.current_round
        r['turn_available_at'] = time.time() + 5
        pos = r['current_turn']
        card = r['hands'][pos][0]
        result = g.play_card(pos, card['suit'], card['rank'])
        assert result.get('error') == 'Turn is not available yet'

    def test_eight_tricks_finish_round(self):
        g = _bid_accepted()
        for _ in range(8):
            result = self._first_trick(g)
        assert 'game_winner' in result

    def test_trick_counts_sum_to_8(self):
        g = _bid_accepted()
        for _ in range(8):
            result = self._first_trick(g)
        r = g.current_round
        assert sum(r['trick_counts'].values()) == 8


class TestMg:
    def _mg_round(self, target_hand) -> BiltGame:
        g = _new_game()
        g.current_round = {
            'dealer': 0,
            'hands': {
                0: [{'suit': 'hearts', 'rank': 'A'}],
                1: target_hand,
                2: [],
                3: [],
            },
            'remaining': [],
            'turned_card': {'suit': 'clubs', 'rank': '7'},
            'mode': 'hokm',
            'trump_suit': 'clubs',
            'bidding_player': None,
            'bid_choices': {},
            'accepted_bid': {'position': 0, 'action': 'to'},
            'bidding_team': 0,
            'bidding_user_id': 1,
            'tricks': [],
            'current_trick': [{'position': 0, 'suit': 'hearts', 'rank': 'A'}],
            'mg_target': None,
            'trick_counts': {0: 0, 1: 0},
            'current_turn': 1,
            'declared_positions': set(),
            'team_declarations': {0: 0, 1: 0},
            'all_declarations': {},
            'status': 'playing',
        }
        g.state = 'playing'
        return g

    def test_mg_true_awards_challenger_team_round_points(self):
        g = self._mg_round([
            {'suit': 'hearts', 'rank': '7'},
            {'suit': 'spades', 'rank': 'A'},
        ])
        result = g.play_card(1, 'spades', 'A')
        assert 'error' not in result

        public_target = result['mg_target']
        assert public_target['position'] == 1
        assert 'valid' not in public_target

        result = g.call_mg(0)
        assert result['round_result']['mg_result']['valid'] is True
        assert result['round_result']['awarded'] == {'0': 26, '1': 0}
        assert g.team_scores == {0: 26, 1: 0}

    def test_mg_false_awards_target_team_round_points(self):
        g = self._mg_round([
            {'suit': 'spades', 'rank': 'A'},
        ])
        result = g.play_card(1, 'spades', 'A')
        assert 'error' not in result

        result = g.call_mg(0)
        assert result['round_result']['mg_result']['valid'] is False
        assert result['round_result']['awarded'] == {'1': 26, '0': 0}
        assert g.team_scores == {0: 0, 1: 26}

    def test_mg_target_stays_visible_after_fourth_card_before_trick_resolves(self):
        g = self._mg_round([
            {'suit': 'hearts', 'rank': '7'},
            {'suit': 'spades', 'rank': 'A'},
        ])
        g.current_round['hands'][1] = []
        g.current_round['hands'][3] = [
            {'suit': 'hearts', 'rank': '7'},
            {'suit': 'spades', 'rank': 'A'},
        ]
        g.current_round['current_trick'] = [
            {'position': 0, 'suit': 'hearts', 'rank': 'A'},
            {'position': 1, 'suit': 'hearts', 'rank': 'K'},
            {'position': 2, 'suit': 'hearts', 'rank': 'Q'},
        ]
        g.current_round['current_turn'] = 3

        result = g.play_card(3, 'spades', 'A')
        assert 'error' not in result
        assert result['status'] == 'trick_pending'
        assert len(result['current_trick']) == 4
        assert result['mg_target']['position'] == 3

        result = g.call_mg(0)
        assert result['round_result']['mg_result']['valid'] is True
        assert result['round_result']['awarded'] == {'0': 26, '1': 0}


class TestScoring:
    def _finish_fake_round(
        self,
        *,
        mode='hokm',
        bidding_team=0,
        team0_raw=82,
        team1_raw=80,
        team0_decls=0,
        team1_decls=0,
        team0_tricks=4,
        team1_tricks=4,
        initial_scores=None,
        accepted_action=None,
        coins=None,
    ) -> tuple[BiltGame, dict]:
        g = _new_game()
        if initial_scores is not None:
            g.team_scores = dict(initial_scores)
        g.current_round = {
            'dealer': 0,
            'hands': {0: [], 1: [], 2: [], 3: []},
            'remaining': [],
            'turned_card': {'suit': 'hearts', 'rank': 'A'},
            'mode': mode,
            'trump_suit': 'hearts' if mode == 'hokm' else None,
            'bidding_player': None,
            'bid_choices': {},
            'accepted_bid': {
                'position': 0,
                'action': accepted_action or ('to' if mode == 'hokm' else 'sans'),
            },
            'coins': coins,
            'bidding_team': bidding_team,
            'bidding_user_id': 1,
            'tricks': [
                {'winner_team': 0, 'points': team0_raw},
                {'winner_team': 1, 'points': team1_raw},
            ],
            'current_trick': [],
            'trick_counts': {0: team0_tricks, 1: team1_tricks},
            'current_turn': None,
            'declared_positions': set(),
            'team_declarations': {0: team0_decls, 1: team1_decls},
            'all_declarations': {},
            'status': 'playing',
        }
        result = g._finish_round()
        return g, result

    def test_to_scores_use_26_point_scale(self):
        g, result = self._finish_fake_round(mode='hokm', team0_raw=82, team1_raw=80)
        assert result['round_result']['awarded'] == {'0': 13, '1': 13}
        assert g.team_scores == {0: 13, 1: 13}
        assert result['game_winner'] is None

    def test_failed_to_gives_other_team_26_not_raw_162(self):
        g, result = self._finish_fake_round(mode='hokm', team0_raw=81, team1_raw=81)
        assert result['round_result']['awarded'] == {'0': 0, '1': 26}
        assert g.team_scores == {0: 0, 1: 26}
        assert result['game_winner'] is None

    def test_sans_scores_use_26_point_scale(self):
        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=66,
            team1_raw=64,
        )
        assert result['round_result']['awarded'] == {'0': 13, '1': 13}
        assert g.team_scores == {0: 13, 1: 13}
        assert result['game_winner'] is None

    def test_suit_bid_scores_use_16_point_scale(self):
        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=66,
            team1_raw=64,
            accepted_action='kerew',
        )
        assert result['round_result']['awarded'] == {'0': 8, '1': 8}
        assert g.team_scores == {0: 8, 1: 8}

    def test_failed_suit_bid_gives_other_team_16(self):
        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=65,
            team1_raw=65,
            accepted_action='kerew',
        )
        assert result['round_result']['awarded'] == {'0': 0, '1': 16}
        assert g.team_scores == {0: 0, 1: 16}

    def test_coins_awards_32_to_bidder_or_challenger_and_8_each_on_tie(self):
        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=70,
            team1_raw=60,
            accepted_action='kerew',
            coins={'position': 1, 'team': 1},
        )
        assert result['round_result']['awarded'] == {'0': 32, '1': 0}
        assert g.team_scores == {0: 32, 1: 0}

        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=60,
            team1_raw=70,
            accepted_action='kerew',
            coins={'position': 1, 'team': 1},
        )
        assert result['round_result']['awarded'] == {'0': 0, '1': 32}
        assert g.team_scores == {0: 0, 1: 32}

        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=65,
            team1_raw=65,
            accepted_action='kerew',
            coins={'position': 1, 'team': 1},
        )
        assert result['round_result']['awarded'] == {'0': 8, '1': 8}
        assert g.team_scores == {0: 8, 1: 8}

    def test_coins_awards_32_against_to_bid(self):
        g, result = self._finish_fake_round(
            mode='hokm',
            team0_raw=90,
            team1_raw=72,
            accepted_action='to',
            coins={'position': 1, 'team': 1},
        )
        assert result['round_result']['awarded'] == {'0': 32, '1': 0}
        assert g.team_scores == {0: 32, 1: 0}

        g, result = self._finish_fake_round(
            mode='hokm',
            team0_raw=72,
            team1_raw=90,
            accepted_action='to',
            coins={'position': 1, 'team': 1},
        )
        assert result['round_result']['awarded'] == {'0': 0, '1': 32}
        assert g.team_scores == {0: 0, 1: 32}

    def test_coins_awards_32_against_sans_bid(self):
        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=80,
            team1_raw=50,
            accepted_action='sans',
            coins={'position': 1, 'team': 1},
        )
        assert result['round_result']['awarded'] == {'0': 32, '1': 0}
        assert g.team_scores == {0: 32, 1: 0}

        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=50,
            team1_raw=80,
            accepted_action='sans',
            coins={'position': 1, 'team': 1},
        )
        assert result['round_result']['awarded'] == {'0': 0, '1': 32}
        assert g.team_scores == {0: 0, 1: 32}

    def test_declarations_are_tracked_but_not_added_to_base_score_yet(self):
        g, result = self._finish_fake_round(
            mode='hokm',
            team0_raw=82,
            team1_raw=80,
            team0_decls=50,
            team1_decls=20,
        )
        assert result['round_result']['team_decl_pts'] == {'0': 50, '1': 20}
        assert result['round_result']['awarded'] == {'0': 13, '1': 13}
        assert g.team_scores == {0: 13, 1: 13}

    def test_failed_sans_gives_other_team_26_not_raw_130(self):
        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=65,
            team1_raw=65,
        )
        assert result['round_result']['awarded'] == {'0': 0, '1': 26}
        assert g.team_scores == {0: 0, 1: 26}
        assert result['game_winner'] is None

    def test_match_is_won_at_100_points(self):
        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=66,
            team1_raw=64,
            initial_scores={0: 86, 1: 0},
        )
        assert g.team_scores[0] == 99
        assert result['game_winner'] is None

        g, result = self._finish_fake_round(
            mode='sans_atout',
            team0_raw=66,
            team1_raw=64,
            initial_scores={0: 99, 1: 0},
        )
        assert g.team_scores[0] == 112
        assert result['game_winner'] == 0

    def _simulate_full_game(self) -> tuple[BiltGame, dict]:
        """Run a complete match (one round, then check winner)."""
        g = _new_game()
        last_result = None
        for _ in range(200):   # safety cap
            g.start_round()
            _bid_accepted(g)
            for _ in range(8):
                r = g.current_round
                starter = r['current_turn']
                for i in range(4):
                    pos = (starter + i) % 4
                    hand = r['hands'][pos]
                    lead_suit = r['current_trick'][0]['suit'] if r['current_trick'] else None
                    card = next(
                        (c for c in hand if lead_suit and c['suit'] == lead_suit),
                        hand[0],
                    )
                    last_result = g.play_card(pos, card['suit'], card['rank'])
                if last_result and last_result.get('status') == 'trick_pending':
                    last_result = g.complete_pending_trick()
            if last_result and last_result.get('game_winner') is not None:
                break
            if g.state == 'game_end':
                break
        return g, last_result

    def test_winner_reaches_match_win_score(self):
        g, result = self._simulate_full_game()
        if result and result.get('game_winner') is not None:
            winner = result['game_winner']
            assert g.team_scores[winner] >= MATCH_WIN_SCORE


class TestBotCoins:
    _strong_hand = [
        {'suit': 'hearts', 'rank': 'A'},
        {'suit': 'diamonds', 'rank': 'A'},
        {'suit': 'clubs', 'rank': 'A'},
        {'suit': 'spades', 'rank': 'A'},
    ]

    def _game_with_accepted_bid(self, action='to', suit='hearts') -> BiltGame:
        g = _new_game()
        g.current_round = {
            'accepted_bid': {'position': 0, 'action': action, 'suit': suit},
            'coins': None,
            'bid_choices': {0: {'action': action, 'suit': suit}},
            'hands': {1: list(self._strong_hand), 3: list(self._strong_hand)},
            'turned_card': {'suit': suit, 'rank': 'K'},
        }
        return g

    def test_bot_calls_coins_against_opposing_teams_bid(self):
        g = self._game_with_accepted_bid(action='to')
        assert _choose_bot_bid(g, 1) == 'coins'

    def test_bot_calls_coins_against_every_bid_type(self):
        for action, suit in [
            ('sans', None), ('pik', None), ('kere', None),
            ('kerew', None), ('treve', None),
        ]:
            g = self._game_with_accepted_bid(action=action, suit=suit)
            assert _choose_bot_bid(g, 1) == 'coins'

    def test_bot_never_calls_coins_on_its_own_teams_bid(self):
        g = self._game_with_accepted_bid(action='to')
        # Position 3 is on the bidding team's opposing side... but position 2
        # shares team 0 with the bidder (position 0).
        g.current_round['hands'][2] = list(self._strong_hand)
        assert _choose_bot_bid(g, 2) != 'coins'

    def test_bot_only_passes_once_coins_already_called(self):
        g = self._game_with_accepted_bid(action='to')
        g.current_round['coins'] = {'position': 1, 'team': 1}
        assert _choose_bot_bid(g, 3) == 'pass'
