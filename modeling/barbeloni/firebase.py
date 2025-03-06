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


def get_workout_data(db: firestore.Client, user_id: str, workout_id: str) -> list[dict]:
    """Retrieve workout data from Firestore."""
    logger.debug('Retrieving workout data from Firestore: %s', workout_id)
    workout_ref = (
        db.collection('users')
        .document(user_id)
        .collection('workouts')
        .document(workout_id)
    )
    workout_doc = workout_ref.get()

    if not workout_doc.exists:
        logger.error('Workout %s not found', workout_id)
        return None

    workout_data = workout_doc.to_dict()
    workout_data['id'] = workout_doc.id

    sets = []
    sets_refs = workout_ref.collection('sets').stream()

    for set_doc in sets_refs:
        set_data = set_doc.to_dict()
        set_data['id'] = set_doc.id

        reps = []
        reps_refs = set_doc.reference.collection('reps').stream()

        for rep_doc in reps_refs:
            rep_data = rep_doc.to_dict()
            rep_data['id'] = rep_doc.id
            reps.append(rep_data)

        set_data['reps'] = reps
        sets.append(set_data)

    workout_data['sets'] = sets
    return [workout_data]


if __name__ == '__main__':
    db = initialize_firestore()
    workout_data = get_workout_data(
        db, 'rjGc2FYrVSeXNnPvXXd4XqvB0Zf2', 'b25UqZf0kY2y1PAomXbj'
    )
    import rich

    rich.print(workout_data)
