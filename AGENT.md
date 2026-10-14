# AGENT.md

## Project scope

- This repository is `bufexplorer.nvim`, a dependency-free Neovim buffer-list plugin.
- The Lua module name is `bufexplorer`.
- The user command must remain `:BufExplore`; do not rename it, because it must remain distinct from `jlanzarotta/bufexplorer` commands.
- Keep the plugin compatible with the supported Neovim version documented in `README.md`.
- Keep Edgy integration optional. The plugin must not require Edgy at runtime.

## Code and documentation conventions

- Use Lua formatting configured by `stylua.toml`.
- Use precise edits and preserve existing behavior unless the task explicitly changes it.
- Update `README.md` and `doc/bufexplorer.txt` when public commands, APIs, configuration, or integration behavior changes.
- Keep the public filetype and module names consistent with the current documentation.
- Do not add runtime dependencies without documenting and discussing the change.
- Project version follows [Semantic Versioning](https://semver.org/).
- Before `1.0.0`, `0.x.x` releases do not guarantee API, configuration, or behavior compatibility.
- Starting with `1.0.0`, a major-version increment indicates an API or behavior-level change. Once there's any breaking changes, a new branch must be used.
- Update the version whenever a release change is made, and document version-impacting changes.
- Before every git commit, increment the patch version and update all version references.
- Minor or major version changes require explicit user instruction; do not infer or make them automatically.

## Testing requirement

- **Every code change must pass all unit tests before it is considered complete.**
- Run the complete test suite with:

  ```sh
  make test
  ```

- Tests run in headless Neovim and must not depend on a user's Neovim configuration.
- When adding or changing behavior, add or update a regression test in `tests/run.lua`.
- Every modification must verify that Lua diagnostics report no errors.
- Every modification must verify that Neovim help tags can be generated successfully:

  ```sh
  nvim --headless -u NONE -c 'set rtp^=.' -c 'helptags doc' -c 'qa!'
  ```
