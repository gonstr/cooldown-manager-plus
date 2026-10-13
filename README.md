# CooldownManagerPlus

CooldownManagerPlus extends Blizzard's built-in Cooldown Manager with extra
options for icon display, cooldowns, and buffs. Its settings are integrated into
the existing Cooldown Manager window through a teal plus tab.

Built for the WoW: Forever beta. Settings are saved separately for each character
and can be copied from another saved character using the **Copy from character**
dropdown in the plus tab. Required libraries are included.

## Installation

1. Place the `CooldownManagerPlus` folder in your WoW installation's
   `Interface/AddOns/` directory, with `CooldownManagerPlus.toc` directly inside it.
2. Restart WoW or reload the UI if the addon is already installed.
3. Open Cooldown Manager settings and select the teal plus tab.

The plus tab contains global settings, with all options always visible. To
customize an individual spell or buff, right-click its icon in Blizzard's Spells
or Buffs tab. The teal **CM Plus** section contains its applicable overrides.
**Use default** inherits the matching General setting; **Reset overrides** clears
all CM Plus overrides for that icon, including a buff's **Always show** selection.

A thin teal border marks settings icons with CM Plus overrides, including
explicitly disabled settings. Hover over an icon for the full override
descriptions. Returning every option to its default removes the border.
Per-icon changes are disabled during combat.

Development guidance and test commands are in [AGENTS.md](AGENTS.md).

## License

CooldownManagerPlus is licensed under the [MIT License](LICENSE).
Bundled libraries in `Libs/` retain their upstream licenses and copyright
notices; see [Libs/LICENSE.txt](Libs/LICENSE.txt) and the library source files.
