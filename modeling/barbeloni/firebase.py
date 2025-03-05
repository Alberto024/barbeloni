import firebase_admin
from firebase_admin import credentials, firestore

from barbeloni.utils import settings, setup_logger

logger = setup_logger(__name__)


def initialize_firestore() -> firestore.Client:
    """Initialize Firestore client with credentials."""
    logger.debug(
        'Initializing Firestore client with credentials: %s',
        settings.google_application_credentials,
    )
    cred = credentials.Certificate(settings.google_application_credentials)
    app = firebase_admin.initialize_app(credential=cred)
    db = firestore.client(app=app)
    logger.info('Firestore client initialized successfully')
    return db


if __name__ == '__main__':
    initialize_firestore()
