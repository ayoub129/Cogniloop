from sm2_api import router as sm2_router
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import credentials, firestore, initialize_app
from datetime import datetime, timedelta
import os

# Initialize Firebase
if not firestore._apps:
    cred = credentials.Certificate('service_Account_key.json')
    initialize_app(cred)
db = firestore.client()

app = FastAPI()

# Allow CORS for local dev
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post('/review/sm2')
def review_sm2(user_id: str, item_id: str, recall_rating: int):
    # Load review item
    doc_ref = db.collection('reviews').document(item_id)
    doc = doc_ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail='Review item not found')
    data = doc.to_dict()
    easiness = data.get('easinessFactor', 2.5)
    interval = data.get('interval', 1)
    repetitions = data.get('repetitions', 0)
    lesson_id = data.get('lessonId', None)

    # Apply SM2
    new_easiness, new_interval, new_repetitions = sm2(easiness, interval, repetitions, recall_rating)
    next_review = datetime.utcnow() + timedelta(days=new_interval)

    # Update Firestore
    doc_ref.update({
        'easinessFactor': new_easiness,
        'interval': new_interval,
        'repetitions': new_repetitions,
        'lastReviewed': datetime.utcnow(),
        'nextReview': next_review,
        'recallRating': recall_rating
    })

    # Log review session in studySessions
    db.collection('studySessions').add({
        'userId': user_id,
        'lessonId': lesson_id,
        'reviewId': item_id,
        'duration': 0,  # You can update this if you track time spent
        'date': datetime.utcnow(),
        'type': 'review',
        'recallRating': recall_rating
    })

    return {'status': 'success', 'nextReview': next_review.isoformat()}

def sm2(easiness, interval, repetitions, quality):
    if quality < 3:
        repetitions = 0
        interval = 1
    else:
        if repetitions == 0:
            interval = 1
        elif repetitions == 1:
            interval = 6
        else:
            interval = int(round(interval * easiness))
        repetitions += 1
    easiness = easiness + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))
    if easiness < 1.3:
        easiness = 1.3
    return easiness, interval, repetitions

app.include_router(sm2_router) 