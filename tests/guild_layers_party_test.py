from pathlib import Path
import sys
import unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/quest-test-python'))
from lupa.lua51 import LuaRuntime
from layerswap_guild_test import MOCK

class PartyTests(unittest.TestCase):
 def setUp(self):
  self.lua=LuaRuntime()
  self.lua.execute('''clock=100; grouped=false; allowed=true; membership=true; accepted=0; invited=0; messages={}; statuses={}; joined=false
   api={now=function() return clock end,key=string.lower,
    member=function(n) return membership and (n=="Alice" or n=="Bob") end,
    grouped=function() return grouped end,
    send=function(n,t) messages[#messages+1]={n,t}; return true end,
    status=function(s) statuses[#statuses+1]=s end,
    canHost=function() return allowed,"Hosting off" end,
    invite=function(n) invited=invited+1; return true end,
    accept=function() accepted=accepted+1; return true end,
    joined=function() return joined end}''')
  self.lua.execute((ROOT/'addons/GuildLayers/Party.lua').read_text())
  self.lua.execute('p=GuildLayersParty(api)')
 def runlua(self,s): self.lua.execute(s)
 def test_matching_request_invite_and_confirmed_join(self):
  self.runlua('''p.request("Alice"); assert(p.pending and accepted==0)
   p.receive("ACK|"..p.pending.token,"Alice"); assert(accepted==0)
   p.invitation("Bob"); assert(accepted==0)
   p.invitation("Alice"); assert(accepted==1 and p.pending)
   p.invitation("Alice"); assert(accepted==1)
   p.tick(); assert(p.pending)
   joined=true; p.tick(); assert(not p.pending)''')
 def test_host_validates_membership_and_deduplicates(self):
  self.runlua('''p.receive("JOIN|1-1","Stranger"); assert(invited==0)
   p.receive("JOIN|1-1","Alice"); assert(invited==1)
   clock=103; p.receive("JOIN|1-1","Alice"); assert(invited==1)
   membership=false; p.receive("JOIN|2-1","Alice"); assert(invited==1)''')
 def test_revocation_and_expiry_prevent_acceptance(self):
  self.runlua('''p.request("Alice"); membership=false; p.invitation("Alice"); assert(accepted==0)
   membership=true; clock=121; p.invitation("Alice"); assert(accepted==0)
   p.tick(); assert(not p.pending)''')
 def test_refusal_requires_matching_sender_and_token(self):
  self.runlua('''p.request("Alice"); local t=p.pending.token
   p.receive("NO|"..t.."|Full","Bob"); assert(p.pending)
   p.receive("NO|999|Full","Alice"); assert(p.pending)
   p.receive("NO|"..t.."|Full","Alice"); assert(not p.pending)''')
 def test_hosting_off_and_existing_group(self):
  self.runlua('''allowed=false; p.receive("JOIN|1-1","Alice")
   assert(invited==0 and messages[1][2]:match("^NO|"))
   grouped=true; p.request("Alice"); assert(not p.pending)''')
 def test_failed_send_never_arms_auto_accept(self):
  self.runlua('''api.send=function() return false end
   p.request("Alice"); assert(not p.pending)
   p.invitation("Alice"); assert(accepted==0)''')
 def test_autoaccept_all_verified_guildmates_without_click(self):
  self.runlua('''api.autoAcceptGuild=function() return true end
   p.invitation("Stranger"); assert(accepted==0)
   p.invitation("Alice"); assert(accepted==1 and p.pending.accepted)
   p.invitation("Alice"); assert(accepted==1)
   membership=false; p.invitation("Bob"); assert(accepted==1)
   membership=true; grouped=true; p.invitation("Bob"); assert(accepted==1)''')
 def test_two_endpoint_exchange(self):
  self.runlua('''host=GuildLayersParty(api)
   p.request("Alice"); host.receive(messages[1][2],"Bob")
   assert(invited==1); p.receive(messages[2][2],"Alice")
   p.invitation("Alice"); assert(accepted==1)
   joined=true; p.tick(); assert(not p.pending)''')
 def test_core_load_layer_detection_and_invite(self):
  l=LuaRuntime(); l.execute(MOCK)
  l.execute('''function UnitName(u) if u=="player" then return "Me" end end
   function UnitGUID(u)
    if u=="target" then return "Creature-0-7000-1-2-10-AAA" end
    if u=="mouseover" then return "Creature-0-7000-1-2-11-BBB" end
   end
   C_Map={GetBestMapForUnit=function() return 1446 end,GetMapInfo=function() return {name="Tanaris"} end}
   combat=true; function InCombatLockdown() return combat end
   function IsInRaid() return false end
   function UnitIsGroupLeader() return true end
   function GetNumGroupMembers() return 0 end
   function UnitIsDeadOrGhost() return false end
   accepts=0; function AcceptGroup() accepts=accepts+1 end
   invites=0; function InviteUnit() invites=invites+1 end
   local create=CreateFrame
   CreateFrame=function(...) local f=create(...); if not coreFrame then coreFrame=f end; return f end''')
  for path in ('LayerSwapGuild/GuildMembers.lua','GuildLayers/Version.lua','GuildLayers/Party.lua','GuildLayers/Escape.lua','GuildLayers/Map.lua','GuildLayers/Raid.lua','GuildLayers/Gold.lua','GuildLayers/Core.lua'):
   l.execute((ROOT/'addons'/path).read_text())
  l.execute('''coreFrame.scripts.OnEvent(coreFrame,"PLAYER_LOGIN")
   assert(GuildLayers and GuildLayersDB.hosting and GuildLayersDB.shareGold==nil)
   assert(#GuildLayers.rows()==0)
   coreFrame.scripts.OnEvent(coreFrame,"CHAT_MSG_ADDON","GuildLayers1","CAP|0","GUILD","Alice")
   assert(#GuildLayers.rows()==1 and GuildLayers.rows()[1].name=="Alice")
   local previousRoster=GetGuildRosterInfo
   function GetNumGuildMembers() return 3 end
   function GetGuildRosterInfo(i)
    if i==3 then return "Mojow Joejoe",nil,nil,40,"Druid","Tanaris",nil,nil,true end
    return previousRoster(i)
   end
   GuildLayers.roster()
   coreFrame.scripts.OnEvent(coreFrame,"CHAT_MSG_ADDON","GuildLayers1","CAP|0","WHISPER","Mojow Joejoe-Realm")
   assert(#GuildLayers.rows()==2)
   local oldSend=C_ChatInfo.SendAddonMessage
   replies=0
   C_ChatInfo.SendAddonMessage=function(prefix,text,channel,target)
    if text:match("^CAP|") and target=="Mojow Joejoe-Realm" and channel=="WHISPER" then replies=replies+1 end
    return 0
   end
   coreFrame.scripts.OnEvent(coreFrame,"CHAT_MSG_ADDON","GuildLayers1","PING|1","WHISPER","Mojow Joejoe-Realm")
   coreFrame.scripts.OnEvent(coreFrame,"CHAT_MSG_ADDON","GuildLayers1","PING|1","WHISPER","Mojow Joejoe-Realm")
   assert(replies==1)
   C_ChatInfo.SendAddonMessage=oldSend
   clock=191; assert(#GuildLayers.rows()==0)
   GuildLayersDB.addonOnly=false; assert(#GuildLayers.rows()==3)
   GuildLayers.ask("Alice")
   coreFrame.scripts.OnEvent(coreFrame,"PARTY_INVITE_REQUEST","Stranger"); assert(accepts==0)
   coreFrame.scripts.OnEvent(coreFrame,"PARTY_INVITE_REQUEST","Bob"); assert(accepts==1)
   coreFrame.scripts.OnEvent(coreFrame,"PARTY_INVITE_REQUEST","Alice"); assert(accepts==2)
   coreFrame.scripts.OnEvent(coreFrame,"CHAT_MSG_ADDON","GuildLayers1","JOIN|999-1","WHISPER","Bob")
   assert(invites==1)
   clock=220; ticker()
   coreFrame.scripts.OnEvent(coreFrame,"CHAT_MSG_ADDON","GuildLayers1","CAP|1","GUILD","Alice")
   GuildLayers.receive("LSGuild1","L|8000-2|Tanaris","GUILD","Alice")
   function UnitIsPlayer(u) return u=="nameplate1" end
   function UnitFactionGroup() return "Horde" end
   function UnitCanAttack() return true end
   checked=false; distance=100
   function UnitDistanceSquared() return distance,checked end
   joins=0; C_ChatInfo.SendAddonMessage=function(_,text)
    if text:match("^JOIN|") then joins=joins+1 end; return 0
   end
   GuildLayersDB.autoEscape=true
   ticker(); assert(joins==0)
   checked=true; distance=2000; ticker(); assert(joins==0)
   GuildLayersDB.hordeRadius=5; distance=100; ticker(); assert(joins==0)
   GuildLayersDB.hordeRadius=10; ticker(); assert(joins==1)
   ticker(); assert(joins==1)
   GuildLayersDB.autoEscape=false; GuildLayersDB.addonOnly=true
   clock=350; ticker()
   GuildLayers.frame.scripts.OnEvent(GuildLayers.frame,"CHAT_MSG_ADDON","LayerSwap",
     "heard Me|8000-2|1446|h","WHISPER","Mojow Joejoe-Realm")
   local rows=GuildLayers.rows()
   assert(#rows==1 and rows[1].name=="Mojow Joejoe" and rows[1].addon=="LayerSwap")
   assert(rows[1].layer=="8000-2" and rows[1].state=="Ask to join")
   stockRequests=0
   C_ChatInfo.SendAddonMessage=function(prefix,text,channel,target)
     if prefix=="LayerSwap" then
       assert(text=="inv layer <LS 1446 want 8000-2>" and channel=="WHISPER" and target=="Mojow Joejoe")
       stockRequests=stockRequests+1
     end
     return 0
   end
   GuildLayers.ask("Mojow Joejoe"); assert(stockRequests==1)
   coreFrame.scripts.OnEvent(coreFrame,"PARTY_INVITE_REQUEST","Mojow Joejoe-Realm")
   assert(accepts==3)''')

if __name__=='__main__': unittest.main()
