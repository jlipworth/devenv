#!/usr/bin/env bash
# ci/neovim-smoke.sh
# Headless Neovim bootstrap smoke test for Linux CI / containers.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$ROOT_DIR"

export CI="${CI:-true}"
export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"
export NVIM_DISABLE_AUTO_INSTALLS="${NVIM_DISABLE_AUTO_INSTALLS:-1}"

TEST_HOME="${TEST_HOME:-$(mktemp -d "${TMPDIR:-/tmp}/devenv-nvim-smoke.XXXXXX")}"
cleanup() {
    if [[ "${KEEP_TEST_HOME:-0}" != "1" ]]; then
        rm -rf "$TEST_HOME"
    else
        echo "Keeping TEST_HOME=$TEST_HOME"
    fi
}
trap cleanup EXIT

export HOME="$TEST_HOME"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

echo "=== Neovim smoke: isolated HOME is $TEST_HOME ==="
NVIM_INSTALL_MODE="${NVIM_INSTALL_MODE:-source}"
if [[ "$NVIM_INSTALL_MODE" == "source" ]]; then
    export CI_INSTALL="${CI_INSTALL:-true}"
fi

echo "=== Step 1: install/configure Neovim ==="
if [[ "$NVIM_INSTALL_MODE" == "source" ]]; then
    make neovim
elif [[ "$NVIM_INSTALL_MODE" == "package" ]]; then
    make neovim-package
else
    echo "Unsupported NVIM_INSTALL_MODE=$NVIM_INSTALL_MODE" >&2
    exit 1
fi
hash -r
if [[ -d /home/linuxbrew/.linuxbrew/bin ]]; then
    export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"
nvim --version | head -1

echo "=== Step 2: verify config symlink ==="
test -L "$XDG_CONFIG_HOME/nvim"
test "$(readlink "$XDG_CONFIG_HOME/nvim")" = "$ROOT_DIR/nvim"

echo "=== Step 3: install plugins at the pinned lockfile revisions ==="
# Deliberately not `Lazy! sync`: the config dir is a symlink to $ROOT_DIR/nvim,
# so a sync would move plugins to upstream HEAD and rewrite the repo's tracked
# nvim/lazy-lock.json. `install` clones anything missing, `restore` checks every
# plugin out at the locked revision (lazy.nvim's restore only touches plugins
# that are already installed, so install must run first).
nvim --headless "+Lazy! install" "+Lazy! restore" +qa

echo "=== Step 4: install representative Mason packages ==="
MASON_PACKAGES=(
    bash-language-server
    css-lsp
    emmet-ls
    html-lsp
    prettier
    ruff
    shellcheck
    texlab
)
export CI_MASON_PACKAGES
CI_MASON_PACKAGES="$(
    IFS=,
    echo "${MASON_PACKAGES[*]}"
)"
export CI_MASON_TIMEOUT_MS="${CI_MASON_TIMEOUT_MS:-180000}"
# Explicitly load mason.nvim before calling :MasonInstall. Relying on Lazy's
# cmd-handler autoload works, but on macOS the r-languageserver install can emit
# a noisy callback error ("Vim:Cloning into '.'...") even though the install
# succeeds. Pre-loading the plugin avoids that path.
nvim --headless \
    "+lua require('lazy').load({ plugins = { 'mason.nvim' } })" \
    "+MasonInstall ${MASON_PACKAGES[*]}" \
    "+luafile $ROOT_DIR/ci/nvim-wait-for-mason.lua" \
    +qa

for pkg in "${MASON_PACKAGES[@]}"; do
    test -d "$XDG_DATA_HOME/nvim/mason/packages/$pkg"
done

echo "=== Step 5: final startup smoke ==="
COLOR_FILE="$TEST_HOME/colors_name.txt"
nvim --headless "+lua vim.fn.writefile({vim.g.colors_name or 'nil'}, '$COLOR_FILE')" +qa > /dev/null 2>&1
test "$(cat "$COLOR_FILE")" = "tokyonight-night"

echo "=== Step 6: headless Lua specs ==="
"$ROOT_DIR/tests/nvim/run_nvim_tests.sh"

echo "=== Step 7: tex buffer assertions ==="
# Proves the tex filetype path wires up end to end: VimTeX's <localleader>ll
# and the <localleader>oc date map from nvim/lua/config/autocmds.lua are both
# buffer-local FileType products, so their presence means the FileType autocmds
# ran to completion on a real .tex buffer.
TEX_FILE="$TEST_HOME/smoke.tex"
cat > "$TEX_FILE" <<'TEX'
\documentclass{article}
\begin{document}
hello
\end{document}
TEX

TEX_ASSERT="$TEST_HOME/tex-assert.lua"
cat > "$TEX_ASSERT" <<'LUA'
local localleader = vim.g.maplocalleader or "\\"

local function mapped(lhs)
  return vim.fn.maparg(localleader .. lhs, "n") ~= ""
end

-- The maps are installed from FileType autocmds that LazyVim only registers on
-- VeryLazy, so poll rather than assert immediately.
vim.wait(60000, function()
  return mapped("ll") and mapped("oc")
end, 200)

local problems = {}
if not mapped("ll") then
  table.insert(problems, "VimTeX did not map <localleader>ll in a tex buffer")
end
if not mapped("oc") then
  table.insert(problems, "tex FileType autocmds did not map <localleader>oc")
end
if #problems > 0 then
  io.stderr:write(table.concat(problems, "\n") .. "\n")
  vim.cmd("cq! 1")
end
print("tex buffer assertions passed (filetype=" .. vim.bo.filetype .. ")")
LUA

nvim --headless "$TEX_FILE" "+luafile $TEX_ASSERT" +qa

echo "=== Step 8: treesitter parser install ==="
# NVIM_DISABLE_AUTO_INSTALLS=1 leaves ensure_installed empty on purpose, so the
# parser is installed explicitly here rather than as a startup side effect.
TS_ASSERT="$TEST_HOME/ts-assert.lua"
cat > "$TS_ASSERT" <<'LUA'
local timeout_ms = tonumber(vim.env.CI_TS_TIMEOUT_MS or "300000")

require("lazy").load({ plugins = { "nvim-treesitter" } })
vim.cmd("TSInstall! python")

local function installed()
  return #vim.api.nvim_get_runtime_file("parser/python.*", false) > 0
end

vim.wait(timeout_ms, installed, 500)

if not installed() then
  io.stderr:write("python treesitter parser was not installed\n")
  vim.cmd("cq! 1")
end
print("treesitter python parser installed")
LUA

nvim --headless "+luafile $TS_ASSERT" +qa

echo "=== Neovim smoke passed (${NVIM_INSTALL_MODE}) ==="
