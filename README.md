# CooldownManagerPlus

A WoW: Forever beta addon that adds a teal plus tab to Cooldown Manager settings.
Install the addon as `Interface/AddOns/CooldownManagerPlus/`, with `CooldownManagerPlus.toc` directly inside. Media paths follow the actual addon name supplied by WoW.

## Configuration

Settings are saved automatically in `CooldownManagerPlusDB` using embedded
AceDB. Each character has its own profile, identified by name and realm, with
built-in defaults and independent per-icon overrides. General settings apply
only to that character. No separate Ace3 installation is required.

Characters start fresh with the built-in defaults. Settings from the earlier
account-wide storage format are discarded.
Use **Settings → Copy from character** in the fixed bottom footer of the C+ tab to
replace the current character's CM Plus settings after confirmation. Copies are
independent. General settings copy across classes; per-icon overrides copy only
from the same class and only for entries present in native Cooldown Manager data.
Unknown-class sources copy General settings only. Copying is blocked in combat.
This copies CM Plus settings only; Blizzard layouts remain unchanged.
The footer uses an addon-owned Settings dropdown aligned with Blizzard's layout
selector. It stays visible while scrolling and hides when returning to native tabs.

**Settings → Export settings** opens a copyable `CMP1:` string containing the selected
Blizzard Cooldown Manager layout, this character's General settings, and per-icon
overrides with native spell identities. The string is selected automatically;
press Ctrl+C on Windows or Command+C on Mac to copy it. Select string highlights
it again. The addon does not call Blizzard's restricted clipboard API.
The string uses WoW's CBOR/base64 encoding;
it contains data only. Edit Mode frame positions are outside Blizzard's layout
export and are not included.

**Settings → Import settings** accepts that string. Click Import to validate and
apply it, then reload the UI automatically. Invalid strings show an error without
changing settings. Combined imports require the matching class and specialization. Per-icon
overrides apply only when their entry's native spell identity matches. Existing
Blizzard layouts are preserved; an imported layout is added and selected. A Starter
Layout export selects Blizzard's starter layout instead. Blizzard's layout limit
still applies. Close and reopen Cooldown Manager to save pending native changes
before importing. Setup import/export is blocked in combat.

Import preparation uses detached layout-manager and serializer objects with native
notifications suppressed. Import saves the merged layout string through
the native persistence API and reloads the UI, leaving live native layout tables
untouched. The setup dialog and menu are addon-owned.

**Settings → Reset CM Plus settings** restores built-in defaults for the current
character after confirmation. Other characters and Blizzard layouts are preserved.

The C+ page uses its own scroll frame inside the native window. General settings
starts expanded and contains separator headers for Display (combat visibility, self/target separation and icon zoom),
Utility (swing timer spark), and Buff display (buff-timer suppression and duplicate-buff hiding).
Below the global settings are three native category accordions: Buffs, Essential spells
and Utility spells. All three categories start collapsed. Empty categories
are omitted, and expansion choices are retained while switching tabs during the session.
The native scroll content and scroll position stay untouched when switching tabs.

- **Zoom icons**: crops 15% from each edge of icon textures and adds thin black
  borders. Appears at the bottom of Display. Keeps native icon sizes and the
  existing close icon arrangement.
  Compact layout uses one buff row above essentials, utility below. Preserves icon sizes
  from Edit Mode and anchors icons directly to their neighbors. Accounts for the
  native art's transparent padding so the visible icons touch.
- **Integrated swing timer spark**: a checkbox enables a soft white glow that
  travels right to left along the spell icons' top borders during combat. It uses
  essentials with at least three icons, otherwise utility with at least three.
  With neither row eligible, it stays hidden and the checkbox is grayed out
  with a tooltip explaining the requirement.
  In compact style, adjacent icons share the glow smoothly across their boundary.
  The glow flows continuously between icons, with clipping only at the row ends. It follows the latest main-hand
  or ranged auto-attack; off-hand events are ignored. Disabling it or entering
  Edit Mode hides the integrated spark. Native swing timers are never changed;
  disable them manually in the game settings if desired. Changes apply immediately.
- **Hide essential cooldowns outside combat**: applies to the entire essential row.
  Edit Mode shows essentials for
  positioning even with this option enabled.
  Compact mode reserves the row's height while hidden, so buffs and utility
  stay at the same vertical positions when entering or leaving combat.
- **Separate self and target buffs**: rearranges icons within the existing native
  tracked-buff viewer, self on the left and target on the right with a fixed
  16-unit extra gap. Works with and without icon zoom. No new viewer or
  Edit Mode bar is created. Uses readable native aura-unit metadata, retaining
  the last observed group for missing effects; unknown effects default to self.
  Tracked buffs keep their slots when inactive or hidden, so remaining icons do
  not recenter as effects appear and disappear unless Center icons is enabled.
- **Center icons**: centers visible icons independently in Essential, Utility and Buff rows,
  growing each row outward.
  Works with native and compact layouts and separate self/target buffs, preserving the
  group gap. Disabled by default; compact mode keeps fixed tracked slots in all three rows
  when this option is off.
- **Notify on missing self buffs in combat**: one Display checkbox enables a combined
  reminder in combat above the bars for tracked, confirmed self buffs that are learned,
  non-passive spells with zero base spell cooldown. Grouped trackers such as Aspects
  also check their linked spells. Eligibility is cached outside
  combat; unavailable or secret metadata never produces a reminder. The message
  bounces continuously while the reminder is visible. Target buffs and
  secret/unknown active states are excluded. Edit Mode hides reminders. Per-buff overrides
  can include or exclude eligible self buffs without bypassing combat or these eligibility checks.
- **Buffs → Always show**: selected missing effects remain visible in gray.
- **Hide utility cooldowns outside combat**: independently hides the utility row
  outside combat and restores it in combat. Edit Mode keeps it visible for positioning.
- **Hide buff timers on spell icons**: one global Buff display checkbox
  for essential and utility icons. Hides only the native Cooldown widget using
  opacity and overlays an addon-owned spell timer driven by duration objects.
  Native methods and aura tracking remain intact. Currently skips charge spells,
  equipment and spell-category items. Excludes GCD and restores native timers
  when disabled or in Edit Mode. New timer creation waits until combat ends.
- **Hide buffs already shown on spell icons**: hides a tracked buff only when a visible
  essential or utility spell icon displays the same aura on the same unit. Uses
  exact instance IDs when readable; when combat makes them secret, it matches
  readable current aura spells or equivalent native aura selectors, including rank
  lists. Different selector candidates or priorities preserve the buff. Ordinary cooldowns, totem timers, hidden/transparent spell icons and
  unknown or ambiguous effect metadata never suppress the buff. Edit Mode reveals the buff.
  The global checkbox is disabled while global buff-timer suppression is enabled;
  its selection is remembered. Per-entry overrides still use the matching spell's
  effective timer setting, keeping the buff visible if its spell timer is suppressed.

### Per-entry settings

The Buffs, Essential spells and Utility spells accordions open directly into plain
icon/name lists. There is one Buffs list, with an Always show column of checkboxes.
Each entry has an options button that opens a small anchored editor containing only
its applicable exceptions to the global settings:

- Spells: combat visibility and, for supported ordinary spells, buff-timer suppression.
- Buffs: duplicate hiding and missing-buff notifications for confirmed eligible self buffs.

Dropdowns default to Use default. Customized marks entries with exceptions hidden
in the editor; checking Always show alone does not add that marker. Reset overrides
restores the editor's options and keeps the visible Always show choice. Only one editor
opens at a time. Click outside, click its close button, collapse its category, or switch
tabs to dismiss it. Icon zoom, self/target separation and the integrated spark
remain global settings.

Manual player/target assignment controls and adjustable gap remain removed. The
optional self/target split uses automatic grouping. Existing selections are retained.

Blizzard already has group-wide Hide When Inactive in Edit Mode. This addon adds
per-effect visibility overrides rather than duplicating that native setting.

## Try it

Check the footer's copy submenu, reset confirmation, and export dialog. Export a
named Blizzard layout, change a CM Plus setting, paste the exported string, then
import and reload. Verify both settings sets, other saved layouts, and per-icon
overrides. Test invalid input, a different class/spec, and combat rejection. After
import, open native tabs and drag icons between displayed and hidden categories;
check for taint errors. Native C encoding, rendering and secure execution need
in-game verification; standalone tests use API substitutes for those boundaries.

Use `/reload`, open Cooldown Manager settings, and select the teal plus tab. Check icon zoom at
normal and non-default icon sizes. Verify essentials/utility touch and buffs form
one row. Toggle combat-only essentials and enter/leave combat; utility should be
unaffected. Move Essential Cooldowns in Edit Mode to position the compact group.
Disable icon zoom and sparks to restore the original presentation.
Toggle icon zoom to check the cropped appearance, thin black border and restoration.

For duplicate hiding, track the same effect in the buff row and a spell row. Verify
it disappears only while that spell icon visibly displays the aura timer; hide the
spell row or suppress its buff timer and verify the buff returns. Test target changes,
combat, Edit Mode and per-entry exceptions. Open an entry's options, change a setting with the opposite global value, and verify Reset and
Use default restore normal behavior. Check Always show remains on the buff row and
is preserved when resetting the popup options. Verify clicking outside and switching
tabs dismiss the editor.

For Lua errors: `/console scriptErrors 1`, then `/reload` and reproduce the issue.

## Verification

```sh
lua tests/OverridesTest.lua
lua tests/DuplicateBuffsTest.lua
lua tests/BuffLayoutModelTest.lua
lua tests/BuffControllerTest.lua
lua tests/BuffEligibilityTest.lua
lua tests/BuffReminderTest.lua
lua tests/CompactModelTest.lua
lua tests/CenteredRowsTest.lua
lua tests/CompactControllerTest.lua
lua tests/CooldownOptionsTest.lua
lua tests/IconStyleTest.lua
lua tests/SettingsPanelTest.lua
lua tests/CooldownTimerLayerTest.lua
luac -p *.lua
```

Targets interface `16001`. Tests simulate the WoW frame boundary; real rendering
and combat behavior need in-game verification. Protected positioning waits until
combat ends. Combat-only essentials use opacity to preserve Blizzard tracking.
Secret buff states remain under Blizzard control. Internal UI frames can change
between beta builds.

References: [Cooldown Viewer](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.lua),
[icon templates](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_CooldownViewer/CooldownViewer.xml),
[swing timers](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_SwingTimer/Blizzard_SwingTimer.lua).

The first buff timer suppression implementation was withdrawn after an in-game secret-aura taint error.
Do not replace native CanUseAuraForDisplay or call native RefreshData from addon
code for this feature. Local frame simulations do not model WoW secure execution.
The replacement changes the visual timer layer only. Enable it
outside combat after `/reload`. Verify Serpent Sting shows no debuff timer on
its cooldown icon while its tracked buff remains timed separately. Verify Arcane
Shot retains its cooldown timer in combat and disabling restores native timers.
The user verified timer replacement and immediate toggling in-game. Native aura-dependent coloring and other
decorations are outside this experiment.

Sources: [Forever spell duration APIs](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua),
[Forever cooldown frame API](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua).
