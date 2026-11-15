from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime
from layerswap_guild_test import MOCK
ROOT=Path(__file__).resolve().parents[1]
class MapTests(unittest.TestCase):
 def setUp(self):
  self.l=LuaRuntime();self.l.execute(MOCK)
  self.l.execute("api={now=GetTime,key=string.lower,member=function(n) return n=='Alice' end,public=function() return true end}; GuildLayersDB={shareLocation=true}")
  self.l.execute((ROOT/'addons/GuildLayers/Map.lua').read_text());self.l.execute('m=GuildLayersMap(api)')
 def test_validation_scope_and_expiry(self):
  self.l.execute("assert(not m.receive('POS|1|500|500|?','Other'));assert(not m.receive('POS|1|10001|500|?','Alice'));assert(m.receive('POS|1|500|500|123-4','Alice'));assert(#m.rows(1)==1 and #m.rows(2)==0);clock=131;assert(#m.rows(1)==0)")
 def test_membership_revoked(self):
  self.l.execute("m.receive('POS|1|0|0|?','Alice');api.member=function() return false end;assert(#m.rows(1)==0)")
 def test_raid_ping_validation_and_throttle(self):
  self.l.execute("function IsInRaid() return true end;function InCombatLockdown() return false end; function UnitName(u) if u=='raid1' then return 'Alice' else return 'Enemy' end end")
  self.l.execute((ROOT/'addons/GuildLayers/Raid.lua').read_text());self.l.execute("r=GuildLayersRaid(api);assert(r.receive('PING|Enemy','Alice'));assert(not r.receive('PING|Enemy','Alice'));clock=103;assert(not r.receive('PING|bad|escape','Alice'));assert(not r.receive('PING|Enemy','Other'));r.tick();r.toggle()")
 def test_raid_protected_attributes_not_changed_in_combat(self):
  self.l.execute("combat=false; attrs=0;function IsInRaid() return true end;function InCombatLockdown() return combat end; function UnitName(u) return u=='raid1' and 'Alice' or nil end; local original=CreateFrame;CreateFrame=function(...) local f=original(...);function f:SetAttribute() assert(not combat);attrs=attrs+1 end;return f end")
  self.l.execute((ROOT/'addons/GuildLayers/Raid.lua').read_text())
  self.l.execute("r=GuildLayersRaid(api);r.tick();local before=attrs;combat=true;r.tick();r.toggle();assert(attrs==before)")
 def test_sharing_off_does_not_send(self):
  self.l.execute("GuildLayersDB.shareLocation=false;C_Map=nil;m.broadcast()")
 def test_lua_syntax(self):
  for f in (ROOT/'addons/GuildLayers').glob('*.lua'):
   self.l.execute('assert(loadstring(...))',f.read_text())
if __name__=='__main__':unittest.main()
