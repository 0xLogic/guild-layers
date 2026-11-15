from pathlib import Path
import zipfile
root=Path(__file__).resolve().parent
destination=root/'dist'; destination.mkdir(exist_ok=True)
with zipfile.ZipFile(destination/'GuildLayers-1.1.0.zip','w',zipfile.ZIP_DEFLATED) as z:
    for path in sorted((root/'addons/GuildLayers').iterdir()):
        if path.is_file(): z.write(path,'GuildLayers/'+path.name)
    z.write(root/'addons/LayerSwapGuild/GuildMembers.lua','GuildLayers/GuildMembers.lua')
print(destination/'GuildLayers-1.1.0.zip')
