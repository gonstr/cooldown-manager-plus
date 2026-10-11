# CooldownManagerPlus

A WoW: Forever beta addon that adds a teal plus tab to Cooldown Manager settings.
Install the addon as `Interface/AddOns/CooldownManagerPlus/`, with `CooldownManagerPlus.toc` directly inside. Media paths follow the actual addon name supplied by WoW.

## Configuration

The C+ page uses its own scroll frame inside the native window. General settings
starts expanded and contains separator headers for Display (retro icon style, combat-only essentials and self/target separation),
Utility (swing timer spark), and Buff display (buff-timer suppression and duplicate-buff hiding).
Below the global settings are three native category accordions: Buffs, Essential spells
and Utility spells. All three categories start collapsed. Empty categories
are omitted, and expansion choices are retained while switching tabs during the session.
The native scroll content and scroll position stay untouched when switching tabs.

- **Use retro icon style**: combines the compact layout and 30% icon zoom
  with thin black borders in one theme checkbox. Keeps native icon sizes.
  Existing compact or zoom selections enable this theme automatically.
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
  16-unit extra gap. Works with and without retro icon style. No new viewer or
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
tabs to dismiss it. The compact theme, self/target separation and integrated spark
remain global settings.

Manual player/target assignment controls and adjustable gap remain removed. The
optional self/target split uses automatic grouping. Existing selections are retained.

Blizzard already has group-wide Hide When Inactive in Edit Mode. This addon adds
per-effect visibility overrides rather than duplicating that native setting.

## Try it

Use `/reload`, open Cooldown Manager settings, and select the teal plus tab. Check retro icon style at
normal and non-default icon sizes. Verify essentials/utility touch and buffs form
one row. Toggle combat-only essentials and enter/leave combat; utility should be
unaffected. Move Essential Cooldowns in Edit Mode to position the compact group.
Disable retro icon style and sparks to restore the original presentation.
Toggle retro icon style to check the cropped appearance, thin black border and restoration.

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
