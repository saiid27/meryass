import random

SUITS = ['hearts', 'diamonds', 'clubs', 'spades']
RANKS = ['7', '8', '9', '10', 'J', 'Q', 'K', 'A']
VALID_SUITS = set(SUITS)
VALID_RANKS = set(RANKS)
VALID_ACTIONS = {'pass', 'take', 'to', 'sans_atout', 'sans'}

NON_TRUMP_POINTS = {'7': 0, '8': 0, '9': 0, '10': 10, 'J': 2, 'Q': 3, 'K': 4, 'A': 11}
TRUMP_POINTS     = {'7': 0, '8': 0, '9': 14, '10': 10, 'J': 20, 'Q': 3, 'K': 4, 'A': 11}

# Strength order (higher index = stronger)
NON_TRUMP_ORDER = ['7', '8', '9', 'J', 'Q', 'K', '10', 'A']
TRUMP_ORDER     = ['7', '8', 'Q', 'K', '10', 'A', '9', 'J']
RANK_ORDER      = ['7', '8', '9', '10', 'J', 'Q', 'K', 'A']


def create_deck():
    """Returns a shuffled 32-card deck."""
    deck = [{'suit': s, 'rank': r} for s in SUITS for r in RANKS]
    random.shuffle(deck)
    assert len(deck) == 32
    return deck


def deal_cards(deck):
    """
    Phase-1 distribution: 3 cards then 2 cards to each player (counter-clockwise).
    Returns hands {position: [5 cards]} and remaining [12 cards].
    The turned card (remaining[0]) stays in remaining — it is a preview only,
    not removed from the deck, so deal_remaining can distribute all 12 correctly.
    """
    assert len(deck) == 32
    hands = {0: [], 1: [], 2: [], 3: []}
    order = [3, 2, 1, 0]  # counter-clockwise
    idx = 0
    # 3 cards each
    for _ in range(3):
        for pos in order:
            hands[pos].append(deck[idx])
            idx += 1
    # 2 cards each
    for _ in range(2):
        for pos in order:
            hands[pos].append(deck[idx])
            idx += 1
    remaining = deck[idx:]   # exactly 12 cards
    assert sum(len(h) for h in hands.values()) == 20
    assert len(remaining) == 12
    return hands, remaining


def deal_remaining(hands, remaining):
    """
    Phase-2 distribution: 3 more cards to each player after bidding.
    remaining must have exactly 12 cards (the 32 - 20 dealt in phase 1).
    Each player ends with 8 cards total.
    """
    assert len(remaining) == 12, f"Expected 12 remaining cards, got {len(remaining)}"
    order = [3, 2, 1, 0]
    idx = 0
    for _ in range(3):
        for pos in order:
            hands[pos].append(remaining[idx])
            idx += 1
    assert sum(len(h) for h in hands.values()) == 32
    return hands


def card_value(card, trump_suit, mode):
    if mode == 'sans_atout':
        return NON_TRUMP_POINTS[card['rank']]
    if card['suit'] == trump_suit:
        return TRUMP_POINTS[card['rank']]
    return NON_TRUMP_POINTS[card['rank']]


def card_strength(card, trump_suit, mode, lead_suit):
    if mode == 'sans_atout':
        base = NON_TRUMP_ORDER.index(card['rank'])
        return base + 100 if card['suit'] == lead_suit else base
    if card['suit'] == trump_suit:
        return TRUMP_ORDER.index(card['rank']) + 200
    if card['suit'] == lead_suit:
        return NON_TRUMP_ORDER.index(card['rank']) + 100
    return NON_TRUMP_ORDER.index(card['rank'])


def resolve_trick(trick_cards, trump_suit, mode):
    """
    trick_cards: list of {'position': int, 'suit': str, 'rank': str}
    Returns the winning position.
    """
    lead_suit = trick_cards[0]['suit']
    best = trick_cards[0]
    best_strength = card_strength(best, trump_suit, mode, lead_suit)
    for card in trick_cards[1:]:
        s = card_strength(card, trump_suit, mode, lead_suit)
        if s > best_strength:
            best = card
            best_strength = s
    return best['position']


def detect_declarations(hand, trump_suit, mode):
    """
    Returns list of declarations in a hand.
    Each: {'type': str, 'points': int}
    """
    declarations = []

    # Bella: K + Q of trump suit (hokm only)
    if mode == 'hokm' and trump_suit:
        has_k = any(c['suit'] == trump_suit and c['rank'] == 'K' for c in hand)
        has_q = any(c['suit'] == trump_suit and c['rank'] == 'Q' for c in hand)
        if has_k and has_q:
            declarations.append({'type': 'bella', 'points': 20})

    # Consecutive-rank runs of 3+ in the same suit
    for suit in SUITS:
        suit_cards = sorted(
            [c for c in hand if c['suit'] == suit],
            key=lambda c: RANK_ORDER.index(c['rank'])
        )
        if len(suit_cards) < 3:
            continue
        run = [suit_cards[0]]
        for i in range(1, len(suit_cards)):
            prev_idx = RANK_ORDER.index(suit_cards[i - 1]['rank'])
            curr_idx = RANK_ORDER.index(suit_cards[i]['rank'])
            if curr_idx == prev_idx + 1:
                run.append(suit_cards[i])
            else:
                if len(run) >= 3:
                    pts = 50 if len(run) >= 4 else 20
                    declarations.append({'type': f'suite_{len(run)}', 'points': pts})
                run = [suit_cards[i]]
        if len(run) >= 3:
            pts = 50 if len(run) >= 4 else 20
            declarations.append({'type': f'suite_{len(run)}', 'points': pts})

    return declarations
