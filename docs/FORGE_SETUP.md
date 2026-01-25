# Forge Setup for Spacemacs

Forge integrates GitHub/GitLab issues and pull requests into Magit.

## Prerequisites

- Spacemacs git layer with forge enabled:
  ```elisp
  (git :variables
       git-enable-magit-forge-plugin t)
  ```

## Authentication Setup

Forge requires both git config settings AND tokens in authinfo.

### Step 1: Set your username in git config

```bash
git config --global github.user YOUR_GITHUB_USERNAME
git config --global gitlab.user YOUR_GITLAB_USERNAME
```

This is required because ghub (Forge's HTTP library) needs to know your username before making API calls.

### Step 2: Add tokens to authinfo

Tokens are stored in `~/.authinfo` (or `~/.authinfo.gpg` for encryption).

### GitHub

1. Get your token from the gh CLI (if authenticated):
   ```bash
   gh auth token
   ```

   Or create a new token at: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)

   Required scopes: `repo`, `read:org`

2. Add to `~/.authinfo`:
   ```
   machine api.github.com login YOUR_USERNAME^forge password YOUR_TOKEN
   ```

### GitLab

1. Get your token from the glab CLI config:
   ```bash
   grep token ~/.config/glab-cli/config.yml
   ```

   Or create a new token at: GitLab → Preferences → Access Tokens

   Required scopes: `api`, `read_user`

2. Add to `~/.authinfo`:
   ```
   machine gitlab.com/api/v4 login YOUR_USERNAME^forge password YOUR_TOKEN
   ```

### Self-hosted GitLab

```
machine gitlab.mycompany.com/api/v4 login YOUR_USERNAME^forge password YOUR_TOKEN
```

## File Permissions

Ensure authinfo is only readable by you:
```bash
chmod 600 ~/.authinfo
```

## Usage in Magit

Open a repository with `SPC g s`, then:

| Key       | Action                    |
|-----------|---------------------------|
| `@ f f`   | Fetch issues/PRs (forge-pull) |
| `@ l i`   | List issues               |
| `@ l p`   | List pull requests        |
| `@ c i`   | Create issue              |
| `@ c p`   | Create pull request       |
| `@ a`     | Assignee menu             |
| `@ r`     | Review menu               |

First `forge-pull` creates the local SQLite database and may take a moment.

## Troubleshooting

### "cannot determine username"
Set the username in git config:
```bash
git config --global github.user YOUR_USERNAME
git config --global gitlab.user YOUR_USERNAME
```

### "forge--request: 401"
Token is invalid or missing scopes. Regenerate with correct permissions.

### "No remote or remote is not a forge"
The repository's remote URL must point to a supported forge (GitHub, GitLab, Gitea, etc.).

### Database issues
Reset forge database: `M-x forge-reset-database`
