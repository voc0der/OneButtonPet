# Contributing

Thanks for working on `OneButtonPet`.

Keep changes focused on pet attack/follow behavior, slash-command ergonomics, and keybind reliability. This addon should stay small and direct.

## Local Setup

- Target client: TBC Anniversary Classic
- Addon install path: `World of Warcraft/_classic_/Interface/AddOns/`
- Main runtime files are listed in [OneButtonPet.toc](OneButtonPet.toc)

## Development

Run the local test suite:

```bash
lua tests/run.lua
```

Run a syntax check before opening a PR:

```bash
luac -p OneButtonPet.lua tests/run.lua
```

If you change packaging or release behavior, verify the runtime-only package contents too:

```bash
bash ./.github/scripts/verify-release-package.sh
```

## Project Expectations

- Keep the addon focused on the one-button pet attack/follow workflow.
- Prefer small, targeted changes over broad rewrites.
- If you add a new runtime file, include it in [OneButtonPet.toc](OneButtonPet.toc).
- Player-facing packages should only include files the game client actually needs.

## Pull Requests

- Use conventional commit titles such as `feat(...)`, `fix(...)`, `docs(...)`, or `ci(...)`.
- Include a short summary of what changed and how you verified it.
- If the change affects visible behavior, include screenshots or a short in-game note.
- Keep PRs scoped to one logical change when possible.

## Releases

- Release-specific steps are documented in [RELEASING.md](RELEASING.md).
- Version bumps should update [OneButtonPet.toc](OneButtonPet.toc), the current version in [README.md](README.md), and the matching entry in [CHANGELOG.md](CHANGELOG.md).
- Packaging changes should keep working with both the PR artifact workflow and the GitHub/CurseForge release workflow.
