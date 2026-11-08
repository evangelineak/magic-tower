# Desktop export

`tools/export_desktop.sh` builds an unsigned development preview for Linux x86_64 and Windows x86_64. It does not publish a release or change the repository branch. Godot 4.6.3 and its matching official export templates must already be installed. Run tests before exporting:

```sh
bash tools/test_all.sh
bash tools/export_desktop.sh
```

The default Godot template location on Linux is `$XDG_DATA_HOME/godot/export_templates/4.6.3.stable`, or `~/.local/share/godot/export_templates/4.6.3.stable`. The required release files are `linux_release.x86_64` and `windows_release_x86_64.exe`.

Official complete template bundle:
- https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz
- Same official asset API: https://api.github.com/repos/godotengine/godot-builds/releases/assets/425482597 (`Accept: application/octet-stream`)
- SHA-256: `3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8`
- 1,255,918,323 bytes. Check the full archive hash before extracting templates. Do not bypass checksum errors.

The export script creates `export/linux` and `export/windows`, each containing the executable, playing instructions, SHA-256 checksums, and Godot/third-party notices extracted from the exact build engine. Distribute the whole folder, not just the executable. Game resources are embedded; editor, Blender sources, tests, tools, and design documentation are excluded. The untracked `export/` directory is intentionally not committed.

The final check launches the Linux executable headlessly. Successful Windows cross-export or a valid PE header does **not** prove Windows runtime compatibility; that needs a real Windows run. Signing, an installer, automatic release publication, and a selected game-source license are not supplied by this script. Never tell players to bypass OS security warnings merely because the build is unsigned.

For a sandbox with an unwritable default config directory, point `HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` to a writable isolated folder, and install the two templates there. This changes only that process's paths, not OS permissions or security settings.

A separate `Build unsigned desktop preview` workflow is manually dispatched, not triggered on every push. It repeats rule tests, verifies the pinned official engine/template hashes, builds both platforms, and uploads a seven-day Actions artifact with build identity and notices. It never creates a release or pushes a tag. It needs to be present on the default branch before GitHub offers its manual-run button; this draft feature branch has not been merged automatically. Adding the workflow does not claim a hosted run has already succeeded.
