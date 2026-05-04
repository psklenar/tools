#!/bin/bash
set -uo pipefail

# Simple torrent CHECKSUM validator
# Just checks if CHECKSUM file matches ISO file in each torrent

VERSION="${1:-43}"
TORRENT_BASE="https://torrent.fedoraproject.org/torrents/"

command -v transmission-show >/dev/null || { echo "Error: transmission-show not installed"; exit 1; }

mkdir -p _torrents
cd _torrents

# Download torrents if needed
if [[ ! -f Fedora-Workstation-Live-x86_64-${VERSION}.torrent ]]; then
  echo "Downloading torrents..."
  wget -q -r -l1 -nd -A "*.torrent" "$TORRENT_BASE"
fi

echo "Fedora $VERSION Torrent CHECKSUM Validation"
echo "============================================="
echo

correct=0
bugs=0

for torrent in *.torrent; do
  # Only check current version
  echo "$torrent" | grep -q -- "-$VERSION" || continue

  # Skip Beta torrents
  echo "$torrent" | grep -q "Beta" && continue

  # Get latest ISO file (sort by version, take last one - usually the final release)
  iso_file=$(transmission-show -f "$torrent" 2>/dev/null | grep '\.iso' | awk '{print $1}' | grep '\.iso$' | sort -V | tail -1 | xargs -r basename | sed 's/_Beta//g; s/Beta//g')

  # Get latest CHECKSUM file (corresponding to latest ISO)
  checksum_file=$(transmission-show -f "$torrent" 2>/dev/null | grep 'CHECKSUM' | awk '{print $1}' | sort -V | tail -1 | xargs -r basename | sed 's/_Beta//g; s/Beta//g')

  # Skip if no CHECKSUM (shouldn't happen)
  [[ -z "$checksum_file" ]] && continue

  # Extract product from ISO filename
  # Fedora-Budgie-Live-43-1.6.x86_64.iso -> Budgie
  iso_product=$(echo "$iso_file" | sed -E 's/Fedora-([^-]+)-.*/\1/')

  # Extract product from CHECKSUM filename
  # Fedora-Spins-43-1.6-x86_64-CHECKSUM -> Spins
  checksum_product=$(echo "$checksum_file" | sed -E 's/Fedora-([^-]+)-.*/\1/' | sed 's/_Beta//g; s/Beta//g')

  # Compare
  if [[ "$iso_product" == "$checksum_product" ]]; then
    echo "[+] $iso_product"
    echo "    ISO: $iso_file"
    echo "    CHECKSUM: $checksum_file"
    echo
    ((correct++))
  else
    # Clean torrent name for display
    torrent_display=$(echo "$torrent" | sed 's/_Beta//g; s/Beta//g')
    echo "[-] $iso_product (CHECKSUM mismatch!)"
    echo "    Torrent: $torrent_display"
    echo "    ISO: $iso_file"
    echo "    CHECKSUM: $checksum_file (says '$checksum_product' instead of '$iso_product')"
    echo
    ((bugs++))
  fi
done

echo "Summary:"
echo "========"
echo "  [+] Correct: $correct"
echo "  [-] Bugs: $bugs"
echo "  Total checked: $((correct + bugs))"
