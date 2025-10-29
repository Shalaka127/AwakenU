from fastapi import FastAPI, HTTPException, Depends, Header, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
import os
from dotenv import load_dotenv
from datetime import datetime, timedelta
import json
from uuid import UUID

from api.sentiment_engine import (
    classify_sentiment,
    detect_urgency,
    classify_intent,
    calculate_priority
)
from api.email_processor import process_inbound_email, normalize_email
from api.database import (
    get_supabase_client,
    get_current_user,
    get_user_tenant,
    verify_tenant_access,
    log_audit_event
)

load_dotenv()

app = FastAPI(
    title="Customer Support Analytics API",
    description="Multi-tenant SaaS for email support analytics",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class FeedbackFilter(BaseModel):
    sentiment: Optional[str] = None
    urgency: Optional[str] = None
    status: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    search: Optional[str] = None

class MarkSatisfiedRequest(BaseModel):
    auto_reply: bool = False
    template_id: Optional[str] = None
    note: Optional[str] = None

class CreateCommentRequest(BaseModel):
    comment: str
    is_internal: bool = True

class EmailIntegrationRequest(BaseModel):
    name: str
    provider: str
    settings: Dict[str, Any]

class CreateExportRequest(BaseModel):
    format: str
    filters: Optional[Dict[str, Any]] = None

@app.get("/")
def read_root():
    return {
        "message": "Customer Support Analytics API",
        "version": "1.0.0",
        "status": "operational"
    }

@app.get("/api/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.post("/webhook/sendgrid")
async def sendgrid_webhook(request: Request, background_tasks: BackgroundTasks):
    try:
        form_data = await request.form()
        email_data = {
            "from": form_data.get("from"),
            "to": form_data.get("to"),
            "subject": form_data.get("subject"),
            "text": form_data.get("text"),
            "html": form_data.get("html"),
            "headers": form_data.get("headers"),
            "attachments": form_data.get("attachments", 0)
        }

        background_tasks.add_task(process_inbound_email, email_data, "sendgrid")

        return {"status": "accepted", "message": "Email queued for processing"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/feedback")
async def get_feedback(
    sentiment: Optional[str] = None,
    urgency: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    query = supabase.table("feedback_items").select("*").eq("tenant_id", tenant_id)

    if sentiment:
        query = query.eq("sentiment", sentiment)
    if urgency:
        query = query.eq("urgency", urgency)
    if status:
        query = query.eq("status", status)

    response = query.order("created_at", desc=True).range(offset, offset + limit - 1).execute()

    return {"data": response.data, "count": len(response.data)}

@app.get("/api/feedback/{feedback_id}")
async def get_feedback_detail(
    feedback_id: str,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    response = supabase.table("feedback_items")\
        .select("*, feedback_comments(*)")\
        .eq("id", feedback_id)\
        .eq("tenant_id", tenant_id)\
        .maybeSingle()\
        .execute()

    if not response.data:
        raise HTTPException(status_code=404, detail="Feedback not found")

    return response.data

@app.post("/api/feedback/{feedback_id}/satisfy")
async def mark_satisfied(
    feedback_id: str,
    request: MarkSatisfiedRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    feedback = supabase.table("feedback_items")\
        .select("*")\
        .eq("id", feedback_id)\
        .eq("tenant_id", tenant_id)\
        .maybeSingle()\
        .execute()

    if not feedback.data:
        raise HTTPException(status_code=404, detail="Feedback not found")

    update_data = {
        "is_satisfied": True,
        "satisfied_at": datetime.utcnow().isoformat(),
        "satisfied_by": user_id,
        "status": "closed"
    }

    supabase.table("feedback_items").update(update_data).eq("id", feedback_id).execute()

    if request.note:
        supabase.table("feedback_comments").insert({
            "feedback_id": feedback_id,
            "user_id": user_id,
            "comment": request.note,
            "is_internal": True
        }).execute()

    await log_audit_event(tenant_id, user_id, "feedback.satisfied", {"feedback_id": feedback_id})

    if request.auto_reply and request.template_id:
        background_tasks.add_task(send_auto_reply, feedback_id, request.template_id, tenant_id)

    return {"success": True, "message": "Feedback marked as satisfied"}

@app.post("/api/feedback/{feedback_id}/comment")
async def add_comment(
    feedback_id: str,
    request: CreateCommentRequest,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    feedback = supabase.table("feedback_items")\
        .select("id")\
        .eq("id", feedback_id)\
        .eq("tenant_id", tenant_id)\
        .maybeSingle()\
        .execute()

    if not feedback.data:
        raise HTTPException(status_code=404, detail="Feedback not found")

    comment_data = {
        "feedback_id": feedback_id,
        "user_id": user_id,
        "comment": request.comment,
        "is_internal": request.is_internal
    }

    response = supabase.table("feedback_comments").insert(comment_data).execute()

    await log_audit_event(tenant_id, user_id, "feedback.comment", {"feedback_id": feedback_id})

    return response.data[0]

@app.get("/api/analytics/summary")
async def get_analytics_summary(
    days: int = 30,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    start_date = (datetime.utcnow() - timedelta(days=days)).isoformat()

    feedback = supabase.table("feedback_items")\
        .select("sentiment, urgency, status, is_satisfied, created_at")\
        .eq("tenant_id", tenant_id)\
        .gte("created_at", start_date)\
        .execute()

    data = feedback.data

    total = len(data)
    positive = len([f for f in data if f.get("sentiment") == "positive"])
    negative = len([f for f in data if f.get("sentiment") == "negative"])
    neutral = len([f for f in data if f.get("sentiment") == "neutral"])

    high_urgency = len([f for f in data if f.get("urgency") == "high"])
    satisfied = len([f for f in data if f.get("is_satisfied")])

    return {
        "total_feedback": total,
        "sentiment_distribution": {
            "positive": positive,
            "negative": negative,
            "neutral": neutral
        },
        "urgency_distribution": {
            "high": high_urgency,
            "medium": len([f for f in data if f.get("urgency") == "medium"]),
            "low": len([f for f in data if f.get("urgency") == "low"])
        },
        "satisfaction_rate": (satisfied / total * 100) if total > 0 else 0,
        "open_items": len([f for f in data if f.get("status") == "open"])
    }

@app.get("/api/analytics/trends")
async def get_analytics_trends(
    days: int = 30,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    start_date = (datetime.utcnow() - timedelta(days=days)).isoformat()

    feedback = supabase.table("feedback_items")\
        .select("created_at, sentiment")\
        .eq("tenant_id", tenant_id)\
        .gte("created_at", start_date)\
        .order("created_at")\
        .execute()

    daily_data = {}
    for item in feedback.data:
        date = item["created_at"][:10]
        if date not in daily_data:
            daily_data[date] = {"positive": 0, "negative": 0, "neutral": 0, "total": 0}

        sentiment = item.get("sentiment", "neutral")
        daily_data[date][sentiment] += 1
        daily_data[date]["total"] += 1

    return {"trends": daily_data}

@app.get("/api/integrations")
async def get_integrations(user_id: str = Depends(get_current_user)):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    response = supabase.table("email_integrations")\
        .select("id, name, provider, is_active, last_sync, created_at")\
        .eq("tenant_id", tenant_id)\
        .execute()

    return {"integrations": response.data}

@app.post("/api/integrations")
async def create_integration(
    request: EmailIntegrationRequest,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    integration_data = {
        "tenant_id": tenant_id,
        "name": request.name,
        "provider": request.provider,
        "settings": request.settings,
        "is_active": True
    }

    response = supabase.table("email_integrations").insert(integration_data).execute()

    await log_audit_event(tenant_id, user_id, "integration.created", {
        "integration_id": response.data[0]["id"],
        "provider": request.provider
    })

    return response.data[0]

@app.post("/api/exports")
async def create_export(
    request: CreateExportRequest,
    background_tasks: BackgroundTasks,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    export_data = {
        "tenant_id": tenant_id,
        "created_by": user_id,
        "format": request.format,
        "parameters": request.filters or {},
        "status": "pending"
    }

    response = supabase.table("exports").insert(export_data).execute()
    export_id = response.data[0]["id"]

    background_tasks.add_task(generate_export, export_id, tenant_id)

    return {"export_id": export_id, "status": "pending"}

@app.get("/api/exports/{export_id}")
async def get_export(
    export_id: str,
    user_id: str = Depends(get_current_user)
):
    supabase = get_supabase_client()
    tenant_id = await get_user_tenant(user_id)

    response = supabase.table("exports")\
        .select("*")\
        .eq("id", export_id)\
        .eq("tenant_id", tenant_id)\
        .maybeSingle()\
        .execute()

    if not response.data:
        raise HTTPException(status_code=404, detail="Export not found")

    return response.data

async def send_auto_reply(feedback_id: str, template_id: str, tenant_id: str):
    print(f"Sending auto-reply for feedback {feedback_id} using template {template_id}")

async def generate_export(export_id: str, tenant_id: str):
    print(f"Generating export {export_id} for tenant {tenant_id}")
    supabase = get_supabase_client()

    try:
        feedback = supabase.table("feedback_items")\
            .select("*")\
            .eq("tenant_id", tenant_id)\
            .execute()

        supabase.table("exports").update({
            "status": "completed",
            "row_count": len(feedback.data),
            "completed_at": datetime.utcnow().isoformat()
        }).eq("id", export_id).execute()
    except Exception as e:
        supabase.table("exports").update({
            "status": "failed",
            "error_message": str(e)
        }).eq("id", export_id).execute()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
