import os
import uuid
import time
import ssl
import socket
import boto3


PARKING_TABLE     = os.environ["PARKING_TABLE"]
REDIS_HOST        = os.environ["REDIS_HOST"]
REDIS_PORT        = int(os.environ.get("REDIS_PORT", 6379))
DYNAMODB_ENDPOINT = os.environ.get("DYNAMODB_ENDPOINT", "")
LOOK_TTL_SECONDS  = 1800


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

    def geoadd(self, key, lng, lat, member):
        return self.execute("GEOADD", key, lng, lat, member)

    def expire(self, key, seconds):
        return self.execute("EXPIRE", key, seconds)

    def hset(self, key, mapping):
        args = ["HSET", key]
        for k, v in mapping.items():
            args += [k, v]
        return self.execute(*args)

    def close(self):
        self._sock.close()


def handler(event, context):
    try:
        args = event.get("arguments", {})

        user_id       = args.get("userId")
        lat           = args.get("lat")
        lng           = args.get("lng")
        radius_meters = args.get("radius_meters", 500)

        if not all([user_id, lat is not None, lng is not None]):
            return {"success": False, "lookId": None, "error": "Missing required fields"}

        if not (-90 <= lat <= 90) or not (-180 <= lng <= 180):
            return {"success": False, "lookId": None, "error": "Invalid coordinates"}

        if not (50 <= radius_meters <= 5000):
            return {"success": False, "lookId": None, "error": "radius_meters must be between 50 and 5000"}

        look_id    = str(uuid.uuid4())
        now        = int(time.time())
        expires_at = now + LOOK_TTL_SECONDS

        CA_BUNDLE = os.path.join(os.path.dirname(__file__), "AmazonRootCA1.pem")
        print(f"[DEBUG] CA bundle path: {CA_BUNDLE}, exists: {os.path.exists(CA_BUNDLE)}")
        print(f"[DEBUG] __file__: {__file__}")
        print(f"[DEBUG] dirname: {os.path.dirname(__file__)}")
        print(f"[DEBUG] files in dir: {os.listdir(os.path.dirname(__file__) or '.')}")

        # ── Redis ──
        r = RawRedis(REDIS_HOST, REDIS_PORT)
        try:
            r.geoadd("aparcar:looking:drivers", lng, lat, user_id)
            r.expire("aparcar:looking:drivers", LOOK_TTL_SECONDS)
            r.hset(f"aparcar:looking:meta:{user_id}", {
                "lookId":        look_id,
                "radius_meters": str(radius_meters),
                "lat":           str(lat),
                "lng":           str(lng),
                "registeredAt":  str(now),
            })
            r.expire(f"aparcar:looking:meta:{user_id}", LOOK_TTL_SECONDS)
        finally:
            r.close()

        # ── DynamoDB ──
        ddb = boto3.resource(
            "dynamodb",
            region_name="eu-west-1",
            endpoint_url=DYNAMODB_ENDPOINT if DYNAMODB_ENDPOINT else None,
            verify=os.path.join(CA_BUNDLE),
        )
        ddb.Table(PARKING_TABLE).put_item(Item={
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