import os
import sys
from datetime import timedelta
from typing import Optional
from dotenv import load_dotenv

load_dotenv()

_ENV = os.environ.get('FLASK_ENV', 'development')
_IS_PROD = _ENV == 'production'


def _require(key: str, default: Optional[str] = None) -> str:
    val = os.environ.get(key, default)
    if _IS_PROD and (val is None or 'change-in-prod' in val):
        print(f'[FATAL] Environment variable {key} is not set for production.', file=sys.stderr)
        sys.exit(1)
    return val or ''


class Config:
    FLASK_ENV = _ENV
    DEBUG = not _IS_PROD

    SECRET_KEY     = _require('SECRET_KEY',     'meryas-secret-change-in-prod')
    JWT_SECRET_KEY = _require('JWT_SECRET_KEY', 'meryas-jwt-secret-change-in-prod')

    _db_url = os.environ.get(
        'DATABASE_URL',
        'postgresql://meryas_user:meryas_pass@localhost:5432/meryas_db'
    )
    SQLALCHEMY_DATABASE_URI     = _db_url.replace('postgres://', 'postgresql://', 1)
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS   = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
        'pool_size': 10,
        'max_overflow': 20,
    }

    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=7)

    UPLOAD_FOLDER       = os.path.join(os.path.dirname(__file__), 'uploads', 'avatars')
    MAX_CONTENT_LENGTH  = 5 * 1024 * 1024  # 5 MB

    # CORS: restrict in production
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*' if not _IS_PROD else '')

    # Development helpers: public rooms are filled with playable bots.
    AUTO_FILL_PUBLIC_ROOMS = (
        not _IS_PROD
        and os.environ.get('AUTO_FILL_PUBLIC_ROOMS', 'true').lower()
        in {'1', 'true', 'yes', 'on'}
    )
