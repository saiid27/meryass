"""Shared helpers for Socket.IO event handlers."""
from typing import Optional
from flask import request
from flask_jwt_extended import decode_token
from flask_socketio import emit
from models.user import User
from models.room import Room, RoomPlayer


def get_user_from_token(token: Optional[str]) -> Optional[User]:
    if not token:
        return None
    try:
        decoded = decode_token(token)
        return User.query.get(int(decoded['sub']))
    except Exception:
        return None


def auth_error(msg: str) -> None:
    emit('error', {'message': msg})


def resolve_context(data: dict, require_player: bool = True):
    """
    Validates token, room membership, and optionally player (non-spectator) status.
    Returns (user, room, member) on success, or emits an error and returns None.

    Parameters
    ----------
    data            : Socket.IO event payload
    require_player  : if True, spectators are rejected
    """
    token = data.get('token')
    room_code = data.get('room_code')

    if not token or not room_code:
        auth_error('Missing token or room_code')
        return None

    user = get_user_from_token(token)
    if not user:
        auth_error('Unauthorized')
        return None

    room = Room.query.filter_by(code=room_code).first()
    if not room:
        auth_error('Room not found')
        return None

    member = RoomPlayer.query.filter_by(room_id=room.id, user_id=user.id).first()
    if not member:
        auth_error('You are not a member of this room')
        return None

    if require_player and member.is_spectator:
        auth_error('Spectators cannot perform this action')
        return None

    # Keep socket_id in sync
    if user.socket_id != request.sid:
        from extensions import db
        user.socket_id = request.sid
        user.is_online = True
        db.session.commit()

    return user, room, member
