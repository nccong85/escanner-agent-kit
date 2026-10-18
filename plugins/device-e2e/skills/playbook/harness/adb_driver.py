import json
import os
import posixpath
import re
import shlex
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path

ADB_KEYBOARD = "com.android.adbkeyboard/.AdbIME"

# Fixed waits after an action whose end adb cannot see. Raise them on a slow phone.
# Callers that need a specific screen still wait for an element.
LAUNCH_WAIT = 4    # monkey returns before the app has drawn its first frame
KEY_WAIT = 1       # Home, force-stop: the launcher or the stop finishes within a second
UNLOCK_WAIT = 2    # the keyguard swipe animation and the app's resume
BACK_WAIT = 0.8    # one route pop animation
IME_WAIT = 1.5     # an IME switch rebinds the input connection
BROADCAST_WAIT = 0.5  # ADB Keyboard commits the broadcast text
DUMP_RETRY_WAIT = 1   # uiautomator dump fails while the screen is animating
POLL = 0.8         # interval of every wait-for loop


def _env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} is not set (see .claude/device-e2e/project.md)")
    return value


def _adb_path():
    explicit = os.environ.get("E2E_ADB", "").strip()
    if explicit:
        return explicit
    found = shutil.which("adb")
    if found:
        return found
    for sdk in (os.environ.get("ANDROID_HOME", ""), str(Path.home() / "Library/Android/sdk"), str(Path.home() / "Android/Sdk")):
        candidate = Path(sdk) / "platform-tools" / "adb"
        if sdk and candidate.exists():
            return str(candidate)
    raise RuntimeError("adb not found: set E2E_ADB or put platform-tools on PATH")


def _safe_fixture_dir(path):
    normal = posixpath.normpath(path)
    if not normal.startswith("/sdcard/Download/") or "e2e" not in posixpath.basename(normal).lower():
        raise ValueError(
            f"E2E_ANDROID_FIXTURE_DIR={path!r} refused: it must be a folder under /sdcard/Download/ whose name "
            "contains 'e2e', because cleanup deletes it"
        )
    return normal


def _safe_app_id(app):
    if not re.fullmatch(r"[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+", app):
        raise ValueError(f"E2E_APP_ID={app!r} is not an Android application id")
    return app


class UnicodeInputUnavailable(RuntimeError):
    pass


class AndroidDriver:
    platform = "android"

    def __init__(self, app_id=None, serial=None):
        self.app = _safe_app_id(app_id or _env("E2E_APP_ID"))
        self.serial = serial or _env("E2E_ANDROID_SERIAL")
        self.adb_bin = _adb_path()
        self.fixture_dir = _safe_fixture_dir(os.environ.get("E2E_ANDROID_FIXTURE_DIR", "/sdcard/Download/e2e"))

    def _adb(self, *args, check=True, timeout=120):
        r = subprocess.run([self.adb_bin, "-s", self.serial, *args], capture_output=True, timeout=timeout)
        if check and r.returncode != 0:
            raise RuntimeError(f"adb {' '.join(args)}: {r.stderr.decode(errors='replace')}")
        return r.stdout.decode(errors="replace")

    def _shell(self, cmd, check=True):
        return self._adb("shell", cmd, check=check)

    def launch(self):
        self._shell(f"monkey -p {self.app} -c android.intent.category.LAUNCHER 1")
        time.sleep(LAUNCH_WAIT)

    def activate(self):
        self.launch()

    def terminate(self):
        self._shell(f"am force-stop {self.app}")
        time.sleep(KEY_WAIT)

    def home(self):
        self._shell("input keyevent KEYCODE_HOME")
        time.sleep(KEY_WAIT)

    def lock_for(self, seconds):
        self._shell("input keyevent KEYCODE_POWER")
        time.sleep(seconds)
        self._shell("input keyevent KEYCODE_WAKEUP")
        time.sleep(KEY_WAIT)
        w, h = self.size()
        self._shell(f"input swipe {w // 2} {int(h * 0.85)} {w // 2} {int(h * 0.3)} 250")
        time.sleep(UNLOCK_WAIT)

    def size(self):
        out = self._shell("wm size")
        m = re.search(r"(\d+)x(\d+)", out.splitlines()[-1])
        return int(m.group(1)), int(m.group(2))

    def screen_height(self):
        return self.size()[1]

    def tap_xy(self, x, y):
        self._shell(f"input tap {int(x)} {int(y)}")

    def long_press(self, x, y, dur=1.0):
        self._shell(f"input swipe {int(x)} {int(y)} {int(x)} {int(y)} {int(dur * 1000)}")

    def drag(self, x1, y1, x2, y2, dur=0.25):
        self._shell(f"input swipe {int(x1)} {int(y1)} {int(x2)} {int(y2)} {int(dur * 1000)}")

    def back(self):
        self._shell("input keyevent KEYCODE_BACK")
        time.sleep(BACK_WAIT)

    def use_adb_keyboard(self):
        installed = self._shell("pm list packages com.android.adbkeyboard", check=False)
        if "com.android.adbkeyboard" not in installed:
            return False
        self._shell(f"ime enable {ADB_KEYBOARD}")
        self._shell(f"ime set {ADB_KEYBOARD}")
        time.sleep(IME_WAIT)
        return True

    def type_text(self, text):
        ime = self._shell("settings get secure default_input_method").strip()
        if "adbkeyboard" in ime.lower():
            self._shell(f"am broadcast -a ADB_INPUT_TEXT --es msg {shlex.quote(text)}")
            time.sleep(BROADCAST_WAIT)
            return
        if not text.isascii():
            raise UnicodeInputUnavailable(text)
        self._shell("input text " + shlex.quote(text.replace(" ", "%s")))

    def elements(self):
        for _ in range(3):
            out = self._shell("uiautomator dump /sdcard/e2e_window.xml", check=False)
            if "dumped" in out:
                break
            time.sleep(DUMP_RETRY_WAIT)
        xml = self._shell("cat /sdcard/e2e_window.xml")
        root = ET.fromstring(xml[xml.index("<?xml"):] if "<?xml" in xml else xml)
        out = []
        for node in root.iter("node"):
            m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
            if not m:
                continue
            x1, y1, x2, y2 = map(int, m.groups())
            text = node.get("text") or node.get("content-desc") or ""
            out.append(
                {
                    "type": node.get("class", ""),
                    "x": x1,
                    "y": y1,
                    "w": x2 - x1,
                    "h": y2 - y1,
                    "text": text,
                    "id": node.get("resource-id", ""),
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

    def wait_for(self, *texts, contains=True, timeout=10):
        end = time.time() + timeout
        while True:
            el = self.find_any(list(texts), contains=contains)
            if el:
                return el
            if time.time() > end:
                raise TimeoutError(f"no element: {texts}")
            time.sleep(POLL)

    def tap_text(self, *texts, contains=True, timeout=10):
        el = self.wait_for(*texts, contains=contains, timeout=timeout)
        self.tap_el(el)
        return el

    def screenshot(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        data = subprocess.run(
            [self.adb_bin, "-s", self.serial, "exec-out", "screencap", "-p"], capture_output=True, check=True
        ).stdout
        Path(path).write_bytes(data)
        return path

    def pull_file(self, device_path, dest):
        Path(dest).parent.mkdir(parents=True, exist_ok=True)
        self._adb("pull", device_path, str(dest))
        return Path(dest)

    def pull_diagnostics(self, dest):
        self.pull_file(_env("E2E_ANDROID_DIAG_PATH"), dest)
        return json.loads(Path(dest).read_text())

    def stage_fixtures(self, local_dir, names):
        self._shell(f"mkdir -p {shlex.quote(self.fixture_dir)}")
        for name in names:
            if "/" in name or name in ("", ".", ".."):
                raise ValueError(f"fixture name {name!r} must be a plain file name")
            remote = f"{self.fixture_dir}/{name}"
            self._adb("push", str(Path(local_dir) / name), remote, timeout=600)
            self._shell(
                "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE "
                f"-d {shlex.quote('file://' + remote)}",
                check=False,
            )

    def remove_fixtures(self):
        self._shell(f"rm -rf {shlex.quote(_safe_fixture_dir(self.fixture_dir))}", check=False)

    def foreground_package(self):
        out = self._shell("dumpsys activity activities | grep -m1 topResumedActivity", check=False)
        m = re.search(r"u0 ([\w.]+)/", out)
        return m.group(1) if m else ""

    def wait_foreground(self, predicate, timeout=20):
        end = time.time() + timeout
        while time.time() < end:
            pkg = self.foreground_package()
            if predicate(pkg):
                return pkg
            time.sleep(POLL)
        return self.foreground_package()

    def keep_screen_on(self, on=True):
        self._shell(f"svc power stayon {'usb' if on else 'false'}", check=False)

    def current_stay_on(self):
        """The stay-awake setting before the run (0 off, 2 USB, 7 any); give it to restore_stay_on at cleanup."""
        return self._shell("settings get global stay_on_while_plugged_in", check=False).strip()

    def restore_stay_on(self, value):
        if str(value).isdigit():
            self._shell(f"settings put global stay_on_while_plugged_in {value}", check=False)

    def restore_ime(self, ime):
        if ime:
            self._shell(f"ime set {shlex.quote(ime)}", check=False)

    def current_ime(self):
        return self._shell("settings get secure default_input_method", check=False).strip()
