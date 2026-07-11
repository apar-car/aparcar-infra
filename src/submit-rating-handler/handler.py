import os
import boto3

EXCHANGES_TABLE  = os.environ["EXCHANGES_TABLE"] 
USERS_TABLE      = os.environ["USERS_TABLE"]
DYNAMODB_ENPOINT = os.environ.get("DYNAMODB_ENDPOINT", "")
CA_BUNDLE        = os.path.join(os.path.dirname(__file__), "AmazonRootCA1.pem")
import os
import boto3

EXCHANGES_TABLE   = os.environ["EXCHANGES_TABLE"]
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
        rater_id    = args.get("userId")
        thumbs_up   = args.get("thumbsUp")  # boolean

        if not all([exchange_id, rater_id, thumbs_up is not None]):
            return {"success": False, "error": "Missing required fields"}

        ddb = get_ddb()
        exchanges = ddb.Table(EXCHANGES_TABLE)

        # ── Fetch exchange ──
        exchange = exchanges.get_item(
            Key={"exchangeId": exchange_id}
        ).get("Item")

        if not exchange:
            return {"success": False, "error": "Exchange not found"}

        if exchange.get("status") != "CONFIRMED":
            return {"success": False, "error": "Can only rate completed exchanges"}

        driver1_id = exchange.get("driver1Id")
        driver2_id = exchange.get("driver2Id")

        # ── Determine who is being rated ──
        if rater_id == driver1_id:
            rated_id       = driver2_id
            rating_field   = "driver1Rating"
        elif rater_id == driver2_id:
            rated_id       = driver1_id
            rating_field   = "driver2Rating"
        else:
            return {"success": False, "error": "Not authorized to rate this exchange"}

        # ── Check not already rated ──
        if exchange.get(rating_field) is not None:
            return {"success": False, "error": "Already rated this exchange"}

        # ── Store rating on exchange ──
        exchanges.update_item(
            Key={"exchangeId": exchange_id},
            UpdateExpression=f"SET {rating_field} = :r",
            ExpressionAttributeValues={":r": thumbs_up},
        )

        # ── Update rated user's aggregate ──
        users = ddb.Table(USERS_TABLE)
        if thumbs_up:
            users.update_item(
                Key={"userId": rated_id},
                UpdateExpression="ADD thumbsUp :one",
                ExpressionAttributeValues={":one": 1},
            )
        else:
            users.update_item(
                Key={"userId": rated_id},
                UpdateExpression="ADD thumbsDown :one",
                ExpressionAttributeValues={":one": 1},
            )

        print(f"[INFO] {rater_id} rated {rated_id}: {'👍' if thumbs_up else '👎'}")

        return {"success": True, "error": None}

    except Exception as e:
        print(f"[ERROR] submit-rating-handler: {e}")
        return {"success": False, "error": str(e)}