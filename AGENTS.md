# Working on CooldownManagerPlus

## Project

CooldownManagerPlus extends Blizzard's built-in WoW Cooldown Manager. This is a
Lua addon, not a standalone application. Read `README.md` for the overview and installation
and `CooldownManagerPlus.toc` for the target interface, saved variable name, and
module load order. No build step or package manager is required.

## Code map

- `Core/Settings.lua`: AceDB character profiles, defaults, and independent character copying.
- `Libs/`: embedded LibStub, CallbackHandler, and AceDB; preserve upstream licenses.
- `CooldownManagerPlus.lua`: global settings page and side tab.
- `EntrySettings.lua`: native icon context-menu overrides, indicators, and tooltips.
- `Overrides.lua`: inheritance and saved per-icon options.
- `BuffLayout.lua`, `BuffLayoutModel.lua`: buff visibility, grouping, and placement.
- `BuffEligibility.lua`, `BuffReminder.lua`: eligibility and missing-self-buff reminders.
- `DuplicateBuffs.lua`: generic detection of effects already displayed on spell icons.
- `CooldownOptions.lua`, `CenteredRows.lua`: spell visibility and row centering.
- `CompactLayout.lua`, `CompactModel.lua`, `IconStyle.lua`: icon zoom, layout, and swing spark.
- `CooldownTimerLayer.lua`: visual timer replacement.
- `Media/`: shipped texture assets. Asset paths must use the installed addon name.
- `tests/`: standalone Lua tests with simulated WoW frames and APIs.

Modules receive the shared addon table through `local _, addon = ...`. Preserve
the `.toc` dependency order when adding or moving modules. Keep geometry and
decision logic separate from frame operations where practical.

## WoW safety

- Derive spell and buff behavior from the available native Cooldown Manager
  entries and their metadata. Keep runtime behavior generic across classes;
  avoid hardcoded spell IDs or class-specific exceptions.
- Treat secret values as opaque. Check readability before comparisons,
  arithmetic, branching, or using values as keys. Unknown data must not produce
  an incorrect missing-buff reminder or duplicate match.
- Respect combat lockdown and protected frames. Defer restricted frame changes
  until combat ends, and preserve Blizzard's tracking and native visibility rules.
- Prefer secure post-hooks and addon-owned state. Do not replace native aura
  predicates or call native data refresh methods from addon code.
- Native Lua methods can mutate internal state even when they appear to perform
  layout only. Investigate their side effects before introducing direct calls.
- Keep the addon settings page on its own scroll frame. Swapping addon content
  into Blizzard's native scroll frame previously caused taint during icon dragging.
  Preserve native scroll content, position, and callbacks. Restore any temporary
  visual changes when leaving the addon page.
- The C+ footer owns its character-copy dropdown. Keep it outside the scroll
  content and preserve the native layout dropdown's parent, anchors, menu, and
  callbacks. Show the addon footer only while the C+ page is active.
- Preserve settings saved in the current profile format. In overrides, `nil` inherits the
  default; `false` explicitly disables a setting. Do not conflate them.
- Each character starts with an independent AceDB profile and built-in defaults.
  Earlier account-wide settings are discarded; do not add compatibility migrations
  or legacy backups. General settings are defaults for that character's overrides,
  not shared across characters.

## Settings UI

Use the existing Blizzard-style controls. The plus tab contains always-visible
global settings without accordions. Per-icon overrides appear below a separator
and teal CM Plus header in Blizzard's icon context menus. Keep spacing consistent.

Per-icon labels match their corresponding General settings labels. Dropdowns
use **Use default**, **Enabled**, and **Disabled**. Explain inheritance with
“Use the matching option in General settings.” Keep tooltips short and describe
what the feature does. Overrides customize existing settings rather than adding
unrelated features.

## Validation

Run the relevant test when changing a module. For changes spanning modules, run
the full suite and parse each root Lua file:

```sh
for test in tests/*Test.lua; do lua "$test" || exit 1; done
for source in *.lua Core/*.lua Libs/*/*.lua; do luac -p "$source" || exit 1; done
```

Tests do not reproduce WoW's secure execution, actual rendering, or combat
restrictions. State those limits when reporting results. For affected features,
request an in-game check covering combat transitions, Edit Mode, target changes,
and settings changes as appropriate. For settings integration changes, also
check dragging icons between Blizzard's displayed and hidden categories.

For character-copy changes, verify copied General settings and compatible
per-icon overrides. Check class mismatches and combat rejection before testing
native icon dragging.

Documentation-only and simple wording changes need proportionate checks; do not
add tests that merely repeat the implementation.

## Scope and packaging

Keep changes focused and update `README.md` when documented behavior changes.
Avoid unrelated saved-variable, interface-version, or release-version changes.
Create release ZIPs only when requested. Include every `.toc`-listed module and
the required `Media/` assets under the addon folder. Exclude Git metadata, tests,
logs, local settings, and generated development files from addon archives.

Never add credentials, personal account configuration, or machine-specific
paths to repository documentation or instructions.
