from extensions import db
from datetime import datetime
import random
import string
from sqlalchemy import UniqueConstraint


def generate_room_code():
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))


class Room(db.Model):
    __tablename__ = 'rooms'

    id         = db.Column(db.Integer, primary_key=True)
    code       = db.Column(db.String(10), unique=True, nullable=False, default=generate_room_code)
    name       = db.Column(db.String(100), nullable=False)
    game_type  = db.Column(db.String(20), default='bilt')
    scoring_mode = db.Column(db.String(20), default='zero')
    status     = db.Column(db.String(20), default='waiting')  # waiting|playing|finished
    creator_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    is_private = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    creator = db.relationship('User', foreign_keys=[creator_id])
    players = db.relationship('RoomPlayer', back_populates='room', lazy='dynamic',
                              cascade='all, delete-orphan')
    games   = db.relationship('Game', back_populates='room', lazy='dynamic')

    @property
    def player_count(self):
        return self.players.filter_by(is_spectator=False).count()

    @property
    def spectator_count(self):
        return self.players.filter_by(is_spectator=True).count()

    def to_dict(self):
        return {
            'id': self.id,
            'code': self.code,
            'name': self.name,
            'game_type': self.game_type,
            'scoring_mode': self.scoring_mode,
            'status': self.status,
            'creator': self.creator.to_dict() if self.creator else None,
            'player_count': self.player_count,
            'spectator_count': self.spectator_count,
            'is_private': self.is_private,
            'created_at': self.created_at.isoformat(),
        }


class RoomPlayer(db.Model):
    __tablename__ = 'room_players'
    __table_args__ = (
        # One membership per user per room
        UniqueConstraint('room_id', 'user_id', name='uq_room_user'),
        # One player per position per room (NULL positions = spectators, excluded by partial index)
    )

    id          = db.Column(db.Integer, primary_key=True)
    room_id     = db.Column(db.Integer, db.ForeignKey('rooms.id', ondelete='CASCADE'), nullable=False)
    user_id     = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    position    = db.Column(db.Integer, default=None)  # 0–3, None if spectator
    team        = db.Column(db.Integer, default=None)  # 0 or 1, None if spectator
    is_spectator = db.Column(db.Boolean, default=False, nullable=False)
    is_ready    = db.Column(db.Boolean, default=False, nullable=False)
    joined_at   = db.Column(db.DateTime, default=datetime.utcnow)

    room = db.relationship('Room', back_populates='players')
    user = db.relationship('User', back_populates='room_memberships')

    def to_dict(self):
        return {
            'id': self.id,
            'room_id': self.room_id,
            'user': self.user.to_dict() if self.user else None,
            'position': self.position,
            'team': self.team,
            'is_spectator': self.is_spectator,
            'is_ready': self.is_ready,
        }
