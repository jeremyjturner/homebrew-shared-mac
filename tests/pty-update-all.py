#!/usr/bin/env python3
"""`brew update-all` must ask for the sudo password once, and run all four steps.

Run by tests/tart-test.sh after setup. Needs a running VM where the second user has a
password-protected sudo and the wrapper in ~/.zshrc. `tart exec` has no tty, so a pty is used.
Usage: tests/pty-update-all.py VM USER PASSWORD
"""
import os, pty, re, select, sys, time

VM, USER, PW = sys.argv[1:4]
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\r")
fail = lambda msg, buf: sys.exit(f"FAIL {msg}\n{ANSI.sub('', buf)[-2500:]}")

pid, fd = pty.fork()
if pid == 0:
    os.execvp("tart", ["tart", "exec", "-i", "-t", VM, "su", "-", USER])
buf = ""


def read(seconds):
    global buf
    r, _, _ = select.select([fd], [], [], seconds)
    if r:
        try:
            buf += os.read(fd, 65536).decode(errors="replace")
        except OSError:
            pass


def wait_for(pattern, timeout):
    end = time.time() + timeout
    while time.time() < end:
        if re.search(pattern, ANSI.sub("", buf)):
            return
        read(0.5)
    fail(f"waiting for {pattern!r}", buf)


def send(s):
    global buf
    time.sleep(0.5)
    buf = ""               # each wait_for() must see only new output
    os.write(fd, (s + "\r").encode())


wait_for(r"Password:", 60); send(PW)
# A custom sudo prompt, so that the count does not depend on the login text.
send("export SUDO_PROMPT=SUDOPW: PATH=/opt/homebrew/bin:$PATH; echo READY$((1+1))"); wait_for(r"READY2", 60)
send("brew update-all --yes; echo RC=$?")
asked = 0
end = time.time() + 540
while time.time() < end:                       # hard limit: no hang
    clean = ANSI.sub("", buf)
    if re.search(r"RC=\d", clean.split("update-all --yes; echo")[-1]):
        break
    if clean.count("SUDOPW:") > asked:
        asked = clean.count("SUDOPW:")
        buf = buf.replace("SUDOPW:", "SUDO-ASKED")
        os.write(fd, (PW + "\r").encode())
        continue
    read(1)
else:
    fail("brew update-all did not finish in 9 minutes", buf)
out = ANSI.sub("", buf)
if "RC=0" not in out:
    fail("brew update-all exit code", buf)
for step in ("update", "upgrade", "autoremove", "cleanup"):
    if f"==> brew {step}" not in out:
        fail(f"step '{step}' did not run", buf)
if asked != 1:
    fail(f"expected 1 password prompt, got {asked}", buf)
print("PASS brew update-all: one password, four steps, exit 0")
os.write(fd, b"exit\r"); time.sleep(1)
try:
    os.kill(pid, 9)
except OSError:
    pass
