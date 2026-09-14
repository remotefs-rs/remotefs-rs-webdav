# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

`AGENTS.md` is a symlink to this file and holds the same agent contract.

## Commands

Every task runs through a [`just`](https://just.systems) recipe. Do not bypass a
recipe with an ad hoc `cargo` or tool command. If a recurring task has no
recipe, add one under `just/` before using it. Run `just` to list all recipes.

```sh
just build                 # cargo build --all-targets
just release               # release build
just test                  # cargo test --lib, then --doc
just containers_up         # start the WebDAV test container
just containers_down       # stop the WebDAV test container
just coverage              # cargo llvm-cov, writes lcov.info
just fmt                   # dprint fmt (Markdown, Rust, TOML, YAML)
just fmt_check             # dprint check
just lint "-- -D warnings" # alias of just clippy
just doc                   # cargo doc --no-deps with RUSTDOCFLAGS="-D warnings"
just deny                  # cargo deny check
just scan_secrets          # trufflehog filesystem
just check                 # the full local quality gate
just setup_githooks        # point core.hooksPath at .githooks
just changelog_preview 0.3.0
just changelog 0.3.0
just publish "--dry-run --allow-dirty"
```

`just check` is the required gate before declaring work done. It chains
`fmt_check`, Clippy with warnings denied, `doc`, `deny`, and `test`.

The tests in `src/client/container_tests.rs` are gated behind the
`with-containers` feature and need the WebDAV container from
`tests/docker-compose.yml` running locally. Start it with `just containers_up`,
then run `just test "--features with-containers,tokio"`. The mock-transport
unit tests in `src/client.rs`, `src/stream.rs`, `src/error.rs`,
`src/resource.rs`, and `src/url.rs` need no container.

If a required tool is missing, say so. Never claim a check passed or silently
swap in a weaker command.

## Architecture

remotefs-webdav is a [remotefs](https://github.com/remotefs-rs/remotefs-rs)
client implementation providing WebDAV access, as specified in
[RFC 4918](https://www.rfc-editor.org/rfc/rfc4918). It is a library-only crate
(`src/lib.rs`, crate name `remotefs_webdav`) with no binaries or examples.

- **One client.** `WebDAVFs<T>` in `src/client.rs` implements
  `remotefs::AsyncRemoteFs` over `dav_xml_client::AsyncDavClient<T>` (`T`
  defaults to the reqwest client; `with_transport` accepts any
  `AsyncTransport`). With the `tokio` feature, `into_blocking` wraps it in
  `remotefs::adapters::blocking::BlockOn` as `BlockingWebDAVFs`. Paths are
  absolute; `src/url.rs` validates them and builds URLs.
- **Transfers.** `src/stream.rs` holds the owned streams: reads are cursors
  over a downloaded (ranged) body, writes buffer and `PUT` on `finish`.
- **Errors.** `src/error.rs` maps `dav_xml_client::Error` onto
  `RemoteErrorType`, keeping the client error as source.
- **Entries.** `src/resource.rs` converts `PROPFIND` resources into
  `remotefs::File`.
- **Command layer.** `Justfile` is a thin importer. Each recipe group lives in
  its own file under `just/` (`build`, `test`, `code_check`, `changelog`,
  `publish`) and carries a `[group(...)]` attribute so `just --list` stays
  organized. Recipes take an `args=""` passthrough rather than hard-coding
  flags.
- **Formatting is dprint, not cargo fmt.** `dprint.json` owns Markdown, TOML,
  and YAML, and delegates `.rs` files to nightly rustfmt through its exec
  plugin (`--edition 2024`, matching this crate's `package.edition`).
  `rustfmt.toml` uses nightly-only options (`imports_granularity`,
  `group_imports`), which is why nightly is required. Always format with
  `just fmt`.
- **Release path.** Commits follow Conventional Commits and `cliff.toml` turns
  them into `CHANGELOG.md`. Publishing goes through `just publish`
  (`cargo publish --locked`); version bumps live in `Cargo.toml`.
- **Supply-chain policy.** `deny.toml` is strict: license allowlist,
  `yanked = "deny"`, `unmaintained = "all"`, wildcard versions denied, and
  crates.io as the only allowed source. It runs with `all-features = true`.
- **CI only runs the container-backed test suite on Linux.**
  `.github/workflows/ci.yml`'s `quality-macos` and `quality-windows` jobs build,
  lint, and run the container-free tests; `quality-linux` starts the
  `bytemark/webdav` container, runs the `find,tokio,with-containers` suite, and
  uploads coverage.

## Conventions

- Toolchain is pinned to Rust 1.98.0 (`rust-toolchain.toml`). `package.edition`
  in `Cargo.toml` is 2024 and `package.rust-version` is 1.94.1; do not bump
  either as part of unrelated changes.
- Public library items need canonical rustdoc, including a runnable example.
  `just test` runs doctests, and `just doc` denies warnings. The vendored
  `src/webdav_xml/` tree is exempt: it keeps upstream's documentation.
- Keep `Cargo.toml` dependency and feature entries alphabetically sorted, with
  bare minimal versions.
- Conventional Commits, imperative and lower-case. No agent attribution,
  session links, or agent `Co-Authored-By` lines.
- Do not stage planning state. `docs/superpowers/`, `.superpowers/`, and
  `.claude/plans/` are gitignored and dprint-excluded.
- After editing a Markdown file that contains a table, run
  `fmt-md-tables -i <file>`.
- After any change under `.github/workflows/`, run `zizmor .github/workflows`
  until it exits clean. Pin actions to a full commit SHA with the matching tag
  in a trailing comment, declare least-privilege permissions, and set
  `persist-credentials: false` on checkout.
