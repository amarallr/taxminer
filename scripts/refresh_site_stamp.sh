#!/usr/bin/env sh
# Refreshes the generation time of the published page after a hand patch of site/app/:
# the version stamp ("v.X · YYYY-MM-DD HH:MM") and the "Gerado em ..." sentence under
# "Sobre" always carry the same time, taken from the system clock. The commit hash is
# appended at deploy by .github/workflows/pages.yml. Run from the project root.
set -eu
f=site/app/index.html
now=$(date +"%Y-%m-%d %H:%M")
sed -i \
  -e "s|\(<div class=\"tm-version\"[^>]*>v\.[0-9.]* · \)[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}</div>|\1$now</div>|" \
  -e "s|Gerado em [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\} a partir|Gerado em $now a partir|" \
  "$f"
s=$(grep -c "tm-version\"[^>]*>v\.[0-9.]* · $now<" "$f" || true)
g=$(grep -c "Gerado em $now a partir" "$f" || true)
if [ "$s" != 1 ] || [ "$g" != 1 ]; then echo "stamp not refreshed (stamp=$s, gerado=$g)" >&2; exit 1; fi
echo "$now"
