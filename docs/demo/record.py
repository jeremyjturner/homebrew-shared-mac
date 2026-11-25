#!/usr/bin/env python3
"""Record the getting-started clips with asciinema and convert them to GIFs.

Needs: tart, asciinema, agg (brew install asciinema agg) and a prepared VM
(docs/demo/prepare.sh). Run from the repository root:

    python3 docs/demo/record.py [clip-name ...]

Casts are kept in docs/casts/. Playback speed is SPEED (agg --speed).
Render one clip: python3 docs/demo/record.py 04-setup  (the VM must be prepared first).

Each clip opens a shell in the VM, runs hidden setup, then types the visible
commands like a person. The driver waits for text in the output stream, not for
pixels on a screen, so long output does not break it. The hidden setup is cut
from the start of every recording.
"""
import fcntl
import json
import os
import pty
import re
import select
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import time

VM = "hb-demo"
COLS, ROWS = 100, 30
IMAGES = os.path.join(os.path.dirname(__file__), "..", "images")
ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07]*\x07|\x1b[()][A-Z0-9]|\r")
TYPE_DELAY = 0.06
SPEED = "0.75"                    # agg playback speed; below 1 is slower
CASTS = os.path.join(os.path.dirname(__file__), "..", "casts")


class Session:
    def __init__(self, cast):
        self.buf = ""
        self.first_output = None
        env = dict(os.environ, TERM="xterm-256color")
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
            os.execvpe(
                "asciinema",
                ["asciinema", "rec", "-q", "--overwrite", "-f", "asciicast-v2",
                 "-c", f"tart exec -i -t {VM} zsh -l", cast],
                env,
            )
        self.last_data = time.time()

    # --- reading ---
    def pump(self, timeout=0.2):
        r, _, _ = select.select([self.fd], [], [], timeout)
        if not r:
            return False
        try:
            data = os.read(self.fd, 65536).decode(errors="replace")
        except OSError:
            return False
        if self.first_output is None:
            self.first_output = time.time()
        self.buf += data
        self.last_data = time.time()
        return True

    def text(self):
        return ANSI.sub("", self.buf)

    def quiet(self, seconds, timeout=120):
        end = time.time() + timeout
        while time.time() < end:
            self.pump(0.2)
            if time.time() - self.last_data >= seconds:
                return
        raise TimeoutError("output never went quiet")

    def expect(self, pattern, timeout=120):
        end = time.time() + timeout
        while time.time() < end:
            if re.search(pattern, self.text()):
                return
            self.pump(0.2)
        raise TimeoutError(f"timeout waiting for {pattern!r}; got: {self.text()[-400:]!r}")

    def prompt(self, timeout=300):
        """Wait until the shell shows the '$ ' prompt and the output stops."""
        end = time.time() + timeout
        while time.time() < end:
            self.pump(0.2)
            if self.text().endswith("$ ") and time.time() - self.last_data > 0.8:
                return
        raise TimeoutError(f"no prompt; got: {self.text()[-400:]!r}")

    # --- writing ---
    def send(self, s, delay=TYPE_DELAY):
        self.buf = ""
        for ch in s:
            os.write(self.fd, ch.encode())
            time.sleep(delay)
            self.pump(0)

    def line(self, s, delay=TYPE_DELAY):
        self.send(s + "\r", delay)

    def run(self, cmd, passwords=(), pause=1.0):
        """Type a command; answer each 'Password:' prompt; wait for the next prompt."""
        time.sleep(pause)
        self.line(cmd)
        for pw in passwords:
            self.expect(r"Password:")
            time.sleep(0.8)
            self.line(pw)
        self.prompt()

    def close(self):
        # Send exit until the session ends. A clip can run inside a nested shell (su - bob).
        for _ in range(3):
            try:
                self.line("exit", 0.05)
            except OSError:
                break
            end = time.time() + 3
            while time.time() < end:
                self.pump(0.1)
                try:
                    done, _ = os.waitpid(self.pid, os.WNOHANG)
                except ChildProcessError:
                    return
                if done:
                    return
        os.kill(self.pid, 9)


def trim(cast, out):
    """Cut the hidden setup (up to the last screen clear) and the final 'exit'.

    Visible commands never clear the screen, so the last clear ends the hidden
    setup. The prompt before the typed 'exit' is the end. No clock is
    used: clocks of the driver and of asciinema do not match.
    """
    with open(cast) as f:
        header = json.loads(f.readline())
        events = [json.loads(line) for line in f if line.strip()]
    clears = [i for i, e in enumerate(events)
              if e[1] == "o" and ("\x1b[2J" in e[2] or "\x1b[3J" in e[2])]
    start = clears[-1] if clears else 0
    # The typed 'exit' is four small events. Keep everything up to the prompt before it.
    plain = lambda d: re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\r|\x08", "", d)
    exit_at = next((j for j in range(start, len(events) - 3)
                    if "".join(plain(e[2]) for e in events[j:j + 4]) in ("exit", "eexit")), len(events))
    shown = [i for i in range(start, exit_at) if events[i][1] == "o" and events[i][2].endswith("\x1b[?2004h")]
    end = shown[-1] + 1 if shown else exit_at
    kept = events[start:end]
    t0 = kept[0][0]
    header["width"], header["height"] = COLS, ROWS
    with open(out, "w") as f:
        f.write(json.dumps(header) + "\n")
        for t, kind, data in kept:
            f.write(json.dumps([round(t - t0, 4), kind, data]) + "\n")


def finish(name, cast_raw):
    """Trim a raw cast, keep the cast, and convert it to a GIF."""
    cast = cast_raw.replace(".raw.cast", ".cast")
    trim(cast_raw, cast)
    os.makedirs(CASTS, exist_ok=True)
    shutil.copyfile(cast, os.path.join(CASTS, name + ".cast"))   # plays in the asciinema player
    gif = os.path.join(IMAGES, name + ".gif")
    subprocess.run(["agg", "--font-size", "18", "--idle-time-limit", "3", "--speed", SPEED,
                    "--last-frame-duration", "5", cast, gif], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    print(f"OK {name} -> {gif}")


def make_clip(name, hidden, visible):
    cast_raw = os.path.join(tempfile.mkdtemp(), name + ".raw.cast")
    s = Session(cast_raw)
    s.quiet(2.0)                      # login banner
    hidden(s)
    s.quiet(1.0)
    time.sleep(1.5)
    visible(s)
    time.sleep(1.0)
    s.close()
    finish(name, cast_raw)


# ---- hidden setup helpers ----
def as_admin(s):
    s.line("PROMPT='$ '; cd ~/homebrew-shared-mac; clear")


def fresh_home(s):
    """Hidden: set the copied scripts aside, so that 'git clone' has an empty home folder."""
    vm_sh("cd ~ && rm -rf .hb-stash && mv homebrew-shared-mac .hb-stash")
    s.line("PROMPT='$ '; cd ~; clear")


def as_bob(extra=""):
    def f(s):
        s.line("su - bob")
        s.expect(r"Password:")
        s.line("bobpw")
        s.quiet(2.0)
        s.line("PROMPT='$ '; " + extra + "clear")
    return f


def vm_sh(cmd):
    subprocess.run(["tart", "exec", VM, "sh", "-c", cmd], check=True)


# ---- clips ----
def clip_start_state(s):
    s.run("brew --version")
    s.run("ls -ld /opt/homebrew")


REPO_URL = "https://github.com/jeremyjturner/homebrew-shared-mac.git"


def clip_get_files(s):
    """Part 2, steps 2 to 5. The real clone from GitHub, into the home folder."""
    try:
        s.run("git --version")
        s.run("cd ~")
        s.run("git clone " + REPO_URL, pause=1.5)
        s.run("cd homebrew-shared-mac")
        time.sleep(2.0)
    finally:
        # Put the copied scripts back (prepare.sh made them) so that the later clips work.
        vm_sh("cd ~ && rm -rf homebrew-shared-mac && mv .hb-stash homebrew-shared-mac")


def clip_check(s):
    s.run("sudo ./scripts/setup.sh --check", ["admin"])


def clip_setup(s):
    time.sleep(1.0)
    s.line("sudo ./scripts/setup.sh")
    s.expect(r"Password:")
    time.sleep(0.8)
    s.line("admin")
    s.expect(r"Name for the hidden Homebrew account")
    time.sleep(1.5)
    s.line("homebrew")
    s.expect(r"Make these changes now\?")
    time.sleep(7.0)                   # time to read the plan
    s.line("y")
    s.expect(r"Add the brew wrapper")
    time.sleep(1.5)
    s.line("y")
    s.prompt()


def clip_wrapper(s):
    s.run("type brew")                    # Part 5, step 2: the new window has the wrapper
    s.run("brew install hello", ["admin"])
    s.run("hello")


def clip_second_user(s):
    s.run("echo 'source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh' >> ~/.zshrc")
    s.run("source ~/.zshrc")
    s.run("brew list")
    s.run("brew install tree", ["bobpw"])


def clip_wrong_password(s):
    s.run("brew install cowsay", ["wrong", "wrong", "wrong"])
    s.run("brew list | grep cowsay || echo 'cowsay is not installed'")


def warm_up_homebrew():
    """Hidden: update Homebrew as the owner so the recording is short."""
    pre = ("echo admin | sudo -S -u homebrew -H /opt/homebrew/bin/brew update >/dev/null 2>&1; "
           "echo admin | sudo -S -u homebrew -H /opt/homebrew/bin/brew trust "
           "buildkite/buildkite equinix-labs/otel-cli openai/tools >/dev/null 2>&1; true")
    vm_sh(pre)


CLIPS = [
    ("01-start-state", as_admin, clip_start_state, None),
    ("02-get-files", fresh_home, clip_get_files, None),
    ("03-check", as_admin, clip_check, None),
    ("04-setup", as_admin, clip_setup, None),
    ("05-wrapper", as_admin, clip_wrapper, warm_up_homebrew),
    ("06-second-user", as_bob(), clip_second_user, None),
    ("07-wrong-password", as_bob("source /usr/local/share/homebrew-shared-mac/brew-wrapper.zsh; "),
     clip_wrong_password, None),
]

if __name__ == "__main__":
    wanted = set(sys.argv[1:])
    os.makedirs(IMAGES, exist_ok=True)
    subprocess.run(["tart", "exec", VM, "true"], check=True)   # never record if the VM is down
    for name, hidden, visible, before in CLIPS:
        if wanted and name not in wanted:
            continue
        if before:
            before()
        make_clip(name, hidden, visible)
