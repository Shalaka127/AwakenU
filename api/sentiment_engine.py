import re
from typing import Dict

positive_words = {
    'good', 'great', 'excellent', 'amazing', 'wonderful', 'fantastic', 'awesome',
    'love', 'best', 'perfect', 'happy', 'joy', 'beautiful', 'brilliant', 'outstanding',
    'superb', 'delightful', 'pleased', 'excited', 'fabulous', 'incredible', 'marvelous',
    'thank', 'thanks', 'appreciate', 'helpful', 'satisfied', 'pleased', 'resolved'
}

negative_words = {
    'bad', 'terrible', 'awful', 'horrible', 'poor', 'worst', 'hate', 'disappointed',
    'disappointing', 'sad', 'angry', 'frustrating', 'annoying', 'pathetic', 'useless',
    'waste', 'disgusting', 'dreadful', 'miserable', 'appalling', 'inferior', 'unacceptable',
    'broken', 'failed', 'error', 'problem', 'issue', 'complaint', 'unhappy'
}

urgency_keywords = {
    'urgent', 'immediately', 'asap', 'emergency', 'critical', 'important', 'priority',
    'now', 'quickly', 'soon', 'deadline', 'time-sensitive', 'right away', 'outage',
    'down', 'not working', 'broken', 'security', 'breach', 'hack', 'unauthorized',
    'charge', 'refund', 'billing', 'payment', 'cancel'
}

intensifiers = {'very', 'extremely', 'really', 'absolutely', 'totally', 'incredibly', 'highly'}
negations = {'not', 'no', "n't", 'never', 'neither', 'nobody', 'nothing', 'nowhere'}

def preprocess_text(text: str) -> list:
    text = text.lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    words = text.split()
    return words

def classify_sentiment(text: str) -> Dict:
    if not text or len(text.strip()) == 0:
        return {
            "score": 0.0,
            "label": "neutral",
            "confidence": 0.5,
            "metadata": {"word_count": 0, "positive_words": 0, "negative_words": 0}
        }

    words = preprocess_text(text)

    positive_count = 0
    negative_count = 0
    intensity_multiplier = 1.0
    negate = False

    for i, word in enumerate(words):
        if word in intensifiers:
            intensity_multiplier = 1.5
            continue

        if word in negations:
            negate = True
            continue

        if word in positive_words:
            score = 1.0 * intensity_multiplier
            if negate:
                score = -score
                negative_count += 1
            else:
                positive_count += 1
        elif word in negative_words:
            score = -1.0 * intensity_multiplier
            if negate:
                score = -score
                positive_count += 1
            else:
                negative_count += 1

        intensity_multiplier = 1.0
        negate = False

    total_sentiment_words = positive_count + negative_count

    if total_sentiment_words == 0:
        sentiment_score = 0.0
        label = "neutral"
        confidence = 0.5
    else:
        sentiment_score = (positive_count - negative_count) / total_sentiment_words

        if sentiment_score > 0.3:
            label = "positive"
            confidence = min(0.95, 0.6 + (sentiment_score * 0.3))
        elif sentiment_score < -0.3:
            label = "negative"
            confidence = min(0.95, 0.6 + (abs(sentiment_score) * 0.3))
        else:
            label = "neutral"
            confidence = 0.5 + (0.3 * (1 - abs(sentiment_score)))

    sentiment_score = max(-1.0, min(1.0, sentiment_score))

    return {
        "score": round(sentiment_score, 3),
        "label": label,
        "confidence": round(confidence, 3),
        "metadata": {
            "word_count": len(words),
            "positive_words": positive_count,
            "negative_words": negative_count,
            "sentiment_words_ratio": round(total_sentiment_words / len(words), 3) if len(words) > 0 else 0
        }
    }

def detect_urgency(text: str, metadata: Dict = None) -> Dict:
    words = preprocess_text(text)

    urgency_count = sum(1 for word in words if word in urgency_keywords)
    has_exclamation = '!' in text
    has_caps = sum(1 for c in text if c.isupper()) / len(text) > 0.3 if len(text) > 0 else False

    urgency_score = urgency_count / len(words) if len(words) > 0 else 0

    if has_exclamation:
        urgency_score += 0.1
    if has_caps:
        urgency_score += 0.15

    if urgency_score > 0.15:
        label = "high"
        score = min(0.95, 0.7 + urgency_score)
    elif urgency_score > 0.05:
        label = "medium"
        score = 0.5 + urgency_score
    else:
        label = "low"
        score = 0.3

    return {
        "label": label,
        "score": round(score, 3)
    }

def classify_intent(text: str) -> Dict:
    words = preprocess_text(text)

    complaint_keywords = {'complaint', 'issue', 'problem', 'broken', 'not working', 'error', 'bug'}
    praise_keywords = {'thank', 'thanks', 'great', 'excellent', 'love', 'appreciate'}
    question_keywords = {'how', 'what', 'when', 'where', 'why', 'can', 'could', 'would', '?'}
    request_keywords = {'please', 'need', 'want', 'request', 'can you', 'could you'}

    complaint_score = sum(1 for word in words if word in complaint_keywords)
    praise_score = sum(1 for word in words if word in praise_keywords)
    question_score = sum(1 for word in words if word in question_keywords) + (1 if '?' in text else 0)
    request_score = sum(1 for word in words if word in request_keywords)

    scores = {
        'complaint': complaint_score,
        'praise': praise_score,
        'question': question_score,
        'request': request_score
    }

    if max(scores.values()) == 0:
        return {"label": "general", "score": 0.5}

    intent = max(scores, key=scores.get)
    confidence = min(0.9, 0.5 + (scores[intent] / len(words)))

    return {
        "label": intent,
        "score": round(confidence, 3)
    }

def calculate_priority(sentiment_score: float, urgency: str, sentiment: str) -> int:
    priority = 50

    if urgency == "high":
        priority += 40
    elif urgency == "medium":
        priority += 20

    if sentiment == "negative":
        priority += 20
    elif sentiment == "positive":
        priority -= 10

    return min(100, max(0, priority))

def analyze_sentiment(text: str) -> Dict:
    return classify_sentiment(text)
