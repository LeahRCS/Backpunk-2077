# 🤝 Contributing to Backpunk-2077

Thanks for helping make modded Cyberpunk backups less terrifying.

## Before opening a pull request

Please make sure:

- your change does not introduce destructive deletion during restore;
- existing destination-only files remain untouched;
- new persistent mod paths have an upstream/CDPR/framework source when possible;
- `bash -n backpunk.sh` passes;
- `bash tests/smoke-test.sh` passes.

## Development workflow

```bash
git clone https://github.com/LeahRCS/Backpunk-2077.git
cd Backpunk-2077

git checkout -b feature/your-change
```

After editing:

```bash
bash -n backpunk.sh
bash -n tests/smoke-test.sh
bash tests/smoke-test.sh
```

## Commit style

Conventional Commit-ish messages are appreciated:

```text
feat: detect another Steam layout
fix: preserve Input Loader r6/input files
test: cover Flatpak library discovery
docs: document new framework path
```

## Adding a new backup path

Please explain:

1. what creates the file/directory;
2. why it contains persistent user/mod state rather than regenerable cache;
3. where the upstream documentation or source code establishes the path;
4. whether restoring it across game/framework versions could be risky.

If the path is generated cache, temporary data, logs, or something the platform can trivially reacquire, it probably should not become part of the default snapshot.

## Safety invariants

The following behavior is intentional and should not be weakened casually:

- no `rm`/`rm -rf`;
- no destination mirroring/deletion;
- backup verification before publication;
- backup verification before restore;
- PRE_RESTORE snapshot by default;
- post-copy validation;
- full `bin/x64` restore remains opt-in.

A restore tool is allowed to be slightly annoying. It is not allowed to be exciting.
