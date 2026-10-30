#!/usr/bin/env python3
"""
Pengaman Salesforce CLI untuk Claude Code (PreToolUse hook pada Bash).

- Perintah sf yang MENGUBAH org wajib menyebut --target-org / -o secara eksplisit,
  dan alias itu harus cocok dengan daftar di .claude/allowed-orgs.txt
  (mendukung wildcard, misal: scratch-*).
- Pembuatan scratch org wajib memakai --alias yang ada di daftar.
- Perintah berbahaya selalu diblokir: hapus org, destructive changes, purge,
  hapus source dari org, buat sandbox dari production.

Exit code 2 = blokir (pesan di stderr dikirim balik ke Claude).
"""
import fnmatch
import json
import os
import re
import shlex
import sys

PROJECT_DIR = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
ALLOWED_FILE = os.path.join(PROJECT_DIR, ".claude", "allowed-orgs.txt")

ALWAYS_BLOCK = [
    (r"\borg\s+delete\b", "menghapus org"),
    (r"\bforce:org:delete\b", "menghapus org"),
    (r"--purge-on-delete", "purge on delete"),
    (r"destructive", "destructive changes"),
    (r"\bproject\s+delete\b", "menghapus metadata dari org"),
    (r"\bforce:source:delete\b", "menghapus metadata dari org"),
    (r"\borg\s+create\s+sandbox\b", "membuat sandbox (butuh akses production)"),
]

MUTATING = [
    r"\bproject\s+deploy\b",
    r"\bforce:source:(deploy|push)\b",
    r"\bforce:mdapi:deploy\b",
    r"\bdata\s+(import|create|update|upsert|delete|bulk)\b",
    r"\bforce:data:",
    r"\bapex\s+run(?!\s+test)\b",
    r"\bforce:apex:execute\b",
    r"\borg\s+assign\b",
    r"\borg\s+generate\s+password\b",
    r"\bpackage\s+install\b",
    r"\bcommunity\s+(create|publish)\b",
]


def load_allowed():
    patterns = []
    try:
        with open(ALLOWED_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.split("#", 1)[0].strip()
                if line:
                    patterns.append(line)
    except FileNotFoundError:
        pass
    return patterns


def flag_value(tokens, names):
    for i, tok in enumerate(tokens):
        for n in names:
            if tok == n and i + 1 < len(tokens):
                return tokens[i + 1]
            if tok.startswith(n + "="):
                return tok.split("=", 1)[1]
    return None


def block(msg):
    sys.stderr.write("DIBLOKIR oleh pengaman org Salesforce: " + msg + "\n")
    sys.exit(2)


def check_segment(seg, allowed):
    s = seg.strip()
    if not re.match(r"^(\S+=\S+\s+)*(npx\s+)?(sf|sfdx)\s", s + " "):
        return
    for pat, why in ALWAYS_BLOCK:
        if re.search(pat, s):
            block(f"perintah '{why}' tidak diizinkan. Lakukan manual jika memang perlu.")

    try:
        tokens = shlex.split(s)
    except ValueError:
        tokens = s.split()

    if re.search(r"\borg\s+create\s+scratch\b", s):
        alias = flag_value(tokens, ["--alias", "-a"])
        if not alias:
            block("buat scratch org wajib memakai --alias (misal --alias scratch-<klien>).")
        if not any(fnmatch.fnmatch(alias, p) for p in allowed):
            block(f"alias scratch '{alias}' tidak ada di .claude/allowed-orgs.txt.")
        return

    if any(re.search(p, s) for p in MUTATING):
        target = flag_value(tokens, ["--target-org", "-o", "-u", "--targetusername"])
        if not target:
            block("perintah yang mengubah org wajib menyebut -o <alias> secara eksplisit.")
        if not allowed:
            block(".claude/allowed-orgs.txt kosong/tidak ada. Tambahkan alias org demo yang diizinkan.")
        if not any(fnmatch.fnmatch(target, p) for p in allowed):
            block(f"org '{target}' tidak ada di daftar yang diizinkan "
                  f"({', '.join(allowed)}). Tambahkan ke .claude/allowed-orgs.txt jika memang org demo.")


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    cmd = (data.get("tool_input") or {}).get("command") or ""
    if not re.search(r"\b(sf|sfdx)\b", cmd):
        sys.exit(0)
    allowed = load_allowed()
    for seg in re.split(r"&&|\|\||;|\||\n", cmd):
        check_segment(seg, allowed)
    sys.exit(0)


if __name__ == "__main__":
    main()
