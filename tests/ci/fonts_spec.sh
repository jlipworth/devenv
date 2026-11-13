#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/fonts-spec.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

python3 - "$repo_root" "$tmp" <<'PY'
import contextlib, importlib.util, io, os, pathlib, sys, unittest.mock as mock
sys.dont_write_bytecode = True
root, temp = map(pathlib.Path, sys.argv[1:])
spec = importlib.util.spec_from_file_location("fonts", root / "bundled_fonts.py")
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
source = temp / "source/family"
source.mkdir(parents=True)
(source / "Meslo Test.ttf").write_bytes(b"font bytes")
(source / "Other.otf").write_bytes(b"other font bytes")

def invoke(args):
    with mock.patch.object(sys, "argv", ["fonts", *map(str, args)]):
        return p.main()

# Fresh macOS has no Library/Fonts; Linux retains ~/.fonts. Both must create
# the destination before copying, then verify exact bytes without mutation.
for system, relative in [("Darwin", "Library/Fonts"), ("Linux", ".fonts")]:
    home = temp / system
    with mock.patch.dict(os.environ, {"HOME": str(home)}), mock.patch.object(p.platform, "system", return_value=system):
        assert not (home / relative).exists()
        assert invoke(["install", "--source", source.parent]) == 0
        dest = home / relative
        assert (dest / "Meslo Test.ttf").read_bytes() == b"font bytes"
        assert invoke(["verify", "--source", source.parent, "--skip-icons"]) == 0
        (dest / "Other.otf").write_bytes(b"corrupt")
        assert invoke(["verify", "--source", source.parent, "--skip-icons"]) == 1
        assert invoke(["install", "--source", source.parent]) == 0
        assert invoke(["verify", "--source", source.parent]) == 1
        for name in p.ICONS:
            (dest / name).write_bytes(b"icon font")
        assert invoke(["verify", "--source", source.parent]) == 0
        (dest / p.ICONS[0]).write_bytes(b"")
        assert invoke(["verify", "--source", source.parent]) == 1

empty = temp / "empty"
empty.mkdir()
dest = temp / "failure-destination"
for missing_or_empty in [temp / "missing", empty]:
    assert invoke(["install", "--source", missing_or_empty, "--destination", dest]) == 1
    assert not dest.exists()

for failure in ["copy-error", "corrupt-copy"]:
    output = io.StringIO()
    def copy(src, dst):
        if failure == "copy-error":
            raise PermissionError("simulated denied copy")
        pathlib.Path(dst).write_bytes(b"corrupt")
    with mock.patch.object(p.shutil, "copy2", side_effect=copy), contextlib.redirect_stdout(output):
        assert invoke(["install", "--source", source.parent, "--destination", dest]) == 1
    assert "PASS:" not in output.getvalue()
    assert not list(dest.glob(".font-install-*"))
    assert not (dest / "Meslo Test.ttf").exists()

with mock.patch.dict(os.environ, {"DRY_RUN": "1"}):
    dry = temp / "dry-run"
    assert invoke(["install", "--source", source.parent, "--destination", dry]) == 0
    assert not dry.exists()
PY

# The caller must propagate font failure before any icon/plugin setup.
mkdir -p "$tmp/fixture"
cp "$repo_root/bundled_fonts.py" "$tmp/fixture/"
if HOME="$tmp/caller-home" GNU_DIR="$tmp/fixture" \
  "$repo_root/prereq_packages.sh" install_editor_prereqs >"$tmp/caller.log" 2>&1; then
  echo "editor prereqs incorrectly succeeded with a missing font source" >&2
  exit 1
fi
if grep -Fq 'Installing vim-plug' "$tmp/caller.log"; then
  echo "editor prereqs continued after font failure" >&2
  exit 1
fi
printf 'Bundled font install, verification, destination and failure propagation specs passed\n'
