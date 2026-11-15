from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/quest-test-python'))
from lupa.lua51 import LuaRuntime

MOCK='''
clock=100; grouped=false; sent=0; SlashCmdList={}; UIParent={}
function GetTime() return clock end
function time() return clock end
function IsInGuild() return true end
function IsInGroup() return grouped end
function GetNumGuildMembers() return 2 end
function GetGuildRosterInfo(i) return i==1 and "Alice" or "Bob",nil,nil,40,"Mage","Tanaris",nil,nil,true end
function CreateFrame()
 local f={scripts={},shown=false}
 function f:SetScript(k,v) self.scripts[k]=v end
 function f:IsShown() return self.shown end
 function f:Show() self.shown=true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
 function f:Hide() self.shown=false end
 setmetatable(f,{__index=function(_,k)
  if k=="CreateTexture" or k=="CreateFontString" then return function() return CreateFrame() end end
  if k=="IsShown" then return function() return false end end
  return function() end
 end}); return f
end
queries=0; requests=0; queryResult=0; probes={}; probeResult=0
C_ChatInfo={SendAddonMessage=function(prefix,text)
 if text=="?" then queries=queries+1 end
 return queryResult
end,RegisterAddonMessagePrefix=function() end}
C_Timer={NewTicker=function(_,callback) ticker=callback end}
box=CreateFrame(); function box:SetText(s) text=s end
function ChatFrame_SendTell(n) recipient=n end
function ChatEdit_GetActiveWindow() return box end
api={current=function() return "100-1" end,zone=function() return "Tanaris" end,
same=function(a,b) return a:match("^%d+")==b:match("^%d+") end,
name=function() return "Me" end,book=function() end,
normalize=function(n) return n:match("^([^%-]+)") end,
zoneName=function(z) return z=="1446" and "Tanaris" or z end,
discover=function() requests=requests+1; return "Request" end,
canProbe=function() return not grouped,"Paused while grouped." end,
probe=function(n,l) probes[#probes+1]=n; requestedLayer=l; return probeResult end,
askText=function(l) return "inv layer "..l end,sent=function() sent=sent+1 end}
'''
class GuildTests(unittest.TestCase):
 def setUp(self):
  self.lua=LuaRuntime(); self.lua.execute(MOCK)
  self.lua.execute((ROOT/'addons/LayerSwapGuild/GuildMembers.lua').read_text())
  self.lua.execute('g=LayerSwapGuildMembers(api)')
 def check(self,code): self.lua.execute(code)
 def test_identity_and_freshness(self):
  self.check('''assert(g.rows()[1].state=="Layer unknown")
   g.receive("LSGuild1","L|200-1|Tanaris","WHISPER","Alice")
   assert(g.rows()[1].state=="Layer unknown")
   g.receive("LSGuild1","L|200-1|Tanaris","GUILD","Stranger")
   assert(g.rows()[1].state=="Layer unknown")
   g.receive("LSGuild1","L|200-1|Tanaris","GUILD","Alice")
   assert(g.rows()[1].state=="Ask to join")
   clock=221; assert(g.rows()[1].state=="Layer unknown")''')
 def test_layer_letters_are_stable_and_zone_local(self):
  self.check('''assert(g.layerLabel("100-1","Tanaris")=="Layer A")
   assert(g.layerLabel("200-1","Tanaris")=="Layer B")
   assert(g.layerLabel("100-99","Tanaris")=="Layer A")
   assert(g.layerLabel("200-1","Elwynn")=="Layer A")
   assert(g.layerLabel(nil,"Tanaris")=="Unknown")
   for i=1,27 do g.layerLabel(tostring(i).."-1","Other") end
   assert(g.layerLabel("27-1","Other")=="Layer AA")''')
 def test_destination_does_not_claim_switch_from_request(self):
  self.check('''g.receive("LSGuild1","L|200-1|Tanaris","GUILD","Alice")
   g.rememberDestination("Alice")
   assert(g.transitionText():find("You: Layer A",1,true))
   assert(g.transitionText():find("Destination: Layer B",1,true))
   assert(g.transitionText():find("Requested",1,true))
   clock=131; assert(g.transitionText():find("unconfirmed",1,true))
   api.current=function() return "200-99" end
   assert(g.transitionText():find("Layer change observed",1,true))
   assert(g.transitionText():find("You: Layer B",1,true))''')
 def test_rejected_request_does_not_select_destination(self):
  self.check('''api.guildRequest=function() return "Blocked",false end
   g.ask("Alice"); assert(g.destination==nil)''')
 def test_same_layer_and_other_zone(self):
  self.check('''g.receive("LSGuild1","L|100-9|Tanaris","GUILD","Alice")
   assert(g.rows()[1].state=="Same layer")
   g.receive("LSGuild1","L|200-1|Elwynn","GUILD","Alice")
   assert(g.rows()[1].state=="Different zone")''')
 def test_click_sends_direct_request_without_chat(self):
  self.check('''g.receive("LSGuild1","L|200-1|Tanaris","GUILD","Alice")
   grouped=true; g.ask("Alice"); assert(#probes==0)
   grouped=false; g.ask("Alice"); assert(probes[1]=="Alice" and sent==1)
   assert(recipient==nil and requestedLayer=="200-1")
   g.ask("Alice"); assert(#probes==1)''')
 def test_stale_click_requests_without_stale_layer(self):
  self.check('''g.receive("LSGuild1","L|200-1|Tanaris","GUILD","Alice")
   clock=300; g.ask("Alice"); assert(probes[1]=="Alice" and requestedLayer==nil)''')
 def test_unknown_member_request_and_refusal(self):
  self.check('''g.ask("Stranger"); assert(#probes==0)
   probeResult=4; g.ask("Alice"); assert(#probes==1 and sent==0)
   clock=111; probeResult=0; g.ask("Bob"); assert(probes[2]=="Bob" and sent==1)
   assert(requestedLayer==nil and recipient==nil)''')
 def test_stock_layerswap_map_ids_and_realm_names(self):
  self.check('''g.receive("LayerSwap","heard Me|200-1|1446|h","WHISPER","Alice-Realm")
   assert(g.rows()[1].state=="Ask to join")
   assert(g.rows()[1].zone=="Tanaris")
   g.receive("LayerSwap","heard Other|100-9|1446|-","GUILD","Bob-Realm")
   assert(g.rows()[2].state=="Same layer")''')
 def test_stock_reply_scope(self):
  self.check('''g.receive("LayerSwap","heard Other|200-1|1446|h","WHISPER","Alice")
   assert(g.rows()[1].state=="Layer unknown")
   g.receive("LayerSwap","heard Me|200-1|1446|h","GUILD","Stranger")
   assert(g.rows()[1].state=="Layer unknown")''')
 def test_automatic_discovery_is_bounded_and_never_requests_invites(self):
  self.check('''g.poll(); assert(queries==1 and requests==0 and recipient==nil)
   g.poll(); clock=129; g.poll(); assert(queries==1)
   clock=130; g.poll(); assert(queries==2 and requests==0)
   assert(not g.queryFailed)
   queryResult=4; clock=160; g.poll(); assert(g.queryFailed)''')
 def test_panel_open_and_timer_refresh(self):
  self.check('''g.frame:Show(); assert(queries==1 and #probes==2)
   clock=130; ticker(); assert(queries==2 and requests==0 and #probes==2)
   clock=220; ticker(); assert(#probes==4)
   g.frame:Hide(); clock=340; ticker(); assert(#probes==4)''')
 def test_stock_requests_pause_for_group_invite_and_stop(self):
  self.check('''grouped=true; g.frame:Show(); assert(#probes==0)
   grouped=false; g.frame.scripts.OnEvent(g.frame,"PARTY_INVITE_REQUEST","Alice")
   ticker(); assert(#probes==0)
   clock=131; ticker(); assert(#probes==2)
   g.stockEnabled=false; clock=260; ticker(); assert(#probes==2)''')
 def test_stock_failure_backs_off_and_does_not_fake_report(self):
  self.check('''probeResult=3; g.frame:Show(); assert(#probes==1)
   clock=120; ticker(); assert(#probes==1)
   probeResult=0; clock=130; ticker(); assert(#probes==2)
   assert(g.rows()[1].state=="Layer unknown")''')
 def test_bridge_uses_stock_request_protocol(self):
  self.check('''LayerSwapGuildMembers=function(a) capturedApi=a; return {} end
   current="100-1"; FOREVER=true
   Layer={zone=function() return "Tanaris" end,same=function() end,instance=function() end}
   Who={rescan=function() end}; LayerSwapDB={}
   function UnitAffectingCombat() return false end
   function zoneOf() return 1446 end
   function askText(target,number,header)
    assert(target==nil and number==nil and header==true)
    return "inv layer <LS 1446 not 100-1>"
   end
   Send={note=function(kind,name,line)
    assert(kind=="WHISPER" and name=="Alice" and line=="inv layer <LS 1446 not 100-1>")
    return 0
   end}''')
  self.lua.execute((ROOT/'addons/LayerSwapGuild/Bridge.lua').read_text())
  self.check('assert(capturedApi.canProbe()); assert(capturedApi.probe("Alice")==0)')
if __name__=='__main__': unittest.main()
