#!/bin/bash

FVERSION="43"

rm -rf _torrents
rm -rf _downloads

mkdir _torrents
mkdir _downloads
output_file="list"


### TORRENTS
pushd _torrents
TORRENT_BASE="https://torrent.fedoraproject.org/torrents/"
wget -r -l1 -nd -A "*.torrent" $TORRENT_BASE

for f in *.torrent; do                                                                  
  transmission-show -f "$f" |grep '.iso'| awk '{print $1}' | xargs basename >> $output_file
done

popd


### DOWNLOADS
pushd _downloads

base="https://mirror.slu.cz/fedora/linux/releases/$FVERSION"


function crawl() {
    local url="$1"
    html=$(curl -s "$url/")
    
    echo "$html" | grep -oP 'href="Fedora[^"]+\.iso"' | sed -E 's/href="([^"]+)"/\1/' >> "$output_file"
    
    echo "$html" | grep -oP 'href="[^"]+/"' | sed -E 's/href="([^"]+)\/"/\1/' | while read -r sub; do
        if [[ "$sub" != "../" ]]; then
            crawl "$url/$sub"
        fi
    done
}

crawl "$base"

popd

### DIFF

sort -f -u _torrents/list -o _torrents/list
sort -f -u _downloads/list -o _downloads/list

echo ""
echo "TORRENT ISSUES: $base contains this iso but its missing in torrents files:"
grep -- "-$FVERSION" _torrents/list | grep -v 'netinst'  | grep -Fxv -f <(grep -- "-$FVERSION" _downloads/list)

echo ""
echo "DOWNLOAD ISSUES: $TORRENT_BASE shows this iso but its NOT in downloads:"
grep -- "-$FVERSION" _downloads/list | grep -v 'netinst' | grep -Fxv -f <(grep -- "-$FVERSION" _torrents/list)





