from pathlib import Path
import sys,unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/quest-test-python'))
from lupa.lua51 import LuaRuntime
class VersionTests(unittest.TestCase):
 def test_numeric_and_malformed_versions(self):
  l=LuaRuntime(); l.execute((ROOT/'addons/GuildLayers/Version.lua').read_text())
  l.execute('''assert(GuildLayersNewerVersion("1.10.0","1.2.0"))
   assert(not GuildLayersNewerVersion("1.2.0","1.2.0"))
   assert(not GuildLayersNewerVersion("1.1.9","1.2.0"))
   assert(not GuildLayersNewerVersion("9999.0.0","1.2.0"))
   assert(not GuildLayersNewerVersion("https://evil","1.2.0"))
   assert(not GuildLayersNewerVersion(nil,"1.2.0"))''')
if __name__=='__main__': unittest.main()
