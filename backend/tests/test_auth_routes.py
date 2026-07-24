"""Integration tests for auth routes."""
import json
import pytest


def _register(client, username='tester', phone='22000001', password='Pass1234'):
    return client.post('/api/auth/register', json={
        'username': username, 'phone': phone, 'password': password,
    })


def _login(client, identifier='22000001', password='Pass1234'):
    return client.post('/api/auth/login', json={
        'identifier': identifier, 'password': password,
    })


class TestRegister:
    def test_success(self, client):
        r = _register(client, username='usr1', phone='22000011')
        assert r.status_code == 201
        data = r.get_json()
        assert 'token' in data
        assert data['user']['username'] == 'usr1'
        assert data['user']['phone'] == '22000011'

    def test_duplicate_username(self, client):
        _register(client, username='dup', phone='22000021')
        r = _register(client, username='dup', phone='22000022')
        assert r.status_code == 409

    def test_duplicate_phone(self, client):
        _register(client, username='phn1', phone='22000031')
        r = _register(client, username='phn2', phone='22000031')
        assert r.status_code == 409

    def test_short_password(self, client):
        r = _register(client, username='short', phone='22000041', password='abc')
        assert r.status_code == 400

    def test_missing_fields(self, client):
        r = client.post('/api/auth/register', json={})
        assert r.status_code == 400


class TestLogin:
    def test_login_with_phone(self, client):
        _register(client, username='logme', phone='22000051')
        r = _login(client, identifier='22000051')
        assert r.status_code == 200
        assert 'token' in r.get_json()

    def test_login_with_username_still_works(self, client):
        _register(client, username='loge', phone='22000061')
        r = _login(client, identifier='loge')
        assert r.status_code == 200

    def test_wrong_password(self, client):
        _register(client, username='wp', phone='22000071')
        r = _login(client, identifier='22000071', password='wrongpass')
        assert r.status_code == 401

    def test_unknown_user(self, client):
        r = _login(client, identifier='22999999')
        assert r.status_code == 401


class TestUserSearch:
    def test_search_by_phone(self, client):
        registered = _register(client, username='finder', phone='22000081')
        token = registered.get_json()['token']
        response = client.get(
            '/api/users/search?phone=22000081',
            headers={'Authorization': f'Bearer {token}'},
        )
        assert response.status_code == 200
        assert response.get_json()['user']['username'] == 'finder'
