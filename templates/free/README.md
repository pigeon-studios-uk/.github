<!--
TEMPLATE: Pigeon Studios free (public) FiveM resource README.
Replace every placeholder in double curly braces, delete sections marked "optional" that don't apply, and delete this comment.
Placeholders: {{RESOURCE_NAME}} display name · {{RESOURCE_FOLDER}} folder/resource name · {{REPO}} GitHub repo name
              {{SHORT_DESCRIPTION}} one sentence · {{MIN_ARTIFACT}} oldest tested FXServer artifact
-->

<div align="center">
  <img src=".github/banner.png" alt="{{RESOURCE_NAME}} by Pigeon Studios" width="100%" />

  <h1>{{RESOURCE_NAME}}</h1>

  <p><strong>{{SHORT_DESCRIPTION}}</strong></p>

  <p>
    <a href="https://github.com/pigeon-studios-uk/{{REPO}}/releases/latest"><img src="https://img.shields.io/github/v/release/pigeon-studios-uk/{{REPO}}?label=release&color=2ea043" alt="Latest release" /></a>
    <a href="LICENSE.md"><img src="https://img.shields.io/badge/licence-Pigeon%20Studios%20Free-6f42c1" alt="Licence: Pigeon Studios Free Licence" /></a>
    <a href="https://discord.gg/2NFVWEUmDF"><img src="https://img.shields.io/badge/support-Discord-5865F2?logo=discord&logoColor=white" alt="Discord support" /></a>
    <img src="https://img.shields.io/badge/FiveM-resource-F40552" alt="FiveM resource" />
  </p>

  <p>
    <a href="https://github.com/pigeon-studios-uk/{{REPO}}/releases/latest"><strong>Download</strong></a> ·
    <a href="#installation">Install</a> ·
    <a href="#configuration">Configure</a> ·
    <a href="CHANGELOG.md">Changelog</a> ·
    <a href="https://discord.gg/2NFVWEUmDF">Support</a>
  </p>
</div>

---

## Contents

- [Overview](#overview)
- [Features](#features)
- [Preview](#preview)
- [Requirements](#requirements)
- [Installation](#installation)
- [Updating](#updating)
- [Configuration](#configuration)
- [Commands](#commands)
- [Permissions](#permissions)
- [Exports and events](#exports-and-events)
- [Localisation](#localisation)
- [Update checker](#update-checker)
- [Performance](#performance)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Support](#support)
- [Contributing](#contributing)
- [Security](#security)
- [Licence](#licence)
- [Credits](#credits)

## Overview

<!-- Two or three short paragraphs: what the resource does, who it's for, and what makes it different. -->

{{RESOURCE_NAME}} is a free resource by [Pigeon Studios](https://pigeonstudios.co.uk) that …

## Features

<!-- What it does, as server owners and players would describe it. Group them if there are many. -->

- **Feature name:** what it does and why it's useful.
- **Feature name:** …
- **Configurable:** every message, timing and permission can be changed in `configuration/config.lua`.
- **Translatable:** ships with English; add your own language in `locales/`.
- **Lightweight:** idles at 0.00 ms on the client.

## Preview

<!-- Optional. Screenshots or a GIF, and a link to a video. -->

<img src="web/img/preview.png" alt="{{RESOURCE_NAME}} in game" width="100%" />

## Requirements

| Requirement | Version | Notes |
|---|---|---|
| FXServer | artifact {{MIN_ARTIFACT}} or newer | [Recommended artifacts](https://runtime.fivem.net/artifacts/) |
| OneSync | enabled | Required for … <!-- or delete this row --> |
| [ox_lib](https://github.com/communityox/ox_lib) | 3.0 or newer | <!-- or delete --> |
| [oxmysql](https://github.com/communityox/oxmysql) | 2.0 or newer | Only if … <!-- or delete --> |

**Frameworks:** works standalone, and with ESX Legacy, QBCore and Qbox. <!-- Be exact: list only what's tested. -->

## Installation

1. **Download** the latest `{{RESOURCE_FOLDER}}.zip` from [Releases](https://github.com/pigeon-studios-uk/{{REPO}}/releases/latest). Don't use the green **Code** button; release zips are the tested builds.
2. **Extract** it into your server's `resources` folder. The folder must be named `{{RESOURCE_FOLDER}}` exactly.
3. **Database** (if the resource has an `sql/` folder): import `sql/install.sql` into your server's database.
4. **Start it** by adding this to `server.cfg`, **after** its dependencies and your framework:

   ```cfg
   ensure ox_lib
   ensure {{RESOURCE_FOLDER}}
   ```

5. **Configure** it in `configuration/config.lua` (see [Configuration](#configuration)).
6. **Restart** your server. The server console shows a short startup message with the version, and tells you if an update is available.

## Updating

1. Read the [changelog](CHANGELOG.md) for the versions between yours and the latest, especially any **Upgrade notes**.
2. Back up your current `configuration/` folder and your database.
3. Replace the resource folder with the new release.
4. Copy your settings back into the new `configuration/config.lua`. Don't copy the old file over the new one; new versions can add settings.
5. Run any new SQL migrations the changelog mentions, then restart the resource.

## Configuration

All settings are in `configuration/config.lua`, and each one is explained by a comment next to it. The most important ones are:

| Setting | Default | What it does |
|---|---|---|
| `Config.Locale` | `'en'` | Language file from `locales/` to use |
| `Config.Debug` | `false` | Prints extra information to the console. Leave off on live servers |
| `Config.…` | | |

<!-- Optional: server-only settings such as webhooks -->
### Server-only settings

Secrets such as Discord webhook URLs belong in `configuration/server.lua` (server-side only, never sent to players) or in server convars:

```cfg
set {{RESOURCE_FOLDER}}:webhook "https://discord.com/api/webhooks/…"
```

## Commands

<!-- Optional. -->

| Command | Who can use it | What it does |
|---|---|---|
| `/command <arg>` | Everyone | … |
| `/admincommand` | `group.admin` | … |

## Permissions

<!-- Optional. ACE permissions, jobs or groups. -->

```cfg
add_ace group.admin {{RESOURCE_FOLDER}}.admin allow
```

## Exports and events

<!-- Optional. For developers integrating with the resource. Document arguments, return values and which side each runs on. -->

### Server exports

```lua
-- Returns ... for the given player, or nil if ...
local result = exports['{{RESOURCE_FOLDER}}']:exportName(source, arg)
```

### Client events

```lua
-- Triggered when ...
AddEventHandler('{{RESOURCE_FOLDER}}:client:eventName', function(data)
end)
```

## Localisation

Change `Config.Locale` to use another language from `locales/`. To add a language, copy `locales/en.lua` to a new file named with the language's two-letter code (for example `de.lua`) and translate the values. We'd love it if you shared it back; see [Contributing](#contributing).

## Update checker

When it starts, the resource checks our public [version registry](https://github.com/pigeon-studios-uk/pigeon-versions) and prints one line in the server console saying whether an update is available. The check is a single request to GitHub; it sends nothing about your server or players. You can change what it does in `server.cfg`:

```cfg
set pigeon_update_check "on"      # default: one short line
set pigeon_update_check "quiet"   # only print when there's an update or a problem
set pigeon_update_check "off"     # never check
```

This setting covers every Pigeon Studios resource on your server.

## Performance

<!-- Optional. Measured resmon figures and how you measured them. -->

| Situation | Client | Server |
|---|---|---|
| Idle | 0.00 ms | 0.00 ms |
| In use | 0.0x ms | 0.0x ms |

## Troubleshooting

**The resource doesn't start, or says a dependency is missing.**
Check the folder name is exactly `{{RESOURCE_FOLDER}}`, and that every dependency is started before it in `server.cfg`.

**Nothing happens and there's no error.**
Turn on `Config.Debug`, restart the resource and check both the server console and the F8 console.

**SQL errors.**
Make sure you imported `sql/install.sql`, and that `oxmysql` is started and connected.

<!-- Add the real problems people hit, with fixes. -->

## FAQ

**Is it really free?**
Yes. Use it on as many servers as you like, including servers that take donations. You just can't reupload, resell or bundle it. See [Licence](#licence).

**Can I change it?**
Yes, for your own servers. If you've fixed or improved something, please send it back as a pull request.

**Does it work with my framework?**
See [Requirements](#requirements). If yours isn't listed, it may still work standalone.

## Support

Read [Troubleshooting](#troubleshooting) first, then ask in the support channels of our [Discord](https://discord.gg/2NFVWEUmDF). Please include your resource version, framework and the full error. See [Getting help](https://github.com/pigeon-studios-uk/.github/blob/main/SUPPORT.md) for more.

Found a bug? Open a [bug report](https://github.com/pigeon-studios-uk/{{REPO}}/issues/new/choose).

## Contributing

Fixes, improvements and translations are welcome. Please read the [contributing guide](https://github.com/pigeon-studios-uk/.github/blob/main/CONTRIBUTING.md) before you start, and open a feature request before working on anything big.

## Security

Please don't report exploits in public issues. Use the **Report a vulnerability** button in this repository's **Security** tab, or follow our [Security Policy](https://github.com/pigeon-studios-uk/.github/blob/main/SECURITY.md).

## Licence

{{RESOURCE_NAME}} is free to use under the **[Pigeon Studios Free Licence](LICENSE.md)**.

- ✅ Use it on any number of servers, including monetised ones
- ✅ Change it for your own servers
- ✅ Show it in videos and streams
- ❌ Don't reupload, share or mirror the files; link to this repository instead
- ❌ Don't sell it, bundle it in packs, or put it behind escrow
- ❌ Don't remove the credits

This summary isn't the licence; [LICENSE.md](LICENSE.md) is. Third-party components are listed in [NOTICE.md](NOTICE.md).

## Credits

Made by [Pigeon Studios](https://pigeonstudios.co.uk). Thanks to everyone who has contributed fixes and translations; see the [changelog](CHANGELOG.md).

<sub>Not affiliated with or endorsed by Rockstar Games, Take-Two Interactive or Cfx.re.</sub>
