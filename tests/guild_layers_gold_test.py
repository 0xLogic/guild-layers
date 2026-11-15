from pathlib import Path
import unittest
from lupa.lua51 import LuaRuntime
from layerswap_guild_test import MOCK
ROOT=Path(__file__).resolve().parents[1]
class GoldTests(unittest.TestCase):
 def setUp(self):
  self.l=LuaRuntime();self.l.execute(MOCK)
  self.l.execute("""sharing=true; money=12345; guild='Guild'; roster={'Me','Alice','Bob'}; sends={}; accepted=true
   api={now=GetTime,key=string.lower,public=function() return true end,
    scope=function() return guild end,name=function() return 'Me' end,
    member=function(n) for _,v in ipairs(roster) do if v==n then return true end end return false end,
    roster=function() return roster end,money=function() return money end,
    sharing=function() return sharing end,setSharing=function(v) sharing=v end,
    send=function(t) sends[#sends+1]=t;return accepted end}
  """)
  self.l.execute((ROOT/'addons/GuildLayers/Gold.lua').read_text());self.l.execute('g=GuildLayersGold(api)')
 def runlua(self,s):self.l.execute(s)
 def test_automatic_reporting_and_copper_total(self):
  self.runlua("g.tick();assert(#sends==1 and sends[1]=='GOLD|1|12345');assert(g.receive('GOLD|1|20001','Alice'));assert(g.receive('GOLD|1|0','Bob'));s=g.summary();assert(s.total==32346 and s.fresh==3 and s.unknown==0);assert(g.moneyText(s.total)=='3g 23s 46c')")
 def test_unknown_and_empty_not_zero_reports(self):
  self.runlua("s=g.summary();assert(s.fresh==0 and s.unknown==3);g.receive('GOLD|1|0','Alice');s=g.summary();assert(s.fresh==1 and s.total==0 and s.unknown==2)")
 def test_duplicate_replaces_not_adds(self):
  self.runlua("g.receive('GOLD|1|100','Alice');g.receive('GOLD|1|100','Alice');s=g.summary();assert(s.fresh==1 and s.total==100);g.receive('GOLD|1|200','Alice');assert(g.summary().total==200)")
 def test_stale_and_expired_excluded(self):
  self.runlua("g.receive('GOLD|1|100','Alice');clock=191;s=g.summary();assert(s.total==0 and s.fresh==0 and s.stale==1);clock=401;s=g.summary();assert(s.stale==0 and s.unknown==3 and next(g.reports)==nil)")
 def test_foreign_and_invalid_messages(self):
  self.runlua("assert(not g.receive('GOLD|1|100','Other'));for _,v in ipairs({'-1','nan','inf','1.5','1e3','1000000000001','100|Alice'}) do assert(not g.receive('GOLD|1|'..v,'Alice')) end;assert(g.summary().fresh==0)")
 def test_offline_and_guild_change_clear(self):
  self.runlua("g.receive('GOLD|1|100','Alice');roster={'Me'};assert(g.summary().total==0 and next(g.reports)==nil);roster={'Me','Alice'};g.receive('GOLD|1|100','Alice');guild='Other';assert(g.summary().total==0);guild=nil;g.tick();assert(next(g.reports)==nil and #sends==0)")
 def test_reporting_is_always_on_even_with_obsolete_disabled_setting(self):
  self.runlua("sharing=false;g.tick();assert(#sends==1 and g.summary().fresh==1);clock=130;g.tick();assert(#sends==2);assert(g.setSharing==nil)")
 def test_remote_withdrawal(self):
  self.runlua("g.receive('GOLD|1|100','Alice');assert(g.receive('GOLD|1|OFF','Alice'));assert(g.summary().fresh==0)")
 def test_coalescing_and_periodic_refresh(self):
  self.runlua("g.tick();clock=101;money=1;g.dirty=true;g.tick();assert(#sends==1);clock=105;g.tick();assert(#sends==2 and sends[2]=='GOLD|1|1');clock=134;g.tick();assert(#sends==2);clock=135;g.tick();assert(#sends==3)")
 def test_requests_throttled_and_automatic_response(self):
  self.runlua("sharing=false;assert(g.request());assert(not g.request());g.receive('GOLDQ|1','Alice');g.tick();assert(#sends==2);clock=115;assert(g.request())")
 def test_restricted_money_and_send_failure(self):
  self.runlua("api.public=function() return false end;g.tick();assert(#sends==0);api.public=function() return true end;accepted=false;g.tick();assert(g.sendFailed and g.summary().total==12345)")
 def test_duplicate_roster_not_double_counted(self):
  self.runlua("roster={'Alice','Alice'};g.receive('GOLD|1|100','Alice');s=g.summary();assert(s.fresh==1 and s.total==100 and #s.rows==1)")
 def test_panel_pagination_and_empty_render(self):
  self.runlua("GuildLayersGoldPanel(g,api);g.render();g.page=999;g.render();assert(g.page==1);g.toggle();g.tick()")
 def test_roster_renders_balance_column_and_footer(self):
  l=LuaRuntime();l.execute(MOCK)
  l.execute("""allFrames={};local old=CreateFrame;CreateFrame=function(...) local f=old(...);function f:SetText(t) self.value=t end;allFrames[#allFrames+1]=f;return f end
   api.goldSummary=function() return {total=12345,fresh=1,unknown=1,stale=0,rows={{name='Alice',copper=12345,state='Fresh'},{name='Bob',state='Unknown'}}} end
   api.goldFormat=function() return '1g 23s 45c' end
   api.goldSharing=function() return true end;api.toggleGold=function() end
  """)
  l.execute((ROOT/'addons/LayerSwapGuild/GuildMembers.lua').read_text())
  l.execute("""ui=LayerSwapGuildMembers(api);ui.render();assert(ui.goldTotal.value:find('1g 23s 45c',1,true));assert(ui.goldTotal.value:find('1 unknown',1,true));local row=false;for _,f in ipairs(allFrames) do if f.columns and f.member=='Alice' then assert(f.columns[6].value=='1g 23s 45c');row=true end end;assert(row)""")
if __name__=='__main__':unittest.main()
