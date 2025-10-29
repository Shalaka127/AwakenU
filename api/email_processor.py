from typing import Dict, Any
import html2text
import re
from datetime import datetime
from api.sentiment_engine import classify_sentiment, detect_urgency, classify_intent, calculate_priority
from api.database import get_supabase_client

def normalize_email(raw_email: Dict[str, Any]) -> Dict[str, Any]:
    h = html2text.HTML2Text()
    h.ignore_links = False

    body_text = raw_email.get("text", "")
    body_html = raw_email.get("html", "")

    if not body_text and body_html:
        body_text = h.handle(body_html)

    body_text = body_text.strip()

    sender_email = raw_email.get("from", "")
    sender_name = None
    if "<" in sender_email:
        match = re.match(r'(.*?)<(.+?)>', sender_email)
        if match:
            sender_name = match.group(1).strip()
            sender_email = match.group(2).strip()

    return {
        "subject": raw_email.get("subject", "(No Subject)"),
        "body_text": body_text,
        "body_html": body_html,
        "sender_email": sender_email,
        "sender_name": sender_name,
        "recipient_email": raw_email.get("to", ""),
        "to_addresses": [raw_email.get("to", "")],
        "cc_addresses": [],
        "metadata": {
            "headers": raw_email.get("headers", {}),
            "attachments_count": raw_email.get("attachments", 0)
        }
    }

async def process_inbound_email(email_data: Dict[str, Any], provider: str):
    try:
        canonical = normalize_email(email_data)

        text_for_analysis = f"{canonical['subject']} {canonical['body_text']}"

        sentiment_result = classify_sentiment(text_for_analysis)
        urgency_result = detect_urgency(text_for_analysis)
        intent_result = classify_intent(text_for_analysis)
        priority = calculate_priority(
            sentiment_result["score"],
            urgency_result["label"],
            sentiment_result["label"]
        )

        supabase = get_supabase_client()

        integration = supabase.table("email_integrations")\
            .select("id, tenant_id")\
            .eq("provider", provider)\
            .eq("is_active", True)\
            .maybeSingle()\
            .execute()

        if not integration.data:
            print(f"No active integration found for provider: {provider}")
            return

        feedback_data = {
            "tenant_id": integration.data["tenant_id"],
            "integration_id": integration.data["id"],
            "source": "email",
            "channel": "email",
            "subject": canonical["subject"],
            "body_text": canonical["body_text"],
            "body_html": canonical["body_html"],
            "sender_email": canonical["sender_email"],
            "sender_name": canonical["sender_name"],
            "recipient_email": canonical["recipient_email"],
            "to_addresses": canonical["to_addresses"],
            "cc_addresses": canonical["cc_addresses"],
            "sentiment": sentiment_result["label"],
            "sentiment_score": sentiment_result["score"],
            "urgency": urgency_result["label"],
            "urgency_score": urgency_result["score"],
            "intent": intent_result["label"],
            "priority": priority,
            "status": "open",
            "is_satisfied": False,
            "metadata": canonical["metadata"],
            "processed_at": datetime.utcnow().isoformat()
        }

        result = supabase.table("feedback_items").insert(feedback_data).execute()

        if urgency_result["label"] == "high" and sentiment_result["label"] == "negative":
            supabase.table("alerts").insert({
                "tenant_id": integration.data["tenant_id"],
                "feedback_id": result.data[0]["id"],
                "alert_type": "high_priority",
                "severity": "high",
                "message": f"High priority feedback from {canonical['sender_email']}"
            }).execute()

        print(f"Processed email: {canonical['subject']} - Sentiment: {sentiment_result['label']}, Urgency: {urgency_result['label']}")

    except Exception as e:
        print(f"Error processing email: {str(e)}")
        raise
