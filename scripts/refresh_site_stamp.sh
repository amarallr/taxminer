#!/usr/bin/env sh
# Refreshes the generation time of the published page after a hand patch of site/app/:
# the version stamp ("v.X · YYYY-MM-DD HH:MM -03:00") and the "Gerado em ..." sentence under
# "Sobre" always carry the same time, taken from the system clock with its UTC offset. It
# also writes site/app/version.json, the publication manifest: version, generation time,
# environment and the commit the build was made on (base_commit, the parent of the commit
# that publishes it: a commit cannot contain its own hash). The deploy step of
# .github/workflows/pages.yml appends the deployed commit to the stamp and fills
# deployed_commit, deployed_at and status in version.json. Run from the project root.
set -eu
f=site/app/index.html
now="$(date +"%Y-%m-%d %H:%M") $(date +%z | sed 's/\([0-9][0-9]\)$/:\1/')"
sed -i \
  -e "s|\(<div class=\"tm-version\"[^>]*>v\.[0-9.]* · \)[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}\( [-+][0-9]\{2\}:[0-9]\{2\}\)\{0,1\}</div>|\1$now</div>|" \
  -e "s|Gerado em [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}\( [-+][0-9]\{2\}:[0-9]\{2\}\)\{0,1\} a partir|Gerado em $now a partir|" \
  "$f"
s=$(grep -c "tm-version\"[^>]*>v\.[0-9.]* · $now<" "$f" || true)
g=$(grep -c "Gerado em $now a partir" "$f" || true)
if [ "$s" != 1 ] || [ "$g" != 1 ]; then echo "stamp not refreshed (stamp=$s, gerado=$g)" >&2; exit 1; fi
version=$(head -n 1 VERSION | tr -d '[:space:]')
base=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "")
printf '{"version":"%s","generated_at":"%s","environment":"PRODUÇÃO","base_commit":"%s","deployed_commit":"","deployed_at":"","status":"gerado, ainda não publicado"}\n' \
  "$version" "$now" "$base" > site/app/version.json
echo "$now"
