import json
import os
import uuid
import time
import ssl
import socket
import boto3
import redis

# ─── Clients ──────────────────────────────────────────────────────────────────

dynamodb = boto3.resource("dynamodb", region_name="eu-west-1")

PARKING_TABLE = os.environ["PARKING_TABLE"]
REDIS_HOST    = os.environ["REDIS_HOST"]
REDIS_PORT    = int(os.environ.get("REDIS_PORT", 6379))

LOOK_TTL_SECONDS = 1800  # 30 minutes

# ─── Redis connection ──────────────────────────────────────────────────────────

def get_redis():
    ssl_context = ssl.create_default_context()
    ssl_context.check_hostname = False
    ssl_context.verify_mode = ssl.CERT_NONE

    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        ssl=True,
        ssl_context=ssl_context,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_timeout=5,
    )

# ─── Handler ──────────────────────────────────────────────────────────────────

def handler(event, context):
    try:
        args = event.get("arguments", {})

        user_id       = args.get("userId")
        lat           = args.get("lat")
        lng           = args.get("lng")
        radius_meters = args.get("radius_meters", 500)

        # Validate
        if not all([user_id, lat is not None, lng is not None]):
            return {"success": False, "lookId": None, "error": "Missing required fields"}

        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            return {"success": False, "lookId": None, "error": "Invalid coordinates"}

        if not (50 <= radius_meters <= 5000):
            return {"success": False, "lookId": None, "error": "radius_meters must be between 50 and 5000"}

        look_id    = str(uuid.uuid4())
        now        = int(time.time())
        expires_at = now + LOOK_TTL_SECONDS

        # ── DNS check ──
        print(f"[DEBUG] Resolving {REDIS_HOST}")
        ip = socket.gethostbyname(REDIS_HOST)
        print(f"[DEBUG] Resolved to {ip}")

        # ── Write to Redis GEOSEARCH index ──
        r = get_redis()
        redis_key = "aparcar:looking:drivers"
        r.geoadd(redis_key, [lng, lat, user_id])
        r.expire(redis_key, LOOK_TTL_SECONDS)

        # Store per-user metadata for radius lookup
        user_key = f"aparcar:looking:meta:{user_id}"
        r.hset(user_key, mapping={
            "lookId":        look_id,
            "radius_meters": str(radius_meters),
            "lat":           str(lat),
            "lng":           str(lng),
            "registeredAt":  str(now),
        })
        r.expire(user_key, LOOK_TTL_SECONDS)

        # ── Write to DynamoDB ──
        table = dynamodb.Table(PARKING_TABLE)
        table.put_item(Item={
            "signalId":     look_id,
            "userId":       user_id,
            "type":         "LOOKING",
            "lat":          str(lat),
            "lng":          str(lng),
            "radiusMeters": radius_meters,
            "status":       "ACTIVE",
            "createdAt":    str(now),
            "expiresAt":    expires_at,
            "ttl":          expires_at,
        })

        return {
            "success": True,
            "lookId":  look_id,
            "error":   None,
        }

    except Exception as e:
        print(f"[ERROR] look-signal-handler: {e}")
        return {
            "success": False,
            "lookId":  None,
            "error":   str(e),
        }