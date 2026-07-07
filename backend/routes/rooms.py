from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from models.room import Room, RoomPlayer
from dev_bots import auto_fill_public_room, remove_one_bot

rooms_bp = Blueprint('rooms', __name__, url_prefix='/api/rooms')


@rooms_bp.route('/', methods=['GET'])
@jwt_required()
def list_rooms():
    status = request.args.get('status', 'waiting')
    rooms = Room.query.filter_by(status=status, is_private=False)\
                      .order_by(Room.created_at.desc()).limit(50).all()
    added_bots = False
    for room in rooms:
        if auto_fill_public_room(room):
            added_bots = True
    if added_bots:
        db.session.commit()
    return jsonify({'rooms': [r.to_dict() for r in rooms]}), 200


@rooms_bp.route('/', methods=['POST'])
@jwt_required()
def create_room():
    user_id = int(get_jwt_identity())
    data = request.get_json()

    name = data.get('name', '').strip()
    if not name:
        return jsonify({'error': 'Room name is required'}), 400

    game_type = data.get('game_type', 'bilt')
    is_private = data.get('is_private', False)

    room = Room(name=name, game_type=game_type, creator_id=user_id, is_private=is_private)
    db.session.add(room)
    db.session.flush()

    # Creator joins as player at position 0
    member = RoomPlayer(room_id=room.id, user_id=user_id, position=0, team=0)
    db.session.add(member)
    db.session.flush()
    auto_fill_public_room(room)
    db.session.commit()

    return jsonify({'room': room.to_dict()}), 201


@rooms_bp.route('/<string:code>', methods=['GET'])
@jwt_required()
def get_room(code):
    room = Room.query.filter_by(code=code).first_or_404()
    if auto_fill_public_room(room):
        db.session.commit()
    players = [p.to_dict() for p in room.players.all()]
    return jsonify({'room': room.to_dict(), 'players': players}), 200


@rooms_bp.route('/<string:code>/join', methods=['POST'])
@jwt_required()
def join_room(code):
    user_id = int(get_jwt_identity())
    room = Room.query.filter_by(code=code).first_or_404()

    existing = RoomPlayer.query.filter_by(room_id=room.id, user_id=user_id).first()
    if existing:
        return jsonify({'room': room.to_dict(), 'membership': existing.to_dict()}), 200

    as_spectator = request.get_json(silent=True) or {}
    force_spectator = as_spectator.get('spectator', False)

    player_count = room.player_count
    if (not force_spectator and not room.is_private and
            room.status == 'waiting' and player_count >= 4):
        # Development bots are placeholders and yield their seats to people.
        if remove_one_bot(room):
            player_count -= 1

    if not force_spectator and room.status == 'waiting' and player_count < 4:
        # Assign position and team
        taken_positions = {p.position for p in room.players.filter_by(is_spectator=False)}
        position = next(i for i in range(4) if i not in taken_positions)
        team = 0 if position in [0, 2] else 1
        member = RoomPlayer(room_id=room.id, user_id=user_id, position=position, team=team)
    else:
        member = RoomPlayer(room_id=room.id, user_id=user_id, is_spectator=True)

    db.session.add(member)
    db.session.flush()
    auto_fill_public_room(room)
    db.session.commit()
    return jsonify({'room': room.to_dict(), 'membership': member.to_dict()}), 200


@rooms_bp.route('/<string:code>/leave', methods=['POST'])
@jwt_required()
def leave_room(code):
    user_id = int(get_jwt_identity())
    room = Room.query.filter_by(code=code).first_or_404()
    member = RoomPlayer.query.filter_by(room_id=room.id, user_id=user_id).first()
    if member:
        db.session.delete(member)
        db.session.flush()
        auto_fill_public_room(room)
        db.session.commit()
    return jsonify({'message': 'Left room'}), 200
