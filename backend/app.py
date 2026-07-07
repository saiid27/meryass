import os
from flask import Flask, jsonify
from config import Config
from extensions import db, bcrypt, jwt, socketio, cors


def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    bcrypt.init_app(app)
    jwt.init_app(app)
    cors.init_app(app, resources={r"/*": {"origins": app.config['CORS_ORIGINS']}})
    socketio.init_app(
        app,
        cors_allowed_origins=app.config['CORS_ORIGINS'],
        async_mode='eventlet',
        logger=False,
        engineio_logger=False,
    )

    from routes.auth import auth_bp
    from routes.users import users_bp
    from routes.rooms import rooms_bp
    app.register_blueprint(auth_bp)
    app.register_blueprint(users_bp)
    app.register_blueprint(rooms_bp)

    import sockets.room_events  # noqa: F401
    import sockets.game_events  # noqa: F401

    # ── Error handlers ──────────────────────────────────────────────
    @app.errorhandler(400)
    def bad_request(e):
        return jsonify({'error': 'Bad request'}), 400

    @app.errorhandler(401)
    def unauthorized(e):
        return jsonify({'error': 'Unauthorized'}), 401

    @app.errorhandler(403)
    def forbidden(e):
        return jsonify({'error': 'Forbidden'}), 403

    @app.errorhandler(404)
    def not_found(e):
        return jsonify({'error': 'Not found'}), 404

    @app.errorhandler(422)
    def unprocessable(e):
        return jsonify({'error': 'Unprocessable entity'}), 422

    @app.errorhandler(500)
    def internal_error(e):
        db.session.rollback()
        return jsonify({'error': 'Internal server error'}), 500

    with app.app_context():
        db.create_all()

    return app


if __name__ == '__main__':
    app = create_app()
    port = int(os.environ.get('PORT', 5000))
    socketio.run(app, host='0.0.0.0', port=port, debug=app.config['DEBUG'])
