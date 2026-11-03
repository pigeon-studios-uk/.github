# Changelog

All notable changes to the Pigeon Studios repository standards are documented here. Each policy and licence carries its own version line; this file records what changed and when. A free project's first release adds it to the organisation profile and the Q&A and Ideas forms by itself; those commits are lists, not policy changes, so they don't get a version or an entry here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [2.13.3] - 2026-11-03

### Fixed

- `New-PigeonProject.ps1` listed every image the README shows as still to add, even ones already in the folder, and always asked to fill in placeholders. It now lists only the images that are missing, and the files that still have `{{...}}` placeholders, if any.
- `Publish-PigeonProject.ps1` sends GitHub lower-case topics. GitLab can hand back a topic with capitals (`ESX`, `Standalone`) when another project made it first, and GitHub only takes lower case.

## [2.13.2] - 2026-11-03

### Fixed

- `Publish-PigeonProject.ps1` run on a repository that's already public would have replaced its description and topics, removing any added by hand, including the frameworks the website reads. It now only adds what's missing.

## [2.13.1] - 2026-11-03

### Changed

- New projects use CI Templates 1.4.1, whose release jobs retry once by themselves.

## [2.13.0] - 2026-11-03

One command for each step of a project's life, safe to run again, and nothing empty is ever public.

### Added

- `tools/Publish-PigeonProject.ps1` makes a free project public from GitLab, with no local copy: the GitHub repository, rulesets, mirror, deploy key and badge. It refuses a project with placeholders in its README, images that don't exist or no release workflow.
- `tools/Release-PigeonProject.ps1` releases a project from GitLab, with no local copy: it moves Unreleased into a dated section, sets the version, waits for the checks, and only then tags.
- `tools/Set-PigeonToken.ps1` saves the GitLab and GitHub tokens in Windows Credential Manager, so they last between sessions without being in a file. An environment variable still overrides them.

### Changed

- `New-PigeonProject.ps1` only makes the private GitLab project; the GitHub side moved to `Publish-PigeonProject.ps1`. It works in a folder where the resource is already written, never overwrites a file, and can be run again after a failure.
- New projects use CI Templates 1.4.0.

## [2.12.1] - 2026-11-03

### Changed

- New projects use CI Templates 1.3.1, so their first pipeline no longer fails because the banner hasn't been drawn.

## [2.12.0] - 2026-11-03

### Added

- `New-PigeonProject.ps1` copies the update checker from Pigeon Versions to `server/version_check.lua` and loads it in `fxmanifest.lua`, so a new resource checks for updates from its first release.
- `New-PigeonProject.ps1` checks everything it can before changing anything, including with `-DryRun`: that each token works, has the access it needs and how long it has left (with a warning at 30 days), that SSH to GitLab works, and that the GitLab project and GitHub repository don't exist yet.

### Changed

- New projects use CI Templates 1.3.0, whose `publish` waits for a free release's GitHub release.

### Fixed

- The GitHub CI that `New-PigeonProject.ps1` writes failed on every new repository's first push: it read a version from the example inside the CHANGELOG's comment. It now ignores comments and passes until the first release, and `release.yml` leaves comments out of the release notes.
- A failed `git` command no longer goes unnoticed; "Pushed" used to show even if the push failed.
- The list of what's left to do says how the website's webhook is really added.
- The README's examples use the `D:\PigeonStudios\Repos` folders.

## [2.11.0] - 2026-11-03

### Added

- Pigeon Enhanced Check in the organisation profile and in the Q&A and Ideas forms' resource lists.

## [2.10.1] - 2026-11-03

### Fixed

- `New-PigeonProject.ps1` failed at its first GitLab request with `{"error":"Invalid JSON format"}`: Windows PowerShell unrolled each request's UTF-8 bytes into a list of numbers, which was sent as text. Request bodies now go as one byte array, so the GitLab and GitHub set-up steps work.

## [2.10.0] - 2026-11-03

### Added

- `New-PigeonProject.ps1` sets up the GitHub side of a free project when `$env:GITHUB_TOKEN` is set alongside `$env:GITLAB_TOKEN`: the public repository with its description ("… Free."), the Free releases page as its website and its topics (with `pigeonstudios-release`), both rulesets from the handbook, the GitLab push mirror over SSH with GitHub's host keys and keep divergent refs, the mirror's deploy key with write access, and one mirror push to check it works.
- `-Icon` uploads the project's icon as the GitLab avatar.
- Free FiveM resources get the GitHub `ci.yml` (every Lua file compiles, the manifest version matches the CHANGELOG) and `release.yml` (builds `<path>.zip` from the tag and publishes the release), as the released free resources have.

### Changed

- New projects go under `D:\PigeonStudios\Repos`, laid out like GitLab (`fivem\releases\github\pigeon-<slug>`, `fivem\dev-releases\pg-<slug>`, `tools\<slug>`), instead of `D:\Git`.
- Free projects get the GitHub set of standard files, like the released free repositories, with the policies coming from the organisation's `.github`, instead of their own GitLab copies.
- The GitLab badge on free projects shows the latest GitHub release, like the existing free projects, and `.gitattributes` keeps tests and CI files out of release zips in the same block they use.

### Fixed

- A description starting with a one-letter word ("A fishing job…") is now lower-cased after the product name, like any other.
- Files the script writes end with a newline.

## [2.9.0] - 2026-11-03

### Added

- Six new free resources in the organisation profile and in the Q&A and Ideas forms' resource lists: Pigeon Bucket Monitor, Pigeon No NPC Aircraft, Pigeon No Blind Fire, Pigeon No Auto Helmet, Pigeon No Helmet Armour and Pigeon No Weapons In Vehicles.

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
