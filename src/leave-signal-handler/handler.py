import json
import os
import uuid
import logging
from datetime import datetime, timezone

import boto3
from boto3.dynamodb.conditions import Key

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
eventbridge = boto3.client('events')

TABLE_NAME = os.environ['PARKING_TABLE']
EVENT_BUS_NAME = os.environ['EVENT_BUS_NAME']

TIMER_MIN_MINUTES = 1
TIMER_MAX_MINUTES = 30
TIMER_DEFAULT_MINUTES = 5
EARLY_WARNING_SECONDS = 120


def validate_input(body: dict) -> tuple[bool, str]:
    required = ['user', 'carDetails', 'lat', 'lng']
    for field in required:
        if field not in body:
            return False, f"Campo requerido: {field}"

    lat = body.get('lat')
    lng = body.get('lng')
    if not isinstance(lat, (int, float)) or not (-90 <= lat <= 90):
        return False, "Latitud invalida"
    if not isinstance(lng, (int, float)) or not (-180 <= lng <= 180):
        return False, "Longitud invalida"

    timer = body.get('timer_minutes', TIMER_DEFAULT_MINUTES)
    if not isinstance(timer, (int, float)) or not (TIMER_MIN_MINUTES <= timer <= TIMER_MAX_MINUTES):
        return False, f"Timer debe estar entre {TIMER_MIN_MINUTES} y {TIMER_MAX_MINUTES} minutos"

    return True, ""


def handler(event, context):
    logger.info(json.dumps({
        "event": "leave_signal_received",
        "request_id": context.aws_request_id
    }))

    try:
        body = event.get('arguments', {})

        valid, error = validate_input(body)
        if not valid:
            logger.warning(json.dumps({
                "event": "validation_failed",
                "error": error
            }))
            return {
                "success": False,
                "error": error
            }

        signal_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc)
        timer_minutes = int(body.get('timer_minutes', TIMER_DEFAULT_MINUTES))
        expires_at = int(now.timestamp()) + (timer_minutes * 60)
        early_warning_at = expires_at - EARLY_WARNING_SECONDS

        item = {
            'signalId': signal_id,
            'userId': body.get('user'),
            'carDetails': body.get('carDetails'),
            'lat': str(body.get('lat')),
            'lng': str(body.get('lng')),
            'timerMinutes': timer_minutes,
            'expiresAt': expires_at,
            'earlyWarningAt': early_warning_at,
            'status': 'ACTIVE',
            'createdAt': now.isoformat(),
            'ttl': expires_at
        }

        table = dynamodb.Table(TABLE_NAME)
        table.put_item(Item=item)

        logger.info(json.dumps({
            "event": "signal_stored",
            "signal_id": signal_id,
            "expires_at": expires_at
        }))

        eventbridge.put_events(
            Entries=[
                {
                    'Source': 'aparcar.leave-signal',
                    'DetailType': 'ParkingSpotLeaving',
                    'Detail': json.dumps({
                        'signalId': signal_id,
                        'userId': body.get('user'),
                        'lat': body.get('lat'),
                        'lng': body.get('lng'),
                        'timerMinutes': timer_minutes,
                        'expiresAt': expires_at,
                        'earlyWarningAt': early_warning_at,
                        'carDetails': body.get('carDetails')
                    }),
                    'EventBusName': EVENT_BUS_NAME
                }
            ]
        )

        logger.info(json.dumps({
            "event": "eventbridge_published",
            "signal_id": signal_id
        }))

        return {
            "success": True,
            "signalId": signal_id,
            "expiresAt": expires_at,
            "earlyWarningAt": early_warning_at,
            "timerMinutes": timer_minutes
        }

    except Exception as e:
        logger.error(json.dumps({
            "event": "unhandled_error",
            "error": str(e)
        }))
        raise