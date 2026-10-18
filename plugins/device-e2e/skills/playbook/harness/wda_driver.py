import base64
import json
import os
import re
import subprocess
import time
import urllib.request
from pathlib import Path

# Fixed waits after a WDA call that returns before the screen settles. Callers that need a specific screen still
# wait for an element.
LAUNCH_WAIT = 3     # /wda/apps/launch returns before the app has drawn its first frame
ACTIVATE_WAIT = 2   # bringing a backgrounded app forward and its resume
KEY_WAIT = 1        # terminate, Home: SpringBoard finishes the transition within a second
UNLOCK_WAIT = 2     # the unlock animation and the app's resume
POLL = 0.8          # interval of every wait-for loop

SID_FILE = Path(os.environ.get("E2E_WDA_SID_FILE", str(Path.home() / ".cache" / "device-e2e" / "wda_sid")))


def _write_private(path, text):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | getattr(os, "O_NOFOLLOW", 0), 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(text)


def _read_cached_sid(path):
    if path.is_symlink() or not path.is_file():
        return ""
    sid = path.read_text().strip()
    return sid if re.fullmatch(r"[A-Za-z0-9-]{1,128}", sid) else ""


def _env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is not set (see .claude/device-e2e/project.md)")
    return value


def _call(method, path, body=None, timeout=90):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        _env("WDA") + path, data=data, method=method, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


class IosDriver:
    platform = "ios"

    def __init__(self, app_id=None, udid=None):
        self.app = app_id or _env("E2E_APP_ID")
        self.udid = udid or os.environ.get("E2E_IOS_UDID", "")
        self.back_labels = [s for s in os.environ.get("E2E_BACK_LABELS", "Back").split(",") if s]
        self._sid = None

    def sid(self):
        if self._sid:
            return self._sid
        cached = _read_cached_sid(SID_FILE)
        if cached:
            try:
                _call("GET", f"/session/{cached}")
                self._sid = cached
                return cached
            except Exception:
                pass
        r = _call("POST", "/session", {"capabilities": {"alwaysMatch": {"shouldWaitForQuiescence": False}}})
        self._sid = r["sessionId"]
        _write_private(SID_FILE, self._sid)
        return self._sid

    def _s(self, path):
        return f"/session/{self.sid()}{path}"

    def launch(self):
        _call("POST", self._s("/wda/apps/launch"), {"bundleId": self.app})
        time.sleep(LAUNCH_WAIT)

    def activate(self):
        _call("POST", self._s("/wda/apps/activate"), {"bundleId": self.app})
        time.sleep(ACTIVATE_WAIT)

    def terminate(self):
        _call("POST", self._s("/wda/apps/terminate"), {"bundleId": self.app})
        time.sleep(KEY_WAIT)

    def home(self):
        _call("POST", "/wda/homescreen")
        time.sleep(KEY_WAIT)

    def locked(self):
        return bool(_call("GET", self._s("/wda/locked"))["value"])

    def lock_for(self, seconds):
        _call("POST", self._s("/wda/lock"))
        time.sleep(seconds)
        _call("POST", self._s("/wda/unlock"))
        time.sleep(UNLOCK_WAIT)

    def size(self):
        return _call("GET", self._s("/window/size"))["value"]

    def screen_height(self):
        return self.size()["height"]

    def tap_xy(self, x, y):
        _call("POST", self._s("/wda/tap"), {"x": x, "y": y})

    def type_text(self, text):
        _call("POST", self._s("/wda/keys"), {"value": list(text)})

    def back(self):
        found = self.find_any(self.back_labels, contains=False)
        if found:
            self.tap_el(found)
        else:
            w = self.size()["width"]
            self.drag(2, 300, w * 0.6, 300)

    def long_press(self, x, y, dur=1.0):
        _call("POST", self._s("/wda/touchAndHold"), {"x": x, "y": y, "duration": dur})

    def drag(self, x1, y1, x2, y2, dur=0.25):
        _call(
            "POST",
            self._s("/wda/dragfromtoforduration"),
            {"fromX": x1, "fromY": y1, "toX": x2, "toY": y2, "duration": dur},
        )

    def elements(self):
        src = _call("GET", "/source?format=description", timeout=120)["value"]
        records = []
        head = re.compile(r"^\s*\w+, 0x[0-9a-f]+, \{\{")
        for line in src.split("Path to element:")[0].splitlines():
            if head.match(line) or not records:
                records.append(line.strip())
            else:
                records[-1] += "\n" + line.strip()
        out = []
        for rec in records:
            m = re.match(
                r"(\w+), 0x\w+, \{\{([\d.-]+), ([\d.-]+)\}, \{([\d.]+), ([\d.]+)\}\}(.*)", rec, re.S
            )
            if not m:
                continue
            rest = m.group(6)
            label = re.search(r"label: '((?:[^'\\]|\\.)*)'", rest, re.S)
            value = re.search(r"value: '((?:[^'\\]|\\.)*)'", rest, re.S)
            ident = re.search(r"identifier: '((?:[^'\\]|\\.)*)'", rest, re.S)
            out.append(
                {
                    "type": m.group(1),
                    "x": float(m.group(2)),
                    "y": float(m.group(3)),
                    "w": float(m.group(4)),
                    "h": float(m.group(5)),
                    "text": (label.group(1) if label else "") or (value.group(1) if value else ""),
                    "id": ident.group(1) if ident else "",
                }
            )
        return out

    def find_any(self, texts, contains=True, min_y=-1):
        for el in self.elements():
            if el["w"] <= 0 or el["h"] <= 0 or el["y"] < min_y:
                continue
            for t in texts:
                hit = t in el["text"] if contains else (el["text"] == t or t in el["text"].split("\n"))
                if hit:
                    return el
        return None

    def tap_el(self, el):
        self.tap_xy(el["x"] + el["w"] / 2, el["y"] + el["h"] / 2)

    def tap_text(self, *texts, contains=True, timeout=10):
        el = self.wait_for(*texts, contains=contains, timeout=timeout)
        self.tap_el(el)
        return el

    def wait_for(self, *texts, contains=True, timeout=10):
        end = time.time() + timeout
        while True:
            el = self.find_any(list(texts), contains=contains)
            if el:
                return el
            if time.time() > end:
                raise TimeoutError(f"no element: {texts}")
            time.sleep(POLL)

    def screenshot(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        Path(path).write_bytes(base64.b64decode(_call("GET", "/screenshot")["value"]))
        return path

    def pull_file(self, container_path, dest):
        Path(dest).parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "xcrun", "devicectl", "device", "copy", "from", "--device", self.udid or _env("E2E_IOS_UDID"),
                "--domain-type", "appDataContainer", "--domain-identifier", self.app,
                "--source", container_path, "--destination", str(dest),
            ],
            check=True,
            capture_output=True,
        )
        return Path(dest)

    def pull_diagnostics(self, dest):
        self.pull_file(_env("E2E_IOS_DIAG_PATH"), dest)
        return json.loads(Path(dest).read_text())
