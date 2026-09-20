# Dependency choices

## Automated updates

The **Update dependencies** workflow runs Mondays at 06:23 UTC and supports
manual dispatch. It runs `bash scripts/update-dependencies.sh`: refresh all flake
inputs, enter the newly locked Nix shell, update Go production/test dependencies
with `go get -u -t ./...`, tidy/verify modules, and regenerate `vendorHash` with
`nix-update`. Native libraries and build tools update through nixpkgs. Go module
major-version migrations remain manual. Dependabot handles SHA-pinned GitHub
Actions only; standalone Go bumps would leave the Nix vendor hash stale.

Each changed run pushes a fresh branch and opens a PR without rewriting existing
branches. No changes means no PR. The workflow explicitly dispatches CI on the
branch: bot-created PR checks may be suppressed or require approval, but GitHub
allows workflow dispatch. The updater enables native GitHub squash auto-merge
only for the PR it creates. Failed checks leave the PR open for investigation.
No personal access token is required.

Repository settings must enable auto-merge and allow GitHub Actions to create
pull requests. Protect `main` with required checks `checks / Linux (x86_64-linux)`
and `checks / Linux (aarch64-linux)` from GitHub Actions, and require branches to
be up to date before merging. These repository-side settings are essential:
`gh pr merge --auto` alone is not a CI gate on an unprotected branch. Required
checks apply to all PRs; automatic merging is enabled only for weekly updates.
If `main` advances, update the PR branch and rerun CI before it can merge.
Merges using `GITHUB_TOKEN` do not trigger ordinary push workflows; the required
pre-merge CI provides validation for these updates.

The updater uses the maintained MIT-licensed `nix-update`, pinned through
`flake.lock`, rather than implementing Nix hash-mismatch parsing. Its releases,
substantive fixes, and automated tests cover Go vendor hashes and flake outputs.
`nixpkgs-update` targets mass updates in nixpkgs rather than this local package.
The existing GitHub CLI handles PR creation and CI dispatch; a separate PR action
would add another dependency and typically rewrite an existing update branch.

## CLI and configuration

The service uses **Cobra v1.10.2** and **Koanf v2.3.6**, with pinned YAML, TOML,
JSON, confmap, and posflag modules. Dependencies and checksums are in `go.mod` and
`go.sum`; Nix also pins the vendored source hash.

The selection compared these maintained projects:

- [Cobra](https://github.com/spf13/cobra): command routing, generated help and shell
  completions; established Apache-2.0 project with releases, CI, and substantive
  fixes to completion/validation behavior. It uses pflag for parsing flags.
- [Koanf](https://github.com/knadh/koanf): MIT-licensed configuration library with
  current releases, tests, and separately versioned parsers/providers. Its
  explicit merge order and case-sensitive keys fit our small service schema.
- [Viper](https://github.com/spf13/viper): established MIT-licensed alternative
  with convenient Cobra bindings. It would meet the requirements, but implicit
  precedence/case-insensitive keys and a broader dependency surface are not
  necessary here. It was evaluated, not retained as a dependency.
- [Kong](https://github.com/alecthomas/kong): maintained MIT-licensed, struct-driven
  CLI with configuration resolvers. Attractive for a compact declarative CLI,
  but replacing Cobra is not needed for Koanf integration.
- [urfave/cli](https://github.com/urfave/cli): actively maintained MIT-licensed
  CLI framework; viable, but offers no decisive advantage for these commands.

Koanf consumes parsed flags through its posflag provider; it is not itself an
argument parser. Cobra provides the subcommands. We use Koanf's published parsers
instead of implementing YAML/TOML/JSON parsing or a precedence engine ourselves.
Only the application-specific schema, validation, bounded file reading, and XDG
selection rules remain local. No environment or remote configuration providers
are enabled, and no global configuration singleton is used.

Strict decoding uses the maintained `go-viper/mapstructure/v2` library that Koanf
itself depends on. That module's name does not mean the Viper configuration
framework is used. Tests cover case sensitivity, partial configuration, explicit
false flags, invalid input, file selection, and actual service behavior.

Before changing or adding dependencies, follow `AGENTS.md`: inspect maintenance,
compatibility, tests, licensing, and dependency burden rather than popularity
alone. Security-sensitive PIN/HID behavior remains behind its existing boundaries.
