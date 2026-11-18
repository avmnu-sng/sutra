"""Regression cases for check_directory_policy in scripts/check.sh.

    python3 -I tests/directory-policy.py [--gate FILE]

Clones HEAD into a temporary directory and writes a runner there from the
gate file (scripts/check.sh, or the copy --gate names): every line before the
line check_ascii, then a call to check_directory_policy. Each case resets the
clone, plants its files, and runs the runner under BASH_UNDER_TEST (default:
the bash on PATH). A case that names messages must fail with every one of
them, and every other case must pass. Names a case-insensitive disk cannot
hold are planted in the index only.
"""

import argparse
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# A GIT_DIR or GIT_INDEX_FILE from a calling hook would aim reset and clean at the real repository.
ENV = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}

ATTR = ": sets an attribute that drops or rewrites files the directory fetches"
NAME = ": holds a colon or another character Windows refuses, ends in a dot or space, or is a reserved device name"
CASE = "%s: differs from %s only by case"
WEBP = ": not a complete .webp image"
CODE = ": writes the bundled file %s in backticks or a code block"
HTML = ": shows the bundled file %s with an HTML tag"
COMMAND = ": names the bundled file %s from a command"
MACOSX = ": macOS archive metadata (__MACOSX)"
TYPE = ": not Markdown, text, JSON, YAML, or a PNG, JPEG, GIF, or WebP image"
PNG = ": not a complete .png image"
LAUNCHER = ": names %s, and the directory flags a download-and-run command"
CREDENTIAL = ": uses the variable $%s, whose name looks like a credential to Claude Code"
READS = ": reads $%s, which the directory can treat as a credential from the environment"

README = "plugins/sutra/README.md"
REFERENCE = "plugins/sutra/skills/hooks-cookbook/reference/recipes.md"
SKILL = "plugins/sutra/skills/debugging/SKILL.md"


def write(path, data):
    return [("write", path, data if isinstance(data, bytes) else data.encode())]


def append(path, text):
    return [("append", path, text.encode())]


def index(*paths):
    return [("index", path, b"planted\n") for path in paths]


def readme(text):
    return append(README, text)


def png():
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    header = struct.pack(">IIBBBBB", 1, 1, 8, 0, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(b"\0\0")) + chunk(b"IEND", b"")


def webp(magic=b"WEBP"):
    chunk = b"VP8L" + struct.pack("<I", 6) + b"\x2f\0\0\0\0\0"
    return b"RIFF" + struct.pack("<I", 4 + len(chunk)) + magic + chunk


def cases():
    for line in ("* text=auto", "*.md eol=lf", "*.bin filter=lfs diff=lfs merge=lfs -text", "x export-ignore",
                 "x export-subst", "* ident", "* working-tree-encoding=UTF-16", "* crlf", "[attr]foo text eol=lf",
                 '"a b" text', '"*"text'):
        yield "gitattributes: " + line, write(".gitattributes", line + "\n"), ".gitattributes" + ATTR
    yield "gitattributes: * text on a CRLF line", write(".gitattributes", "* text\r\n"), ".gitattributes" + ATTR
    for folder in ("plugins/sutra/", "docs/", "plugins/", "|touch PWNED #/"):
        path = folder + ".gitattributes"
        yield "gitattributes: * text in " + path, write(path, "* text\n"), path + ATTR
    for line in ("*.png binary", "* -text", "* !text", "# * text=auto", "text -diff", '"a b" -text',
                 "*.md linguist-documentation", "* textual", "filter -diff", "* -filter"):
        yield "gitattributes: " + line, write(".gitattributes", line + "\n"), None

    for path in ("docs/foo:bar.md", "docs/aux.md", "docs/trailing.", "docs/trail ", "docs/con.tar.gz", "docs/COM1",
                 "docs/what?.md", "docs/a|b.md", "docs/a*b.md", "docs/<x>.md", 'docs/say"hi".md', "docs/a\\b.md",
                 "docs/lpt0.md", "docs/Prn"):
        yield "names: %r" % path, index(path), path + NAME
    for path, part in (("docs/nul/x.md", "docs/nul"), ("plugins/sutra/skills/aux/x.md", "plugins/sutra/skills/aux")):
        yield "names: %r" % path, index(path), part + NAME
    for path in ("docs/auxiliary.md", "docs/console.md", "docs/com10.md", "docs/a%b.md", "docs/a b.md", "docs/it's.md"):
        yield "names: %r" % path, index(path), None

    yield "case: docs/Foo/a.md and docs/foo/b.md", index("docs/Foo/a.md", "docs/foo/b.md"), CASE % ("docs/foo", "docs/Foo")
    yield "case: Docs/x.md and docs/y.md", index("Docs/x.md", "docs/y.md"), CASE % ("docs", "Docs")
    yield "case: docs/foo/a.md and docs/foo/b.md", index("docs/foo/a.md", "docs/foo/b.md"), None

    image, whole = "plugins/sutra/assets/x.webp", webp()
    yield "webp: a whole file", write(image, whole), None
    yield "webp: truncated", write(image, whole[:-1]), image + WEBP
    yield "webp: a 16-byte stub whose size is 8", write(image, b"RIFF" + struct.pack("<I", 8) + b"WEBPVP8 "), image + WEBP
    yield "webp: trailing bytes", write(image, whole + b"\0\0"), image + WEBP
    yield "webp: a WAVE magic", write(image, webp(b"WAVE")), image + WEBP

    code, html = README + CODE % "icon.png", README + HTML % "icon.png"
    text, command = "plugins/sutra/notes.txt", "plugins/sutra/commands/x.md"
    yield "bundled: `assets/icon.png` in the README", readme("The icon is `assets/icon.png`."), code
    yield "bundled: a backtick fence", readme("```\nassets/icon.png\n```"), code
    yield "bundled: a tilde fence", readme("~~~\nassets/icon.png\n~~~"), code
    yield "bundled: an indented block after a blank line", readme("The icon:\n\n    assets/icon.png"), code
    yield "bundled: ``assets/icon.png``", readme("The icon is ``assets/icon.png``."), code
    yield "bundled: `ICON.PNG`", readme("The icon is `ICON.PNG`."), README + CODE % "ICON.PNG"
    yield "bundled: a stray backtick in the paragraph before", readme("A stray ` mark.\n\nThe icon is `assets/icon.png`."), code
    yield "bundled: six spaces in after a list item and a blank line", readme("- The icon:\n\n      assets/icon.png"), code
    yield "bundled: a fence opened on a list marker line", readme("- ```\n  assets/icon.png\n  ```"), code
    yield "bundled: backticks in a reference file", append(REFERENCE, "The icon is `assets/icon.png`."), REFERENCE + CODE % "icon.png"
    yield "bundled: backticks in a new .txt file", write(text, "The icon is `assets/icon.png`.\n"), text + CODE % "icon.png"
    yield "bundled: an img tag in the README", readme('<img src="assets/icon.png">'), html
    yield "bundled: a picture source in the README", readme('<picture><source srcset="assets/icon.png"></picture>'), html
    yield ("bundled: a command naming it in prose",
           write(command, "---\ndescription: Show the listing icon.\n---\n\nThe listing shows assets/icon.png.\n"),
           command + COMMAND % "icon.png")
    yield "bundled: image syntax in the README", readme("![icon](assets/icon.png)"), None
    yield "bundled: prose in the README", readme("The listing shows assets/icon.png."), None
    yield "bundled: `myicon.png`", readme("Another file is `myicon.png`."), None
    yield "bundled: `icon.png.txt`", readme("Another file is `icon.png.txt`."), None
    yield "bundled: a wrapped list line", readme("- The listing shows the icon from\n      assets/icon.png when it loads."), None
    yield "bundled: an image four spaces in under a numbered step", readme("1. Open the listing.\n\n    ![icon](assets/icon.png)"), None
    yield "bundled: an img tag in a skill", append(SKILL, '<img src="assets/icon.png">'), None
    yield ("bundled: an indented JSON value after a blank line",
           write("plugins/sutra/listing.json", '{\n  "listing": {\n\n    "icon": "icon.png"\n  }\n}\n'), None)

    yield "credential: $secret in a reference file", append(REFERENCE, "Read the value from $secret."), REFERENCE + CREDENTIAL % "secret"
    yield "credential: ${api_key} in a reference file", append(REFERENCE, "Pass ${api_key} to the client."), REFERENCE + CREDENTIAL % "api_key"
    yield "credential: $GITHUB_TOKEN in a reference file", append(REFERENCE, "The job exports $GITHUB_TOKEN."), REFERENCE + CREDENTIAL % "GITHUB_TOKEN"
    yield ('credential: "$MY_TOKEN" as a JSON value', write("plugins/sutra/listing.json", '{\n  "token": "$MY_TOKEN"\n}\n'),
           "plugins/sutra/listing.json" + CREDENTIAL % "MY_TOKEN")
    yield "credential: $DEPLOY_KEY in a SKILL.md", append(SKILL, "Deploy with $DEPLOY_KEY set."), SKILL + CREDENTIAL % "DEPLOY_KEY"
    yield "credential: $DB_PASSWORD in a new .txt file", write(text, "Connect with $DB_PASSWORD.\n"), text + CREDENTIAL % "DB_PASSWORD"
    yield ("credential: $AuthHeader in a new .yaml file", write("plugins/sutra/listing.yaml", "header: $AuthHeader\n"),
           "plugins/sutra/listing.yaml" + CREDENTIAL % "AuthHeader")
    yield ("credential: $api_key before $HOME in a SKILL.md", append(SKILL, "Set $api_key, then read $HOME."),
           (SKILL + CREDENTIAL % "api_key", SKILL + READS % "HOME"))
    yield "credential: $PWD in a reference file", append(REFERENCE, "Paths are relative to $PWD."), None
    yield "credential: $missed in a reference file", append(REFERENCE, "Search the tree for the value in $missed."), None
    yield "credential: ${CLAUDE_PLUGIN_ROOT} in a SKILL.md", append(SKILL, "Scripts live under ${CLAUDE_PLUGIN_ROOT}."), None
    yield ("credential: prose naming the secret key",
           append(REFERENCE, "Rotate the secret key, and never paste an auth token or a password into a file."), None)

    macosx, ico, png_path = "plugins/sutra/__MACOSX/x.md", "plugins/sutra/assets/x.ico", "plugins/sutra/assets/x.png"
    yield "earlier: " + macosx, write(macosx, "Archive metadata.\n"), macosx + MACOSX
    yield "earlier: an .ico file", write(ico, b"\0\0\1\0\0\0"), ico + TYPE
    yield "earlier: a truncated PNG", write(png_path, png()[:-12]), png_path + PNG
    yield "earlier: a complete PNG", write(png_path, png()), None
    yield "earlier: curl in a reference file", append(REFERENCE, "Fetch the page with curl first."), REFERENCE + LAUNCHER % "curl"
    yield "earlier: the DLX queue", append(REFERENCE, "Failed messages wait in the DLX queue."), None


def git(cwd, *args, data=None):
    feed = {"input": data} if data is not None else {"stdin": subprocess.DEVNULL}
    proc = subprocess.run(["git", "-c", "core.hooksPath=/dev/null", *args], cwd=cwd, env=ENV, capture_output=True, **feed)
    if proc.returncode:
        sys.exit("tests/directory-policy.py: git %s: %s" % (" ".join(args), proc.stderr.decode("utf-8", "replace").strip()))
    return proc.stdout.decode("utf-8", "replace")


def clone_head(tmp):
    clone = os.path.join(tmp, "repo")
    head = git(REPO, "rev-parse", "--verify", "HEAD^{commit}").strip()
    git(tmp, "clone", "--quiet", "--no-checkout", REPO, clone)
    # These outrank a planted .gitattributes, so reset never reads a file through one.
    os.makedirs(os.path.join(clone, ".git", "info"), exist_ok=True)
    with open(os.path.join(clone, ".git", "info", "attributes"), "w") as fh:
        fh.write("* -text -filter -ident !eol !working-tree-encoding\n")
    git(clone, "checkout", "--quiet", "--detach", head)
    if os.path.realpath(git(clone, "rev-parse", "--show-toplevel").strip()) != os.path.realpath(clone):
        sys.exit("tests/directory-policy.py: the clone in %s is not its own work tree" % clone)
    return clone


def write_runner(gate, clone):
    with open(gate, "rb") as fh:
        lines = fh.read().split(b"\n")
    if b"check_ascii" not in lines or b"check_directory_policy() {" not in lines[:lines.index(b"check_ascii")]:
        sys.exit("tests/directory-policy.py: %s defines no check_directory_policy before the line check_ascii" % gate)
    runner = os.path.join(clone, ".git", "directory-policy-runner.sh")
    with open(runner, "wb") as fh:
        fh.write(b"\n".join(lines[:lines.index(b"check_ascii")]) + b'\ncheck_directory_policy\n[ "$failed" -eq 0 ]\n')
    return runner


def plant(clone, plants):
    for kind, path, data in plants:
        full = os.path.join(clone, path)
        if kind == "index":
            blob = git(clone, "hash-object", "-w", "--stdin", data=data).strip()
            git(clone, "update-index", "--add", "--cacheinfo", "100644,%s,%s" % (blob, path))
        elif kind == "append":
            with open(full, "rb") as fh:
                old = fh.read()
            with open(full, "ab") as fh:
                fh.write(b"\n" * (1 if old.endswith(b"\n") else 2) + data + b"\n")
        else:
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "xb") as fh:
                fh.write(data)
    listed = git(clone, "ls-files", "-z", "--cached", "--others", "--exclude-standard").split("\0")
    missing = [path for _, path, _ in plants if path not in listed]
    if missing:
        raise RuntimeError("git ls-files does not list %s" % ", ".join(missing))


def judge(expect, rc, out, err):
    problems = [line[8:] for line in out.splitlines() if line.startswith(" " * 8)]
    said = "; ".join(problems) or " ".join(out.split()) or "no output"
    if err:
        return "the gate wrote to stderr: " + " ".join(err.split())
    if expect is None:
        if rc == 0 and out.startswith("ok    directory-policy: ") and not problems:
            return None
        return "should pass, but the gate said: " + said
    wanted = [expect] if isinstance(expect, str) else list(expect)
    if rc == 0:
        return 'should fail with "%s", but the gate passed it' % '" and "'.join(wanted)
    if rc != 1 or not out.startswith("FAIL  directory-policy: "):
        return 'should fail with "%s", but the gate exited %d: %s' % ('" and "'.join(wanted), rc, said)
    missing = [message for message in wanted if not any(message in problem for problem in problems)]
    if missing:
        return 'should fail with "%s", but the gate said: %s' % ('" and "'.join(missing), said)
    return None


def planted_file(tmp):
    for root, dirs, files in os.walk(tmp):
        if root == os.path.join(tmp, "repo"):
            dirs[:] = [name for name in dirs if name != ".git"]
        if "PWNED" in files or "PWNED" in dirs:
            return os.path.join(root, "PWNED")
    return None


def run_case(tmp, clone, runner, shell, plants, expect):
    git(clone, "reset", "--quiet", "--hard")
    git(clone, "clean", "--quiet", "-fdx")
    try:
        plant(clone, plants)
    except (OSError, RuntimeError) as err:
        return "could not plant the case: %s" % err
    proc = subprocess.run([shell, runner], cwd=clone, env=ENV, stdin=subprocess.DEVNULL, capture_output=True)
    why = judge(expect, proc.returncode, proc.stdout.decode("utf-8", "replace"), proc.stderr.decode("utf-8", "replace"))
    ran = planted_file(tmp)
    if ran:
        why = (why + "; " if why else "") + "a command planted in a file name ran and made " + ran
    return why


def main():
    parser = argparse.ArgumentParser(description="Regression cases for check_directory_policy in scripts/check.sh.")
    parser.add_argument("--gate", default=os.path.join(REPO, "scripts", "check.sh"),
                        help="the copy of check.sh whose check_directory_policy runs (default: scripts/check.sh)")
    gate = os.path.abspath(parser.parse_args().gate)
    shell = shutil.which(ENV.get("BASH_UNDER_TEST", "bash"), path=ENV.get("PATH"))
    if not shell:
        sys.exit("tests/directory-policy.py: no shell %s" % ENV.get("BASH_UNDER_TEST", "bash"))
    version = subprocess.run([shell, "-c", 'echo "$BASH_VERSION"'], env=ENV, stdin=subprocess.DEVNULL,
                             capture_output=True).stdout.decode("utf-8", "replace").strip()
    label = os.path.relpath(gate, REPO) if gate.startswith(REPO + os.sep) else gate
    passed = failed = 0
    with tempfile.TemporaryDirectory(prefix="directory-policy.") as tmp:
        clone = clone_head(tmp)
        runner = write_runner(gate, clone)
        why = run_case(tmp, clone, runner, shell, [], None)
        if why:
            print("FAIL  baseline: the clone of HEAD, with nothing planted: %s" % why)
            print("tests/directory-policy.py: stopped, because no case can be judged (gate: %s)" % label)
            return 1
        for name, plants, expect in cases():
            why = run_case(tmp, clone, runner, shell, plants, expect)
            if why:
                failed += 1
                print("FAIL  %s: %s" % (name, why))
            else:
                passed += 1
    print("tests/directory-policy.py: %d passed, %d failed (gate: %s, shell: %s)" % (passed, failed, label, version))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
