import json
import os
import uuid
import time
import boto3
import redis
import socket

# ─── Clients ──────────────────────────────────────────────────────────────────

dynamodb = boto3.resource("dynamodb", region_name="eu-west-1")


PARKING_TABLE = os.environ["PARKING_TABLE"]
REDIS_HOST = os.environ["REDIS_HOST"]
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))

LOOK_TTL_SECONDS = 1800  # 30 minutes

# ─── Redis connection ──────────────────────────────────────────────────────────

import ssl

def get_redis():
    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        ssl=True,
        ssl_cert_reqs=ssl.CERT_NONE,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_timeout=5,
    )

# ─── Handler ──────────────────────────────────────────────────────────────────

def handler(event, context):
    try:
        print(f"[DEBUG] Testing TCP to {REDIS_HOST}:{REDIS_PORT}")
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((REDIS_HOST, REDIS_PORT))
        sock.close()
        print(f"[DEBUG] TCP connect result: {result}")  # 0 = success, non-zero = error code
        return {"success": False, "lookId": None, "error": f"TCP test: {result}"}
    except Exception as e:
        print(f"[ERROR] {e}")
        return {"success": False, "lookId": None, "error": str(e)}