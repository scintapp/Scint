#!/usr/bin/env python3
"""Draft Scint Command.Parameter declarations from a fish completion script.

    dew --generate-completion-script fish | script/draft-parameters.py dew --usage
    script/draft-parameters.py codex ~/.config/fish/completions/codex.fish --path "codex exec"

Completions describe flags, whether they take a value, literal choices, and file
arguments. They don't describe positionals; --usage recovers those from each
subcommand's `--help` USAGE line (this runs the tool).
"""

import argparse, re, shlex, subprocess, sys
from collections import OrderedDict

VALUE_LETTERS = set("cnsloadwp")
QUOTE = "\u0001"
SKIP = {"help", "version", "h", "V"}


def logical_lines(text):
    buf = ""
    for line in text.splitlines():
        buf = f"{buf}\n{line}" if buf else line
        if not buf.lstrip().startswith("complete"):
            buf = ""
            continue
        try:
            yield shlex.split(buf.replace("\\'", QUOTE))
            buf = ""
        except ValueError:
            continue  # unbalanced quotes: keep reading


def parse_complete(tokens):
    spec = {"s": [], "l": [], "o": [], "flags": set()}
    i = 1
    while i < len(tokens):
        tok = tokens[i]
        if tok.startswith("--"):
            i += 1
            continue
        if tok.startswith("-") and len(tok) > 1:
            letters = tok[1:]
            for j, ch in enumerate(letters):
                if ch in VALUE_LETTERS and j == len(letters) - 1:
                    i += 1
                    value = tokens[i].replace(QUOTE, "'") if i < len(tokens) else ""
                    if ch in "slo":
                        spec[ch].append(value)
                    else:
                        spec[ch] = value
                else:
                    spec["flags"].add(ch)
        i += 1
    return spec


def command_path(tool, condition):
    if not condition:
        return (tool,), False
    quoted = re.search(r'should_offer_completions_for_\w+\s+"([^"]+)"(.*)$', condition)
    if quoted:  # swift-argument-parser
        path = tuple(quoted.group(1).split())
        tail = quoted.group(2).strip()
        repeatable = "flags_or_options" in condition and tail == ""
        return path, repeatable
    path = [tool]
    using = re.search(r"using_subcommand\s+([\w.-]+)", condition)
    if using:
        path.append(using.group(1))
    for seen in re.finditer(r"(not\s+)?__fish_seen_subcommand_from\s+([\w.-]+)", condition):
        if not seen.group(1):
            path.append(seen.group(2))
    return tuple(path), False


def choices(raw):
    if not raw or raw.startswith("("):
        return []
    values = []
    for entry in re.split(r"\n+", raw.strip()):
        if entry.strip().startswith("#"):
            continue
        for word in (entry.split("\\t")[0].split("\t")[0]).split():
            values.append(word.strip("'\""))
    values = [v for v in values if v]
    if len(values) > 20 or any("{" in v for v in values):
        return ["…"]  # too many, or brace-expanded: suggestions, not a closed set
    return values


def collect(tool, text):
    commands = OrderedDict()
    for tokens in logical_lines(text):
        spec = parse_complete(tokens)
        path, repeatable = command_path(tool, spec.get("n", ""))
        if "help" in path[1:] or (spec.get("a") == "help" and not (spec["l"] or spec["s"] or spec["o"])):
            continue
        node = commands.setdefault(path, {"options": OrderedDict(), "children": OrderedDict(), "desc": ""})
        names = spec["l"] + spec["o"] + spec["s"]
        if not names:
            for child in choices(spec.get("a", "")):
                commands.setdefault(path + (child,), {"options": OrderedDict(), "children": OrderedDict(), "desc": ""})["desc"] = spec.get("d", "")
                node["children"][child] = spec.get("d", "")
            continue
        if set(names) & SKIP:
            continue
        key = f"--{spec['l'][0]}" if spec["l"] else (f"-{spec['o'][0]}" if spec["o"] else f"-{spec['s'][0]}")
        desc = spec.get("d", "").replace(QUOTE, "'")
        dynamic = spec.get("a", "")
        node["options"].setdefault(key, {
            "desc": desc,
            "takes": bool(spec["flags"] & {"r", "x"}),
            "files": "F" in spec["flags"] or "__fish_complete_path" in dynamic,
            "dirs": "__fish_complete_directories" in dynamic,
            "choices": choices(dynamic),
            "repeatable": repeatable or "repeatable" in desc.lower(),
        })
    return commands


def usage_positionals(path):
    try:
        out = subprocess.run(list(path) + ["--help"], capture_output=True, text=True, timeout=5).stdout
    except Exception:
        return []
    match = re.search(r"^\s*usage:\s*(.+)$", out, re.I | re.M)
    if not match:
        return []
    line = match.group(1)
    line = re.sub(r"\[--?[^\]]*\]", " ", line)                    # [--flag <v>]
    line = re.sub(r"--?[\w-]+(\s+<[^>]+>)?(\s*\.\.\.)?", " ", line)  # --flag <v> ...
    found = []
    for m in re.finditer(r"(\[)?<([\w-]+)>(\])?|\[([A-Z][A-Z_-]*)\]", line):
        name = (m.group(2) or m.group(4)).lower()
        if name in {"options", "command", "subcommand"}:
            continue
        found.append((name, m.group(4) is None and not m.group(1)))
    return found


def camel(words):
    parts = re.split(r"[^A-Za-z0-9]+", " ".join(words))
    parts = [p for p in parts if p]
    return parts[0].lower() + "".join(p.capitalize() for p in parts[1:]) if parts else "command"


def control(opt):
    if opt["choices"]:
        short = len(opt["choices"]) <= 5 and all(len(c) <= 12 for c in opt["choices"])
        return "segmented control" if short else "pop-up button"
    if opt["repeatable"]:
        return "token field · repeatable"
    return "text field"


def emit(tool, commands, only, positionals):
    artifact = camel([tool, "cli"])
    out = [f'let {artifact} = artifact("{tool}", URL(fileURLWithPath: "{resolve(tool)}"))', ""]
    options = {k: v["options"] for k, v in commands.items()}
    for path, node in commands.items():
        if only and " ".join(path) != only:
            continue
        if node["children"] and not node["options"] and len(path) > 1:
            continue
        name = " ".join(w.capitalize() for w in path)
        lines = [f"// {' '.join(path)}" + (f" — {node['desc']}" if node["desc"] else "")]
        lines.append(f'let {camel(path)} = command("{name}", {artifact}, [')
        body = [f'    .fixed(.string("{w}")),' for w in path[1:]]
        if positionals:
            for pname, required in usage_positionals(path):
                body.append(f'    .argument(name: "{pname}", type: .string(""), required: {str(required).lower()}),  // text field · positional')
        if node["children"]:
            body.append(f"    // subcommands: {', '.join(node['children'])}")
        opts = node["options"]
        for key, opt in opts.items():
            label = key.lstrip("-")
            if label.startswith("no-") and f"--{label[3:]}" in opts:
                continue
            if not opt["takes"]:
                pair = f"--no-{label}" in opts
                kind = f"negatable flag {key} / --no-{label}" if pair else f"flag {key}"
                body.append(f"    // {kind}: bare flag, no Value shape yet → toggle{' with Default' if pair else ''}")
                continue
            guessed = not (opt["files"] or opt["dirs"]) and re.search(r"\b(directory|folder)\b|\b(path|file) (to|of|for)\b", opt["desc"], re.I)
            if opt["choices"] == ["…"]:
                body.append(f'    .argument(name: "{camel([label])}", type: .collection(["{key}": .string("")])),  // combo box (long suggestion list in completions)')
                continue
            if opt["choices"]:
                inner = ".sequence([" + ", ".join(f'.string("{c}")' for c in opt["choices"]) + "])"
            elif opt["files"] or opt["dirs"] or guessed:
                inner = ".reference(Artifact.self)"
                if opt["repeatable"]:
                    inner = f".sequence({inner})"
            elif opt["repeatable"]:
                inner = '.sequence(.string(""))'
            else:
                inner = '.string("")'
            note = control(opt) if inner != ".reference(Artifact.self)" and not inner.startswith(".sequence(.reference") else "path control"
            if guessed:
                note += " (guessed from description)"
            body.append(f'    .argument(name: "{camel([label])}", type: .collection(["{key}": {inner}])),  // {note}')
        lines += body
        desc = node["desc"].replace('"', '\\"')
        lines.append(f'], description: "{desc}")' if desc else "])")
        out += lines + [""]
    return "\n".join(out)


def resolve(tool):
    try:
        return subprocess.run(["which", tool], capture_output=True, text=True).stdout.strip() or f"/usr/local/bin/{tool}"
    except Exception:
        return f"/usr/local/bin/{tool}"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tool")
    ap.add_argument("file", nargs="?", default="-", help="fish completion script, or - for stdin")
    ap.add_argument("--path", help='only this command path, e.g. "codex exec"')
    ap.add_argument("--usage", action="store_true", help="run `<path> --help` to recover positionals")
    args = ap.parse_args()
    text = sys.stdin.read() if args.file == "-" else open(args.file).read()
    print(emit(args.tool, collect(args.tool, text), args.path, args.usage))


if __name__ == "__main__":
    main()
