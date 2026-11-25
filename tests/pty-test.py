#!/usr/bin/env python3
"""Interactive prompt tests for scripts/setup.sh, driven through a pty.

`tart exec` without -t has no terminal, so reads from /dev/tty fail there.
Run by tests/tart-test.sh. Needs a running VM with a password on sudo.
Usage: tests/pty-test.py VM ADMIN_PASSWORD
"""
import os, pty, re, select, sys, time

VM, PW = sys.argv[1], sys.argv[2]
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\r")


class Term:
    def __init__(self, cmd):
        self.buf = ""
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvp("tart", ["tart", "exec", "-i", "-t", VM, "sh", "-c", cmd])

    def expect(self, pattern, timeout=120):
        end = time.time() + timeout
        while time.time() < end:
            if re.search(pattern, ANSI.sub("", self.buf)):
                return
            r, _, _ = select.select([self.fd], [], [], 0.5)
            if r:
                try:
                    self.buf += os.read(self.fd, 65536).decode(errors="replace")
                except OSError:
                    break
        raise AssertionError(f"waiting for {pattern!r}; got {ANSI.sub('', self.buf)[-300:]!r}")

    def line(self, s):
        time.sleep(0.5)
        self.buf = ""          # each expect() must see only new output
        os.write(self.fd, (s + "\r").encode())

    def finish(self, timeout=60):
        """Drain output until the child exits; fail instead of hanging."""
        end = time.time() + timeout
        while time.time() < end:
            r, _, _ = select.select([self.fd], [], [], 0.5)
            if r:
                try:
                    self.buf += os.read(self.fd, 65536).decode(errors="replace")
                except OSError:
                    pass
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                return os.waitstatus_to_exitcode(status)
        os.kill(self.pid, 9)
        raise AssertionError(f"child did not exit; got {ANSI.sub('', self.buf)[-300:]!r}")


def ok(name):
    print("PASS", name)


# 1. A wrong sudo password is refused and the script does not start.
t = Term("cd /tmp && sudo -k && sudo -p 'Password:' ./setup.sh --check")
for _ in range(3):
    t.expect(r"Password:")
    t.line("wrong")
t.expect(r"(incorrect password attempts|Sorry, try again)")
assert t.finish() != 0
assert "Homebrew" not in ANSI.sub("", t.buf)
ok("wrong sudo password stops setup.sh")

# 2. Answering n at the plan changes nothing.
t = Term("cd /tmp && sudo -k && sudo -p 'Password:' ./setup.sh --report /tmp/report-n.txt")
t.expect(r"Password:"); t.line(PW)
t.expect(r"Name for the hidden Homebrew account"); t.line("")      # Enter = default
t.expect(r"Make these changes now\?"); t.line("n")
t.finish()
t.buf = ""
chk = Term("dscl . -read /Users/homebrew UniqueID 2>&1; true")
chk.expect(r"(does not exist|DS Error)")
ok("answer n changes nothing (no homebrew account)")

# 3. Enter at the name prompt gives 'homebrew'; y at both questions finishes.
t = Term("cd /tmp && sudo -k && sudo -p 'Password:' ./setup.sh --report /tmp/report-y.txt")
t.expect(r"Password:"); t.line(PW)
t.expect(r"Name for the hidden Homebrew account"); t.line("")
t.expect(r"Make these changes now\?"); t.line("y")
t.expect(r"Add the brew wrapper"); t.line("y")
assert t.finish() == 0
ok("interactive run with defaults creates the account")

# Put the passwordless sudo of the base image back, for the rest of tests/tart-test.sh.
t = Term("sudo -k && sudo -p 'Password:' mv /tmp/admin-nopasswd.bak /etc/sudoers.d/admin-nopasswd")
t.expect(r"Password:"); t.line(PW)
assert t.finish() == 0
