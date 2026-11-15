from pathlib import Path
import sys,unittest
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'build/quest-test-python'))
from lupa.lua51 import LuaRuntime
class EscapeTests(unittest.TestCase):
 def setUp(self):
  self.l=LuaRuntime(); self.l.execute('''now=100; enabled=true; blocked=false; hostile=true; calls=0; layer="1"; available=true
   api={now=function() return now end,enabled=function() return enabled end,
    blocked=function() return blocked end,hostileNear=function() return hostile end,
    layer=function() return layer end,same=function(a,b) return a==b end,
    status=function(s) status=s end,
    candidates=function() return available and {{name="Alice",layer="2"},{name="Bob",layer="3"}} or {} end,
    request=function(n) calls=calls+1; requested=n; return true end}''')
  self.l.execute((ROOT/'addons/GuildLayers/Escape.lua').read_text()); self.l.execute('e=GuildLayersEscape(api)')
 def test_trigger_and_observed_transfer(self):
  self.l.execute('e.tick(); assert(calls==1 and e.pending); layer="2"; e.tick(); assert(not e.pending); assert(status:match("observed"))')
 def test_disabled_grouped_no_hostile_no_candidates(self):
  self.l.execute('''enabled=false; e.tick(); enabled=true; blocked=true; e.tick()
   blocked=false; hostile=false; e.tick(); hostile=true; available=false; e.tick(); assert(calls==0)''')
 def test_timeout_cooldown_and_next_candidate(self):
  self.l.execute('''e.tick(); assert(requested=="Alice")
   now=131; e.tick(); assert(not e.pending)
   now=159; e.tick(); assert(calls==1)
   now=160; e.tick(); assert(calls==2 and requested=="Bob")''')
if __name__=='__main__': unittest.main()
