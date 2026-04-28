#!/bin/bash
#
# sync-juju-image-metadata.sh
#
# Syncs OpenStack Glance images into:
#   1. SimpleStreams metadata (uploaded to Swift for new bootstraps)
#   2. Juju model DB image metadata (used by the provisioner at runtime)
#
# Run this whenever OpenStack images are refreshed (e.g. after
# glance-simplestreams-sync runs) to keep Juju in sync.
#
# Prerequisites:
#   - OpenStack credentials sourced (OS_AUTH_URL, OS_REGION_NAME, etc.)
#   - Juju CLI logged in and model selected
#   - swift CLI available (python-swiftclient)
#
# Usage:
#   sync-juju-image-metadata.sh [--dry-run] [--skip-simplestreams] [--skip-model-db]
#
# --dry-run for the SimpleStreams step will also fetch the current Swift metadata
# and show a diff (+NEW / ~UPDATE / =OK) without making any changes.
#

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# Parse arguments
# ──────────────────────────────────────────────────────────────────────
DRY_RUN=false
SKIP_SS=false
SKIP_DB=false
for arg in "$@"; do
    case "$arg" in
        --dry-run)          DRY_RUN=true ;;
        --skip-simplestreams) SKIP_SS=true ;;
        --skip-model-db)    SKIP_DB=true ;;
        -h|--help)
            echo "Usage: $0 [--dry-run] [--skip-simplestreams] [--skip-model-db]"
            echo ""
            echo "  --dry-run             Show what would be done; for SimpleStreams also diffs against current Swift state"
            echo "  --skip-simplestreams  Skip regenerating SimpleStreams in Swift"
            echo "  --skip-model-db       Skip updating Juju model DB image entries"
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

# ──────────────────────────────────────────────────────────────────────
# Configuration — derived from OS_ environment variables
# ──────────────────────────────────────────────────────────────────────
for _var in OS_AUTH_URL OS_REGION_NAME; do
    [ -n "${!_var:-}" ] || { echo "[ERROR] \$$_var is not set — source your openrc first" >&2; exit 1; }
done

KEYSTONE_ENDPOINT="$OS_AUTH_URL"
REGION="$OS_REGION_NAME"
SWIFT_CONTAINER="simplestreams"
STREAM="released"
# Only process images matching this grep pattern (active, auto-sync, non-daily)
IMAGE_FILTER="auto-sync/ubuntu-"
IMAGE_EXCLUDE_FILTER="-daily-"

# Resolve the Swift account URL from the service catalog
SWIFT_ACCOUNT_URL=$(swift auth 2>/dev/null | grep -oP '(?<=OS_STORAGE_URL=)\S+')
if [ -z "$SWIFT_ACCOUNT_URL" ]; then
    echo "[ERROR] Could not resolve Swift storage URL — check OS_ credentials and swift CLI" >&2
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────
info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; }

parse_image_name() {
    # Input:  auto-sync/ubuntu-jammy-22.04-amd64-server-20260320-disk1.img
    # Output: version and arch via global vars
    local name="$1"
    IMG_VERSION=$(echo "$name" | grep -oP '\d+\.\d+' | awk 'NR==1')
    IMG_ARCH=$(echo "$name" | grep -oP '(amd64|arm64|ppc64el|s390x|i386|riscv64)')
}

# ──────────────────────────────────────────────────────────────────────
# Step 1: Fetch current OpenStack image list
# ──────────────────────────────────────────────────────────────────────
info "Fetching active images from OpenStack..."
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

openstack image list --status active -f value -c ID -c Name 2>/dev/null | \
    grep -F "$IMAGE_FILTER" | grep -vF -- "$IMAGE_EXCLUDE_FILTER" > "$TMPFILE"

TOTAL=$(wc -l < "$TMPFILE")
info "Found $TOTAL released images in Glance"

if [ "$TOTAL" -eq 0 ]; then
    error "No images found — check your OpenStack credentials and filters"
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────
# Step 2: Regenerate SimpleStreams metadata and upload to Swift
# ──────────────────────────────────────────────────────────────────────
if [ "$SKIP_SS" = false ]; then
    info ""
    info "=== Regenerating SimpleStreams metadata ==="

    # ── Fetch current Swift state for diff (always, so dry-run can show delta) ──
    declare -A SWIFT_IMAGES   # key=version:arch  value=image_id
    SWIFT_META_PATH="images/streams/v1/com.ubuntu.cloud-released-imagemetadata.json"
    info "Fetching current Swift simplestreams metadata for comparison..."
    SWIFT_JSON=$(swift --os-storage-url "$SWIFT_ACCOUNT_URL" \
        download --output - "$SWIFT_CONTAINER" "$SWIFT_META_PATH" 2>/dev/null || true)
    if [ -n "$SWIFT_JSON" ]; then
        while IFS= read -r entry; do
            # entry format: "<version>:<arch> <image_id>"  produced by the python below
            s_key=$(echo "$entry" | awk '{print $1}')
            s_id=$(echo "$entry" | awk '{print $2}')
            SWIFT_IMAGES["$s_key"]="$s_id"
        done < <(echo "$SWIFT_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for pid,pdata in d.get('products',{}).items():
    parts=pid.split(':')
    if len(parts)<4: continue
    version,arch=parts[2],parts[3]
    for vdata in pdata.get('versions',{}).values():
        for item in vdata.get('items',{}).values():
            if 'id' in item:
                print(f'{version}:{arch} {item[\"id\"]}');
                break
        else:
            continue
        break
" 2>/dev/null)
        info "Swift currently has ${#SWIFT_IMAGES[@]} image entries"
    else
        warn "Could not fetch Swift metadata — will treat all Glance images as new"
    fi

    # Build a deduplicated map of the latest Glance image per (version, arch).
    # When multiple images share the same version+arch, the last one in the list wins
    # (Glance returns them sorted by name/date, so the newest is last).
    declare -A GLANCE_IMAGES   # key=version:arch  value=image_id
    declare -A GLANCE_NAMES    # key=version:arch  value=image_name
    while IFS= read -r line; do
        img_id=$(echo "$line" | awk '{print $1}')
        img_name=$(echo "$line" | awk '{print $2}')
        parse_image_name "$img_name"
        if [ -z "$IMG_VERSION" ] || [ -z "$IMG_ARCH" ]; then
            warn "Cannot parse name, skipping: $img_name"
            continue
        fi
        key="${IMG_VERSION}:${IMG_ARCH}"
        GLANCE_IMAGES["$key"]="$img_id"
        GLANCE_NAMES["$key"]="$img_name"
    done < "$TMPFILE"

    SS_DIR="$HOME/juju-simplestreams"
    rm -rf "$SS_DIR"
    mkdir -p "$SS_DIR"

    SS_NEW=0; SS_UPDATE=0; SS_OK=0; SS_FAIL=0
    if [ "$DRY_RUN" = true ]; then
        for key in $(echo "${!GLANCE_IMAGES[@]}" | tr ' ' '\n' | sort); do
            img_id="${GLANCE_IMAGES[$key]}"
            img_name="${GLANCE_NAMES[$key]}"
            swift_id="${SWIFT_IMAGES[$key]:-}"

            if [ -z "$swift_id" ]; then
                info "  [+NEW]    $key  $img_id  ($img_name)"
                SS_NEW=$((SS_NEW+1))
            elif [ "$swift_id" != "$img_id" ]; then
                info "  [~UPDATE] $key  $swift_id -> $img_id  ($img_name)"
                SS_UPDATE=$((SS_UPDATE+1))
            else
                info "  [=OK]     $key  $img_id"
                SS_OK=$((SS_OK+1))
            fi
        done
    else
        while IFS= read -r line; do
            img_id=$(echo "$line" | awk '{print $1}')
            img_name=$(echo "$line" | awk '{print $2}')
            parse_image_name "$img_name"
            if [ -z "$IMG_VERSION" ] || [ -z "$IMG_ARCH" ]; then
                continue
            fi
            if juju metadata generate-image \
                -d "$SS_DIR" \
                -i "$img_id" \
                --base "ubuntu@${IMG_VERSION}" \
                -a "$IMG_ARCH" \
                -r "$REGION" \
                -u "$KEYSTONE_ENDPOINT" \
                --stream "$STREAM" > /dev/null 2>&1; then
                SS_OK=$((SS_OK+1))
            else
                warn "generate-image failed for $img_id ($img_name)"
                SS_FAIL=$((SS_FAIL+1))
            fi
        done < "$TMPFILE"
    fi

    if [ "$DRY_RUN" = true ]; then
        info "SimpleStreams diff: $SS_NEW new, $SS_UPDATE would update, $SS_OK already up-to-date"

        # Report Swift entries that no longer have a matching Glance image
        for s_key in $(echo "${!SWIFT_IMAGES[@]}" | tr ' ' '\n' | sort); do
            if [ -z "${GLANCE_IMAGES[$s_key]:-}" ]; then
                info "  [-GONE]   $s_key  ${SWIFT_IMAGES[$s_key]}  (in Swift but not in Glance)"
            fi
        done
    else
        info "SimpleStreams generation: $SS_OK ok, $SS_FAIL failed"

        info "Uploading to Swift ($SWIFT_CONTAINER)..."
        find "$SS_DIR" -type f | while IFS= read -r f; do
            obj_path="${f#$SS_DIR/}"
            swift --os-storage-url "$SWIFT_ACCOUNT_URL" \
                upload --object-name "$obj_path" "$SWIFT_CONTAINER" "$f" 2>&1 | \
                grep -v 'BucketAlreadyExists' || true
        done
        info "SimpleStreams upload complete"
    fi
else
    info "Skipping SimpleStreams regeneration (--skip-simplestreams)"
fi

# ──────────────────────────────────────────────────────────────────────
# Step 3: Update Juju model DB image metadata
# ──────────────────────────────────────────────────────────────────────
if [ "$SKIP_DB" = false ]; then
    info ""
    info "=== Updating Juju model DB image metadata ==="

    # 3a: Get current entries from Juju model DB
    info "Fetching current Juju image metadata..."
    # Parse juju metadata images output (skip header line)
    # Columns: Source, Version, Arch, Region, ImageID, Stream, VirtType, StorageType
    declare -A JUJU_IMAGES=()
    while IFS= read -r line; do
        # Extract fields by position (image ID is the 36-char UUID)
        j_version=$(echo "$line" | awk '{print $2}')
        j_arch=$(echo "$line" | awk '{print $3}')
        j_imgid=$(echo "$line" | grep -oP '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
        if [ -n "$j_imgid" ] && [ -n "$j_version" ] && [ -n "$j_arch" ]; then
            JUJU_IMAGES["${j_version}:${j_arch}"]="$j_imgid"
        fi
    done < <(juju metadata images 2>/dev/null | grep -v '^Source')

    info "Current Juju DB entries: ${#JUJU_IMAGES[@]}"
    for key in "${!JUJU_IMAGES[@]}"; do
        info "  $key -> ${JUJU_IMAGES[$key]}"
    done

    # 3b: Build map of latest Glance image per (version, arch)
    # When multiple images match the same version+arch, pick the newest
    # (last one in the list, which is sorted by name/date)
    # GLANCE_IMAGES/GLANCE_NAMES may already be populated by Step 2; declare
    # them here as a fallback for the --skip-simplestreams path.
    declare -A GLANCE_IMAGES 2>/dev/null || true
    declare -A GLANCE_NAMES  2>/dev/null || true
    while IFS= read -r line; do
        img_id=$(echo "$line" | awk '{print $1}')
        img_name=$(echo "$line" | awk '{print $2}')
        parse_image_name "$img_name"

        if [ -z "$IMG_VERSION" ] || [ -z "$IMG_ARCH" ]; then
            continue
        fi

        key="${IMG_VERSION}:${IMG_ARCH}"
        GLANCE_IMAGES["$key"]="$img_id"
        GLANCE_NAMES["$key"]="$img_name"
    done < "$TMPFILE"

    # 3c: For each Juju DB entry, check if Glance has a newer/different ID
    DB_UPDATED=0; DB_SKIPPED=0
    for key in "${!JUJU_IMAGES[@]}"; do
        old_id="${JUJU_IMAGES[$key]}"
        new_id="${GLANCE_IMAGES[$key]:-}"
        version="${key%%:*}"
        arch="${key##*:}"

        if [ -z "$new_id" ]; then
            warn "No Glance image for $key — leaving Juju DB entry as-is"
            DB_SKIPPED=$((DB_SKIPPED+1))
            continue
        fi

        if [ "$old_id" = "$new_id" ]; then
            info "  $key: already up to date ($old_id)"
            DB_SKIPPED=$((DB_SKIPPED+1))
            continue
        fi

        info "  $key: STALE $old_id -> $new_id (${GLANCE_NAMES[$key]})"
        if [ "$DRY_RUN" = true ]; then
            info "    [dry-run] Would delete $old_id and add $new_id"
        else
            juju metadata delete-image "$old_id" 2>/dev/null || warn "    delete failed for $old_id"
            juju metadata add-image "$new_id" \
                --base "ubuntu@${version}" \
                --arch "$arch" \
                --region "$REGION" \
                --stream "$STREAM" 2>/dev/null || warn "    add failed for $new_id"
            info "    Updated"
        fi
        DB_UPDATED=$((DB_UPDATED+1))
    done

    info "Model DB: $DB_UPDATED updated, $DB_SKIPPED unchanged"
else
    info "Skipping Juju model DB update (--skip-model-db)"
fi

info ""
info "=== Sync complete ==="
