"""Integration tests for auth routes."""
import json
import pytest


def _register(client, username='tester', email='tester@test.com', password='Pass1234'):
    return client.post('/api/auth/register', json={
        'username': username, 'email': email, 'password': password,
    })


def _login(client, identifier='tester', password='Pass1234'):
    return client.post('/api/auth/login', json={
        'identifier': identifier, 'password': password,
    })


class TestRegister:
    def test_success(self, client):
        r = _register(client, username='usr1', email='usr1@x.com')
        assert r.status_code == 201
        data = r.get_json()
        assert 'token' in data
        assert data['user']['username'] == 'usr1'

    def test_duplicate_username(self, client):
        _register(client, username='dup', email='dup1@x.com')
        r = _register(client, username='dup', email='dup2@x.com')
        assert r.status_code == 409

    def test_duplicate_email(self, client):
        _register(client, username='eml1', email='same@x.com')
        r = _register(client, username='eml2', email='same@x.com')
        assert r.status_code == 409

    def test_short_password(self, client):
        r = _register(client, username='short', email='short@x.com', password='abc')
        assert r.status_code == 400

    def test_missing_fields(self, client):
        r = client.post('/api/auth/register', json={})
        assert r.status_code == 400


class TestLogin:
    def test_login_with_username(self, client):
        _register(client, username='logme', email='logme@x.com')
        r = _login(client, identifier='logme')
        assert r.status_code == 200
        assert 'token' in r.get_json()

    def test_login_with_email(self, client):
        _register(client, username='loge', email='loge@x.com')
        r = _login(client, identifier='loge@x.com')
        assert r.status_code == 200

    def test_wrong_password(self, client):
        _register(client, username='wp', email='wp@x.com')
        r = _login(client, identifier='wp', password='wrongpass')
        assert r.status_code == 401

    def test_unknown_user(self, client):
        r = _login(client, identifier='nobody@x.com')
        assert r.status_code == 401
