# Changelog

## 0.1.0 - 2026-08-16

Initial public prototype.

### Added

- Native Steam and Flatpak Steam discovery.
- `libraryfolders.vdf` scanning for secondary libraries.
- Cyberpunk 2077 AppID `1091500` detection.
- Proton-prefix and Windows-user discovery.
- Backup of saves, settings/keybinds, and major mod/framework locations.
- Portable snapshots by dereferencing deployed symlinks.
- SHA-256 manifests and pre-publication backup verification.
- Additive restore with post-copy hash validation.
- Automatic `PRE_RESTORE` safety snapshots.
- Conservative default handling for `bin/x64`.
- Optional advanced full `bin/x64` snapshot.
- CLI path overrides and basic non-interactive commands.
- Smoke test.
- GitHub Actions smoke-test workflow and issue templates.
- Coverage for both `r6/input` (Input Loader) and `r6/inputs` (modded input data).
