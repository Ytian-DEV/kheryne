from typing import Optional
import httpx
from fastapi import Header, HTTPException, status

from .config import settings


async def verify_user(authorization: Optional[str] = Header(default=None)) -> Optional[dict]:
    """Verifies a Supabase user access token via Supabase Auth when REQUIRE_AUTH=true."""
    if not settings.require_auth and not authorization:
        return None

    if not authorization or not authorization.lower().startswith("bearer "):
        if settings.require_auth:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing Bearer token.",
            )
        return None

    token = authorization.split(" ", 1)[1].strip()
    async with httpx.AsyncClient(timeout=8.0) as client:
        resp = await client.get(
            f"{settings.supabase_url.rstrip('/')}/auth/v1/user",
            headers={
                "apikey": settings.supabase_publishable_key,
                "Authorization": f"Bearer {token}",
            },
        )
    if resp.status_code != 200:
        if settings.require_auth:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid or expired Supabase session token.",
            )
        return None
    return resp.json()
