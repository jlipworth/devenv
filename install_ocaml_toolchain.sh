#!/usr/bin/env bash
# Install the compatible editor toolchain in one constrained opam solve.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=versions.conf
source "$script_dir/versions.conf"

# Initialise metadata without first building opam's unrelated default compiler.
if ! opam var root &>/dev/null; then
  # CI containers and WSL may lack bubblewrap's namespaces; see DEPENDENCIES.md.
  opam init --bare --disable-sandboxing -a -y
fi
if ! opam switch show &>/dev/null; then
  opam switch create default --empty -y
else
  opam update
fi

# Do not run unconstrained `opam upgrade` first: that can rebuild the existing
# LSP against a newer, incompatible Stdune before these constraints are applied.
opam install -y \
  "ocaml-base-compiler.${OCAML_COMPILER_VERSION}" \
  "dune.${OCAML_DUNE_VERSION}" \
  "stdune.${OCAML_STDUNE_VERSION}" \
  "ocp-indent.${OCAML_OCP_INDENT_VERSION}" \
  "merlin.${OCAML_MERLIN_VERSION}" \
  "utop.${OCAML_UTOP_VERSION}" \
  "ocamlformat.${OCAMLFORMAT_VERSION}" \
  "ocaml-lsp-server.${OCAML_LSP_VERSION}"
