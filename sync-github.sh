#!/data/data/com.termux/files/usr/bin/bash
#
# sync-github.sh — bidirectional sync of ~/projects to a private GitHub repo.
#
# First run (with --setup): prompts for GitHub username, repo name, PAT;
#   creates the repo if missing; initializes ~/projects as a git repo;
#   makes an initial commit; pushes.
#
# Subsequent runs (no args): commits local changes with a timestamp message,
#   pulls remote changes, pushes. Idempotent.
#
# Only ~/projects is synced. ~/.claude state stays on-device (avoids leaking
# auth tokens and conversation history to the repo).

set -euo pipefail

DEVBOX_HOME="$HOME/.devbox"
PROJECTS_DIR="$HOME/projects"
TOKEN_FILE="$DEVBOX_HOME/github-token"
CONFIG_FILE="$DEVBOX_HOME/github-sync.conf"

log()  { printf "\033[1;36m[sync:gh]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[sync:gh:warn]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[sync:gh:err]\033[0m %s\n" "$*" >&2; }

# ─── Setup flow ─────────────────────────────────────────────────────────────

setup() {
    log "GitHub sync setup."
    echo

    # Username
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
    printf "GitHub username [%s]: " "${GH_USER:-}"
    read -r input
    GH_USER="${input:-${GH_USER:-}}"
    [ -z "$GH_USER" ] && { err "Username required."; return 1; }

    # Repo name
    printf "Repo name for your DevBox projects [devbox-projects]: "
    read -r input
    GH_REPO="${input:-devbox-projects}"

    # PAT
    echo
    echo "Now a GitHub Personal Access Token. Create one at:"
    echo "  https://github.com/settings/tokens/new"
    echo "Scopes needed: repo (full)"
    echo
    printf "Paste token (won't be echoed): "
    stty -echo 2>/dev/null
    read -r GH_TOKEN
    stty echo 2>/dev/null
    echo
    [ -z "$GH_TOKEN" ] && { err "Token required."; return 1; }

    # Verify token
    log "Verifying token..."
    local who
    who=$(curl -s -H "Authorization: token $GH_TOKEN" https://api.github.com/user | \
          python -c "import sys,json; print(json.load(sys.stdin).get('login',''))" 2>/dev/null || true)
    if [ -z "$who" ] || [ "$who" != "$GH_USER" ]; then
        warn "Token verified as user '$who' but you entered '$GH_USER'."
        printf "Use '%s' instead? (y/N): " "$who"
        read -r ok
        if [ "${ok,,}" = "y" ]; then
            GH_USER="$who"
        else
            err "Username mismatch. Aborting."
            return 1
        fi
    fi

    # Save config (token in separate, chmod 600 file)
    mkdir -p "$DEVBOX_HOME"
    cat > "$CONFIG_FILE" << CONF_EOF
GH_USER="$GH_USER"
GH_REPO="$GH_REPO"
CONF_EOF
    printf "%s" "$GH_TOKEN" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE" "$CONFIG_FILE"

    # Create the repo if missing
    local repo_exists
    repo_exists=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: token $GH_TOKEN" \
        "https://api.github.com/repos/$GH_USER/$GH_REPO")
    if [ "$repo_exists" = "404" ]; then
        log "Creating private repo $GH_USER/$GH_REPO..."
        curl -s -X POST \
            -H "Authorization: token $GH_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"$GH_REPO\",\"private\":true,\"description\":\"DevBox project sync\"}" \
            https://api.github.com/user/repos > /dev/null
    else
        log "Repo $GH_USER/$GH_REPO already exists."
    fi

    # Initialize ~/projects as a git repo if it isn't one
    mkdir -p "$PROJECTS_DIR"
    cd "$PROJECTS_DIR"
    if [ ! -d .git ]; then
        git init -b main >/dev/null
        git config user.name "$GH_USER"
        git config user.email "$GH_USER@users.noreply.github.com"

        # Placeholder so we can commit
        if [ -z "$(ls -A .)" ]; then
            cat > README.md << README_EOF
# DevBox projects

Synced from a DevBox device. Each subfolder is a project.
README_EOF
        fi

        git add -A
        git commit -m "Initial DevBox sync" >/dev/null
    fi

    # Set remote
    local remote_url="https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git"
    if git remote | grep -q "^origin$"; then
        git remote set-url origin "$remote_url"
    else
        git remote add origin "$remote_url"
    fi

    log "Pushing initial commit..."
    git push -u origin main 2>&1 | grep -v "^remote:" || true

    log "GitHub sync configured."
    log "  Repo: https://github.com/$GH_USER/$GH_REPO"
    log "  Token stored: $TOKEN_FILE (chmod 600)"
    log "  Run 'devbox sync' any time to push changes."
}

# ─── Push / pull flow ───────────────────────────────────────────────────────

sync_push_pull() {
    if [ ! -f "$CONFIG_FILE" ] || [ ! -f "$TOKEN_FILE" ]; then
        err "GitHub sync not configured. Run: bash $0 --setup"
        return 1
    fi
    source "$CONFIG_FILE"
    local GH_TOKEN
    GH_TOKEN=$(cat "$TOKEN_FILE")

    cd "$PROJECTS_DIR" || { err "$PROJECTS_DIR missing"; return 1; }

    if [ ! -d .git ]; then
        err "$PROJECTS_DIR is not a git repo. Run: bash $0 --setup"
        return 1
    fi

    # Refresh remote URL with current token (in case token rotated)
    git remote set-url origin \
        "https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git"

    # Commit local changes
    local changes
    changes=$(git status --porcelain)
    if [ -n "$changes" ]; then
        log "Committing local changes..."
        git add -A
        git commit -m "devbox sync $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null
    else
        log "No local changes."
    fi

    # Pull remote changes (rebase keeps history linear)
    log "Pulling remote..."
    git pull --rebase --autostash origin main 2>&1 | grep -v "^From\|^remote:" || true

    # Push
    log "Pushing..."
    git push origin main 2>&1 | grep -v "^remote:" || true

    log "Sync complete."
}

# ─── Entry point ────────────────────────────────────────────────────────────

case "${1:-}" in
    --setup) setup ;;
    "")      sync_push_pull ;;
    *)       err "Unknown flag: $1"; echo "Usage: $0 [--setup]"; exit 1 ;;
esac
