Guild Layers 1.2.0

- In-game notices when guildmates report a newer version. Old 1.1 clients need one manual update to gain notices.
- Separate Python updater checks GitHub; --install verifies SHA256 and ZIP paths, backs up replaced files and installs the latest release.
- Existing joining, filtering and optional Horde escape retained.
- 27 headless tests pass. Live invite/detection/transfer verification remains pending.
- Reload the UI after updating. No game restart or background service is initiated.
