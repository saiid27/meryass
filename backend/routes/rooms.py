from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db, socketio
from models.room import Room, RoomPlayer
from dev_bots import auto_fill_public_room, remove_one_bot

rooms_bp = Blueprint('rooms', __name__, url_prefix='/api/rooms')

VALID_GAME_TYPES = {'bilt', 'torneeka'}
VALID_SCORING_MODES = {'zero', 'twenty_six'}


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
    if game_type not in VALID_GAME_TYPES:
        return jsonify({'error': 'Invalid game type'}), 400

    scoring_mode = data.get('scoring_mode', 'zero')
    if scoring_mode not in VALID_SCORING_MODES:
        return jsonify({'error': 'Invalid scoring mode'}), 400
    if game_type == 'bilt' and scoring_mode != 'zero':
        return jsonify({'error': 'This game option is not available yet'}), 400

    is_private = data.get('is_private', False)

    room = Room(
        name=name,
        game_type=game_type,
        scoring_mode=scoring_mode,
        creator_id=user_id,
        is_private=is_private,
    )
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


@rooms_bp.route('/<string:code>/players/<int:member_id>/bench', methods=['POST'])
@jwt_required()
def bench_player(code, member_id):
    user_id = int(get_jwt_identity())
    room = Room.query.filter_by(code=code).first_or_404()
    if room.creator_id != user_id:
        return jsonify({'error': 'Only the room supervisor can change seats'}), 403
    if room.status != 'waiting':
        return jsonify({'error': 'Seats can only be changed before the game starts'}), 400

    member = RoomPlayer.query.filter_by(room_id=room.id, id=member_id).first_or_404()
    if member.user_id == room.creator_id:
        return jsonify({'error': 'The room supervisor cannot be moved'}), 400

    member.position = None
    member.team = None
    member.is_spectator = True
    member.is_ready = False
    db.session.flush()
    db.session.commit()
    return _room_state_response(room)


@rooms_bp.route('/<string:code>/seats/<int:position>', methods=['POST'])
@jwt_required()
def assign_seat(code, position):
    user_id = int(get_jwt_identity())
    room = Room.query.filter_by(code=code).first_or_404()
    if room.creator_id != user_id:
        return jsonify({'error': 'Only the room supervisor can change seats'}), 403
    if room.status != 'waiting':
        return jsonify({'error': 'Seats can only be changed before the game starts'}), 400
    if position not in range(4):
        return jsonify({'error': 'Invalid position'}), 400

    data = request.get_json(silent=True) or {}
    target_member_id = data.get('member_id')
    if target_member_id is None:
        return jsonify({'error': 'member_id is required'}), 400

    target = RoomPlayer.query.filter_by(room_id=room.id, id=target_member_id).first_or_404()
    occupant = RoomPlayer.query.filter_by(
        room_id=room.id,
        position=position,
        is_spectator=False,
    ).first()

    if occupant and occupant.id != target.id:
        if occupant.user_id == room.creator_id:
            return jsonify({'error': 'The room supervisor seat cannot be replaced'}), 400
        occupant.position = None
        occupant.team = None
        occupant.is_spectator = True
        occupant.is_ready = False

    target.position = position
    target.team = 0 if position in [0, 2] else 1
    target.is_spectator = False
    target.is_ready = False
    db.session.flush()
    db.session.commit()
    return _room_state_response(room)


def _room_state_response(room):
    players = [p.to_dict() for p in room.players.all()]
    payload = {'room': room.to_dict(), 'players': players}
    socketio.emit('room:state', payload, to=room.code)
    return jsonify(payload), 200
