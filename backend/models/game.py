from extensions import db
from datetime import datetime


class Game(db.Model):
    __tablename__ = 'games'

    id = db.Column(db.Integer, primary_key=True)
    room_id = db.Column(db.Integer, db.ForeignKey('rooms.id'), nullable=False)
    game_type = db.Column(db.String(20), default='bilt')
    status = db.Column(db.String(20), default='active')  # active | finished
    team0_score = db.Column(db.Integer, default=0)
    team1_score = db.Column(db.Integer, default=0)
    winner_team = db.Column(db.Integer, default=None)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    finished_at = db.Column(db.DateTime, default=None)

    room = db.relationship('Room', back_populates='games')
    rounds = db.relationship('GameRound', back_populates='game', lazy='dynamic')

    def to_dict(self):
        return {
            'id': self.id,
            'room_id': self.room_id,
            'game_type': self.game_type,
            'status': self.status,
            'team0_score': self.team0_score,
            'team1_score': self.team1_score,
            'winner_team': self.winner_team,
            'created_at': self.created_at.isoformat(),
        }


class GameRound(db.Model):
    __tablename__ = 'game_rounds'

    id = db.Column(db.Integer, primary_key=True)
    game_id = db.Column(db.Integer, db.ForeignKey('games.id'), nullable=False)
    round_number = db.Column(db.Integer, nullable=False)
    mode = db.Column(db.String(20), default=None)     # hokm | sans_atout
    trump_suit = db.Column(db.String(20), default=None)
    bidding_team = db.Column(db.Integer, default=None)
    bidding_player_id = db.Column(db.Integer, db.ForeignKey('users.id'), default=None)
    dealer_position = db.Column(db.Integer, nullable=False)
    team0_round_points = db.Column(db.Integer, default=0)
    team1_round_points = db.Column(db.Integer, default=0)
    team0_declarations = db.Column(db.Integer, default=0)
    team1_declarations = db.Column(db.Integer, default=0)
    cot_team = db.Column(db.Integer, default=None)    # team that won all 8 tricks
    status = db.Column(db.String(20), default='bidding')  # bidding | playing | finished
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    game = db.relationship('Game', back_populates='rounds')
    tricks = db.relationship('GameTrick', back_populates='round', lazy='dynamic')

    def to_dict(self):
        return {
            'id': self.id,
            'game_id': self.game_id,
            'round_number': self.round_number,
            'mode': self.mode,
            'trump_suit': self.trump_suit,
            'bidding_team': self.bidding_team,
            'dealer_position': self.dealer_position,
            'team0_round_points': self.team0_round_points,
            'team1_round_points': self.team1_round_points,
            'team0_declarations': self.team0_declarations,
            'team1_declarations': self.team1_declarations,
            'cot_team': self.cot_team,
            'status': self.status,
        }


class GameTrick(db.Model):
    __tablename__ = 'game_tricks'

    id = db.Column(db.Integer, primary_key=True)
    round_id = db.Column(db.Integer, db.ForeignKey('game_rounds.id'), nullable=False)
    trick_number = db.Column(db.Integer, nullable=False)
    winner_position = db.Column(db.Integer, default=None)
    points = db.Column(db.Integer, default=0)

    round = db.relationship('GameRound', back_populates='tricks')
    cards = db.relationship('GameTrickCard', back_populates='trick', lazy='dynamic')


class GameTrickCard(db.Model):
    __tablename__ = 'game_trick_cards'

    id = db.Column(db.Integer, primary_key=True)
    trick_id = db.Column(db.Integer, db.ForeignKey('game_tricks.id'), nullable=False)
    player_position = db.Column(db.Integer, nullable=False)
    suit = db.Column(db.String(10), nullable=False)
    rank = db.Column(db.String(5), nullable=False)

    trick = db.relationship('GameTrick', back_populates='cards')
