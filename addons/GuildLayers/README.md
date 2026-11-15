# Guild Layers 1.1.0 — WoW Forever

Install the GuildLayers folder in Interface/AddOns on both players, enable it,
then open `/guildlayers` (also `/lsguild`). LayerSwap is not required. This package
contains independently maintained guild UI and protocol code, not LayerSwap's source.

**Addon only**, enabled by default, filters to online members whose Guild Layers
capability advertisement was received in the last 90 seconds. Hosting-off members
still appear. Advertisements refresh every 30 seconds; a newly opened client may
need to wait for the next one. This reports recent presence, not installed files.

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
