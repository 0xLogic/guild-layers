from pathlib import Path
import sys,unittest,json
from lupa.lua51 import LuaRuntime
from layerswap_guild_test import MOCK
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import guild_layers_armory_sync as sync
class ArmoryTests(unittest.TestCase):
 def test_serialization_cannot_inject_lua(self):
  l=LuaRuntime();value='"}; hacked=true; --é';l.execute('cache='+sync.lua({'name':value}));self.assertEqual(l.globals().cache['name'],value);self.assertIsNone(l.globals().hacked)
 def test_partial_profile_not_empty_gear_claim(self):
  row=sync.profile({'details':{'profile':{'data':{'name':'Alice'}}}},'alice')
  self.assertTrue(row['equipmentStale']);self.assertIsNone(row['equipmentAt']);self.assertEqual(row['stats'],[])
 def test_profile_missing_rejected(self):
  with self.assertRaises(ValueError):sync.profile({},'alice')
 def test_cached_panel_and_no_wrong_model(self):
  l=LuaRuntime();l.execute(MOCK)
  l.execute("function UnitName() return 'Different' end;function date() return 'date' end;models=0;local old=CreateFrame;CreateFrame=function(kind,n,...) local f=old(...);if n then _G[n]=f end;if kind=='PlayerModel' then function f:SetUnit() models=models+1 end end;return f end")
  data={'schema':1,'characters':{'alice':{'name':'Alice','level':43,'race':'Human','class':'Paladin','items':{'HEAD':{'id':123,'name':'Test helm','detail':'Strength'}},'stats':[{'name':'Health','value':'2379'}],'equipmentStale':True,'statisticsStale':True}}}
  l.execute('GuildLayersArmoryData='+sync.lua(data));l.execute((ROOT/'addons/GuildLayers/Armory.lua').read_text())
  l.execute("assert(GuildLayersArmory('Missing'):find('No cached'));assert(GuildLayersArmory('Alice'):find('Showing cached'));assert(models==0);assert(GuildLayersArmoryFrame.data.level==43)")
 def test_real_export_loads_if_present(self):
  p=ROOT/'build/test-armory-data.lua'
  if not p.exists():return
  l=LuaRuntime();l.execute(p.read_text());r=l.globals().GuildLayersArmoryData.characters['qouchi-liquor'];self.assertIsNotNone(r);self.assertGreater(len(list(r['items'].keys())),0)
if __name__=='__main__':unittest.main()
