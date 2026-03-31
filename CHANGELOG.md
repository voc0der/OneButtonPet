## [Unreleased]

## [1.0.3] - 2026-03-31

### Changed
- Repositioned the addon keybind as the actual pet-control path and clarified the slash-command wording around it

### Fixed
- Prevented the slash toggle path from attempting protected pet commands during combat, with in-game messaging that directs players to the addon keybind

## [1.0.2] - 2026-03-26

### Added
- Added pull-request packaging workflows that can post a downloadable addon artifact for labeled PRs
- Added a `CONTRIBUTING.md` guide with local setup, verification, packaging, and PR expectations

### Changed
- Simplified the README for players, moved contributor/development details out of the main page, and refreshed the Star History embed

### Fixed
- Updated tag workflow secret handling so the release tag flow behaves correctly when `RELEASE_PAT` is missing
- Limited packaged addon archives to runtime files listed in `OneButtonPet.toc`, keeping tests, assets, and repo-only docs out of builds

## [1.0.1] - 2026-03-22

### Changed
- Added CurseForge project metadata to support automated uploads
- Updated the README with release metadata cleanup and a Star History chart

## [1.0.0] - 2026-03-21

### Added
- Initial release of OneButtonPet
- Slash-command pet attack/follow toggle via `/pettoggle`
- Direct addon key binding through `Bindings.xml`
- Local regression test coverage for target switching, follow fallback, and rapid re-press behavior
- GitHub Actions validation plus tag-and-release packaging workflows modeled after OneButtonMount
