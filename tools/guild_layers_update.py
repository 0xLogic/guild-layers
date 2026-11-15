"""Python 3 updater. Check by default; --install explicitly replaces addon files."""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import tempfile
import time
import urllib.request
import zipfile

API='https://api.github.com/repos/0xLogic/guild-layers/releases/latest'
FILES={'GuildLayers.toc','GuildMembers.lua','Core.lua','Party.lua','Escape.lua','Map.lua','Raid.lua','Gold.lua','Bindings.xml','Version.lua','README.md'}
LIMIT=5*1024*1024

def fetch(url):
    request=urllib.request.Request(url,headers={'User-Agent':'GuildLayers-Updater','Accept':'application/vnd.github+json'})
    with urllib.request.urlopen(request,timeout=30) as response:
        data=response.read(LIMIT+1)
    if len(data)>LIMIT: raise ValueError('Download exceeds size limit')
    return data

def version(text):
    if not re.fullmatch(r'v?\d{1,3}\.\d{1,3}\.\d{1,3}',text): raise ValueError('Invalid version')
    return tuple(map(int,text.lstrip('v').split('.')))

def unpack(data,digest):
    if digest!='sha256:'+hashlib.sha256(data).hexdigest(): raise ValueError('Release checksum mismatch')
    result={}
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        if len(archive.infolist())!=len(FILES): raise ValueError('Unexpected archive entries')
        for item in archive.infolist():
            name=item.filename
            if not name.startswith('GuildLayers/') or name[len('GuildLayers/'):] not in FILES:
                raise ValueError('Unexpected archive path')
            name=name[len('GuildLayers/'):]
            if name in result or item.file_size>1024*1024: raise ValueError('Duplicate or oversized file')
            result[name]=archive.read(item)
    if set(result)!=FILES: raise ValueError('Incomplete addon archive')
    return result

def install(addons,files):
    addons=addons.resolve(strict=True)
    target=addons/'GuildLayers'
    if target.is_symlink() or target.resolve().parent!=addons: raise ValueError('Unsafe addon directory')
    target.mkdir(exist_ok=True)
    for name in files:
        if (target/name).is_symlink(): raise ValueError('Symlinked addon file')
    backup=Path(tempfile.mkdtemp(prefix='GuildLayers-backup-'+time.strftime('%Y%m%d-'),dir=addons))
    previous={}; written=[]
    try:
        for name,data in files.items():
            dest=target/name
            previous[name]=dest.exists()
            if dest.exists(): shutil.copy2(dest,backup/name)
            fd,temp=tempfile.mkstemp(prefix='.update-',dir=target)
            try:
                with os.fdopen(fd,'wb') as stream: stream.write(data)
                os.replace(temp,dest)
            finally:
                if os.path.exists(temp): os.unlink(temp)
            written.append(name)
    except Exception:
        for name in reversed(written):
            if previous[name]: shutil.copy2(backup/name,target/name)
            else: (target/name).unlink()
        raise
    return backup

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--addons-dir',required=True,type=Path)
    parser.add_argument('--install',action='store_true')
    args=parser.parse_args()
    toc=args.addons_dir/'GuildLayers/GuildLayers.toc'
    match=re.search(r'^## Version:\s*(\S+)',toc.read_text(encoding='utf-8'),re.M) if toc.exists() else None
    installed=match.group(1) if match else '0.0.0'
    release=json.loads(fetch(API)); tag=release['tag_name']
    print('Installed:',installed,'Latest:',tag)
    if version(installed)>=version(tag): print('No update needed.'); return
    if not args.install: print('Update available. Run again with --install to install it.'); return
    name='GuildLayers-'+tag.lstrip('v')+'.zip'
    assets=[a for a in release['assets'] if a['name']==name]
    if len(assets)!=1: raise ValueError('Expected exactly one matching release ZIP')
    asset=assets[0]; url=asset['browser_download_url']
    if not url.startswith('https://github.com/0xLogic/guild-layers/releases/download/'):
        raise ValueError('Unexpected download source')
    files=unpack(fetch(url),asset.get('digest'))
    archive_version=re.search(rb'^## Version:\s*(\S+)',files['GuildLayers.toc'],re.M)
    if not archive_version or version(archive_version.group(1).decode())!=version(tag):
        raise ValueError('Archive version does not match release')
    backup=install(args.addons_dir,files)
    print('Installed',tag,'Backup:',backup,'Use /reload to load the update.')

if __name__=='__main__': main()
