import os
import uuid
from typing import Optional
from flask import Blueprint, request, jsonify, current_app, send_from_directory
from flask_jwt_extended import jwt_required, get_jwt_identity
from PIL import Image
from extensions import db
from models.user import User

users_bp = Blueprint('users', __name__, url_prefix='/api/users')

ALLOWED_MIME = {'image/jpeg', 'image/png', 'image/gif', 'image/webp'}
MAX_IMAGE_DIMENSION = 4096


def _verify_image(stream) -> Optional[str]:
    """
    Open the stream with Pillow to confirm it is a real image.
    Returns the detected format (e.g. 'JPEG') or None on failure.
    """
    try:
        img = Image.open(stream)
        img.verify()   # raises if corrupt / not an image
        return img.format
    except Exception:
        return None


@users_bp.route('/<int:user_id>', methods=['GET'])
@jwt_required()
def get_user(user_id):
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404
    return jsonify({'user': user.to_dict()}), 200


@users_bp.route('/profile', methods=['PUT'])
@jwt_required()
def update_profile():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    data = request.get_json(silent=True) or {}

    if 'username' in data:
        new_username = str(data['username']).strip()
        if len(new_username) < 3 or len(new_username) > 50:
            return jsonify({'error': 'Username must be 3–50 characters'}), 400
        existing = User.query.filter_by(username=new_username).first()
        if existing and existing.id != user_id:
            return jsonify({'error': 'Username already taken'}), 409
        user.username = new_username

    db.session.commit()
    return jsonify({'user': user.to_dict(public=False)}), 200


@users_bp.route('/avatar', methods=['POST'])
@jwt_required()
def upload_avatar():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({'error': 'User not found'}), 404

    if 'avatar' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['avatar']
    if not file or not file.filename:
        return jsonify({'error': 'Empty file'}), 400

    # Content-type check
    if file.mimetype not in ALLOWED_MIME:
        return jsonify({'error': 'Invalid file type'}), 400

    # Verify actual image content with Pillow
    fmt = _verify_image(file.stream)
    if not fmt:
        return jsonify({'error': 'File is not a valid image'}), 400

    upload_folder = current_app.config['UPLOAD_FOLDER']
    os.makedirs(upload_folder, exist_ok=True)

    # Delete old avatar if it exists
    if user.avatar:
        old_path = os.path.join(upload_folder, user.avatar)
        if os.path.isfile(old_path):
            os.remove(old_path)

    ext = fmt.lower().replace('jpeg', 'jpg')
    filename = f'avatar_{user_id}_{uuid.uuid4().hex[:8]}.{ext}'

    # Re-open (stream was consumed by verify) and save
    file.stream.seek(0)
    img = Image.open(file.stream)
    # Cap dimensions
    img.thumbnail((MAX_IMAGE_DIMENSION, MAX_IMAGE_DIMENSION))
    img.save(os.path.join(upload_folder, filename))

    user.avatar = filename
    db.session.commit()

    avatar_url = f'/api/users/avatars/{filename}'
    return jsonify({'avatar': filename, 'avatar_url': avatar_url}), 200


@users_bp.route('/avatars/<path:filename>', methods=['GET'])
def serve_avatar(filename):
    return send_from_directory(current_app.config['UPLOAD_FOLDER'], filename)


@users_bp.route('/leaderboard', methods=['GET'])
@jwt_required()
def leaderboard():
    top = User.query.order_by(User.wins.desc(), User.total_points.desc()).limit(50).all()
    return jsonify({'leaderboard': [u.to_dict() for u in top]}), 200
