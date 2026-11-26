#!/usr/bin/env python3
"""Static smoke checks for the NeedsList front-end package. No live Supabase calls."""
from pathlib import Path
from html.parser import HTMLParser
import re, shutil, subprocess, sys

ROOT = Path(__file__).resolve().parents[1]
HTML_FILES = sorted(ROOT.glob('*.html'))
errors, warnings = [], []

class Checker(HTMLParser):
    def __init__(self, file):
        super().__init__(); self.file=file; self.ids=set(); self.duplicates=[]; self.refs=[]
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if 'id' in a:
            if a['id'] in self.ids: self.duplicates.append(a['id'])
            self.ids.add(a['id'])
        attr = 'src' if tag == 'script' else 'href' if tag == 'link' else None
        if attr and a.get(attr): self.refs.append(a[attr])

for file in HTML_FILES:
    parser=Checker(file.name)
    try: parser.feed(file.read_text(encoding='utf-8'))
    except Exception as exc: errors.append(f'{file.name}: HTML parse error: {exc}')
    for item in parser.duplicates: errors.append(f'{file.name}: duplicate id="{item}"')
    for ref in parser.refs:
        if ref.startswith(('https://','http://','//','#','data:')): continue
        if not (ROOT / ref.split('#')[0]).exists(): errors.append(f'{file.name}: missing local reference {ref}')

node=shutil.which('node')
if node:
    for file in HTML_FILES:
        source=file.read_text(encoding='utf-8')
        scripts=re.findall(r'<script(?![^>]*\bsrc=)[^>]*>(.*?)</script>', source, re.I|re.S)
        for i,script in enumerate(scripts,1):
            p=subprocess.run([node,'--check'],input=script,text=True,capture_output=True)
            if p.returncode: errors.append(f'{file.name}: inline JS block {i}: {p.stderr.strip()}')
    for js in ROOT.glob('*.js'):
        p=subprocess.run([node,'--check',str(js)],text=True,capture_output=True)
        if p.returncode: errors.append(f'{js.name}: {p.stderr.strip()}')
else:
    warnings.append('Node.js not found: inline and standalone JavaScript syntax checks skipped.')

config=(ROOT/'config.js').read_text(encoding='utf-8') if (ROOT/'config.js').exists() else ''
if 'SUPABASE_URL' not in config or 'SUPABASE_ANON_KEY' not in config: errors.append('config.js: Supabase public configuration is missing.')
if re.search(r'service_role|sb_secret_', config, re.I): errors.append('config.js: possible privileged/secret key found; never publish it to GitHub Pages.')

for name in ['manifest.webmanifest','service-worker.js','pwa.js','offline.html']:
    if not (ROOT/name).exists(): errors.append(f'Missing PWA file: {name}')

print(f'HTML pages: {len(HTML_FILES)}')
print(f'Node.js: {node or "not installed"}')
for w in warnings: print('WARNING:',w)
for e in errors: print('ERROR:',e)
if errors: sys.exit(1)
print('PASS: static structure and available syntax checks completed.')
print('NOTE: this does not test Supabase credentials, RLS, RPCs, live CRUD, or mobile browser behavior.')
