import os
import ssl
import json
import socket
import boto3


REDIS_HOST        = os.environ["REDIS_HOST"]
REDIS_PORT        = int(os.environ.get("REDIS_PORT", 6379))
DYNAMODB_ENDPOINT = os.environ.get("DYNAMODB_ENDPOINT", "")
NOTIFIER_ARN      = os.environ["NOTIFICATION_DISPATCHER_ARN"]
MAX_SEARCH_RADIUS = 5000
LAMBDA_ENDPOINT = os.environ.get("LAMBDA_ENDPOINT", "")


class RawRedis:
    def __init__(self, host, port, timeout=5):
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        raw = socket.create_connection((host, port), timeout=timeout)
        self._sock = context.wrap_socket(raw, server_hostname=host)
        self._sock.settimeout(timeout)
        self._buf = b""

    def _send(self, *args):
        cmd = f"*{len(args)}\r\n"
        for a in args:
            s = str(a)
            cmd += f"${len(s.encode())}\r\n{s}\r\n"
        self._sock.sendall(cmd.encode())

    def _read_line(self):
        while b"\r\n" not in self._buf:
            self._buf += self._sock.recv(4096)
        line, self._buf = self._buf.split(b"\r\n", 1)
        return line.decode()

    def _read_response(self):
        line = self._read_line()
        if line.startswith("+"):
            return line[1:]
        if line.startswith(":"):
            return int(line[1:])
        if line.startswith("-"):
            raise Exception(f"Redis error: {line[1:]}")
        if line.startswith("$"):
            n = int(line[1:])
            if n == -1:
                return None
            while len(self._buf) < n + 2:
                self._buf += self._sock.recv(4096)
            data, self._buf = self._buf[:n], self._buf[n+2:]
            return data.decode()
        if line.startswith("*"):
            n = int(line[1:])
            return [self._read_response() for _ in range(n)]
        raise Exception(f"Unknown response: {line}")

    def execute(self, *args):
        self._send(*args)
        return self._read_response()

    def geosearch(self, key, lng, lat, radius_m):
        return self.execute(
            "GEOSEARCH", key,
            "FROMLONLAT", lng, lat,
            "BYRADIUS", radius_m, "m",
            "ASC",
            "COUNT", "50",
            "WITHCOORD", "WITHDIST"
        )

    def hgetall(self, key):
        result = self.execute("HGETALL", key)
        if not result:
            return {}
        return dict(zip(result[::2], result[1::2]))

    def close(self):
        self._sock.close()


def handler(event, context):
    print(f"[INFO] radius-matcher triggered: {json.dumps(event)}")

    try:
        detail      = event.get("detail", {})
        signal_id   = detail.get("signalId")
        leaving_lat = float(detail.get("lat"))
        leaving_lng = float(detail.get("lng"))
        car_details = detail.get("carDetails", "")
        timer_min   = detail.get("timerMinutes", 5)
        expires_at  = detail.get("expiresAt")

        print(f"[INFO] Spot leaving at {leaving_lat},{leaving_lng} signal={signal_id}")

        # ── Redis GEOSEARCH ──
        r = RawRedis(REDIS_HOST, REDIS_PORT)
        try:
            candidates = r.geosearch(
                "aparcar:looking:drivers",
                leaving_lng, leaving_lat,
                MAX_SEARCH_RADIUS
            )
            print(f"[INFO] Found {len(candidates)} candidates within {MAX_SEARCH_RADIUS}m")

            matched = []
            for entry in candidates:
                user_id  = entry[0]
                distance = float(entry[1])
                meta     = r.hgetall(f"aparcar:looking:meta:{user_id}")

                if not meta:
                    print(f"[WARN] No metadata for {user_id}, skipping")
                    continue

                driver_radius = int(meta.get("radius_meters", 500))
                if distance <= driver_radius:
                    print(f"[MATCH] {user_id} within {distance:.0f}m (radius={driver_radius}m)")
                    matched.append({
                        "userId":   user_id,
                        "distance": distance,
                        "meta":     meta,
                    })
                else:
                    print(f"[SKIP] {user_id} at {distance:.0f}m exceeds radius {driver_radius}m")

        finally:
            r.close()

        print(f"[INFO] {len(matched)} drivers matched after radius filter")

        # ── Invoke notification-dispatcher synchronously ──
        lambda_client = boto3.client("lambda", 
                                     region_name="eu-west-1",
                                     endpoint_url=LAMBDA_ENDPOINT if LAMBDA_ENDPOINT else None,
                                     verify=os.path.join(os.path.dirname(__file__), "AmazonRootCA1.pem"),
                                     )

        for match in matched:
            payload = {
                "matchedUserId":  match["userId"],
                "distanceMeters": match["distance"],
                "parkingSignal": {
                    "signalId":     signal_id,
                    "lat":          leaving_lat,
                    "lng":          leaving_lng,
                    "timerMinutes": timer_min,
                    "expiresAt":    expires_at,
                    "carDetails":   car_details,
                }
            }
            print(f"[INFO] Invoking notification-dispatcher for {match['userId']}")
            lambda_client.invoke(
                FunctionName=NOTIFIER_ARN,
                InvocationType="Event",
                Payload=json.dumps(payload),
            )
            

        return {
            "signalId":        signal_id,
            "candidatesFound": len(candidates),
            "matched":         len(matched),
        }

    except Exception as e:
        print(f"[ERROR] radius-matcher: {e}")
        raise              