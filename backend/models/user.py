from extensions import db, bcrypt
from datetime import datetime
import re
from sqlalchemy import and_, or_


def normalize_phone(value):
    if value is None:
        return ''
    phone = re.sub(r'[\s().-]+', '', str(value).strip())
    if phone.startswith('00'):
        phone = '+' + phone[2:]
    return phone


class User(db.Model):
    __tablename__ = 'users'

    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    phone = db.Column(db.String(30), unique=True, nullable=True)
    password_hash = db.Column(db.String(255), nullable=False)
    avatar = db.Column(db.String(255), default=None)
    wins = db.Column(db.Integer, default=0)
    losses = db.Column(db.Integer, default=0)
    rounds_played = db.Column(db.Integer, default=0)
    total_points = db.Column(db.Integer, default=0)
    is_online = db.Column(db.Boolean, default=False)
    socket_id = db.Column(db.String(100), default=None)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    room_memberships = db.relationship('RoomPlayer', back_populates='user', lazy='dynamic')

    def set_password(self, password):
        self.password_hash = bcrypt.generate_password_hash(password).decode('utf-8')

    def check_password(self, password):
        return bcrypt.check_password_hash(self.password_hash, password)

    @property
    def is_bot(self):
        return self.email.endswith('@devbot.meryas')

    @property
    def rank(self):
        better_players = User.query.filter(
            User.id != self.id,
            or_(
                User.wins > self.wins,
                and_(User.wins == self.wins, User.total_points > self.total_points),
            ),
        ).count()
        return better_players + 1

    def to_dict(self, public=True):
        data = {
            'id': self.id,
            'username': self.username,
            'avatar': self.avatar,
            'phone': self.phone,
            'wins': self.wins,
            'losses': self.losses,
            'rounds_played': self.rounds_played,
            'total_points': self.total_points,
            'rank': self.rank,
            'is_online': self.is_online,
            'is_bot': self.is_bot,
            'created_at': self.created_at.isoformat(),
        }
        if not public:
            data['email'] = self.email
        return data
