{ pkgs, lib ? pkgs.lib }:
{
  moduleDocs ? null,
  optionsJSON ? null,
  releaseName ? "local",
  siteTitle ? "Option Search",
  releaseSwitchTitle ? "Release",
  languageCode ? "en-us",
  baseURL ? "https://example.invalid/",
  themeName ? "extranix-options-search",
  themeSrc ? pkgs.fetchFromGitHub {
    owner = "mipmip";
    repo = "hugo-theme-extranix-options-search";
    rev = "72c868cd62e738470d6c7bb0f3cad9f05b4c2b87";
    hash = "sha256-WXDtzgyWrhPzTRedAoCWpSS5juDdwJfY2Xq/CqL0jBI=";
  },
  searchDebounceMs ? 250,
  searchMaxResults ? 200,
  searchSortMinChars ? 3,
  hideParentSite ? true,
  footerCreditsLine ? "Powered by the <a href=\"https://nix-community.org/\">Nix Community</a>",
  footerCopyrightLine ? "",
  extraReleases ? [ ],
  config ? { },
}:
let
  optionsJSONPath =
    if moduleDocs != null then
      moduleDocs.optionsJSON
    else if optionsJSON != null then
      optionsJSON
    else
      throw "mkOptionSearchSite: set either moduleDocs or optionsJSON";

  siteConfig = lib.recursiveUpdate {
    inherit baseURL languageCode;
    title = siteTitle;
    theme = themeName;
    params = {
      release_current_stable = releaseName;
      release_switch_title = releaseSwitchTitle;
      releases = [
        {
          name = releaseName;
          value = releaseName;
        }
      ] ++ extraReleases;
      search_debounce_ms = searchDebounceMs;
      search_max_results = searchMaxResults;
      search_sort_min_chars = searchSortMinChars;
      hide_parent_site = hideParentSite;
      footer_credits_line = footerCreditsLine;
      footer_copyright_line = footerCopyrightLine;
    };
  } config;

  optionsFileName = "options-${releaseName}.json";
in
pkgs.runCommand "option-search-site"
  {
    nativeBuildInputs = [ pkgs.hugo pkgs.python3 ];
    passthru = {
      inherit optionsJSONPath;
      optionsJSON = optionsJSONPath;
    };
  }
  ''
    set -euo pipefail

    workdir="$(mktemp -d)"
    trap 'rm -rf "$workdir"' EXIT

    mkdir -p "$workdir/themes" "$workdir/static/data" "$workdir/content"
    ln -s ${themeSrc} "$workdir/themes/${themeName}"

    cat > "$workdir/config.json" <<'EOF'
${builtins.toJSON siteConfig}
EOF

    python3 - "$workdir/static/data/${optionsFileName}" \
      ${optionsJSONPath}/share/doc/nixos/options.json <<'PY'
from __future__ import annotations
import datetime as dt
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
infile = Path(sys.argv[2])

raw = json.loads(infile.read_text())

options = []
for title in sorted(raw.keys()):
    val = raw[title]

    def literal_text(v):
        if isinstance(v, dict) and v.get('_type') == 'literalExpression':
            return v.get('text', "")
        if isinstance(v, dict) and v.get('_type') == 'literalMD':
            return v.get('text', "")
        if v is None:
            return ""
        return v

    declarations = []
    for decl in val.get('declarations', []):
        if isinstance(decl, dict):
            name = decl.get('name') or decl.get('path') or ""
            url = decl.get('url') or ('file://' + name if name else "")
        else:
            name = str(decl)
            url = "file://" + name if name.startswith('/') else name
        declarations.append({'name': name, 'url': url})

    options.append({
        'title': title,
        'loc': val.get('loc', []),
        'type': val.get('type', ""),
        'description': val.get('description', ""),
        'default': literal_text(val.get('default', "")),
        'example': literal_text(val.get('example', "")),
        'declarations': declarations,
        'readOnly': bool(val.get('readOnly', False)),
    })

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps({
    'last_update': dt.datetime.utcnow().strftime('%B %d, %Y at %H:%M UTC'),
    'options': options,
}, ensure_ascii=False))
PY

    touch "$workdir/content/_index.md"
    cp "$workdir/config.json" "$workdir/config.yaml"
    hugo --source "$workdir" --destination "$out" --minify >/dev/null
  ''
