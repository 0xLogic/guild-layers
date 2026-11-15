Guild Layers 1.2.1

- Fix presence discovery: explicit query/reply over guild messages and direct addon whispers.
- Presence broadcasts are independent of layer scans, combat and escape callbacks.
- Addon-only includes verified hosting-off members and handles Forever surname/realm suffixes.
- Bounded queries: two direct requests per five seconds, at most once per member per minute. No party requests are sent for presence discovery.
- Add /guildlayers status for presence diagnostics.
- Both clients should update for the new handshake; old versions still broadcast periodically.
- 27 headless tests pass, including Mojow Joejoe-Realm direct replies and duplicate-query throttling. Mojow's live presence and live game transfers remain unverified.
- Reload the UI after updating.
