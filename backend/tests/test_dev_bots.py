"""Integration coverage for development bots in public rooms."""


def _register(client, username, email):
    response = client.post('/api/auth/register', json={
        'username': username,
        'email': email,
        'password': 'Pass1234',
    })
    assert response.status_code == 201
    return response.get_json()['token']


def _auth(token):
    return {'Authorization': f'Bearer {token}'}


def test_public_room_is_filled_with_three_ready_bots(client):
    token = _register(client, 'bot-owner-public', 'bot-owner-public@test.com')
    response = client.post('/api/rooms/', json={
        'name': 'Public bot room',
        'is_private': False,
    }, headers=_auth(token))

    assert response.status_code == 201
    room = response.get_json()['room']
    assert room['player_count'] == 4

    detail = client.get(f"/api/rooms/{room['code']}", headers=_auth(token)).get_json()
    bots = [player for player in detail['players'] if player['user']['is_bot']]
    assert len(bots) == 3
    assert all(bot['is_ready'] for bot in bots)


def test_private_room_has_no_bots(client):
    token = _register(client, 'bot-owner-private', 'bot-owner-private@test.com')
    response = client.post('/api/rooms/', json={
        'name': 'Private room',
        'is_private': True,
    }, headers=_auth(token))

    assert response.status_code == 201
    assert response.get_json()['room']['player_count'] == 1


def test_real_player_replaces_a_bot(client):
    owner_token = _register(client, 'bot-owner-replace', 'bot-owner-replace@test.com')
    room = client.post('/api/rooms/', json={
        'name': 'Replace bot room',
        'is_private': False,
    }, headers=_auth(owner_token)).get_json()['room']

    guest_token = _register(client, 'bot-real-guest', 'bot-real-guest@test.com')
    joined = client.post(
        f"/api/rooms/{room['code']}/join",
        json={'spectator': False},
        headers=_auth(guest_token),
    )
    assert joined.status_code == 200
    assert joined.get_json()['membership']['is_spectator'] is False

    detail = client.get(
        f"/api/rooms/{room['code']}",
        headers=_auth(owner_token),
    ).get_json()
    bots = [player for player in detail['players'] if player['user']['is_bot']]
    humans = [player for player in detail['players'] if not player['user']['is_bot']]
    assert len(bots) == 2
    assert len(humans) == 2
