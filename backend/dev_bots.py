"""Development-only players used to fill and exercise public rooms."""
import secrets

from flask import current_app

from extensions import db
from models.room import RoomPlayer
from models.user import User


def bots_enabled() -> bool:
    return bool(current_app.config.get('AUTO_FILL_PUBLIC_ROOMS', False))


def is_bot_user(user: User) -> bool:
    return bool(user and user.is_bot)


def remove_one_bot(room) -> bool:
    """Free one bot seat so a real player can enter a full public room."""
    for member in room.players.filter_by(is_spectator=False).all():
        if is_bot_user(member.user):
            db.session.delete(member)
            db.session.flush()
            return True
    return False


def auto_fill_public_room(room) -> list[RoomPlayer]:
    """Fill every vacant player position in a waiting public room with bots."""
    if not bots_enabled() or room.is_private or room.status != 'waiting':
        return []

    members = room.players.filter_by(is_spectator=False).all()
    occupied = {member.position for member in members}
    created = []

    for position in range(4):
        if position in occupied:
            continue

        email = f'room-{room.id}-bot-{position}@devbot.meryas'
        bot = User.query.filter_by(email=email).first()
        if bot is None:
            bot = User(
                username=f'DevBot {position + 1} · {room.code}',
                email=email,
                is_online=True,
            )
            bot.set_password(secrets.token_urlsafe(32))
            db.session.add(bot)
            db.session.flush()

        membership = RoomPlayer(
            room_id=room.id,
            user_id=bot.id,
            position=position,
            team=position % 2,
            is_ready=True,
        )
        db.session.add(membership)
        created.append(membership)

    db.session.flush()
    return created
