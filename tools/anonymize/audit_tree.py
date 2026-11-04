#!/usr/bin/env python3
"""Fail closed on known identifiers in a staged tree, including container content.

This does not recognize faces, logos, spoken names, or text rasterized into media.
Those need separate visual/audio review.
"""
import gzip
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import zipfile

import pymupdf
from PIL import Image

# Underscores and digits also delimit names (e.g. andrea_build, grillo2026).
FORBIDDEN = re.compile(r'(?<![a-z])(andrea|grillo|plancher|brian|a2r|dartmouth|epfl|lausanne|agrillo|ag-think|arxiv|nsf|toyota|burke)(?![a-z])|2609\.09380', re.I | re.ASCII)
PERSONAL_PATH = re.compile(r'(?:/home/|/Users/)(?!user(?:[/\s\"\']|$))[^/\s\"\']+')
errors = []


def check(label, value):
    if isinstance(value, bytes):
        value = value.decode('utf-8', errors='replace')
    for pattern in (FORBIDDEN, PERSONAL_PATH):
        matches = sorted(set(m.group() for m in pattern.finditer(value)))
        if matches:
            errors.append(f'{label}: {matches}')


def scan(label, data, depth=0):
    if depth > 10:
        raise ValueError(f'archive nesting too deep: {label}')
    # Compressed image/video bytes contain random short-name matches. Inspect
    # their decoded metadata below; PDF/archive content is decoded here.
    media = Path(label).suffix.lower() in {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.tif', '.tiff', '.bmp', '.mp4', '.mov', '.avi', '.mkv', '.webm', '.pdf', '.zip', '.dcp', '.gz', '.tgz'}
    if not media:
        check(label, data)
    stream = io.BytesIO(data)
    if zipfile.is_zipfile(stream):
        with zipfile.ZipFile(stream) as archive:
            check(label + ': archive comment', archive.comment)
            for member in archive.infolist():
                check(label + ': member name', member.filename)
                check(label + ': member comment', member.comment)
                scan(label + '!' + member.filename, archive.read(member), depth + 1)
    elif data.startswith(b'\x1f\x8b'):
        scan(label + '!gzip', gzip.decompress(data), depth + 1)
    elif label.lower().endswith(('.tar', '.tgz', '.tar.gz')):
        with tarfile.open(fileobj=stream) as archive:
            for member in archive:
                check(label + ': member', str(member.pax_headers) + member.name + member.uname + member.gname + member.linkname)
                if member.isfile():
                    scan(label + '!' + member.name, archive.extractfile(member).read(), depth + 1)
    elif data.startswith(b'%PDF'):
        with pymupdf.open(stream=data, filetype='pdf') as doc:
            check(label + ': metadata', str(doc.metadata) + doc.get_xml_metadata())
            for page in doc:
                check(label + ': text', page.get_text())
                check(label + ': links', str(page.get_links()))
                for annot in page.annots() or []:
                    check(label + ': annotation', str(annot.info))
            for xref in range(1, doc.xref_length()):
                check(label + ': PDF object', doc.xref_object(xref))
                if doc.xref_is_stream(xref) and '/Subtype /Image' not in doc.xref_object(xref):
                    check(label + ': PDF stream', doc.xref_stream(xref))
            for name in doc.embfile_names():
                check(label + ': attachment name', name)
                scan(label + '!' + name, doc.embfile_get(name), depth + 1)


def main(root):
    count = 0
    for path in sorted(root.rglob('*')):
        label = str(path.relative_to(root))
        check('filename', label)
        if path.is_symlink():
            raise ValueError(f'unreviewed symlink: {label}')
        if not path.is_file():
            continue
        count += 1
        scan(label, path.read_bytes())
        if path.suffix.lower() in {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.tif', '.tiff', '.bmp'}:
            with Image.open(path) as im:
                check(label + ': image metadata', repr(im.info) + repr(dict(im.getexif())))
                for key, value in im.info.items():
                    if key.startswith('Raw profile type'):
                        check(label + ': decoded profile', bytes.fromhex(''.join(value.splitlines()[3:])))
        if path.suffix.lower() in {'.mp4', '.mov', '.avi', '.mkv', '.webm'}:
            info = subprocess.check_output(['ffprobe', '-v', 'error', '-show_format', '-show_streams', '-of', 'json', str(path)])
            check(label + ': video metadata', info)
            for stream in json.loads(info)['streams']:
                if stream['codec_type'] == 'subtitle':
                    check(label + ': subtitles', subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-map', f'0:{stream["index"]}', '-f', 'srt', '-']))
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'clean: {count} files; names, file content, archives, PDFs, image/video metadata and subtitles')


if __name__ == '__main__':
    main(Path(sys.argv[1]))
