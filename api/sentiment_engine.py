import re
from typing import Dict

positive_words = {
    'good', 'great', 'excellent', 'amazing', 'wonderful', 'fantastic', 'awesome',
    'love', 'best', 'perfect', 'happy', 'joy', 'beautiful', 'brilliant', 'outstanding',
    'superb', 'delightful', 'pleased', 'excited', 'fabulous', 'incredible', 'marvelous'
}

negative_words = {
    'bad', 'terrible', 'awful', 'horrible', 'poor', 'worst', 'hate', 'disappointed',
    'disappointing', 'sad', 'angry', 'frustrating', 'annoying', 'pathetic', 'useless',
    'waste', 'disgusting', 'dreadful', 'miserable', 'appalling', 'inferior', 'unacceptable'
}

intensifiers = {'very', 'extremely', 'really', 'absolutely', 'totally', 'incredibly', 'highly'}
negations = {'not', 'no', "n't", 'never', 'neither', 'nobody', 'nothing', 'nowhere'}

def preprocess_text(text: str) -> list:
    text = text.lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    words = text.split()
    return words

def analyze_sentiment(text: str) -> Dict:
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
