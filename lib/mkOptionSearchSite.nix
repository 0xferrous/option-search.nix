{ pkgs, lib ? pkgs.lib }:
{
  moduleDocs ? null,
  optionsJSON ? null,
  releaseName ? "local",
  config ? { },
  ...
}:
let
  optionsJSONPath =
    if moduleDocs != null then
      moduleDocs.optionsJSON
    else if optionsJSON != null then
      optionsJSON
    else
      throw "mkOptionSearchSite: set either moduleDocs or optionsJSON";

  optionsFileName = "options-${releaseName}.json";
in
pkgs.runCommand "option-search-site"
  {
    nativeBuildInputs = [ pkgs.python3 ];
    passthru = {
      inherit optionsJSONPath;
      optionsJSON = optionsJSONPath;
      inherit config;
    };
  }
  ''
    set -euo pipefail

    mkdir -p "$out/data"

    python3 - "$out/data/${optionsFileName}" \
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
    if title.startswith("_module"):
        continue

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

out.write_text(json.dumps({
    'last_update': dt.datetime.utcnow().strftime('%B %d, %Y at %H:%M UTC'),
    'options': options,
}, ensure_ascii=False))
PY
  ''
