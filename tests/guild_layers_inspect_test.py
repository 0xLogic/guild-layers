from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime
from layerswap_guild_test import MOCK
ROOT=Path(__file__).resolve().parents[1]
class InspectTests(unittest.TestCase):
 def setUp(self):
  self.l=LuaRuntime();self.l.execute(MOCK)
  self.l.execute("units={target='Enemy',party1='Alice'};calls=0;near=true;eligible=true;function UnitName(u) return units[u] end;function UnitIsPlayer(u) return units[u]~=nil end;function CanInspect(u) return eligible end;function CheckInteractDistance(u,i) assert(i==1);return near end;function InspectUnit(u) calls=calls+1;inspected=u end")
  self.l.execute((ROOT/'addons/GuildLayers/Core.lua').read_text())
 def check(self,s):self.l.execute(s)
 def test_opens_correct_guildmate_without_targeting(self):
  self.check("assert(GuildLayersInspect('Alice'):find('requested'));assert(calls==1 and inspected=='party1' and units.target=='Enemy')")
 def test_unavailable_offline_foreign_and_range(self):
  self.check("GuildLayersInspect('Other');assert(calls==0);near=false;GuildLayersInspect('Alice');assert(calls==0);near=true;eligible=false;GuildLayersInspect('Alice');assert(calls==0);units.party1=nil;GuildLayersInspect('Alice');assert(calls==0)")
 def test_nameplate_and_pacing(self):
  self.check("units.party1=nil;units.nameplate2='Alice';GuildLayersInspect('Alice');assert(inspected=='nameplate2');GuildLayersInspect('Alice');assert(calls==1);clock=102;GuildLayersInspect('Alice');assert(calls==2)")
 def test_target_changes_before_dispatch(self):
  self.check("function CanInspect(u) units[u]='Enemy';return true end;GuildLayersInspect('Alice');assert(calls==0)")
 def test_missing_api_and_errors(self):
  self.check("InspectUnit=nil;GuildLayersInspect('Alice');assert(calls==0);function InspectUnit() error('blocked') end;assert(GuildLayersInspect('Alice'):find('could not'))")
 def test_restricted_values_not_used(self):
  self.check("function issecretvalue(v) return v=='Alice' end;GuildLayersInspect('Alice');assert(calls==0)")
 def test_roster_inspect_click_does_not_request_layer_switch(self):
  l=LuaRuntime();l.execute(MOCK)
  l.execute("allFrames={};local old=CreateFrame;CreateFrame=function(...) local f=old(...);allFrames[#allFrames+1]=f;return f end;api.inspect=function(n) inspected=n;return 'Requested' end")
  l.execute((ROOT/'addons/LayerSwapGuild/GuildMembers.lua').read_text())
  l.execute("ui=LayerSwapGuildMembers(api);ui.render();local clicked=false;for _,f in ipairs(allFrames) do if f.member=='Alice' and f.inspectButton then f.inspectButton.scripts.OnClick();clicked=true end end;assert(clicked and inspected=='Alice' and #probes==0 and sent==0)")
if __name__=='__main__':unittest.main()
