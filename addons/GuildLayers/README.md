# Guild Layers 1.9.0 — WoW Forever

Install the GuildLayers folder in Interface/AddOns on both players, enable it,
then open `/guildlayers` (also `/lsguild`). LayerSwap is not required. This package
contains independently maintained guild UI and protocol code, not LayerSwap's source.

## Roster and mini bar

The roster uses aligned Member, Level/Class, Layer, Addon and Status columns with
bounded single-line labels, alternating dark rows and compact controls. Click a row
to request that guildmate. Main and mini panels can be dragged and stay on screen.

A single-line mini bar appears at the top of the screen. **Force guild switch**
selects a fresh, available host on another known layer in your current zone, using
the normal request/accept path. It cannot force the server to transfer you. If no
eligible host is known, it opens the roster and refreshes reports instead of claiming
a switch. **Roster** toggles the main panel; `/guildlayersmini` hides/shows the mini
bar. Hover the bar for the latest request status. Positions are session-local.

UI code loads in headless tests and switch logic is tested; visual verification in the client is
still pending. No screenshots or game restarts were performed during development.

## LayerSwap compatibility

Guildmates running standard LayerSwap can now appear under **Addon only** after a
valid `heard` reply. Rows identify Guild Layers as **[GL]** and LayerSwap as **[LS]**.
The standalone addon registers LayerSwap's message prefix and reads fresh reported
layer/zone/hosting state. Unknown layers remain unknown, but a valid unknown-layer
reply still establishes that LayerSwap is running.

While the panel is open, bounded direct LayerSwap requests discover missing peers
(two candidates per five seconds, at most once per member per two minutes). These
are real swap requests, not read-only presence queries: hosts may invite you.
With **Accept guild invites** enabled, invitations from verified guildmates are
accepted automatically, including invitations provoked by discovery. Clicking a
verified LayerSwap member uses the standard LayerSwap request. Their hosting
switch, zone checks and server rules still apply.
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
attackable Horde player within your saved **Horde radius**, default 40 yards. Enter
5–100 yards and press Enter to save. It chooses an available compatible host with a fresh different-layer report in the
same zone. No candidate, unknown/secret distance or faction, being dead, an instance,
or an existing party/request prevents a new attempt. Attempts are spaced 60 seconds
apart, with a two-minute per-host retry delay. It never leaves an existing party.
Successful joining is not reported as a layer switch until a different matching
layer is actually observed. The server may block transfers during combat.

When exact distance is unavailable, a successful close-range duel-interaction
distance check also qualifies when the configured radius is at least ten yards.
If both checks are unavailable, the mode cannot
detect that player. Detection and transfer remain LIVE TEST PENDING, not a proven
escape guarantee. Enemy nameplates must be visible for nameplate detection.

Click an online guildmate: their addon verifies current guild membership and
attempts an invite. **Accept guild invites** is enabled by default: every invitation
from a verified current online guildmate is eligible, without a prior click and
even during combat. Non-guild invitations are never automatically accepted. If
you turn this off, only invitations matching a request made in the last 20 seconds
are accepted. Party membership is confirmed from the roster. Hosting is enabled by default;
**Guild hosting** toggles it and persists the preference. Leaving the guild revokes
eligibility on the next action. No external website, credentials, or service is used.

Joining across zones is allowed by this addon. It cannot force a cross-zone layer
transfer, bypass server restrictions, invite from a full party/raid, or replace a
current party. Combat no longer blocks the addon's own invite/accept attempts.
Lack of party leadership still blocks hosting.
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

## Map and target pings (1.7)
Updated guildmates share outdoor zone coordinates every 5 seconds, guild-only.
Open their zone map to see markers; hover for name, raw layer ID and report age.
Reports expire after 30 seconds/offline and are not saved. Toggle your sharing
with /guildlayers mapshare. Missing locations are unknown. Members need 1.7;
LayerSwap does not supply coordinates. Continent/world projections are not included.

Bind Ping my target under Guild Layers in Key Bindings, or /guildlayers ping.
Guild members in your raid/party receive the target name. /guildlayers raid opens
a movable target panel: left-click a row to target that member's current target,
right-click to focus it. Open before combat. Unit-token changes wait until combat
ends; displayed names always follow the configured token. No network GUID selects
a target. These are hardware actions, not autonomous combat target changes.
Pings highlight for 10 seconds; target names use locally visible group units.

## Reported guild gold (1.8)
Gold reporting is automatic and always on while Guild Layers is enabled. There
is no gold-sharing toggle. The roster shows each online member's reported balance
and a fresh-report total below the list. Gold on the mini bar or /guildlayers gold
opens a detailed, paginated view with report ages.

The addon broadcasts this character's carried copper balance to the guild. Every
guild member with this version can view received reports; these are not officer-
private. Balances are self-reported client observations, not server-certified.
Updates are coalesced to at most once per five seconds and refreshed every 30
seconds. Fresh reports (up to 90 seconds old) count toward the total. Older reports
are excluded and expire after five minutes. Offline/non-member reports are removed.
Unknown is not zero; reporting zero is a valid observation. Only online roster
characters are counted once, never player accounts or inferred alts. Bank, mail,
auction proceeds and item value are excluded. Received balances are memory-only
and clear on reload or guild change. No individual gold-sharing preference is saved.
Other members must install this version to contribute; disabling or removing the
addon stops its reporting. No addon can force reports from an absent client.

## Inspect (1.8.1)
Use Inspect at the right edge of a guild roster row to request the normal in-game
inspect window. The addon resolves the exact guildmate among target/focus/mouseover,
party, raid and nameplate units, then checks client eligibility and inspect range.
It does not change your target, join a party or switch layers. If no usable unit
is visible, approach the guildmate on the same layer (or target them) and retry.
A remote/offline armory is not provided by the standard inspect API. A submitted
request is not proof that the server returned equipment. Requests are paced at
one per two seconds. The client controls the equipment/talent tabs it exposes.

## Cached armory (1.9)
Armory beside Inspect opens a character-style equipment/statistics snapshot.
You can also use /guildlayers armory Qouchi Liquor to open a cached profile by name.
Inspect remains the live nearby-player action. Remote 3D appearances are not
fabricated; a matching locally targeted player can provide the model. Gear icons
use the client's item cache and may be unavailable until item metadata is loaded.
Hover gear for the recorded name and bonuses. Source timestamps and missing/stale
sections are shown separately. Public data may lag the character in game.

Standalone addons cannot perform HTTPS requests. Run the included Python tool:
`python guild_layers_armory_sync.py qouchi-liquor lost-thewar --output <AddOns>/GuildLayers/ArmoryData.lua`
Then reload UI. Use `--local` only on the website host to use its existing loopback
service on 8787. The default public osrs.services endpoint currently returned 403
in our verification; loopback fetching succeeded. No credentials are embedded.
This is an explicit snapshot sync, not live web requests from the Inspect button.
The selected character set replaces the cache atomically after validation; supply
all desired character slugs each time. Addon updates may replace the cache stub:
run sync again after updating. Private generated snapshots are not published.
