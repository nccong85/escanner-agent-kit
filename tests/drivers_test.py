import json
import os
import shlex
import shutil
import sys
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE / "plugins/device-e2e/skills/playbook/harness"))

passed = 0
failed = 0


def check(name, cond):
    global passed, failed
    if cond:
        passed += 1
    else:
        failed += 1
        print(f"FAIL {name}")


WORK = Path(tempfile.mkdtemp(prefix="e2e_drv_"))
LOG = WORK / "adb.log"
DUMP = """<?xml version='1.0' encoding='UTF-8' standalone='yes' ?><hierarchy rotation="0">
<node index="0" text="" resource-id="" class="android.widget.FrameLayout" content-desc="" bounds="[0,0][720,1600]">
<node index="1" text="Documents" resource-id="app:id/title" class="android.widget.TextView" content-desc="" bounds="[40,100][300,160]" />
<node index="2" text="" resource-id="" class="android.widget.Button" content-desc="Import" bounds="[600,1400][700,1500]" />
<node index="3" text="hidden" resource-id="" class="android.view.View" content-desc="" bounds="[10,10][10,10]" />
</node></hierarchy>"""
(WORK / "dump.xml").write_text(DUMP)
fake_adb = WORK / "adb"
fake_adb.write_text(
    "#!/bin/sh\n"
    f'echo "$*" >> "{LOG}"\n'
    'case "$*" in\n'
    '  *"uiautomator dump"*) echo "UI hierchary dumped to: /sdcard/e2e_window.xml" ;;\n'
    f'  *"cat /sdcard/e2e_window.xml"*) cat "{WORK / "dump.xml"}" ;;\n'
    '  *"wm size"*) echo "Physical size: 720x1600" ;;\n'
    '  *"default_input_method"*) echo "${FAKE_IME:-com.google.android.inputmethod.latin/.LatinIME}" ;;\n'
    '  *"topResumedActivity"*) echo "topResumedActivity=ActivityRecord{1 u0 com.example.app/.Main t1}" ;;\n'
    "esac\n"
)
fake_adb.chmod(0o755)

for k in ("E2E_APP_ID", "E2E_ANDROID_SERIAL", "WDA", "E2E_IOS_UDID"):
    os.environ.pop(k, None)
os.environ["E2E_ADB"] = str(fake_adb)

import adb_driver
import wda_driver

check("wda session file defaults to a private per-user path",
      str(wda_driver.SID_FILE).startswith(str(Path.home())) and not str(wda_driver.SID_FILE).startswith("/tmp"))
target = WORK / "victim.txt"
target.write_text("keep")
link = WORK / "sid_link"
link.symlink_to(target)
try:
    wda_driver._write_private(link, "S9")
    check("wda session write refuses a symlink", False)
except OSError:
    check("wda session write refuses a symlink", target.read_text() == "keep")

loose = WORK / "loose_sid"
loose.write_text("old")
loose.chmod(0o644)
wda_driver._write_private(loose, "S2")
check("wda session write tightens an existing file to 0600", (loose.stat().st_mode & 0o777) == 0o600 and loose.read_text() == "S2")
secret = WORK / "secret.txt"
secret.write_text("AKIA-SECRET-VALUE")
sid_link = WORK / "sid_points_elsewhere"
sid_link.symlink_to(secret)
check("wda ignores a symlinked session file on read", wda_driver._read_cached_sid(sid_link) == "")
bad_sid = WORK / "bad_sid"
bad_sid.write_text("../../etc/passwd")
check("wda ignores a malformed cached session id", wda_driver._read_cached_sid(bad_sid) == "")
good_sid = WORK / "good_sid"
good_sid.write_text("0A1B2C3D-4E5F-6789-ABCD-EF0123456789\n")
check("wda accepts a UUID session id", wda_driver._read_cached_sid(good_sid) == "0A1B2C3D-4E5F-6789-ABCD-EF0123456789")

try:
    adb_driver.AndroidDriver()
    check("android driver requires E2E_APP_ID", False)
except RuntimeError as e:
    check("android driver requires E2E_APP_ID", "E2E_APP_ID" in str(e))

os.environ["E2E_APP_ID"] = "com.example.app"
os.environ["E2E_ANDROID_SERIAL"] = "SER123"
os.environ["E2E_ANDROID_FIXTURE_DIR"] = "/sdcard/Download/e2e_kit"
a = adb_driver.AndroidDriver()
els = a.elements()
texts = [e["text"] for e in els]
check("android parses text and content-desc", "Documents" in texts and "Import" in texts)
doc = next(e for e in els if e["text"] == "Documents")
check("android bounds become x/y/w/h", (doc["x"], doc["y"], doc["w"], doc["h"]) == (40, 100, 260, 60))
check("android find_any skips zero-size nodes", a.find_any(["hidden"]) is None)
check("android find_any finds visible node", a.find_any(["Import"])["id"] == "")
check("android size parses wm size", a.size() == (720, 1600))
check("android foreground package parsed", a.foreground_package() == "com.example.app")
a.stage_fixtures(WORK, ["f.pdf"])
a.launch()
log = LOG.read_text()
check("android every call targets the serial", all(line.startswith("-s SER123 ") for line in log.splitlines()))
check("android fixtures pushed to the configured folder", "push " in log and "/sdcard/Download/e2e_kit/f.pdf" in log)
check("android media scan uses the configured folder", "file:///sdcard/Download/e2e_kit/f.pdf" in log)
check("android launch uses the app id", "monkey -p com.example.app" in log)
try:
    a.type_text("hợp đồng")
    check("android non-ASCII without ADB Keyboard raises", False)
except adb_driver.UnicodeInputUnavailable:
    check("android non-ASCII without ADB Keyboard raises", True)

for bad in ("/sdcard", "/sdcard/Download", "/sdcard/Download/photos", "/sdcard/Download/../DCIM/e2e", "/data/e2e"):
    os.environ["E2E_ANDROID_FIXTURE_DIR"] = bad
    try:
        adb_driver.AndroidDriver()
        check(f"android refuses fixture dir {bad}", False)
    except ValueError:
        check(f"android refuses fixture dir {bad}", True)
for bad_app in ("com.example.app; rm -rf /", "noDots", "com.example app"):
    try:
        adb_driver.AndroidDriver(app_id=bad_app)
        check(f"android refuses app id {bad_app!r}", False)
    except ValueError:
        check(f"android refuses app id {bad_app!r}", True)
os.environ["E2E_ANDROID_FIXTURE_DIR"] = "/sdcard/Download/my e2e"
LOG.write_text("")
q = adb_driver.AndroidDriver()
q.stage_fixtures(WORK, ["a b.pdf"])
q.remove_fixtures()
log = LOG.read_text()
check("android quotes the fixture dir in rm -rf", "rm -rf '/sdcard/Download/my e2e'" in log)
check("android quotes the media-scan uri", "-d 'file:///sdcard/Download/my e2e/a b.pdf'" in log)
try:
    q.stage_fixtures(WORK, ["../x.pdf"])
    check("android refuses a fixture name with a path", False)
except ValueError:
    check("android refuses a fixture name with a path", True)

def device_argv(fragment):
    line = [ln for ln in LOG.read_text().splitlines() if fragment in ln][-1]
    cmd = line.split(" shell ", 1)[1]
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        argv = list(lex)
    except ValueError:
        return None
    for i, tok in enumerate(argv):
        if ("$" in tok or "`" in tok) and not cmd.endswith(shlex.quote(tok)):
            argv[i] = None
    return argv


LOG.write_text("")
os.environ["E2E_ANDROID_FIXTURE_DIR"] = "/sdcard/Download/e2e"
r = adb_driver.AndroidDriver()
for text in ("price&reboot", "a;b|c", "it's $HOME", "R&D `id`"):
    r.type_text(text)
    check(f"android input text reaches the device as one argument: {text!r}",
          device_argv("input text") == ["input", "text", text.replace(" ", "%s")])
os.environ["FAKE_IME"] = "com.android.adbkeyboard/.AdbIME"
for text in ("hợp đồng & co", "x'; reboot; echo '"):
    r.type_text(text)
    check(f"android ADB Keyboard payload stays one argument: {text!r}",
          device_argv("ADB_INPUT_TEXT")[-1] == text and device_argv("ADB_INPUT_TEXT")[-2] == "msg")
del os.environ["FAKE_IME"]
r.restore_ime("com.x/.Ime; reboot")
check("android restore_ime quotes the IME", device_argv("ime set") == ["ime", "set", "com.x/.Ime; reboot"])
r.restore_stay_on("2")
check("android restore_stay_on puts the recorded value back",
      device_argv("stay_on_while_plugged_in") == ["settings", "put", "global", "stay_on_while_plugged_in", "2"])
LOG.write_text("")
r.restore_stay_on("2; reboot")
check("android restore_stay_on ignores a value that is not a number", "stay_on_while_plugged_in" not in LOG.read_text())

SOURCE = (
    "Application, 0x1, {{0.0, 0.0}, {390.0, 844.0}}, label: 'App'\n"
    "    Button, 0x2, {{20.0, 40.0}, {60.0, 30.0}}, label: 'Back'\n"
    "    StaticText, 0x3, {{20.0, 200.0}, {200.0, 80.0}}, label: 'e2e_vi.pdf\n"
    "12 pages'\n"
    "    Other, 0x4, {{0.0, 0.0}, {0.0, 0.0}}, label: 'ghost'\n"
    "Path to element:\n"
)
calls = []


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, obj):
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        calls.append(("GET", self.path, None))
        if self.path.startswith("/source"):
            self._send({"value": SOURCE})
        elif self.path.endswith("/window/size"):
            self._send({"value": {"width": 390, "height": 844}})
        else:
            self._send({"value": None})

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(n) or b"null")
        calls.append(("POST", self.path, body))
        if self.path == "/session":
            self._send({"sessionId": "S1", "value": {}})
        else:
            self._send({"value": None})


srv = HTTPServer(("127.0.0.1", 0), Handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()
os.environ["WDA"] = f"http://127.0.0.1:{srv.server_address[1]}"
os.environ["E2E_WDA_SID_FILE"] = str(WORK / "sid")
wda_driver.SID_FILE = WORK / "sid"
i = wda_driver.IosDriver()
els = i.elements()
tile = next(e for e in els if e["text"].startswith("e2e_vi.pdf"))
check("ios joins multi-line labels", tile["text"] == "e2e_vi.pdf\n12 pages")
check("ios keeps element type", tile["type"] == "StaticText")
check("ios find_any skips zero-size elements", i.find_any(["ghost"]) is None)
i.back()
taps = [c for c in calls if c[0] == "POST" and c[1].endswith("/wda/tap")]
check("ios back taps the Back label", taps and taps[-1][2] == {"x": 50.0, "y": 55.0})
i.launch()
launches = [c for c in calls if c[1].endswith("/wda/apps/launch")]
check("ios launch uses the app id", launches and launches[-1][2] == {"bundleId": "com.example.app"})
check("ios session id cached", (WORK / "sid").read_text() == "S1")
check("ios session file is owner-only", ((WORK / "sid").stat().st_mode & 0o777) == 0o600)
srv.shutdown()
shutil.rmtree(WORK, ignore_errors=True)

print(f"drivers: pass={passed} fail={failed}")
sys.exit(1 if failed else 0)
