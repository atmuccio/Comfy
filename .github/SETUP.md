# GitHub Repository Setup

## Required Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Required By | Description |
|--------|-------------|-------------|
| `DISCORD_WEBHOOK` | `release.yml`, `discord-notifications.yml` | Discord webhook URL for notifications. Create one in Discord: Server Settings → Integrations → Webhooks → New Webhook → Copy Webhook URL |

> `GITHUB_TOKEN` is provided automatically by GitHub Actions — no setup needed.

## Release Process

1. Update `CHANGELOG.md` with the new version's changes
2. Commit: `git commit -am "Release v1.0.0"`
3. Tag: `git tag v1.0.0`
4. Push: `git push && git push --tags`

BigWigs Packager will:
- Replace `@project-version@` in the .toc with the tag version
- Build and upload a `.zip` to the GitHub Release
- Generate `release.json` metadata for WoWUp compatibility

## WoWUp Integration

No additional setup needed. Once a GitHub Release exists with a `.zip` asset:
- Users add the repo URL in WoWUp → "Install from URL"
- WoWUp detects the release automatically via `release.json`
