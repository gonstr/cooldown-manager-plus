# Embedded libraries

CooldownManagerPlus embeds only LibStub (minor 2), CallbackHandler-1.0 (minor 8),
and AceDB-3.0 (minor 33). The addon works without a separate Ace3 installation.
The library sources are unmodified; retain their headers and `LICENSE.txt` when
distributing or updating them. LibStub is public domain as stated in its header.

Upstream: https://github.com/WoWUIDev/Ace3

All three Lua files are loaded explicitly by `CooldownManagerPlus.toc` before
the settings module. Include them and the license in every release package.
