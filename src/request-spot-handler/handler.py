import os
import uuid
import time
import json
import boto3

EXCHANGES_TABLE = os.environ["EXCHANGES_TABLE"]
SIGNALS_TABLE   = os.environ["SIGNALS_TABLE"]
USERS_TABLE     = os.environ["USERS_TABLE"]
DYNAMODB_ENDPOINT = os.environ.get("DYNAMODB_ENDPOINT", "")
CA_BUNDLE = os.path.join(os.path.dirname(__file__), "AmazonRootCA1.pem")

ARRIVAL_WINDOW_SECONDS = 600  # 10 minutes


def get_ddb():
    return boto3.resource(
        "dynamodb",
        region_name="eu-west-1",
        endpoint_url=DYNAMODB_ENDPOINT if DYNAMODB_ENDPOINT else None,
        verify=CA_BUNDLE if DYNAMODB_ENDPOINT else True,
    )


def handler(event, context):
    try:
        args      = event.get("arguments", {})
        signal_id = args.get("signalId")
        driver2_id = args.get("userId")

        if not all([signal_id, driver2_id]):
            return {"success": False, "exchangeId": None, "error": "Missing required fields"}

        ddb = get_ddb()

        # ── Check signal exists and is ACTIVE ──
        signals = ddb.Table(SIGNALS_TABLE)
        signal = signals.get_item(Key={"signalId": signal_id}).get("Item")

        if not signal:
            return {"success": False, "exchangeId": None, "error": "Signal not found"}

        if signal.get("status") != "ACTIVE":
            return {"success": False, "exchangeId": None, "error": "Spot no longer available"}

        driver1_id = signal.get("userId")

        if driver1_id == driver2_id:
            return {"success": False, "exchangeId": None, "error": "Cannot request your own spot"}

        # ── Create exchange record ──
        exchange_id = str(uuid.uuid4())
        now         = int(time.time())
        expires_at  = now + ARRIVAL_WINDOW_SECONDS

        exchanges = ddb.Table(EXCHANGES_TABLE)
        exchanges.put_item(Item={
            "exchangeId":   exchange_id,
            "signalId":     signal_id,
            "driver1Id":    driver1_id,
            "driver2Id":    driver2_id,
            "status":       "REQUESTED",
            "requestedAt":  now,
            "arrivalDeadline": expires_at,
            "ttl":          expires_at + 86400,  # keep record 24h after deadline
        })

        # ── Mark signal as RESERVED ──
        signals.update_item(
            Key={"signalId": signal_id},
            UpdateExpression="SET #s = :s, exchangeId = :eid",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": "RESERVED", ":eid": exchange_id},
        )

        print(f"[INFO] Exchange {exchange_id} created: {driver1_id} → {driver2_id}")

        return {
            "success":        True,
            "exchangeId":     exchange_id,
            "arrivalDeadline": expires_at,
            "error":          None,
        }

    except Exception as e:
        print(f"[ERROR] request-spot-handler: {e}")
        return {"success": False, "exchangeId": None, "error": str(e)}