"""
Script d'initialisation : crée la base de données et toutes les tables.
Usage : python init_db.py
"""
from app import create_app
from extensions import db

app = create_app()

with app.app_context():
    db.create_all()
    print("Tables créées avec succès.")
