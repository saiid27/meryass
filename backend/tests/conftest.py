import pytest
from app import create_app
from extensions import db as _db
from config import Config


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    DEBUG = False
    SECRET_KEY = 'test-secret'
    JWT_SECRET_KEY = 'test-jwt-secret'
    SQLALCHEMY_ENGINE_OPTIONS = {}   # disable pool options for SQLite


@pytest.fixture(scope='session')
def app():
    application = create_app(TestConfig)
    with application.app_context():
        _db.create_all()
        yield application
        _db.drop_all()


@pytest.fixture(scope='function')
def client(app):
    return app.test_client()


@pytest.fixture(scope='function')
def db(app):
    with app.app_context():
        yield _db
        _db.session.rollback()
