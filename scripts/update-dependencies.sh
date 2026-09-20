#!/usr/bin/env bash
# Copyright Étienne Lafarge. SPDX-License-Identifier: Apache-2.0
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
nix flake update
# Enter the newly locked environment so Go and native libraries agree with CI.
nix develop --command bash -euo pipefail -c '
  go get -u -t ./...
  go mod tidy
  go mod verify
  nix-update --flake --version=skip --override-filename nix/package.nix ssh-askpass-fido
'
