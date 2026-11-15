from pathlib import Path
import zipfile
import re
root=Path(__file__).resolve().parent
version=re.search(r'^## Version:\s*(\S+)',(root/'addons/GuildLayers/GuildLayers.toc').read_text(),re.M).group(1)
destination=root/'dist'; destination.mkdir(exist_ok=True)
with zipfile.ZipFile(destination/('GuildLayers-'+version+'.zip'),'w',zipfile.ZIP_DEFLATED) as z:
    for path in sorted((root/'addons/GuildLayers').iterdir()):
        if path.is_file(): z.write(path,'GuildLayers/'+path.name)
    z.write(root/'addons/LayerSwapGuild/GuildMembers.lua','GuildLayers/GuildMembers.lua')
print(destination/('GuildLayers-'+version+'.zip'))
