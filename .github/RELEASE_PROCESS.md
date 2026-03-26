# Release Process

## Automated Process

Every push to `main` triggers an automated release pipeline:
- The tag workflow reads the version from `OneButtonPet.toc`
- A git tag is created if one does not already exist for that version
- The tag push triggers the packager workflow
- `BigWigsMods/packager` builds the release zip and uploads to CurseForge when project metadata is configured

**Update the version in OneButtonPet.toc before pushing.**

## Prerequisites

- `RELEASE_PAT` repository secret:
  - Fine-grained PAT with repo `Contents: Read and write`
  - Required so workflow-created tag pushes can trigger downstream workflows
- `CF_API_KEY` repository secret:
  - Required for CurseForge upload in the packager step
- `## X-Curse-Project-ID: <id>` in `OneButtonPet.toc`:
  - Required by packager to know which CurseForge project to publish to

## Manual Steps (For Major/Minor Releases)

### 1. Update Version

Update `## Version:` in `OneButtonPet.toc` to a version that is not already tagged.

### 2. Update CHANGELOG.md

```markdown
## [Unreleased]

### Added
- New feature description

### Fixed
- Bug fix description
```

### 3. Commit and Push

```bash
git add OneButtonPet.toc CHANGELOG.md
git commit -m "Release v1.0.X"
git push
```

GitHub Actions handles tagging and packaging automatically.

If no new tag appears, check whether the tag for that version already exists.

## Version Numbering

Following [Semantic Versioning](https://semver.org/):
- **MAJOR** (`v2.0.0`): Breaking changes
- **MINOR** (`v1.1.0`): New features, backwards-compatible
- **PATCH** (`v1.0.1`): Bug fixes, backwards-compatible
