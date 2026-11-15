from pathlib import Path
import sys,unittest,io,zipfile,hashlib,tempfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import guild_layers_update as update
class UpdaterTests(unittest.TestCase):
 def archive(self,names):
  stream=io.BytesIO()
  with zipfile.ZipFile(stream,'w') as z:
   for name in names: z.writestr(name,b'test')
  data=stream.getvalue(); return data,'sha256:'+hashlib.sha256(data).hexdigest()
 def test_valid_package_and_backup(self):
  data,digest=self.archive(['GuildLayers/'+n for n in update.FILES])
  files=update.unpack(data,digest)
  with tempfile.TemporaryDirectory() as directory:
   root=Path(directory); (root/'GuildLayers').mkdir(); (root/'GuildLayers/Core.lua').write_text('old')
   backup=update.install(root,files)
   self.assertEqual((backup/'Core.lua').read_text(),'old')
   self.assertEqual((root/'GuildLayers/Core.lua').read_bytes(),b'test')
 def test_wrong_digest_and_traversal_rejected(self):
  data,digest=self.archive(['GuildLayers/'+n for n in update.FILES])
  with self.assertRaises(ValueError): update.unpack(data,'sha256:wrong')
  names=['GuildLayers/'+n for n in update.FILES]; names[0]='GuildLayers/../../outside'
  with self.assertRaises(ValueError): update.unpack(*self.archive(names))
 def test_numeric_version(self):
  self.assertGreater(update.version('v1.10.0'),update.version('1.2.0'))
if __name__=='__main__': unittest.main()
