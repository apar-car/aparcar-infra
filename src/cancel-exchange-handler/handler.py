import os
import time
import boto3

EXCHANGES_TABLE   = os.environ["EXCHANGES_TABLE"]
SIGNALS_TABLE     = os.environ["SIGNALS_TABLE"]
DYNAMODB_ENDPOINT = os.environ.get("DYNAMODB_ENDPOINT", "")
CA_BUNDLE = os.path.join(os.path.dirname(__file__), "AmazonRootCA1.pem")

VALID_REASONS = {
    "driver1": [
        "DRIVER1_CHANGED_MIND",
        "DRIVER1_ALREADY_LEFT",
        "DRIVER1_TIMER_EXPIRED",
    ],
    "driver2": [
        "DRIVER2_FOUND_OTHER",
        "DRIVER2_TOO_FAR",
    ],
}


def get_ddb():
    return boto3.resource(
        "dynamodb",
        region_name="eu-west-1",
        endpoint_url=DYNAMODB_ENDPOINT if DYNAMODB_ENDPOINT else None,
        verify=CA_BUNDLE if DYNAMODB_ENDPOINT else True,
    )


def handler(event, context):
    try:
        args        = event.get("arguments", {})
        exchange_id = args.get("exchangeId")
        user_id     = args.get("userId")
        reason      = args.get("reason")

        if not all([exchange_id, user_id, reason]):
            return {"success": False, "error": "Missing required fields"}

        ddb = get_ddb()
        exchanges = ddb.Table(EXCHANGES_TABLE)

        # ── Fetch exchange ──
        exchange = exchanges.get_item(
            Key={"exchangeId": exchange_id}
        ).get("Item")

        if not exchange:
            return {"success": False, "error": "Exchange not found"}

        if exchange.get("status") not in ["REQUESTED"]:
            return {"success": False, "error": f"Exchange is {exchange.get('status')} — cannot cancel"}

        # ── Determine role ──
        driver1_id = exchange.get("driver1Id")
        driver2_id = exchange.get("driver2Id")

        if user_id == driver1_id:
            role = "driver1"
        elif user_id == driver2_id:
            role = "driver2"
        else:
            return {"success": False, "error": "Not authorized to cancel this exchange"}

        # ── Validate reason ──
        if reason not in VALID_REASONS[role]:
            return {
                "success": False,
                "error": f"Invalid reason for {role}. Valid: {VALID_REASONS[role]}"
            }

        now = int(time.time())

        # ── Mark exchange CANCELLED ──
        exchanges.update_item(
            Key={"exchangeId": exchange_id},
            UpdateExpression="SET #s = :s, cancelledBy = :cb, cancelReason = :cr, cancelledAt = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":s":  "CANCELLED",
                ":cb": role,
                ":cr": reason,
                ":t":  now,
            },
        )

        # ── Re-open signal if driver1 cancels ──
        signals = ddb.Table(SIGNALS_TABLE)
        if role == "driver1":
            signals.update_item(
                Key={"signalId": exchange.get("signalId")},
                UpdateExpression="SET #s = :s",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":s": "CANCELLED"},
            )
            print(f"[INFO] Signal {exchange.get('signalId')} cancelled by driver1")
        else:
            # Driver2 cancelled — re-open spot for other looking drivers
            signals.update_item(
                Key={"signalId": exchange.get("signalId")},
                UpdateExpression="SET #s = :s, exchangeId = :null",
                ExpressionAttributeNames={"#s": "status"},
                ExpressionAttributeValues={":s": "ACTIVE", ":null": None},
            )
            print(f"[INFO] Signal {exchange.get('signalId')} re-opened after driver2 cancel")

        print(f"[INFO] Exchange {exchange_id} cancelled by {role} ({reason})")

        return {
            "success":    True,
            "exchangeId": exchange_id,
            "error":      None,
        }

    except Exception as e:
        print(f"[ERROR] cancel-exchange-handler: {e}")
        return {"success": False, "error": str(e)}