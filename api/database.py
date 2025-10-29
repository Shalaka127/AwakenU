import os
from supabase import create_client, Client
from fastapi import Header, HTTPException
from typing import Optional, Dict, Any
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

_supabase_client: Optional[Client] = None

def get_supabase_client() -> Client:
    global _supabase_client
    if _supabase_client is None:
        supabase_url = os.getenv("VITE_SUPABASE_URL")
        supabase_key = os.getenv("VITE_SUPABASE_ANON_KEY")

        if not supabase_url or not supabase_key:
            raise Exception("Supabase credentials not found")

        _supabase_client = create_client(supabase_url, supabase_key)

    return _supabase_client

async def get_current_user(authorization: str = Header(None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")

    token = authorization.split(" ")[1]
    supabase = get_supabase_client()

    try:
        user_response = supabase.auth.get_user(token)
        if not user_response or not user_response.user:
            raise HTTPException(status_code=401, detail="Invalid token")

        return user_response.user.id
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

async def get_user_tenant(user_id: str) -> str:
    supabase = get_supabase_client()

    response = supabase.table("tenant_users")\
        .select("tenant_id")\
        .eq("user_id", user_id)\
        .eq("is_active", True)\
        .maybeSingle()\
        .execute()

    if not response.data:
        raise HTTPException(status_code=403, detail="User not associated with any tenant")

    return response.data["tenant_id"]

async def verify_tenant_access(user_id: str, tenant_id: str) -> bool:
    supabase = get_supabase_client()

    response = supabase.table("tenant_users")\
        .select("id")\
        .eq("user_id", user_id)\
        .eq("tenant_id", tenant_id)\
        .eq("is_active", True)\
        .maybeSingle()\
        .execute()

    return response.data is not None

async def log_audit_event(
    tenant_id: str,
    user_id: str,
    action: str,
    metadata: Dict[str, Any],
    resource_type: Optional[str] = None,
    resource_id: Optional[str] = None
):
    supabase = get_supabase_client()

    audit_data = {
        "tenant_id": tenant_id,
        "user_id": user_id,
        "action": action,
        "resource_type": resource_type,
        "resource_id": resource_id,
        "metadata": metadata
    }

    try:
        supabase.table("audit_logs").insert(audit_data).execute()
    except Exception as e:
        print(f"Failed to log audit event: {str(e)}")
