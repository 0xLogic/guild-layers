Guild Layers 1.9.0

Adds a separate cached Armory button beside live Inspect, with character-style equipment slots, recorded item bonuses, paginated statistics and section timestamps. A remote 3D appearance is not invented; only a matching local target supplies a model.

The standalone addon cannot make HTTP requests. Use the attached guild_layers_armory_sync.py to fetch selected player profiles, then reload UI. This is snapshot sync, not live website access. The public osrs.services endpoint returned 403 during verification; the website host's --local service succeeded. Profiles without cached data show setup status. No credentials or populated character caches are shipped.

66 headless tests pass. Local-source verification returned 16 gear slots and 57 statistics for Qouchi, and 19 slots and 57 statistics for Lost Thewar. In-game visual verification remains pending. Reload UI after installing and resync snapshots after addon updates.
