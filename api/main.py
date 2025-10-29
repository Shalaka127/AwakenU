from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import os
from dotenv import load_dotenv
from datetime import datetime
import re

from api.sentiment_engine import analyze_sentiment
from api.database import get_supabase_client, get_current_user

load_dotenv()

app = FastAPI(title="awakenU Sentiment Analysis API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class SentimentRequest(BaseModel):
    text: str

class SentimentResponse(BaseModel):
    id: str
    text: str
    sentiment_score: float
    sentiment_label: str
    confidence: float
    created_at: str
    metadata: dict

class UserStats(BaseModel):
    total_analyses: int
    api_calls_remaining: int
    subscription_tier: str
    recent_analyses: List[SentimentResponse]

@app.get("/")
def read_root():
    return {"message": "awakenU Sentiment Analysis API", "version": "1.0.0"}

@app.get("/api/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.post("/api/analyze", response_model=SentimentResponse)
async def analyze_text(request: SentimentRequest, user_id: str = Depends(get_current_user)):
    supabase = get_supabase_client()

    user_response = supabase.table("users").select("*").eq("id", user_id).maybeSingle().execute()

    if not user_response.data:
        raise HTTPException(status_code=404, detail="User not found")

    user = user_response.data

    if user["api_calls_remaining"] <= 0:
        raise HTTPException(status_code=403, detail="API call limit reached. Please upgrade your plan.")

    sentiment_result = analyze_sentiment(request.text)

    analysis_data = {
        "user_id": user_id,
        "text_content": request.text,
        "sentiment_score": sentiment_result["score"],
        "sentiment_label": sentiment_result["label"],
        "confidence": sentiment_result["confidence"],
        "metadata": sentiment_result.get("metadata", {})
    }

    analysis_response = supabase.table("sentiment_analyses").insert(analysis_data).execute()

    supabase.table("users").update({
        "api_calls_remaining": user["api_calls_remaining"] - 1
    }).eq("id", user_id).execute()

    result = analysis_response.data[0]

    return SentimentResponse(
        id=result["id"],
        text=result["text_content"],
        sentiment_score=result["sentiment_score"],
        sentiment_label=result["sentiment_label"],
        confidence=result["confidence"],
        created_at=result["created_at"],
        metadata=result["metadata"]
    )

@app.get("/api/analyses", response_model=List[SentimentResponse])
async def get_analyses(limit: int = 20, user_id: str = Depends(get_current_user)):
    supabase = get_supabase_client()

    response = supabase.table("sentiment_analyses") \
        .select("*") \
        .eq("user_id", user_id) \
        .order("created_at", desc=True) \
        .limit(limit) \
        .execute()

    return [
        SentimentResponse(
            id=item["id"],
            text=item["text_content"],
            sentiment_score=item["sentiment_score"],
            sentiment_label=item["sentiment_label"],
            confidence=item["confidence"],
            created_at=item["created_at"],
            metadata=item["metadata"]
        )
        for item in response.data
    ]

@app.get("/api/stats", response_model=UserStats)
async def get_user_stats(user_id: str = Depends(get_current_user)):
    supabase = get_supabase_client()

    user_response = supabase.table("users").select("*").eq("id", user_id).maybeSingle().execute()

    if not user_response.data:
        raise HTTPException(status_code=404, detail="User not found")

    user = user_response.data

    analyses_response = supabase.table("sentiment_analyses") \
        .select("*", count="exact") \
        .eq("user_id", user_id) \
        .order("created_at", desc=True) \
        .limit(5) \
        .execute()

    total_analyses = analyses_response.count or 0

    recent_analyses = [
        SentimentResponse(
            id=item["id"],
            text=item["text_content"],
            sentiment_score=item["sentiment_score"],
            sentiment_label=item["sentiment_label"],
            confidence=item["confidence"],
            created_at=item["created_at"],
            metadata=item["metadata"]
        )
        for item in analyses_response.data
    ]

    return UserStats(
        total_analyses=total_analyses,
        api_calls_remaining=user["api_calls_remaining"],
        subscription_tier=user["subscription_tier"],
        recent_analyses=recent_analyses
    )

@app.delete("/api/analyses/{analysis_id}")
async def delete_analysis(analysis_id: str, user_id: str = Depends(get_current_user)):
    supabase = get_supabase_client()

    response = supabase.table("sentiment_analyses") \
        .delete() \
        .eq("id", analysis_id) \
        .eq("user_id", user_id) \
        .execute()

    return {"message": "Analysis deleted successfully"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
