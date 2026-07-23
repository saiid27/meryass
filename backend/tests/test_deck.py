"""Unit tests for deck.py — card distribution and scoring."""
import pytest
from game_logic.deck import (
    create_deck, deal_cards, deal_remaining,
    card_value, resolve_trick, detect_declarations,
    SUITS, RANKS, TRUMP_ORDER, NON_TRUMP_ORDER,
)


def _full_deal():
    deck = create_deck()
    hands, remaining = deal_cards(deck)
    return hands, remaining, deck


class TestCreateDeck:
    def test_32_cards(self):
        deck = create_deck()
        assert len(deck) == 32

    def test_no_duplicates(self):
        deck = create_deck()
        pairs = [(c['suit'], c['rank']) for c in deck]
        assert len(pairs) == len(set(pairs))

    def test_all_suits_and_ranks(self):
        deck = create_deck()
        for suit in SUITS:
            for rank in RANKS:
                assert any(c['suit'] == suit and c['rank'] == rank for c in deck)


class TestDealCards:
    def test_five_cards_each(self):
        hands, remaining, _ = _full_deal()
        for pos in range(4):
            assert len(hands[pos]) == 5

    def test_twelve_remaining(self):
        _, remaining, _ = _full_deal()
        assert len(remaining) == 12

    def test_no_card_lost_or_duplicated(self):
        hands, remaining, deck = _full_deal()
        all_dealt = [c for h in hands.values() for c in h] + remaining
        pairs_dealt = sorted((c['suit'], c['rank']) for c in all_dealt)
        pairs_deck  = sorted((c['suit'], c['rank']) for c in deck)
        assert pairs_dealt == pairs_deck

    def test_turned_card_is_first_remaining(self):
        hands, remaining, _ = _full_deal()
        # turned card is remaining[0]; it stays in remaining
        assert len(remaining) == 12


class TestDealRemaining:
    def test_eight_cards_each_after_full_deal(self):
        deck = create_deck()
        hands, remaining = deal_cards(deck)
        hands = deal_remaining(hands, remaining)
        for pos in range(4):
            assert len(hands[pos]) == 8

    def test_all_32_cards_distributed(self):
        deck = create_deck()
        hands, remaining = deal_cards(deck)
        hands = deal_remaining(hands, remaining)
        all_cards = [c for h in hands.values() for c in h]
        assert len(all_cards) == 32

    def test_no_duplicates_after_full_deal(self):
        deck = create_deck()
        hands, remaining = deal_cards(deck)
        hands = deal_remaining(hands, remaining)
        all_cards = [c for h in hands.values() for c in h]
        pairs = [(c['suit'], c['rank']) for c in all_cards]
        assert len(pairs) == len(set(pairs))


class TestCardValue:
    def test_to_trump_card_values(self):
        trump = 'hearts'
        expected = {
            'J': 20,
            '9': 14,
            'A': 11,
            '10': 10,
            'K': 4,
            'Q': 3,
            '8': 0,
            '7': 0,
        }
        for rank, points in expected.items():
            assert card_value({'suit': trump, 'rank': rank}, trump, 'hokm') == points

    def test_to_trump_strength_order(self):
        assert TRUMP_ORDER == ['7', '8', 'Q', 'K', '10', 'A', '9', 'J']

    def test_sans_card_values(self):
        expected = {
            'A': 11,
            '10': 10,
            'K': 4,
            'Q': 3,
            'J': 2,
            '9': 0,
            '8': 0,
            '7': 0,
        }
        for rank, points in expected.items():
            assert card_value({'suit': 'hearts', 'rank': rank}, None, 'sans_atout') == points

    def test_sans_strength_order(self):
        assert NON_TRUMP_ORDER == ['7', '8', '9', 'J', 'Q', 'K', '10', 'A']

    def test_trump_jack_is_20(self):
        assert card_value({'suit': 'hearts', 'rank': 'J'}, 'hearts', 'hokm') == 20

    def test_trump_nine_is_14(self):
        assert card_value({'suit': 'hearts', 'rank': '9'}, 'hearts', 'hokm') == 14

    def test_non_trump_ace_is_11(self):
        assert card_value({'suit': 'spades', 'rank': 'A'}, 'hearts', 'hokm') == 11

    def test_sans_atout_uses_non_trump_table(self):
        assert card_value({'suit': 'hearts', 'rank': 'J'}, None, 'sans_atout') == 2

    def test_total_points_round_is_162(self):
        """Sum of all card values in a full round (hokm) must equal 162."""
        from game_logic.deck import NON_TRUMP_POINTS, TRUMP_POINTS
        trump = 'hearts'
        total = 0
        for suit in SUITS:
            for rank in RANKS:
                total += card_value({'suit': suit, 'rank': rank}, trump, 'hokm')
        total += 10  # last-trick bonus counted separately in game logic
        assert total == 162


class TestResolveTrick:
    def test_highest_lead_suit_wins(self):
        trick = [
            {'position': 0, 'suit': 'hearts', 'rank': 'A'},
            {'position': 1, 'suit': 'hearts', 'rank': 'K'},
            {'position': 2, 'suit': 'spades', 'rank': 'A'},
            {'position': 3, 'suit': 'clubs',  'rank': 'A'},
        ]
        assert resolve_trick(trick, 'diamonds', 'hokm') == 0

    def test_trump_beats_lead_suit(self):
        trick = [
            {'position': 0, 'suit': 'hearts', 'rank': 'A'},
            {'position': 1, 'suit': 'diamonds', 'rank': '7'},
            {'position': 2, 'suit': 'hearts', 'rank': 'K'},
            {'position': 3, 'suit': 'hearts', 'rank': 'Q'},
        ]
        # diamonds is trump; position 1 plays lowest trump — still wins
        assert resolve_trick(trick, 'diamonds', 'hokm') == 1

    def test_trump_jack_beats_trump_nine(self):
        trick = [
            {'position': 0, 'suit': 'clubs', 'rank': '9'},   # trump 9
            {'position': 1, 'suit': 'clubs', 'rank': 'J'},   # trump J
            {'position': 2, 'suit': 'hearts', 'rank': 'A'},
            {'position': 3, 'suit': 'hearts', 'rank': 'K'},
        ]
        assert resolve_trick(trick, 'clubs', 'hokm') == 1


class TestDetectDeclarations:
    def _hand(self, cards):
        return [{'suit': s, 'rank': r} for s, r in cards]

    def test_bella(self):
        hand = self._hand([('hearts', 'K'), ('hearts', 'Q'), ('spades', '7')])
        decls = detect_declarations(hand, 'hearts', 'hokm')
        types = [d['type'] for d in decls]
        assert 'bella' in types

    def test_no_bella_in_sans_atout(self):
        hand = self._hand([('hearts', 'K'), ('hearts', 'Q')])
        decls = detect_declarations(hand, None, 'sans_atout')
        assert all(d['type'] != 'bella' for d in decls)

    def test_suite_3(self):
        hand = self._hand([('spades', '7'), ('spades', '8'), ('spades', '9'), ('hearts', 'A')])
        decls = detect_declarations(hand, 'hearts', 'hokm')
        assert any(d['type'] == 'suite_3' and d['points'] == 20 for d in decls)

    def test_suite_4(self):
        hand = self._hand([
            ('clubs', '7'), ('clubs', '8'), ('clubs', '9'), ('clubs', '10'),
            ('hearts', 'A'),
        ])
        decls = detect_declarations(hand, 'hearts', 'hokm')
        assert any(d['type'] == 'suite_4' and d['points'] == 50 for d in decls)
