# Neovim Debug + Polish — Design

Date: 2026-04-12
Status: Draft (awaiting user review)
Branch: `feature/nvim-parity`
Scope: Sub-project 4 of 4 (final) in the Neovim Spacemacs-parity pass.

## 1. Goal & Non-Goals

### Goal

Close the last gaps in Spacemacs parity for Neovim, then lock the config
against silent plugin rot. Specifically:

1. **Debugging** for Python and JS/TS via `nvim-dap`, wired through
   LazyVim's pre-baked extras so we inherit their keymap layout and
   adapter auto-install without custom code.
2. **Multi-cursor** editing via `mg979/vim-visual-multi`, which the user
   reaches for occasionally and wants available.
3. **Spell check** — confirm LazyVim's built-in `:set spell` behaves
   correctly with the dictionary layout in this environment. No plugin.
4. **Snippet parity** — port the six Yasnippet templates in `snippets/`
   to LuaSnip's VSCode-style JSON format so the same triggers work in
   both editors.
### Non-Goals

- **New language-DAP support beyond Python + JS/TS.** LazyVim has extras
  for Go, Rust, etc.; the user has not asked for them in this round.
- **nvim-dap key rebinding.** Accept LazyVim's `<leader>d*` defaults
  verbatim. Any rebind is a follow-up, not this spec.
- **Multi-cursor on top of LSP-rename workflows.** Visual-multi is a
  manual tool, not an IDE-grade rename. Users who need rename use `grn`.
- **Custom spell dictionaries / technical-term lists.** Out of scope.
  Only standard `en` is verified.
- **Porting Yasnippet snippets from Spacemacs private layers outside the
  tracked `snippets/` directory.** Anything not in Git is personal; the
  repo only owns what's in Git.
- **Plugin-freshness audit tooling.** Originally in-scope; removed.
  Per-plugin decisions live in the spec/PR, not a committed script.

### Success Criteria

1. `NVIM_APPNAME=nvim_parity_debug nvim --headless` loads cleanly after
   all changes; plugin count increases in a known, bounded way.
2. In a Python file, `<leader>db` sets a breakpoint, `<leader>dc`
   launches debugpy, DAP-UI opens, and `<leader>dPt` debugs the pytest
   method under cursor.
3. In a `.ts` file, `<leader>dc` launches `js-debug-adapter` and stops
   at the configured entrypoint.
4. `<C-n>` on a word in normal mode starts a vim-visual-multi session
   and subsequent `<C-n>` presses add matches. `<Esc>` exits cleanly.
5. `:set spell` on a `.md` buffer highlights misspellings. Dictionary
   download instructions are documented.
6. `require("luasnip").get_snippets("tex")` returns at least 6 entries
   matching the ported Yasnippets' triggers.
7. No regression: Jupyter cells/repl tests and claudecode module load
   still pass.

## 2. Plugin Stack

| Component | Plugin / Source | Maintenance status (2026-04-12) |
|---|---|---|
| DAP core + UI + virtual text | `mfussenegger/nvim-dap` + `rcarriga/nvim-dap-ui` + `theHamsta/nvim-dap-virtual-text` via `lazyvim.plugins.extras.dap.core` | LazyVim-maintained; extras are the canonical wiring, pinned via `lazy-lock.json` |
| Python DAP adapter | `mfussenegger/nvim-dap-python` via `lazyvim.plugins.extras.lang.python` (already imported? verify) | LazyVim extra; debugpy auto-installed via Mason |
| JS/TS DAP adapter | `js-debug-adapter` (vscode-js-debug) via `lazyvim.plugins.extras.lang.typescript` | LazyVim extra; adapter auto-installed via Mason |
| Mason DAP bridge | `jay-babu/mason-nvim-dap.nvim` (comes with `extras.dap.core`) | Tracks mason-registry |
| Multi-cursor | `mg979/vim-visual-multi` | Last commit 2024-09-01 (~19 mo as of 2026-04-12). Feature-complete and widely used; acceptable risk. |
| Snippet engine | `L3MON4D3/LuaSnip` + `rafamadriz/friendly-snippets` | Already present in LazyVim base; no plugin delta |

Net plugin delta expected after this sub-spec:

- `extras.dap.core` pulls: nvim-dap, nvim-dap-ui, nvim-dap-virtual-text,
  nvim-nio (dep of dap-ui), mason-nvim-dap. Net ~5 plugins.
- `extras.lang.python` adds: nvim-dap-python, venv-selector.nvim,
  neotest-python (if neotest loaded). Net ~2-3 plugins.
- `extras.lang.typescript` adds: the ts LSP extra chain (vtsls by
  default) + js-debug-adapter via Mason (adapter is a Mason package,
  not a lazy plugin, so 0 plugin count delta from the adapter itself).
  Net ~1-2 plugins.
- vim-visual-multi: +1.
- LuaSnip loader: +0 (already present; we only add a snippets path).

Total plugin delta: roughly **+9 to +11**. Exact number recorded
during plan Task 8 validation.

### Rejected alternatives

- **`hrsh7th/vim-vsnip` instead of LuaSnip.** LuaSnip is LazyVim's
  default; swapping would mean maintaining our own spec and losing
  friendly-snippets integration. No upside.
- **`terryma/vim-multiple-cursors`** (the older multi-cursor plugin).
  Last meaningful commit 2019, explicitly deprecated by its author in
  favor of vim-visual-multi. Rejected.
- **`smjonas/multicursors.nvim`** (newer Lua-native option). Smaller
  community, fewer supported commands; the user has muscle memory for
  vim-visual-multi's `<C-n>` and that is the decisive factor.
- **`vim-test/vim-test` + `nvim-neotest/neotest` wired to DAP** for
  debug-on-test ergonomics. LazyVim already wires neotest-python when
  the python extra is active; adding vim-test on top is redundant.
- **`spellsitter.nvim`** for treesitter-aware spell. Nice-to-have, not
  needed for parity with Spacemacs's default flyspell; defer.
### No-abandonware check (this sub-spec's new plugins)

- **vim-visual-multi**: last commit 2024-09-01. The plugin is functionally
  complete and still the canonical Vim multi-cursor tool; issues get
  community patches. Accepted.
- **nvim-dap family**: LazyVim-maintained extras; all underlying repos
  (mfussenegger/nvim-dap, rcarriga/nvim-dap-ui, dap-python,
  dap-virtual-text) had commits within the last 3 months as of spec
  write. Green.

## 3. Keymap Layout

All debug bindings come from LazyVim's `extras.dap.core` and
`extras.lang.python`. We do NOT override them.

### Debug — `<leader>d` subtree (group label "debug")

| Keys | Action | Source |
|---|---|---|
| `<leader>db` | Toggle breakpoint | extras.dap.core |
| `<leader>dB` | Breakpoint with condition (prompts) | extras.dap.core |
| `<leader>dc` | Run / Continue | extras.dap.core |
| `<leader>dC` | Run to cursor | extras.dap.core |
| `<leader>da` | Run with args (prompts) | extras.dap.core |
| `<leader>dg` | Go to line (no execute) | extras.dap.core |
| `<leader>di` | Step into | extras.dap.core |
| `<leader>dj` | Down (frame) | extras.dap.core |
| `<leader>dk` | Up (frame) | extras.dap.core |
| `<leader>dl` | Run last | extras.dap.core |
| `<leader>do` | Step out | extras.dap.core |
| `<leader>dO` | Step over | extras.dap.core |
| `<leader>dP` | Pause | extras.dap.core |
| `<leader>dr` | Toggle REPL | extras.dap.core |
| `<leader>ds` | Session | extras.dap.core |
| `<leader>dt` | Terminate | extras.dap.core |
| `<leader>dw` | Widgets / hover | extras.dap.core |
| `<leader>du` | Toggle DAP UI | extras.dap.core (dap-ui block) |
| `<leader>de` | Evaluate expression (n, x) | extras.dap.core (dap-ui block) |
| `<leader>dPt` | Debug test method (ft=python) | extras.lang.python |
| `<leader>dPc` | Debug test class (ft=python) | extras.lang.python |

### Multi-cursor — `<C-n>` et al. (vim-visual-multi defaults)

| Keys | Mode | Action |
|---|---|---|
| `<C-n>` | normal / visual | Start session, select word / range under cursor; repeated press adds next match |
| `<C-Up>` / `<C-Down>` | normal | Add cursor above / below |
| `<S-Left>` / `<S-Right>` | normal | Extend selection of all cursors |
| `n` / `N` | VM | Next / previous match |
| `q` | VM | Skip current, select next |
| `Q` | VM | Remove current cursor |
| `<Esc>` | VM | Exit multi-cursor mode |

We will not re-document the full VM cheatsheet; `:help visual-multi`
and upstream wiki remain the canonical reference. The bindings above
are the minimum the user asked to have written down.

### `<C-n>` conflict analysis

- **Normal mode**: LazyVim does not bind `<C-n>` in normal mode out of
  the box. `Ctrl-n` in normal mode traditionally scrolls down one
  line; it is a single-line operation rarely used when `j`/`<C-d>`
  exist. Visual-multi claims `<C-n>` in normal/visual modes; the
  (negligible) loss of `j`-like scroll is acceptable.
- **Insert mode**: nvim-cmp's extra (if loaded) binds `<C-n>` in
  insert mode to "next completion item." Visual-multi does NOT map
  insert-mode `<C-n>`, so there is no conflict.
- **Neo-tree / other filetype plugins**: `<C-n>` is not reserved by
  any LazyVim default tree / picker binding we grep'd. Safe.

No rebinding is required. If a future conflict surfaces, the escape
hatch is `let g:VM_maps = { 'Find Under': '<C-d>' }` in the plugin
spec's `init` function (standard VM pattern).

### Which-key

- `<leader>d` group label comes from LazyVim's `extras.dap.core` (it
  registers "debug" as the group name via which-key). No repo wiring.
- `<leader>dP` sub-group for Python debug surfaces automatically from
  the extras.lang.python key entries.

## 4. Spell Checking

### LazyVim default behavior

LazyVim sets `vim.opt.spell = true` for `gitcommit` and `markdown`
filetypes out of the box (see
`lazyvim/lua/lazyvim/plugins/extras/editor/`-adjacent autocmds). We do
not override; we just document.

### Dictionary file path

Neovim stores downloaded `.spl` files under `stdpath("data") .. /site/spell/`,
which resolves to `~/.local/share/nvim_parity_debug/site/spell/` under
the test app-name, and `~/.local/share/nvim/site/spell/` under the
user's normal config. First time the user does `:setlocal spell` on a
buffer with an unrecognized language, Neovim prompts to download the
`.spl`. No scripting needed.

### Validation

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'setlocal spell spelllang=en_us' \
  -c 'lua print(vim.o.spell, vim.o.spelllang)' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `true    en_us`.

### Documentation

Append a "Spell check" subsection to `docs/NEOVIM_KEYBINDINGS.md`
covering:

- `z=` — suggest replacements under cursor.
- `]s` / `[s` — jump to next / previous misspelling.
- `zg` / `zw` — mark word good / wrong (adds to spellfile).
- Where `.spl` lives; how to force a download with `:set spell` in an
  interactive session if auto-download was declined.

No code change beyond the doc append.

## 5. Snippet Parity

### Source inventory

`snippets/` contains exactly **6 Yasnippets**, all under
`snippets/latex-mode/`:

| File | Trigger (key) | Name | Body pattern |
|---|---|---|---|
| `align_star` | `al*` | align* | `\begin{align*}...\end{align*}` |
| `equation_star` | `eq*` | equation* | `\begin{equation*}...\end{equation*}` |
| `section_star` | `secc` | section* | `\section*{...}` |
| `subsection_star` | `subb` | subsection* | `\subsection*{...}` |
| `textit` | `i` | textit | `\textit{...}` |
| `underline` | `u` | underline | `\underline{...}` |

(Full bodies listed; no other snippets exist anywhere in the repo.
`snippets/README.md` confirms this directory is the authoritative
source.)

Because the count is 6 — well under the user's "split if >20" threshold
— the port fits in **one** plan task.

### Target format: LuaSnip VSCode-style JSON

LuaSnip supports three loader styles:

1. **VSCode** — JSON files grouped under a directory with a
   `package.json`. Loaded via `require("luasnip.loaders.from_vscode").lazy_load({ paths = { ... } })`.
2. **SnipMate** — `.snippets` plain-text files.
3. **Lua** — native Lua tables.

We pick **VSCode-style JSON** because:

- It mirrors how `friendly-snippets` already ships, keeping loader
  configuration uniform.
- The JSON format is portable: the user can paste the same files into
  VSCode's `~/.config/Code/User/snippets/` if they ever want.
- Syntax is compact and the six snippets translate trivially.

### Target layout

```
nvim/
  snippets/
    package.json           # VSCode snippet manifest
    latex.json             # The six ported snippets
```

`package.json` declares one contribution pointing `language: ["tex"]`
at `latex.json`. The spec contribution only; actual file contents land
in the plan.

### Trigger preservation

Yasnippet triggers (`al*`, `eq*`, `secc`, `subb`, `i`, `u`) map 1:1 to
LuaSnip `prefix` fields. The two short triggers (`i`, `u`) are risky
— they could fire mid-word — but that matches the Spacemacs behavior
the user has been living with, so preserve it. If the user files a
bug later, we'd add a `regex` condition; not done preemptively.

### Loader wiring

A new spec file `nvim/lua/plugins/snippets.lua` adds:

```lua
return {
  {
    "L3MON4D3/LuaSnip",
    opts = function(_, opts)
      opts.loaders = opts.loaders or {}
      return opts
    end,
    config = function(_, opts)
      require("luasnip").setup(opts)
      require("luasnip.loaders.from_vscode").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/snippets" },
      })
    end,
  },
}
```

(Exact form subject to plan refinement; the invariant is: LuaSnip gets
a `lazy_load` call pointing at `nvim/snippets/`.)

### Spacemacs symlink — leave alone

The existing `create_snippet_symlink()` in `prereq_packages.sh` keeps
wiring `snippets/` into `~/.emacs.d/private/snippets`. We do NOT remove
that; the source-of-truth yasnippets remain valid for Emacs. Neovim
reads the same six sources via the port, not via symlink.

## 7. Implementation Structure

### Files touched

- `nvim/lua/config/lazy.lua` — add three extras imports (`dap.core`,
  already-present or newly-added `lang.python`, `lang.typescript`).
- `nvim/lua/plugins/visual-multi.lua` — new local plugin spec.
- `nvim/lua/plugins/snippets.lua` — new LuaSnip loader wiring.
- `nvim/snippets/package.json` — new VSCode manifest.
- `nvim/snippets/latex.json` — new ported snippets.
- `docs/NEOVIM_KEYBINDINGS.md` — append Debug, Multi-cursor, Spell
  sections.

No deletions. No rewrites of existing files beyond appends.

### lazy.lua shape after this sub-spec

```lua
spec = {
  { "LazyVim/LazyVim", import = "lazyvim.plugins" },
  { import = "lazyvim.plugins.extras.ai.claudecode" },    -- sub-spec 2
  { import = "lazyvim.plugins.extras.dap.core" },         -- new
  { import = "lazyvim.plugins.extras.lang.python" },      -- new (or already present from jupyter work; verify)
  { import = "lazyvim.plugins.extras.lang.typescript" },  -- new
  { import = "plugins" },
},
```

Order: LazyVim first, then extras (extras can override defaults), then
local `plugins` (local can override extras). Matches the convention
established in sub-spec 2.

### visual-multi spec shape

```lua
return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    keys = {
      { "<C-n>", mode = { "n", "v" }, desc = "Multi-cursor: select next match" },
    },
    init = function()
      -- Leave g:VM_maps at defaults unless a conflict is observed.
    end,
  },
}
```

The `keys` entry triggers lazy-loading on first `<C-n>` press without
eager-loading at startup.

### Plan task boundaries

See companion plan. Roughly:

1. Add `dap.core` + verify Python extra is imported and wired.
2. Add `lang.typescript` extra for JS/TS debug.
3. Add vim-visual-multi spec + `<C-n>` conflict verification.
4. Verify spell works + doc update.
5. Port six LaTeX yasnippets to LuaSnip VSCode JSON.
6. Append Debug / Multi-cursor / Spell / Snippet sections to
   `docs/NEOVIM_KEYBINDINGS.md`.
7. Full validation pass (headless parse, plugin count, module loads,
   Jupyter regression, claudecode regression).

## 8. Testing Strategy

### Headless parse

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless -c 'qall' 2>&1 | tail -5
```

Expected: empty stderr, exit 0.

### Plugin count delta

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua print(require("lazy").stats().count)' \
  -c 'qall' 2>&1 | tail -3
```

Expected: a number between (pre-sub-spec count + 8) and (pre-sub-spec
count + 12). Exact value recorded in the plan during Task 8.

### DAP loads

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua require("dap"); require("dap-python"); print("OK")' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `OK`. For JS/TS, check that `dap.adapters["pwa-node"]` is
defined after opening a `.ts` buffer (the extra sets this lazily).

### Visual-multi loads

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'let g:VM_mouse_mappings = 0' \
  -c 'qall' 2>&1 | tail -3
```

Expected: empty. A `:h vim-visual-multi` style global is benign if the
plugin hasn't loaded yet (lazy-loaded on `<C-n>`), but once VM loads
the global suppresses mouse mappings.

### Snippets load

```bash
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua require("luasnip"); require("luasnip.loaders.from_vscode").lazy_load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })' \
  -c 'lua print(vim.tbl_count(require("luasnip").get_snippets("tex") or {}))' \
  -c 'qall' 2>&1 | tail -3
```

Expected: `6` (or more, if friendly-snippets contributes additional
`tex` snippets — then ≥ 6).

### Regression guards

```bash
# Jupyter tests still pass
bash tests/nvim/run_nvim_tests.sh 2>&1 | tail -5

# claudecode still loads
NVIM_APPNAME=nvim_parity_debug nvim --headless \
  -c 'lua require("claudecode")' -c 'qall' 2>&1 | tail -3
```

### Manual smoke (HUMAN-RUN, documented in plan Task 8)

1. Open a Python file, set a breakpoint with `<leader>db`, run with
   `<leader>dc`. Confirm DAP-UI opens.
2. Open a `.ts` file (create `/tmp/smoke.ts` if needed), set a
   breakpoint, run `<leader>dc`, pick the node launch config.
3. In any buffer, position on a word and press `<C-n>`. Confirm a
   multi-cursor session starts. Press `<C-n>` again to add the next
   match.
4. Open a `.md` file, ensure misspellings highlight. Press `z=` on
   one.
5. Open `/tmp/test.tex`, type `secc` + `<Tab>`. Confirm snippet
   expands.

### CI

Existing lint / Jupyter tests remain blocking. No new CI steps.

## 9. Risks & Open Questions

### Risks

1. **`extras.lang.python` import conflicts.** Sub-spec 1 (Jupyter)
   may or may not have already imported this extra. Plan Task 1 Step
   1 explicitly inspects `lazy.lua` and skips the import if already
   present. Re-importing is a no-op in lazy.nvim but looks messy.
2. **Mason adapter install flakiness.** `mason-nvim-dap` tries to
   install `debugpy` and `js-debug-adapter` on first run; network or
   registry flakes could leave adapters missing. Mitigation: the
   smoke test manually runs `:MasonInstall debugpy js-debug-adapter`
   as a fallback (documented, not automated).
3. **`<C-n>` insert-mode cmp clash.** Mitigated: vim-visual-multi
   does not bind insert-mode `<C-n>`. If a future cmp change DID
   bind normal-mode `<C-n>`, the `keys = { ... mode = { "n", "v" } }`
   in the local spec wins (local specs override extras per lazy.nvim
   resolution order). Verified in plan Task 3.
4. **Vim-visual-multi's 19-month age.** Plugin is feature-complete;
   community patches land in forks occasionally. If it becomes truly
   abandoned (>24 mo), a migration decision will need to happen. Not
   today's problem.
5. **LuaSnip `i` and `u` single-char triggers firing mid-word.** This
   matches Spacemacs yasnippet behavior, so it's a parity feature, not
   a regression. If the user finds it annoying, a one-line `regex`
   condition can gate expansion.

### Resolved decisions

- **Make target?** No. Script is invoked directly.
- **Keymap overrides for DAP?** None. Accept LazyVim defaults.
- **`<C-n>` rebind?** No. Conflict analysis confirms no clash.
- **Snippet format?** VSCode JSON (portable).
- **Batch yasnippet port?** Not needed; only 6 files — one task.
- **Plugin-freshness audit tooling?** Dropped — handled as skill/reference, not committed code.

### Open questions (defer to plan)

- **Exact plugin-count delta.** Plan Task 8 records it after real
  `:Lazy sync`. Spec gives a 3-unit band.

## 10. Out of Scope (for future work)

Not deferred to any other sub-spec — these are genuine follow-ups:

- DAP extras for Go / Rust / Java / Lua.
- Custom launch.json generator.
- Treesitter-aware spell (`spellsitter.nvim`).
- Technical-term dictionaries.
- Yasnippet → LuaSnip round-trip tooling (auto-regenerate one format
  from the other on commit).
- Audit script's `--update-map` flag that commits the map refresh.
- Full renovate.json integration to auto-bump lazy-lock.json.

This is the last sub-spec in the parity pass; there is no sibling
sub-spec 5.
