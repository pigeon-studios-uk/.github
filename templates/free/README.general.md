<!--
TEMPLATE: Pigeon Studios free (public) README for anything that isn't a FiveM resource:
Discord bots, Node.js services, tools, libraries, website components.
Replace every placeholder in double curly braces, delete sections that don't apply, and delete this comment.
-->

<div align="center">
  <img src=".github/banner.png" alt="{{RESOURCE_NAME}} by Pigeon Studios" width="100%" />

  <h1>{{RESOURCE_NAME}}</h1>

  <p><strong>{{SHORT_DESCRIPTION}}</strong></p>

  <p>
    <a href="https://github.com/pigeon-studios-uk/{{REPO}}/releases/latest"><img src="https://img.shields.io/github/v/release/pigeon-studios-uk/{{REPO}}?label=release&color=2ea043" alt="Latest release" /></a>
    <a href="LICENSE.md"><img src="https://img.shields.io/badge/licence-Pigeon%20Studios%20Free-6f42c1" alt="Licence: Pigeon Studios Free Licence" /></a>
    <a href="https://discord.gg/2NFVWEUmDF"><img src="https://img.shields.io/badge/support-Discord-5865F2?logo=discord&logoColor=white" alt="Discord support" /></a>
  </p>

  <p>
    <a href="https://github.com/pigeon-studios-uk/{{REPO}}/releases/latest"><strong>Download</strong></a> ·
    <a href="#getting-started">Get started</a> ·
    <a href="#configuration">Configure</a> ·
    <a href="CHANGELOG.md">Changelog</a> ·
    <a href="https://discord.gg/2NFVWEUmDF">Support</a>
  </p>
</div>

---

## Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [Usage](#usage)
- [Deploying](#deploying)
- [Updating](#updating)
- [Data and privacy](#data-and-privacy)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Support](#support)
- [Contributing](#contributing)
- [Security](#security)
- [Licence](#licence)
- [Credits](#credits)

## Overview

<!-- Two or three short paragraphs: what it does, who it's for, and why you'd use it. -->

{{RESOURCE_NAME}} is a free project by [Pigeon Studios](https://pigeonstudios.co.uk) that …

## Features

- **Feature name:** what it does and why it's useful.
- **Feature name:** …

## Requirements

| Requirement | Version | Notes |
|---|---|---|
| Node.js | {{NODE_VERSION}} or newer | <!-- or PHP / WordPress / PowerShell, as appropriate --> |
| A Discord application | | From the [Discord Developer Portal](https://discord.com/developers/applications) <!-- bots only --> |
| | | |

## Getting started

1. **Download** the latest release from [Releases](https://github.com/pigeon-studios-uk/{{REPO}}/releases/latest), or clone the repository:

   ```bash
   git clone https://github.com/pigeon-studios-uk/{{REPO}}.git
   cd {{REPO}}
   ```

2. **Install** dependencies:

   ```bash
   npm ci
   ```

3. **Configure** it: copy `.env.example` to `.env` and fill in the values (see [Configuration](#configuration)).
4. **Run** it:

   ```bash
   npm start
   ```

<!-- Bots: add how to invite the bot, with the permissions and intents it needs. -->

## Configuration

Settings are read from environment variables, set in `.env` locally or in your host's settings in production. `.env.example` lists every one.

| Variable | Required | Default | What it does |
|---|---|---|---|
| `DISCORD_TOKEN` | Yes | | Your bot's token. Keep it secret |
| `LOG_LEVEL` | No | `info` | `error`, `warn`, `info` or `debug` |
| `…` | | | |

Never commit your `.env` file or share your token. If it's ever exposed, reset it in the Discord Developer Portal straight away.

## Usage

<!-- Commands, CLI options, API or examples. -->

| Command | Who can use it | What it does |
|---|---|---|
| `/command` | | |

## Deploying

<!-- How to run it in production: a process manager such as PM2, a host such as Render, Docker, or a WordPress install. -->

## Updating

1. Read the [changelog](CHANGELOG.md) for the versions between yours and the latest, especially any **Upgrade notes**.
2. Back up your configuration and data.
3. Download the new release, or `git pull`, then run `npm ci` again.
4. Add any new variables from `.env.example` to your `.env`, then restart.

## Data and privacy

<!-- What data it stores or sends anywhere (Discord IDs, messages, logs), where, and for how long.
     If you run it, you're responsible for that data under the law and Discord's Developer Policy. -->

## Troubleshooting

**It won't start.**
Check every required variable in `.env.example` is set in your `.env`, and that your Node.js version meets the [Requirements](#requirements).

<!-- Add the real problems people hit, with fixes. -->

## FAQ

**Is it really free?**
Yes. Use it for as many communities and projects as you like, including ones that make money. You just can't reupload, resell or bundle it. See [Licence](#licence).

**Can I change it?**
Yes, for your own use. If you've fixed or improved something, please send it back as a pull request.

## Support

Read [Troubleshooting](#troubleshooting) first, then ask in the support channels of our [Discord](https://discord.gg/2NFVWEUmDF). See [Getting help](https://github.com/pigeon-studios-uk/.github/blob/main/SUPPORT.md) for more.

Found a bug? Open a [bug report](https://github.com/pigeon-studios-uk/{{REPO}}/issues/new/choose).

## Contributing

Fixes, improvements and translations are welcome. Please read the [contributing guide](https://github.com/pigeon-studios-uk/.github/blob/main/CONTRIBUTING.md) before you start, and open a feature request before working on anything big.

## Security

Please don't report vulnerabilities in public issues. Use the **Report a vulnerability** button in this repository's **Security** tab, or follow our [Security Policy](https://github.com/pigeon-studios-uk/.github/blob/main/SECURITY.md).

## Licence

{{RESOURCE_NAME}} is free to use under the **[Pigeon Studios Free Licence](LICENSE.md)**.

- ✅ Use it for any number of communities and projects, including ones that make money
- ✅ Change it for your own use
- ✅ Run it for someone you work for
- ❌ Don't reupload, share or mirror the files; link to this repository instead
- ❌ Don't sell it, bundle it, or put it behind a paywall or licence key
- ❌ Don't remove the credits

This summary isn't the licence; [LICENSE.md](LICENSE.md) is. Third-party components are listed in [NOTICE.md](NOTICE.md).

## Credits

Made by [Pigeon Studios](https://pigeonstudios.co.uk). Thanks to everyone who has contributed; see the [changelog](CHANGELOG.md).

<sub>Not affiliated with or endorsed by Discord Inc.</sub> <!-- adjust or remove -->
