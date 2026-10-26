# Changelog

All notable changes to the Pigeon Studios repository standards are documented here. Each policy and licence carries its own version line; this file records what changed and when.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.8.0] - 2026-10-26

### Added

- `tools/New-PigeonProject.ps1`: starts a whole new project in one go. It works out the GitLab area, the `pg-` or `pigeon-` path, the local folder and the registry slug; copies the standard files; writes a starting `fxmanifest.lua` (or `package.json` for bots and tools) and a `.gitlab-ci.yml` with the shared checks and release jobs; makes the first commit; and, with a GitLab token, creates the GitLab project with the studio's settings and pushes. It ends with a list of what's left to do by hand.

### Changed

- The free README templates show the banner from `.github/banner.png`, where the free repositories keep it.

## [2.7.0] - 2026-10-22

### Added

- [GitHub Discussions](https://github.com/orgs/pigeon-studios-uk/discussions) for the organisation, hosted in this repository: Announcements, General, Ideas, Polls, Q&A and Show and tell.
- Q&A and Ideas forms (`.github/DISCUSSION_TEMPLATE/`) that ask for the resource, version and setup.

### Changed

- The issue chooser, `SUPPORT.md` and the organisation profile point questions about free resources to Discussions Q&A and ideas to Discussions Ideas. Paid products are still supported in Discord.

## [2.6.0] - 2026-10-22

Free releases moved from the WelshPigeon GitHub account to the Pigeon Studios organisation, [pigeon-studios-uk](https://github.com/pigeon-studios-uk).

### Added

- `profile/README.md`: the organisation's public profile, with our free releases, where to buy paid ones, support, policies and legal pages.
- `LEGAL.md`: who we are and an index of every legal page on https://pigeonstudios.co.uk/legal/, so they're one click away from any repository.

### Changed

- Every GitHub link in the policies, issue forms, pull request template, licences and templates now points to the organisation. Old WelshPigeon links still redirect.
- The Pigeon Studios Free Licence's "Official Repository" definition names the organisation, and still covers repositories published under the WelshPigeon account before the move.

## [2.5.1] - 2026-10-18

### Fixed

- The free and paid README templates and the paid `CONTRIBUTING.md` named the retired `pigeon-resource-versions` registry. They now point to [`pigeon-versions`](https://github.com/pigeon-studios-uk/pigeon-versions).
- The README templates described a `Config.CheckForUpdates` setting that the update checker doesn't have. They now explain the `pigeon_update_check` server convar (`on`, `quiet` or `off`), which covers every Pigeon Studios resource.
- The paid `CONTRIBUTING.md` pointed reviewers to `.github/CODEOWNERS`, which GitLab projects don't get. It now says Pigeon Studios reviews every pull or merge request.

## [2.5] - 2026-10-17

The current set of standards, rewritten in full to match the legal pages on https://pigeonstudios.co.uk/legal/ and to cover every kind of project on GitHub and GitLab.

### Added

- Separate licences for free, paid and internal projects:
  - **Pigeon Studios Free Licence**, for public projects: free use and modification on any number of servers and communities, no redistribution, resale, bundling or escrow;
  - **Digital Product Licence (EULA)** copy for paid products, matching the website; and
  - **Proprietary and Confidential** notice for internal projects.
- Policies that apply across every repository: `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md` and `CODE_OF_CONDUCT.md`, covering FiveM and RedM resources, Discord bots and services, website code and tools.
- Issue forms for FiveM and RedM bugs, other software bugs, feature requests and documentation problems, with links to support, security reporting and order help.
- A pull request template with checklists for each project type.
- Templates for every repository: README (free FiveM, free general, paid and internal), CHANGELOG, NOTICE, CODEOWNERS, `.editorconfig`, `.gitattributes`, `.gitignore`, `.env.example`, and internal notes for paid products.
- Private `CONTRIBUTING.md` and pull request templates for paid and internal repositories.
- GitLab issue and merge request templates.
- `tools/New-PigeonRepo.ps1` to set up a repository from the templates.

### Changed

- The business is described as **Pigeon Studios, the trading name of a sole trader based in England**, matching the website. Earlier documents used "Pigeon Studios Group".
- The governing law is **England and Wales**, matching the website. Earlier documents said "United Kingdom".
- The contact address for everything, including security reports, is **pigeon@pigeonstudios.co.uk**.
- Each repository now has a single `LICENSE.md` instead of both `LICENSE` and `LICENSE.md`.

### Removed

- Placeholder links (Discord invites, wiki URLs) and references to branches and processes that weren't in use.

First published 2 February 2019.

[2.7.0]: https://github.com/pigeon-studios-uk/.github/tree/v2.7.0
[2.6.0]: https://github.com/pigeon-studios-uk/.github/tree/v2.6.0
[2.5.1]: https://github.com/pigeon-studios-uk/.github/tree/v2.5.1
[2.5]: https://github.com/pigeon-studios-uk/.github/tree/v2.5
