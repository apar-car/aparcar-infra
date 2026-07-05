import json

def handler(event, context):
    print(f"[MATCH] Notification stub received: {json.dumps(event)}")
    matched_user_id  = event.get("matchedUserId")
    parking_signal   = event.get("parkingSignal", {})

    print(f"[MATCH] Driver {matched_user_id} matched spot {parking_signal.get('signalId')} "
          f"at {parking_signal.get('lat')},{parking_signal.get('lng')}")

    return {
        "success": True,
        "notified": matched_user_id,
    }