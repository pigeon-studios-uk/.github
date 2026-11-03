<div align="center">
  <h1>Pigeon Studios Repository Standards</h1>
  <p><strong>The licences, policies and templates behind every Pigeon Studios project on GitHub and GitLab.</strong></p>
  <p>
    <a href="https://pigeonstudios.co.uk">Website</a> ·
    <a href="https://pigeonstudios.co.uk/legal/">Legal</a> ·
    <a href="https://discord.gg/2NFVWEUmDF">Discord</a> ·
    <a href="CHANGELOG.md">Changelog</a>
  </p>
</div>

---

**Version 2.7.0** · First published 2 February 2019 · Last updated 22 October 2026

This repository holds the master copy of every licence, policy and template used across Pigeon Studios projects: FiveM and RedM resources, Discord bots and services, website code, tools and libraries, whether they're free, paid or internal.

- On **GitHub** it's the special `pigeon-studios-uk/.github` repository of the [Pigeon Studios organisation](https://github.com/pigeon-studios-uk). GitHub automatically shows its policies and issue and pull request templates on every repository in the organisation that doesn't have its own, and `profile/README.md` is the organisation's public profile page.
- On **GitLab** it's `pigeon-studios/repo-standards`, the same content. GitLab's Free plan doesn't share templates across a group, so files are copied into each project with the setup script.

Everything here is written to match the legal pages at https://pigeonstudios.co.uk/legal/. Pigeon Studios is the trading name of a **sole trader** based in England, our terms are governed by the law of **England and Wales**, and the contact address is **pigeon@pigeonstudios.co.uk**.

## Contents

- [Policies](#policies)
- [Licences](#licences)
- [Templates](#templates)
- [Which files each repository gets](#which-files-each-repository-gets)
- [Setting up a repository](#setting-up-a-repository)
- [How GitHub defaults work](#how-github-defaults-work)
- [How GitLab works](#how-gitlab-works)
- [Placeholders](#placeholders)
- [Rules for everything we publish](#rules-for-everything-we-publish)
- [Changing a document](#changing-a-document)
- [Layout](#layout)

## Policies

These apply to every project, on both platforms, unless a repository has its own version. They change rarely, and every change bumps the version.

| Policy | What it covers |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to report bugs, suggest features and contribute code, with standards for FiveM resources, Discord bots, website code and tools |
| [SECURITY.md](SECURITY.md) | How to report a vulnerability privately, what happens next, scope, safe harbour and disclosure |
| [SUPPORT.md](SUPPORT.md) | Where to get help, what to check first and what to include |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | How everyone is expected to behave, how to report problems and how we enforce it |
| [Issue forms](.github/ISSUE_TEMPLATE/) | Bug reports for FiveM/RedM resources and for other software, feature requests, documentation problems, and links to support |
| [LEGAL.md](LEGAL.md) | Who we are, and an index of every legal page on the website: terms, refunds, licence, privacy, copyright and takedown, brand and the rest |
| [Organisation profile](profile/README.md) | The public page at https://github.com/pigeon-studios-uk: free releases, support, policies and legal links |
| [Discussion forms](.github/DISCUSSION_TEMPLATE/) | The Q&A and Ideas forms for [organisation Discussions](https://github.com/orgs/pigeon-studios-uk/discussions), which live in this repository |
| [Pull request template](.github/pull_request_template.md) | What every pull request must include, with checklists for each project type |

## Licences

Every repository gets exactly one licence file, `LICENSE.md`, chosen by what kind of project it is.

| Licence | Use it for | In short |
|---|---|---|
| [Pigeon Studios Free Licence](licences/free/LICENSE.md) | Free, public projects | Free to use and modify, on any number of servers and communities, including ones that make money. No reuploading, reselling, bundling or escrow. |
| [Digital Product Licence (EULA)](licences/paid/LICENSE.md) | Paid products, sold through Tebex or our website | A copy of https://pigeonstudios.co.uk/legal/licence/: one community per standard licence, no sharing or leaking, escrow stays intact. |
| [Proprietary and Confidential](licences/internal/LICENSE.md) | Internal projects: bots, services, the website, tools | No licence granted; access by written agreement only; confidential. |

## Templates

Starting points for each repository. Placeholders in double curly braces get filled in by the setup script or by hand.

| Folder | What's in it |
|---|---|
| [templates/common](templates/common) | Every repository: `CHANGELOG.md`, `NOTICE.md`, `.editorconfig`, `.gitattributes`, `.gitignore`, `.env.example` and `.github/CODEOWNERS` |
| [templates/free](templates/free) | Free projects: `README.md` for FiveM and RedM resources, and `README.general.md` for bots, tools, libraries and anything else |
| [templates/paid](templates/paid) | Paid FiveM resources: buyer-facing `README.md`, `docs/INTERNAL.md` for notes that never ship, and the private `CONTRIBUTING.md` and pull request template |
| [templates/internal](templates/internal) | Internal projects: `README.md`, private `CONTRIBUTING.md` and pull request template |
| [templates/gitlab](templates/gitlab) | GitLab issue and merge request templates, for free and private projects |

## Which files each repository gets

| File | Free (public) | Paid (private) | Internal (private) |
|---|---|---|---|
| `LICENSE.md` | Free Licence | Digital Product Licence | Proprietary and Confidential |
| `README.md` | `free/README.md` or `free/README.general.md` | `paid/README.md` | `internal/README.md` |
| `CHANGELOG.md`, `.editorconfig`, `.gitattributes`, `.gitignore`, `.github/CODEOWNERS` | ✅ | ✅ | ✅ |
| `NOTICE.md` | ✅ | ✅ | Only if it includes third-party code |
| `.env.example` | Bots and services | | ✅ |
| `docs/INTERNAL.md` | | ✅ | |
| `CONTRIBUTING.md` | GitHub: from this repository · GitLab: copied | `paid/CONTRIBUTING.md` | `internal/CONTRIBUTING.md` |
| Pull/merge request template | GitHub: from this repository · GitLab: copied | `paid/` version | `internal/` version |
| `SECURITY.md`, `CODE_OF_CONDUCT.md` | GitHub: from this repository · GitLab: copied | Same | Same |
| `SUPPORT.md`, issue forms | GitHub: from this repository · GitLab: copied | GitHub: from this repository | GitHub: from this repository |

## Setting up a repository

Use the setup script, which copies the right files, fills in the placeholders you give it and lists any left to do. It never overwrites existing files unless you add `-Force`.

```powershell
# A free FiveM resource on GitHub
.\tools\New-PigeonRepo.ps1 -Path D:\PigeonStudios\Repos\fivem\releases\github\pigeon-dice -Kind Free -Name "Pigeon Dice" -Description "Roleplay dice rolling with cooldowns and chat output."

# A free Discord bot on GitHub
.\tools\New-PigeonRepo.ps1 -Path D:\PigeonStudios\Repos\tools\monday-discord-relay -Kind Free -Type General -Name "Monday Discord Relay"

# A paid resource on GitLab
.\tools\New-PigeonRepo.ps1 -Path D:\PigeonStudios\Repos\fivem\dev-releases\pg-citizenportal -Kind Paid -Platform GitLab -Name "Citizen Portal"

# An internal bot on GitLab
.\tools\New-PigeonRepo.ps1 -Path D:\PigeonStudios\Repos\bots\flightpath-systems -Kind Internal -Platform GitLab -Name "FlightPath Systems"
```

Run `Get-Help .\tools\New-PigeonRepo.ps1 -Full` for every option. Afterwards:

1. search the repository for `{{` and fill in anything left;
2. delete any old `LICENSE` file without an extension, and any old copies of the policies in free GitHub repositories, so the defaults show;
3. on GitHub, turn on **Private vulnerability reporting**, **Secret scanning** and **Push protection** in the repository's **Settings → Code security**; and
4. protect the `main` branch so changes arrive through pull or merge requests.

## How GitHub defaults work

GitHub uses the files in this **public** repository for every repository in the pigeon-studios-uk organisation, **public and private**, that doesn't have its own copy of that file. That covers `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md`, `CODE_OF_CONDUCT.md`, the issue forms and the pull request template.

- This repository must stay **public**, or the defaults stop working.
- Paid and internal repositories override `CONTRIBUTING.md` and the pull request template with their private versions.
- `LICENSE.md`, `README.md`, `CHANGELOG.md`, `NOTICE.md` and `CODEOWNERS` can't be defaults; every repository needs its own.

See GitHub's guide: [Creating a default community health file](https://docs.github.com/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file).

## How GitLab works

On GitLab's Free plan, templates can't be shared across a group, and code owners need GitLab Premium. So every GitLab project gets its own copies: run the setup script with `-Platform GitLab`, which adds `.gitlab/issue_templates/`, `.gitlab/merge_request_templates/Default.md` and the policy files, and leaves out `CODEOWNERS`.

## Placeholders

| Placeholder | Meaning | Example |
|---|---|---|
| `{{RESOURCE_NAME}}`, `{{PRODUCT_NAME}}`, `{{PROJECT_NAME}}` | Display name | Pigeon Dice |
| `{{RESOURCE_FOLDER}}`, `{{PROJECT_FOLDER}}`, `{{REPO}}`, `{{SLUG}}` | Folder, `ensure` name, repository name and version registry slug | pigeon-dice |
| `{{SHORT_DESCRIPTION}}` | One sentence | Roleplay dice rolling with cooldowns and chat output. |
| `{{YEAR}}` | First year of publication, or a range | 2026, or 2019–2026 |
| `{{MIN_ARTIFACT}}` | Oldest tested FXServer artifact | |
| `{{NODE_VERSION}}` | Minimum Node.js version | 22 |
| `{{RELEASE_DATE}}` | First release date, YYYY-MM-DD | 2026-11-02 |
| `{{STORE_URL}}`, `{{ASSET_NAME}}` | Tebex product page and Cfx.re Portal asset name | |
| `{{FRAMEWORKS}}`, `{{INVENTORIES}}` | Supported frameworks and inventories | ESX Legacy, QBCore, Qbox |

## Rules for everything we publish

- **Pigeon Studios only.** Commits, pull and merge requests, releases and documents are published under Pigeon Studios. No co-author, "generated by" or tool attribution lines anywhere.
- **The right name.** The brand is "Pigeon Studios". Don't use "Pigeon Studios Group" or "PSG" in public text.
- **No secrets, ever.** `.env.example` files hold placeholders only. A secret that reaches any repository, even briefly, is revoked and replaced.
- **One licence file.** `LICENSE.md` only, matching the kind of project.
- **Consistent with the website.** If a page at https://pigeonstudios.co.uk/legal/ changes, check the matching file here, and the other way round.

## Changing a document

1. Edit the master copy here first, never a copy in another repository.
2. Bump the document's version and "Last updated" date, and record the change in [CHANGELOG.md](CHANGELOG.md).
3. GitHub picks up policy changes automatically. Copy changed files into GitLab projects and into any repository that has its own copy.
4. Licences are versioned: each release of a project keeps the licence it shipped with. The paid licence must always match https://pigeonstudios.co.uk/legal/licence/, so update both together.

These documents were drafted to be consistent with our published legal pages, but they're not a substitute for advice from a solicitor. Have them reviewed if the business changes or a dispute arises.

## Layout

```
.
├── README.md                     this file
├── CHANGELOG.md                  changes to these standards
├── LICENSE.md                    licence for this repository
├── CONTRIBUTING.md               ┐
├── SECURITY.md                   │ policies: shown on every repository in the organisation
├── SUPPORT.md                    │ that doesn't have its own
├── CODE_OF_CONDUCT.md            ┘
├── LEGAL.md                      index of our legal pages, with who we are
├── profile/README.md             the organisation's public GitHub profile
├── .github/
│   ├── ISSUE_TEMPLATE/           issue forms and contact links
│   ├── DISCUSSION_TEMPLATE/      Q&A and Ideas forms for organisation Discussions
│   └── pull_request_template.md
├── licences/
│   ├── free/LICENSE.md           Pigeon Studios Free Licence
│   ├── paid/LICENSE.md           Digital Product Licence (EULA)
│   └── internal/LICENSE.md       Proprietary and Confidential
├── templates/
│   ├── common/                   files every repository gets
│   ├── free/                     README templates for free projects
│   ├── paid/                     README, internal notes, CONTRIBUTING, PR template
│   ├── internal/                 README, CONTRIBUTING, PR template
│   └── gitlab/                   GitLab issue and merge request templates
└── tools/
    └── New-PigeonRepo.ps1        sets up a repository from these templates
```

---

© 2019–2026 Pigeon Studios. See [LICENSE.md](LICENSE.md).
