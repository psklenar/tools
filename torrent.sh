#!/bin/bash
set -uo pipefail

# ============================================================================
# Fedora ISO Torrent vs Mirror Comparison Tool
# ============================================================================
#
# DESCRIPTION:
#   Compares Fedora ISO files available via torrents against download mirrors
#   to identify discrepancies. Used for Fedora QA validation to ensure all
#   released ISOs have corresponding torrent files for distribution.
#
#   The script performs TWO types of validation:
#   1. ISO Availability: Checks if ISOs exist in both torrents and mirrors
#   2. CHECKSUM Bugs: Validates that torrent CHECKSUM files match product names
#
# WHAT IT FINDS:
#
#   A) ISO AVAILABILITY ISSUES:
#      - Missing in torrents: ISOs on mirrors but no torrent file exists
#      - Missing on mirrors: Torrent files exist but ISOs not on mirrors
#      - Mirror synchronization: Tests 11 global mirrors (Asia, Europe, US)
#
#   B) CHECKSUM BUGS (Critical QA Issue):
#      Detects when torrent files contain wrong CHECKSUM files:
#
#      Example Bug: Fedora-SoaS-Live-x86_64-43.torrent contains:
#        WRONG: Fedora-Spins-43-1.6-x86_64-CHECKSUM (generic)
#        RIGHT: Fedora-SoaS-Live-43-1.6-x86_64-CHECKSUM (product-specific)
#
#      The script tracks CHECKSUM bugs across F42 → F43 → F44 and categorizes:
#      - REGRESSIONS: Correct in F42, broken in F43+
#      - PERSISTING: Wrong in F42, F43, AND F44 (never fixed)
#      - FIXED: Were wrong, fixed in F44
#
#      For each bug, shows EXACT filenames:
#        F42: ❌ Fedora-Spins-42-1.1-x86_64-CHECKSUM
#        F43: ❌ Fedora-Spins-43-1.6-x86_64-CHECKSUM
#        F44: ❌ Fedora-Spins-iso-44_Beta-1.2-x86_64-CHECKSUM
#
# USEFUL FOR:
#   - Fedora QA team validating release consistency
#   - Identifying missing torrent files for released ISOs
#   - Identifying ISOs in torrents but not yet on mirrors
#   - Checking mirror synchronization across multiple continents
#   - **Tracking CHECKSUM bugs across Fedora releases**
#   - **Finding regressions where correct CHECKSUMs became wrong**
#
# WHAT TO CHECK:
#   1. "Missing in torrents" - ISOs released but no torrent file exists
#      → ACTION: Create torrent files for these ISOs
#   2. "Missing on mirror" - Torrents exist but ISOs not on mirrors
#      → ACTION: Check if mirrors are synced, or torrent is outdated
#   3. "Working: X/11 mirrors" - How many mirrors are reachable
#      → ACTION: If < 5, mirrors may be down or network issues
#   4. ISO counts match between torrents and mirrors
#      → ACTION: If counts differ significantly, investigate why
#   5. **"CHECKSUM bugs" - Products using wrong CHECKSUM files**
#      → ACTION: Report to Fedora infrastructure team, file bugs
#   6. **"Regressions" - CHECKSUMs that broke in newer releases**
#      → ACTION: Priority fix - these worked before and broke
#   7. **"Never fixed" - CHECKSUMs wrong across 3+ releases**
#      → ACTION: Long-standing issue, needs upstream attention
#
# POSSIBLE ISSUES:
#   - Mirrors down/slow: Script has 5s timeout per mirror, skips failed ones
#   - Torrent site down: Script will fail early with error message
#   - Version mismatch: Check VERSION parameter matches actual release
#   - Netinst excluded: Script filters out netinst images by design
#   - Script takes 2-3 minutes: Normal, checking 11 mirrors × many variants
#   - No transmission-show: Install with: dnf install transmission-cli
#   - Partial results: Check _downloads/mirror_isos.txt for details
#
# USAGE:
#   ./torrent.sh           # Check Fedora 43 (default)
#   ./torrent.sh 44        # Check Fedora 44
#   ./torrent.sh 42        # Check Fedora 42
#
# OUTPUT FILES:
#   _torrents/torrent_isos.txt       - ISOs found in torrent files
#   _downloads/mirror_isos.txt       - ISOs found on mirrors
#   _torrents/checksum_bugs.txt      - Raw CHECKSUM bug data
#   _torrents/bugs_regression.txt    - CHECKSUM regressions (F42✅→F43❌)
#   _torrents/bugs_persisting.txt    - Never-fixed CHECKSUM bugs
#   _torrents/bugs_fixed.txt         - Fixed in F44
#
# ============================================================================
# AI REGENERATION NOTES
# ============================================================================
#
# HOW TO REGENERATE THIS SCRIPT:
#
# 1. CORE FUNCTIONALITY:
#    - Download all .torrent files from torrent.fedoraproject.org
#    - Extract ISO filenames from torrents using transmission-show
#    - Crawl mirror sites for ISO files (multiple variants/architectures)
#    - Compare lists to find discrepancies
#
# 2. CHECKSUM VALIDATION LOGIC:
#    For each torrent file:
#      a) Extract CHECKSUM filename from torrent contents
#      b) Extract product name from torrent filename
#      c) Extract product name from CHECKSUM filename
#      d) If they don't match → BUG
#      e) Check same product in F42, F43, F44 torrents
#      f) Categorize: Regression, Persisting, or Fixed
#
#    Example:
#      Torrent: Fedora-SoaS-Live-x86_64-43.torrent
#      Product: "SoaS" (from torrent name)
#      CHECKSUM: Fedora-Spins-43-1.6-x86_64-CHECKSUM
#      CHECKSUM Product: "Spins" (from CHECKSUM name)
#      SoaS ≠ Spins → BUG!
#
# 3. VERSION COMPARISON:
#    - Check F(VERSION-1), F(VERSION), F(VERSION+1)
#    - Build bug history files for each version
#    - Compare patterns:
#      * F42:❌ F43:❌ F44:❌ = Never fixed
#      * F42:✅ F43:❌ F44:❌ = Regression
#      * F42:❌ F43:❌ F44:✅ = Fixed in F44
#
# 4. MIRROR CONFIGURATION:
#    Current mirrors (11 total):
#      - Asia: Taiwan (2), China (2), Japan (1), Korea (1), Hong Kong (1)
#      - Europe: Czech (1), Germany (1), Sweden (1)
#      - US: (1)
#
#    Find more: https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-VER&arch=x86_64
#    By country: Add &country=TW (or CN, JP, KR, SG, HK, etc.)
#
# 5. KEY TOOLS NEEDED:
#    - transmission-show: Extract file lists from .torrent files
#    - curl: Download torrents and crawl mirrors
#    - wget: Download all torrents (alternative)
#    - grep/sed/awk: Parse torrent/mirror HTML and extract names
#
# 6. IMPORTANT PATTERNS:
#    - Product name extraction: sed -E 's/Fedora-([^-]+)-.*/\1/'
#    - ISO filtering: grep -v 'netinst' (exclude netinst images)
#    - Timeout handling: curl -m 5 (5 second timeout per mirror)
#    - Version matching: grep -- "-$VERSION" (match specific version)
#
# 7. ERROR HANDLING:
#    - Use || true for non-critical operations
#    - Check mirror reachability before scanning
#    - Show ✓ for working mirrors, ✗ for failed ones
#    - Continue on partial failures (some mirrors down is OK)
#
# 8. OUTPUT FORMAT:
#    - Progressive: Show each step as it completes
#    - Detailed: Show exact CHECKSUM filenames, not just status
#    - Categorized: Group bugs by type (regression/persisting/fixed)
#    - Actionable: Tell user what each finding means
#
# ============================================================================

VERSION="${1:-43}"
TORRENT_BASE="https://torrent.fedoraproject.org/torrents/"

# Find mirror list at:
# https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$VERSION&arch=x86_64
# Or by country: ...&country=TW (CN, JP, KR, SG, HK, IN, TH, MY, ID)
# Or: curl -s "https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$VERSION&arch=x86_64&country=TW" | grep -E "^http"
#
# Available mirrors (some may be down):
# Taiwan: mirror.twds.com.tw, free.nchc.org.tw
# China: mirrors.tuna.tsinghua.edu.cn, mirrors.bfsu.edu.cn, mirrors.huaweicloud.com
# Japan: ftp.riken.jp, ftp.yz.yamagata-u.ac.jp
# Korea: mirror.krfoss.org
# Singapore: mirror.freedif.org
# Hong Kong: hkg.mirror.rackspace.com
# Czech: mirror.slu.cz, ftp.sh.cvut.cz, mirror.karneval.cz
# Germany: ftp.fau.de
# Sweden: mirror.bahnhof.net
# Switzerland: mirror.init7.net
# US: mirrors.nxthost.com
MIRRORS=(
  # Asia
  "https://mirror.twds.com.tw/fedora/fedora/linux/releases"
  "https://free.nchc.org.tw/fedora/linux/releases"
  "https://mirrors.tuna.tsinghua.edu.cn/fedora/releases"
  "https://mirrors.bfsu.edu.cn/fedora/releases"
  "http://ftp.riken.jp/Linux/fedora/releases"
  "https://mirror.krfoss.org/fedora/releases"
  "http://hkg.mirror.rackspace.com/fedora/releases"
  # Europe
  "https://mirror.slu.cz/fedora/linux/releases"
  "https://ftp.fau.de/fedora/linux/releases"
  "https://mirror.bahnhof.net/pub/fedora/linux/releases"
  # US
  "https://mirrors.nxthost.com/fedora/releases"
)

command -v transmission-show >/dev/null || { echo "Error: transmission-show not installed"; exit 1; }

mkdir -p _torrents _downloads

echo "Fedora $VERSION ISO Comparison"
echo "==============================="
echo "Torrent: $TORRENT_BASE"
echo "Mirrors: ${#MIRRORS[@]} configured"
echo

# Get ISOs from torrents
echo "Scanning torrents..."
cd _torrents

# Download torrents if needed
if [[ ! -f Fedora-Workstation-Live-x86_64-43.torrent ]]; then
  echo "  Downloading..."
  wget -q -r -l1 -nd -A "*.torrent" "$TORRENT_BASE"
fi

# Extract ISO names and check for CHECKSUM mismatches
{
  for f in *.torrent; do
    transmission-show -f "$f" 2>/dev/null | grep '\.iso' | awk '{print $1}' | grep '\.iso$' | xargs -r -n1 basename
  done
} | sort -u | grep -v 'netinst' | grep -- "-$VERSION" > torrent_isos.txt

echo "  Found $(wc -l < torrent_isos.txt) ISOs"

# Check for CHECKSUM file mismatches (e.g., SoaS torrent with Spins CHECKSUM)
echo "  Checking CHECKSUM files across versions..."
> checksum_bugs.txt

# Check F42, F43, F44 for comparison
PREV_VERSION=$((VERSION - 1))
PREV_PREV_VERSION=$((VERSION - 2))
NEXT_VERSION=$((VERSION + 1))

# Build bug history for all versions
for ver in $PREV_PREV_VERSION $PREV_VERSION $VERSION $NEXT_VERSION; do
  > checksum_bugs_v${ver}.txt
  for f in *.torrent; do
    if echo "$f" | grep -q -- "-${ver}"; then
      torrent_base=$(basename "$f" .torrent | sed 's/-[0-9]*$//')
      checksums=$(transmission-show -f "$f" 2>/dev/null | grep 'CHECKSUM' | awk '{print $1}')

      if [[ -n "$checksums" ]]; then
        while IFS= read -r checksum_line; do
          checksum_file=$(basename "$checksum_line")
          checksum_product=$(echo "$checksum_file" | sed -E 's/Fedora-([^-]+)-.*/\1/')
          torrent_product=$(echo "$torrent_base" | sed -E 's/Fedora-([^-]+)-.*/\1/')

          if [[ "$checksum_product" != "$torrent_product" ]]; then
            echo "$torrent_product|$checksum_product" >> checksum_bugs_v${ver}.txt
          fi
        done <<< "$checksums"
      fi
    fi
  done
done

# Now check current version and categorize
for f in *.torrent; do
  echo "$f" | grep -q -- "-$VERSION" || continue

  torrent_base=$(basename "$f" .torrent | sed 's/-[0-9]*$//')
  checksums=$(transmission-show -f "$f" 2>/dev/null | grep 'CHECKSUM' | awk '{print $1}')

  if [[ -n "$checksums" ]]; then
    while IFS= read -r checksum_line; do
      checksum_file=$(basename "$checksum_line")
      checksum_product=$(echo "$checksum_file" | sed -E 's/Fedora-([^-]+)-.*/\1/')
      torrent_product=$(echo "$torrent_base" | sed -E 's/Fedora-([^-]+)-.*/\1/')

      if [[ "$checksum_product" != "$torrent_product" ]]; then
        # Check status across versions
        in_prev_prev=$(grep -q "^${torrent_product}|${checksum_product}$" checksum_bugs_v${PREV_PREV_VERSION}.txt 2>/dev/null && echo "yes" || echo "no")
        in_prev=$(grep -q "^${torrent_product}|${checksum_product}$" checksum_bugs_v${PREV_VERSION}.txt 2>/dev/null && echo "yes" || echo "no")
        in_next=$(grep -q "^${torrent_product}|${checksum_product}$" checksum_bugs_v${NEXT_VERSION}.txt 2>/dev/null && echo "yes" || echo "no")

        echo "$f|$checksum_file|$torrent_product|$in_prev_prev|$in_prev|$in_next" >> checksum_bugs.txt
      fi
    done <<< "$checksums"
  fi
done

checksum_bug_count=$(wc -l < checksum_bugs.txt 2>/dev/null || echo 0)
if [[ $checksum_bug_count -gt 0 ]]; then
  echo "  Found $checksum_bug_count CHECKSUM bugs"
else
  echo "  ✓ No CHECKSUM issues"
fi

cd ..

# Get ISOs from mirrors
echo "Scanning mirrors..."
cd _downloads

> mirror_isos.txt
working=0

for MIRROR_BASE in "${MIRRORS[@]}"; do
  mirror_host=$(echo "$MIRROR_BASE" | sed 's|https\?://||;s|/.*||')

  # Test if mirror is reachable
  if curl -sf -m 5 "$MIRROR_BASE/$VERSION/" >/dev/null 2>&1; then
    echo "  ✓ $mirror_host"
    ((working++))

    # Common paths where ISOs are located
    for variant in Workstation Server Spins Labs Cloud Everything KDE Kinoite Silverblue \
                   Sericea Onyx COSMIC-Atomic; do
      for arch in x86_64 aarch64 ppc64le s390x; do
        curl -s -m 10 "$MIRROR_BASE/$VERSION/$variant/$arch/iso/" 2>/dev/null | \
          grep -oP 'href="Fedora[^"]*\.iso"' | sed 's/href="//;s/"$//' || true
      done
    done >> mirror_isos_temp.txt
  else
    echo "  ✗ $mirror_host (down/timeout)"
  fi
done

cat mirror_isos_temp.txt 2>/dev/null | sort -u | grep -v 'netinst' | grep -- "-$VERSION" > mirror_isos.txt
rm -f mirror_isos_temp.txt

echo "  Working: $working/${#MIRRORS[@]} mirrors"
echo "  Found $(wc -l < mirror_isos.txt) ISOs"
cd ..

# Compare
echo "Comparing..."
echo

TORRENT_COUNT=$(wc -l < _torrents/torrent_isos.txt)
MIRROR_COUNT=$(wc -l < _downloads/mirror_isos.txt)

echo "Torrents: $TORRENT_COUNT ISOs"
echo "Mirror:   $MIRROR_COUNT ISOs"
echo

# Compare sorted files
MISSING_TORRENTS=$(comm -13 _torrents/torrent_isos.txt _downloads/mirror_isos.txt 2>/dev/null)
MISSING_MIRROR=$(comm -23 _torrents/torrent_isos.txt _downloads/mirror_isos.txt 2>/dev/null)

if [[ -n "$MISSING_TORRENTS" ]]; then
  echo "Missing in torrents:"
  echo "$MISSING_TORRENTS" | sed 's/^/  /'
  echo
fi

if [[ -n "$MISSING_MIRROR" ]]; then
  echo "Missing on mirror:"
  echo "$MISSING_MIRROR" | sed 's/^/  /'
  echo
fi

if [[ -z "$MISSING_TORRENTS" && -z "$MISSING_MIRROR" ]]; then
  echo "✓ All match"
fi

# Report CHECKSUM bugs
if [[ -f _torrents/checksum_bugs.txt && -s _torrents/checksum_bugs.txt ]]; then
  echo
  echo "CHECKSUM Bug Evolution (F$PREV_VERSION → F$VERSION → F$NEXT_VERSION):"
  echo "============================================================"
  echo

  cd _torrents

  # Categorize products
  > bugs_persisting.txt
  > bugs_regression.txt
  > bugs_fixed.txt

  while IFS='|' read -r torrent checksum expected in_41 in_42 in_44; do
    product=$(echo "$torrent" | sed -E 's/Fedora-([^-]+)-.*/\1/')

    # Extract what CHECKSUM filename was used in current version (F43)
    f43_checksum_file=$(basename "$checksum")

    # Check if product exists in F42 and F44
    has_42=$(ls -1 | grep -q "${product}.*-${PREV_VERSION}.torrent" && echo "yes" || echo "no")
    has_44=$(ls -1 | grep -q "${product}.*-${NEXT_VERSION}" && echo "yes" || echo "no")

    # Get actual CHECKSUM filenames for F42 and F44
    if [[ "$has_42" == "yes" ]]; then
      f42_torrent=$(ls -1 | grep "${product}.*-${PREV_VERSION}.torrent" | head -1)
      f42_checksum_file=$(transmission-show -f "$f42_torrent" 2>/dev/null | grep CHECKSUM | awk '{print $1}' | head -1 | xargs -r basename)
      f42_product=$(echo "$f42_checksum_file" | sed -E 's/Fedora-([^-]+)-.*/\1/')
    else
      f42_checksum_file="N/A"
      f42_product="N/A"
    fi

    if [[ "$has_44" == "yes" ]]; then
      f44_torrent=$(ls -1 | grep "${product}.*-${NEXT_VERSION}" | head -1)
      f44_checksum_file=$(transmission-show -f "$f44_torrent" 2>/dev/null | grep CHECKSUM | awk '{print $1}' | head -1 | xargs -r basename)
      f44_product=$(echo "$f44_checksum_file" | sed -E 's/Fedora-([^-]+)-.*/\1/')
    else
      f44_checksum_file="N/A"
      f44_product="N/A"
    fi

    # Build status with actual wrong CHECKSUM names
    if [[ "$has_42" == "no" ]]; then
      f42="N/A"
    elif [[ "$in_42" == "yes" ]]; then
      f42="❌"
    else
      f42="✅"
    fi

    f43="❌"  # Current version has the bug

    if [[ "$has_44" == "no" ]]; then
      f44="N/A"
    elif [[ "$in_44" == "yes" ]]; then
      f44="❌"
    else
      f44="✅"
    fi

    # Categorize and store with full CHECKSUM filenames
    if [[ "$in_42" == "yes" && "$in_44" == "yes" && "$has_42" == "yes" && "$has_44" == "yes" ]]; then
      echo "$product|$torrent|$f42|$f42_checksum_file|$f43|$f43_checksum_file|$f44|$f44_checksum_file|Never fixed" >> bugs_persisting.txt
    elif [[ "$in_42" == "no" && "$in_44" == "yes" && "$has_42" == "yes" && "$has_44" == "yes" ]]; then
      echo "$product|$torrent|$f42|$f42_checksum_file|$f43|$f43_checksum_file|$f44|$f44_checksum_file|Regression" >> bugs_regression.txt
    elif [[ "$in_42" == "yes" && "$in_44" == "no" && "$has_42" == "yes" && "$has_44" == "yes" ]]; then
      echo "$product|$torrent|$f42|$f42_checksum_file|$f43|$f43_checksum_file|$f44|$f44_checksum_file|Fixed" >> bugs_fixed.txt
    elif [[ "$in_42" == "no" && "$in_44" == "no" && "$has_42" == "yes" && "$has_44" == "yes" ]]; then
      echo "$product|$torrent|$f42|$f42_checksum_file|$f43|$f43_checksum_file|$f44|$f44_checksum_file|F${VERSION} only" >> bugs_fixed.txt
    fi
  done < checksum_bugs.txt | sort -u

  # Display results
  if [[ -s bugs_regression.txt ]]; then
    echo "REGRESSIONS (correct → broken):"
    echo "==============================="
    while IFS='|' read -r product torrent f42 f42_file f43 f43_file f44 f44_file bug_status; do
      echo
      echo "Product: $product"
      echo "  Torrent: $torrent"
      echo "  F${PREV_VERSION}: $f42 $f42_file"
      echo "  F${VERSION}: $f43 $f43_file"
      echo "  F${NEXT_VERSION}: $f44 $f44_file"
      echo "  Status: $bug_status"
    done < bugs_regression.txt
    echo
  fi

  if [[ -s bugs_persisting.txt ]]; then
    echo "PERSISTING BUGS (never fixed):"
    echo "==============================="
    count=$(wc -l < bugs_persisting.txt)
    head -10 bugs_persisting.txt | while IFS='|' read -r product torrent f42 f42_file f43 f43_file f44 f44_file bug_status; do
      echo
      echo "Product: $product"
      echo "  Torrent: $torrent"
      echo "  F${PREV_VERSION}: $f42 $f42_file"
      echo "  F${VERSION}: $f43 $f43_file"
      echo "  F${NEXT_VERSION}: $f44 $f44_file"
      echo "  Status: $bug_status"
    done
    if [[ $count -gt 10 ]]; then
      echo
      echo "  ... and $((count - 10)) more persisting bugs (total: $count)"
    fi
    echo
  fi

  if [[ -s bugs_fixed.txt ]]; then
    echo "FIXED in F${NEXT_VERSION}:"
    echo "=========================="
    while IFS='|' read -r product torrent f42 f42_file f43 f43_file f44 f44_file bug_status; do
      echo
      echo "Product: $product"
      echo "  Torrent: $torrent"
      echo "  F${PREV_VERSION}: $f42 $f42_file"
      echo "  F${VERSION}: $f43 $f43_file"
      echo "  F${NEXT_VERSION}: $f44 $f44_file"
      echo "  Status: $bug_status"
    done < bugs_fixed.txt
    echo
  fi

  # Summary
  total=$(wc -l < checksum_bugs.txt)
  regression_count=$(wc -l < bugs_regression.txt 2>/dev/null || echo 0)
  persisting_count=$(wc -l < bugs_persisting.txt 2>/dev/null || echo 0)
  fixed_count=$(wc -l < bugs_fixed.txt 2>/dev/null || echo 0)

  echo "Summary: $total CHECKSUM bugs in F$VERSION"
  echo "  - Regressions (broke in F$VERSION): $regression_count"
  echo "  - Never fixed (F$PREV_VERSION→F$VERSION→F$NEXT_VERSION): $persisting_count"
  [[ $fixed_count -gt 0 ]] && echo "  - Fixed in F$NEXT_VERSION: $fixed_count"
  echo
  echo "Legend: ✅ = Correct, ❌ = Wrong (shows actual CHECKSUM product name)"

  cd ..
fi
