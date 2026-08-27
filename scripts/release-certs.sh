#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-Voronenko/fiks.im}"
ACME_SH="${ACME_SH:-$HOME/.acme.sh/acme.sh}"
DOMAIN="${DOMAIN:-fiks.im}"
DRY_RUN=0
FORCE=0
VERBOSE=0
SKIP_INSTALL=0
ALLOW_DIRTY=0

usage() {
  cat <<'EOF'
Usage: scripts/release-certs.sh [OPTIONS]

Retrieve certificates for fiks.im from acme.sh, check validity date,
check for a GitHub release tagged yyyy-mm-dd, and if absent commit
traefik_certs/ and create the release.

Options:
  --dry-run       Print what would be done, no git push or release create
  --force         Recreate release even if it already exists
  --skip-install  Skip acme.sh --install-cert (use current traefik_certs/)
  --allow-dirty   Allow unrelated dirty files in git working tree
  --repo SLUG     GitHub repo (default: Voronenko/fiks.im)
  --verbose       Verbose logging
  -h, --help      Show this help
Env:
  REPO, ACME_SH, DOMAIN, GITHUB_TOKEN
EOF
}

log()  { echo "[release-certs] $*" >&2; }
vlog() { [[ $VERBOSE -eq 1 ]] && echo "[release-certs] $*" >&2 || true; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --force) FORCE=1; shift ;;
    --skip-install) SKIP_INSTALL=1; shift ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [[ ! -d "$ROOT/traefik_certs" ]]; then
  echo "traefik_certs/ not found under $ROOT" >&2; exit 2
fi
cd "$ROOT"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2; return 1
  fi
}

has_gh=0
if command -v gh >/dev/null 2>&1; then has_gh=1; fi

missing=0
for cmd in openssl git date; do require_cmd "$cmd" || missing=1; done
if [[ $missing -eq 1 ]]; then exit 2; fi
if [[ $has_gh -eq 0 ]] && ! command -v curl >/dev/null 2>&1; then
  echo "Need gh or curl for GitHub API" >&2; exit 2
fi

if [[ -f "$HOME/.acme.sh/acme.sh.env" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.acme.sh/acme.sh.env" || true
fi

# ---------------------------------------------------------------------------
# a) retrieve certificates from acme.sh
# ---------------------------------------------------------------------------
install_certs() {
  local ec_store="$HOME/.acme.sh/${DOMAIN}_ecc"
  local rsa_store="$HOME/.acme.sh/${DOMAIN}"

  # Prefer EC store for EC certs, fallback to RSA store if _ecc missing
  if [[ ! -x "$ACME_SH" && ! -f "$ACME_SH" ]]; then
    echo "acme.sh not found at $ACME_SH (install: https://github.com/acmesh-official/acme.sh)" >&2
    return 2
  fi

  log "Installing EC certs from acme.sh (domain $DOMAIN, --ecc)..."
  if [[ -d "$ec_store" ]]; then
    "$ACME_SH" --install-cert -d "$DOMAIN" --ecc \
      --cert-file "$ROOT/traefik_certs/fiksim_cert.pem" \
      --key-file  "$ROOT/traefik_certs/fiksim_privkey.pem" \
      --fullchain-file "$ROOT/traefik_certs/fiksim_fullchain.pem"
  else
    vlog "No $ec_store, trying without --ecc (EC may be in $rsa_store)"
    "$ACME_SH" --install-cert -d "$DOMAIN" --ecc \
      --cert-file "$ROOT/traefik_certs/fiksim_cert.pem" \
      --key-file  "$ROOT/traefik_certs/fiksim_privkey.pem" \
      --fullchain-file "$ROOT/traefik_certs/fiksim_fullchain.pem" || \
    "$ACME_SH" --install-cert -d "$DOMAIN" \
      --cert-file "$ROOT/traefik_certs/fiksim_cert.pem" \
      --key-file  "$ROOT/traefik_certs/fiksim_privkey.pem" \
      --fullchain-file "$ROOT/traefik_certs/fiksim_fullchain.pem"
  fi

  log "Installing RSA certs from acme.sh (domain $DOMAIN)..."
  "$ACME_SH" --install-cert -d "$DOMAIN" \
    --cert-file "$ROOT/traefik_certs/rsa_fiksim_cert.pem" \
    --key-file  "$ROOT/traefik_certs/rsa_fiksim_privkey.pem" \
    --fullchain-file "$ROOT/traefik_certs/rsa_fiksim_fullchain.pem"
}

if [[ $SKIP_INSTALL -eq 0 ]]; then
  if ! install_certs; then
    echo "acme.sh install-cert failed" >&2; exit 2
  fi
else
  log "Skipping acme.sh install (--skip-install)"
fi

for f in traefik_certs/fiksim_cert.pem traefik_certs/rsa_fiksim_cert.pem; do
  if [[ ! -f "$f" ]]; then echo "Missing $f after install" >&2; exit 2; fi
done

# ---------------------------------------------------------------------------
# b) check validity date (notAfter -> yyyy-mm-dd)
# ---------------------------------------------------------------------------
parse_tag() {
  local cert="$1"
  local raw
  raw="$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)"
  if [[ -z "$raw" ]]; then echo "Failed to parse notAfter from $cert" >&2; return 1; fi
  # Try GNU date, then gdate, then python3
  local tag=""
  if tag="$(date -u -d "$raw" +%F 2>/dev/null)"; then
    echo "$tag"
  elif command -v gdate >/dev/null 2>&1 && tag="$(gdate -u -d "$raw" +%F 2>/dev/null)"; then
    echo "$tag"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c "
import sys
from datetime import datetime
raw = sys.argv[1]
for fmt in ('%b %d %H:%M:%S %Y %Z', '%b  %d %H:%M:%S %Y %Z'):
    try:
        print(datetime.strptime(raw, fmt).strftime('%Y-%m-%d'))
        sys.exit(0)
    except ValueError:
        pass
sys.exit(1)
" "$raw"
  else
    echo "Cannot parse date '$raw' (need GNU date, gdate, or python3)" >&2; return 1
  fi
}

ec_raw="$(openssl x509 -enddate -noout -in traefik_certs/fiksim_cert.pem | cut -d= -f2)"
rsa_raw="$(openssl x509 -enddate -noout -in traefik_certs/rsa_fiksim_cert.pem | cut -d= -f2)"
TAG="$(parse_tag traefik_certs/fiksim_cert.pem)"
RSA_TAG="$(parse_tag traefik_certs/rsa_fiksim_cert.pem)"

if [[ ! "$TAG" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Invalid tag derived: $TAG" >&2; exit 2
fi

log "EC  notAfter: $ec_raw -> tag $TAG"
log "RSA notAfter: $rsa_raw -> tag $RSA_TAG"
if [[ "$TAG" != "$RSA_TAG" ]]; then
  log "WARNING: EC and RSA expiry differ (EC=$TAG RSA=$RSA_TAG); using EC tag $TAG"
fi

if ! [[ "$TAG" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Invalid tag: $TAG" >&2; exit 2
fi

# ---------------------------------------------------------------------------
# c) check presence of release for this validity date
# ---------------------------------------------------------------------------
release_exists() {
  local tag="$1"
  if [[ $has_gh -eq 1 ]]; then
    if gh release view "$tag" --repo "$REPO" >/dev/null 2>&1; then return 0; fi
    # gh may return 0 even when not found on some versions, double-check via api
    if gh api "repos/$REPO/releases/tags/$tag" >/dev/null 2>&1; then return 0; fi
    return 1
  else
    if curl -sf "https://api.github.com/repos/$REPO/releases/tags/$tag" >/dev/null 2>&1; then return 0; fi
    return 1
  fi
}

if [[ $FORCE -eq 0 ]] && release_exists "$TAG"; then
  log "Release $TAG already exists in $REPO — nothing to do."
  exit 0
fi

if [[ $FORCE -eq 1 ]] && release_exists "$TAG"; then
  log "Release $TAG exists but --force given, will recreate."
fi

# ---------------------------------------------------------------------------
# d) commit/push + create release
# ---------------------------------------------------------------------------
mapfile -t ASSETS < <(find traefik_certs -maxdepth 1 -type f ! -name 'Makefile' | sort)
if [[ ${#ASSETS[@]} -eq 0 ]]; then
  echo "No assets found in traefik_certs/ (excluding Makefile)" >&2; exit 2
fi

log "Assets to publish (${#ASSETS[@]}): ${ASSETS[*]}"

if [[ $ALLOW_DIRTY -eq 0 ]]; then
  other_dirty="$(git status --porcelain 2>/dev/null | grep -v "^\?\?" | grep -v "traefik_certs" || true)"
  if [[ -n "$other_dirty" ]]; then
    echo "Working tree has changes outside traefik_certs/:" >&2
    echo "$other_dirty" >&2
    echo "Commit or stash them, or pass --allow-dirty" >&2
    exit 3
  fi
fi

# Stage certs
if [[ $DRY_RUN -eq 1 ]]; then
  log "[dry-run] would run: git add ${ASSETS[*]}"
else
  git add "${ASSETS[@]}"
fi

has_staged=1
if git diff --cached --quiet 2>/dev/null; then
  has_staged=0
  log "No staged changes (certs already committed), proceeding to release"
else
  vlog "Staged changes:"
  git diff --cached --stat >&2 || true
fi

if [[ $has_staged -eq 1 ]]; then
  commit_msg="chore(certs): update certs valid until $TAG

EC  notAfter: $ec_raw
RSA notAfter: $rsa_raw
"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would run: git commit -m \"chore(certs): update certs valid until $TAG\""
    log "[dry-run] would run: git push origin HEAD:master"
  else
    git commit -m "$commit_msg"
    log "Pushing to origin..."
    if ! git push origin HEAD:master; then
      # Try current branch if master push fails (e.g. not on master)
      cur_branch="$(git rev-parse --abbrev-ref HEAD)"
      if [[ "$cur_branch" != "master" ]]; then
        log "Push to master failed, trying current branch $cur_branch"
        git push origin "HEAD:$cur_branch"
      else
        exit 3
      fi
    fi
  fi
else
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would skip git commit/push (no staged changes)"
  fi
fi

# Create GitHub release
notes="Certificates valid until $TAG

- EC  fiksim: $ec_raw
- RSA fiksim: $rsa_raw
"

if [[ $has_gh -eq 1 ]]; then
  if [[ $DRY_RUN -eq 1 ]]; then
    if [[ $FORCE -eq 1 ]] && release_exists "$TAG"; then
      log "[dry-run] would run: gh release delete $TAG --repo $REPO --yes && gh release create $TAG --repo $REPO --title $TAG --notes \"...\" ${ASSETS[*]}"
    else
      log "[dry-run] would run: gh release create $TAG --repo $REPO --title $TAG --notes \"...\" ${ASSETS[*]}"
    fi
  else
    if [[ $FORCE -eq 1 ]] && release_exists "$TAG"; then
      log "Deleting existing release $TAG (--force)..."
      gh release delete "$TAG" --repo "$REPO" --yes || true
      # Delete tag if gh didn't
      git push origin ":refs/tags/$TAG" 2>/dev/null || true
    fi
    log "Creating release $TAG..."
    # gh release create creates tag if missing and uploads assets atomically
    if ! gh release create "$TAG" --repo "$REPO" --title "$TAG" --notes "$notes" "${ASSETS[@]}" 2>&1; then
      # If release already exists (race), try upload
      if release_exists "$TAG"; then
        log "Release $TAG already exists (race), uploading assets..."
        gh release upload "$TAG" "${ASSETS[@]}" --repo "$REPO" --clobber || exit 4
      else
        exit 4
      fi
    fi
    log "Release $TAG created."
  fi
else
  # curl fallback — create via API (requires GITHUB_TOKEN)
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "gh not installed and GITHUB_TOKEN not set — cannot create release" >&2
    echo "Install gh (https://cli.github.com) or set GITHUB_TOKEN" >&2
    exit 4
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[dry-run] would create release $TAG via GitHub API with ${#ASSETS[@]} assets"
  else
    log "Creating release $TAG via GitHub API..."
    # Create release
    api_resp="$(curl -sf -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Content-Type: application/json" \
      -d "$(printf '{"tag_name":"%s","name":"%s","body":%s,"draft":false,"prerelease":false}' "$TAG" "$TAG" "$(printf '%s' "$notes" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')")" \
      "https://api.github.com/repos/$REPO/releases" 2>&1)" || { echo "$api_resp" >&2; exit 4; }
    upload_url="$(printf '%s' "$api_resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("upload_url","").split("{")[0])' 2>/dev/null || true)"
    if [[ -z "$upload_url" ]]; then
      echo "Failed to get upload_url from GitHub API" >&2; echo "$api_resp" >&2; exit 4
    fi
    for asset in "${ASSETS[@]}"; do
      fname="$(basename "$asset")"
      log "Uploading $fname..."
      curl -sf -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$asset" \
        "${upload_url}?name=${fname}" >/dev/null || { echo "Upload failed for $fname" >&2; exit 4; }
    done
    log "Release $TAG created via API."
  fi
fi

log "Done. Tag: $TAG"
