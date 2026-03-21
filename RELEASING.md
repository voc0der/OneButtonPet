# Releasing to CurseForge

## TBC Anniversary Support

OneButtonPet targets TBC Anniversary Classic. The TOC file specifies:

```text
## Interface: 20504
```

## Workflow Prerequisites

Before automated release can work end-to-end, configure:

1. GitHub Actions secret `RELEASE_PAT`
   - Fine-grained token with repository `Contents: Read and write`
   - Needed so tag push can trigger the release workflow
2. GitHub Actions secret `CF_API_KEY`
   - CurseForge API token used by `BigWigsMods/packager`
3. CurseForge project metadata in addon TOC
   - Add `## X-Curse-Project-ID: <your_project_id>` to `OneButtonPet.toc`
   - Without this, packager can still build archives but cannot upload to CurseForge

## Release Process

### Automated (GitHub Actions)

1. Update version in `OneButtonPet.toc`
2. Update `CHANGELOG.md` with release notes
3. Commit and push to `main`
4. CI validates syntax/tests, then the tag workflow creates a version tag from the TOC
5. The tag triggers the packager workflow

### Troubleshooting

- No new tag created:
  - Check `## Version:` in `OneButtonPet.toc` is bumped (for example `1.0.1`)
  - If tag already exists (for example `v1.0.1`), workflow will skip by design
- Tag created but no release upload:
  - Confirm `CF_API_KEY` exists in repo secrets
  - Confirm `## X-Curse-Project-ID:` is set to a valid numeric project ID
- Tag workflow failing authentication:
  - Confirm `RELEASE_PAT` exists and has repo contents write permissions
  - If using org SSO, ensure the token is authorized for the org

### Manual Upload to CurseForge

1. Create a zip file:
   ```bash
   cd /home/vocoder/Code
   zip -r OneButtonPet-v1.0.X.zip OneButtonPet -x "*.git*" -x "*README.md"
   ```
2. Upload at your CurseForge addon files page

## What Gets Released

The `.pkgmeta` file controls what gets included:
- OneButtonPet.lua
- OneButtonPet.toc
- Bindings.xml
- CHANGELOG.md
- README.md (excluded)
- .git files (excluded)
