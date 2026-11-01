#!/usr/bin/env python3
"""Build an offline catalog from existing project/worktree images; originals stay untouched."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import hashlib, json, os, re, shutil, struct, subprocess
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.svg', '.avif'}
EXCLUDE = {'node_modules', '.git', '.build', '.agents', '__pycache__', 'DerivedData'}


def roots():
    result = [(ROOT, 'Основной проект')]
    try:
        raw = subprocess.check_output(['git', 'worktree', 'list', '--porcelain', '-z'], cwd=ROOT).decode()
        paths = [Path(x[len('worktree '):]) for x in raw.split('\0') if x.startswith('worktree ')]
        for path in paths:
            if path.resolve() != ROOT.resolve():
                result.append((path, 'Orbit O' if 'orbit' in str(path).lower() else 'UI worktree'))
    except (OSError, subprocess.CalledProcessError):
        pass
    visited = set()
    for base, label in result:
        for relative in ('design', 'Design', 'outputs', 'iOSApp/Assets.xcassets', 'preview/assets'):
            folder = base / relative
            if folder.exists():
                st = folder.stat()
                identity = (st.st_dev, st.st_ino)
                if identity in visited: continue
                visited.add(identity)
                yield base, folder, label


def category(path, label):
    name = path.name.lower()
    text = path.as_posix().lower()
    if name.startswith('ios-') or '/ios/' in text:
        return 'ios'
    if ('owner-references/' in text or name.startswith('reference-') or
        ('research/evidence/2026-10-29/' in text and not name.startswith(('overview-concept', 'moneywise', 'okaneyan')))):
        return 'references'
    if any(word in text for word in ('/brand/', 'assets.xcassets/', '/icons/', 'orbit-o', '/design/')) and (
        name.endswith('.svg') or 'okaneyan' in name or 'orbit' in name or 'appicon' in text):
        return 'brand'
    if '/outputs/' in text or name.startswith(('web-', 'overview-concept')) or '/preview/' in text:
        return 'web'
    return 'other'


def dimensions(path, data):
    try:
        if data.startswith(b'\x89PNG\r\n\x1a\n'):
            return struct.unpack('>II', data[16:24])
        if data[:3] == b'GIF':
            return struct.unpack('<HH', data[6:10])
        if path.suffix.lower() == '.svg':
            node = ET.fromstring(data)
            box = re.split(r'[ ,]+', node.get('viewBox', '').strip())
            if len(box) == 4:
                return round(float(box[2])), round(float(box[3]))
            return tuple(round(float(re.sub(r'[^0-9.]', '', node.get(k, '0')) or 0)) for k in ('width','height'))
        out = subprocess.check_output(['sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(path)], stderr=subprocess.DEVNULL).decode()
        return tuple(int(re.search(k + r': (\d+)', out)[1]) for k in ('pixelWidth', 'pixelHeight'))
    except Exception:
        return 0, 0


def tags(name):
    words = []
    for keys, title in [
        (('gravity','structure'), 'Структура'), (('horizon',), 'Горизонт'),
        (('reserve','lock'), 'Резервы'), (('debt',), 'Долги'),
        (('import','picker','rule'), 'Импорт'), (('overview','living-card'), 'Обзор'),
        (('transaction','ledger'), 'Операции'), (('budget',), 'Бюджеты'),
        (('orbit','okaneyan'), 'Брендинг'), (('time-machine','scenario'), 'Сценарий'),
        (('before',), 'До изменения'), (('after',), 'После изменения'),
        (('light',), 'Светлая тема'), (('dark',), 'Тёмная тема')]:
        if any(k in name.lower() for k in keys): words.append(title)
    return words


def thumbnail(item):
    source = HERE / item['url']
    if item['format'] == 'SVG':
        item['thumbnail'] = item['url']
        return
    ext = '.png' if item['category'] == 'brand' else '.jpg'
    dest = HERE / 'thumbs' / (item['id'] + ext)
    if not dest.exists():
        cmd = ['sips']
        w, h = item['width'], item['height']
        if item['category'] in {'references', 'web'} and w and h > w * 1.5:
            cmd += ['--cropToHeightWidth', str(round(w * .75)), str(w), '--cropOffset', '0', '0']
        cmd += ['-Z', '700' if item['category'] == 'ios' else '600', '-s', 'format', 'png' if ext == '.png' else 'jpeg']
        if ext == '.jpg': cmd += ['-s', 'formatOptions', '75']
        cmd += [str(source), '--out', str(dest)]
        completed = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if completed.returncode != 0 or not dest.exists():
            item['thumbnail'] = item['url']
            return
    item['thumbnail'] = 'thumbs/' + dest.name


def main():
    for folder in ('media','thumbs','fonts'):
        (HERE / folder).mkdir(exist_ok=True)
    unique = {}
    source_count = 0
    for base, folder, label in roots():
        for path in sorted(folder.rglob('*')):
            if path.suffix.lower() not in EXTENSIONS or not path.is_file() or any(p in EXCLUDE for p in path.parts):
                continue
            data = path.read_bytes()
            digest = hashlib.sha256(data).hexdigest()[:24]
            source_count += 1
            relative = str(path.relative_to(base))
            alias = {'project': label, 'path': relative}
            if digest in unique:
                unique[digest]['sources'].append(alias)
                continue
            extension = path.suffix.lower()
            destination = HERE / 'media' / (digest + extension)
            if not destination.exists(): destination.write_bytes(data)
            width, height = dimensions(path, data)
            kind = category(path, label)
            unique[digest] = {
                'id': digest, 'name': path.name, 'category': kind,
                'tags': tags(path.stem), 'format': extension[1:].upper().replace('JPEG','JPG'),
                'width': width, 'height': height, 'bytes': len(data),
                'modified': path.stat().st_mtime,
                'url': 'media/' + destination.name,
                'sources': [alias]
            }
    items = list(unique.values())
    with ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(thumbnail, items))
    for src, name in [('Onest[wght].ttf','Onest.ttf'), ('Oswald[wght].ttf','Oswald.ttf'),
                      ('OFL-Onest.txt','OFL-Onest.txt'), ('OFL-Oswald.txt','OFL-Oswald.txt')]:
        original = ROOT / 'preview/fonts' / src
        if original.exists(): shutil.copyfile(original, HERE/'fonts'/name)
    payload = {'generated': datetime.now(timezone.utc).isoformat(), 'sourceCount': source_count, 'items': items}
    encoded = json.dumps(payload, ensure_ascii=False, separators=(',',':')).replace('<','\\u003c')
    (HERE/'catalog.js').write_text('window.GALLERY_CATALOG = '+encoded+';\n')
    counts = {k:sum(i['category']==k for i in items) for k in ('references','ios','web','brand','other')}
    print(json.dumps({'unique': len(items),'sourceFiles': source_count,'categories': counts},ensure_ascii=False))

if __name__ == '__main__': main()
