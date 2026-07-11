import os
import time
import json
import boto3

EXCHANGES_TABLE   = os.environ["EXCHANGES_TABLE"]
SIGNALS_TABLE     = os.environ["SIGNALS_TABLE"]
USERS_TABLE       = os.environ["USERS_TABLE"]
DYNAMODB_ENDPOINT = os.environ.get("DYNAMODB_ENDPOINT", "")
CA_BUNDLE = os.path.join(os.path.dirname(__file__), "AmazonRootCA1.pem")


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
        driver2_id  = args.get("userId")

        if not all([exchange_id, driver2_id]):
            return {"success": False, "error": "Missing required fields"}

        ddb = get_ddb()
        exchanges = ddb.Table(EXCHANGES_TABLE)

        # ── Fetch exchange ──
        exchange = exchanges.get_item(
            Key={"exchangeId": exchange_id}
        ).get("Item")

        if not exchange:
            return {"success": False, "error": "Exchange not found"}

        if exchange.get("status") != "REQUESTED":
            return {"success": False, "error": f"Exchange is {exchange.get('status')} — cannot confirm"}

        if exchange.get("driver2Id") != driver2_id:
            return {"success": False, "error": "Not authorized to confirm this exchange"}

        now = int(time.time())

        if now > int(exchange.get("arrivalDeadline", 0)):
            return {"success": False, "error": "Arrival window has expired"}

        # ── Mark exchange CONFIRMED ──
        exchanges.update_item(
            Key={"exchangeId": exchange_id},
            UpdateExpression="SET #s = :s, confirmedAt = :t",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": "CONFIRMED", ":t": now},
        )

        # ── Mark signal COMPLETED ──
        signals = ddb.Table(SIGNALS_TABLE)
        signals.update_item(
            Key={"signalId": exchange.get("signalId")},
            UpdateExpression="SET #s = :s",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": "COMPLETED"},
        )

        # ── Increment exchange count for both drivers ──
        users = ddb.Table(USERS_TABLE)
        for user_id in [exchange.get("driver1Id"), exchange.get("driver2Id")]:
            users.update_item(
                Key={"userId": user_id},
                UpdateExpression="ADD totalExchanges :one",
                ExpressionAttributeValues={":one": 1},
            )

        print(f"[INFO] Exchange {exchange_id} confirmed by {driver2_id}")

        return {
            "success":    True,
            "exchangeId": exchange_id,
            "error":      None,
        }

    except Exception as e:
        print(f"[ERROR] confirm-exchange-handler: {e}")
        return {"success": False, "error": str(e)}