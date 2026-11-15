# Guild Layers 1.4.0 — WoW Forever

Install the GuildLayers folder in Interface/AddOns on both players, enable it,
then open `/guildlayers` (also `/lsguild`). LayerSwap is not required. This package
contains independently maintained guild UI and protocol code, not LayerSwap's source.

## LayerSwap compatibility

Guildmates running standard LayerSwap can now appear under **Addon only** after a
valid `heard` reply. Rows identify Guild Layers as **[GL]** and LayerSwap as **[LS]**.
The standalone addon registers LayerSwap's message prefix and reads fresh reported
layer/zone/hosting state. Unknown layers remain unknown, but a valid unknown-layer
reply still establishes that LayerSwap is running.

While the panel is open, bounded direct LayerSwap requests discover missing peers
(two candidates per five seconds, at most once per member per two minutes). These
are real swap requests, not read-only presence queries: hosts may invite you.
Discovery does not auto-accept invitations. Clicking a verified LayerSwap member
uses the standard LayerSwap request and arms acceptance only for that member's
matching invitation. Their hosting switch, zone checks and server rules still apply.
Known fresh Guild Layers capability takes precedence when both addons are installed.
LayerSwap users do not need this addon to report layers or answer requests.

The header shows your current layer and the requested destination as **Layer A,
Layer B, ...**. Letters are assigned on observation and remain stable per zone for
this UI session; they are local aliases, not server-wide names or guaranteed matches
to another player's LayerSwap letters. Equivalent Forever server IDs share a letter.
After requesting, the header says Requested, Switch unconfirmed after 30 seconds,
or Layer change observed only when your observed layer matches a different requested
destination in the same zone. Joining a party alone does not confirm a layer change.

## Updates

Version 1.2.0 and newer announce their version to online guildmates. When a newer
version is reported, chat and the panel show an update notice once per newer version
per session. This is peer-reported, not an authoritative GitHub check; use the fixed
project release page to verify. Old 1.1 clients need one manual update to gain notices.

The release also supplies `guild_layers_update.py` (Python 3, no dependencies).
Check GitHub independently of guild members:

```text
python guild_layers_update.py --addons-dir "D:/wforever/_forever_/Interface/AddOns"
python guild_layers_update.py --addons-dir "D:/wforever/_forever_/Interface/AddOns" --install
```

The second command downloads the latest release, verifies the GitHub asset SHA256,
validates ZIP paths/version, backs up replaced files, and installs them. Failed writes
attempt restoration. Settings in WTF/SavedVariables are preserved. Run `/reload`
after installation; the updater never restarts the game. It does not install itself
as a background service. A user-managed scheduled invocation can check for updates.
The addon itself cannot fetch GitHub or replace its own files.

**Addon only**, enabled by default, filters to online members whose Guild Layers
capability or LayerSwap reply was received in the last 90 seconds. Hosting-off members
still appear. Advertisements refresh every 30 seconds; a newly opened client may
need to wait for the next one. This reports recent presence, not installed files.

Version 1.2.1 actively requests presence on opening the panel and uses bounded
direct addon-whisper queries as a fallback (two per five seconds, once per member
per minute). Presence is independent of layer scans and combat callbacks. Both
hosting-on and hosting-off replies count. `/guildlayers status` shows presence
send attempts/results and received reports. Both clients should update for the
new query/reply handshake; older clients only broadcast periodically.

**Auto Horde escape**, disabled by default, checks once a second for a visible,
attackable Horde player with a public, checked distance of 40 yards or less. It
chooses an available Guild Layers host with a fresh different-layer report in the
same zone. No candidate, unknown/secret distance or faction, being dead, an instance,
or an existing party/request prevents a new attempt. Attempts are spaced 60 seconds
apart, with a two-minute per-host retry delay. It never leaves an existing party.
Successful joining is not reported as a layer switch until a different matching
layer is actually observed. The server may block transfers during combat.

When exact distance is unavailable, a successful close-range duel-interaction
distance check also qualifies. If both checks are unavailable, the mode cannot
detect that player. Detection and transfer remain LIVE TEST PENDING, not a proven
escape guarantee. Enemy nameplates must be visible for nameplate detection.

Click an online guildmate: their addon verifies current guild membership and
attempts an invite. Your addon accepts only an invitation from that clicked member
within 20 seconds. Party membership is confirmed from the party roster. No arbitrary
incoming invitations are automatically accepted. Hosting is enabled by default;
**Guild hosting** toggles it and persists the preference. Leaving the guild revokes
eligibility on the next action. No external website, credentials, or service is used.

Joining across zones is allowed by this addon. It cannot force a cross-zone layer
transfer, bypass server restrictions, invite from a full party/raid, or replace a
current party. Host combat and lack of party leadership block automated hosting.
If the game protects invite/accept APIs, manual interaction may still be required.
An API call without an error is an attempt, not proof of a completed join.

Layer reports use two distinct observed creature GUIDs agreeing on the server
component for Forever. Unknown layers remain unknown until NPC evidence exists.
Reports refresh at most every 30 seconds, expire after 120 seconds, and are cleared
on zone/shard changes. Party joining and layer-transfer confirmation are separate.
The addon reports a confirmed join, not an instant successful layer transfer.

Tests use simulated two-endpoint protocol events. Real-client guild membership,
invite/accept API behavior, actual grouping, and layer transfer are LIVE TEST PENDING.
No claim of live success is made by the package.

To remove: disable/delete GuildLayers. Saved settings may be retained. Local installer
backs up and removes only our prior appended LayerSwap bridge/TOC entry so both UIs
do not run simultaneously. It does not modify stock hosting policies or guild rules.
