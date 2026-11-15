-- Cached website data, kept separate from the live native inspect window.
function GuildLayersArmory(who)
  local key=who:lower():gsub("%s+","-")
  local cache=GuildLayersArmoryData
  local data=cache and cache.schema==1 and cache.characters[key]
  if not data then return "No cached armory for "..who..". Sync this character with guild_layers_armory_sync.py, then reload UI." end
  local f=GuildLayersArmoryFrame
  if not f then
    f=CreateFrame("Frame","GuildLayersArmoryFrame",UIParent,"BackdropTemplate")
    f:SetSize(820,550);f:SetPoint("CENTER");f:SetFrameStrata("DIALOG");f:SetClampedToScreen(true)
    f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});f:SetBackdropColor(.025,.04,.05,.98)
    local function text(x,y,w,h,font)
      local t=f:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall");t:SetPoint("TOPLEFT",x,y);t:SetSize(w,h);t:SetJustifyH("LEFT");t:SetJustifyV("TOP");return t
    end
    f.title=text(20,-15,740,25,"GameFontNormalLarge")
    f.age=text(20,-45,770,40)
    f.info=text(90,-135,315,340)
    f.stats=text(480,-90,320,390)
    f.model=CreateFrame("PlayerModel",nil,f);f.model:SetSize(300,375);f.model:SetPoint("TOPLEFT",90,-100)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT");close:SetScript("OnClick",function() f:Hide() end)
    local previous=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");previous:SetSize(90,24);previous:SetPoint("BOTTOMLEFT",480,16);previous:SetText("Previous")
    local nextPage=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");nextPage:SetSize(90,24);nextPage:SetPoint("BOTTOMRIGHT",-20,16);nextPage:SetText("Next stats")
    previous:SetScript("OnClick",function() f.page=math.max(1,f.page-1);f.drawStats() end)
    nextPage:SetScript("OnClick",function() f.page=math.min(math.max(1,math.ceil(#f.data.stats/18)),f.page+1);f.drawStats() end)
    function f.drawStats()
      local lines={"STATISTICS (cached)"}
      for i=(f.page-1)*18+1,math.min(#f.data.stats,f.page*18) do local r=f.data.stats[i];lines[#lines+1]=r.name..": "..r.value end
      if #f.data.stats==0 then lines[#lines+1]="Statistics unavailable from the source." end
      f.stats:SetText(table.concat(lines,"\n"))
    end
    f.slots={}
    local slots={"HEAD","NECK","SHOULDER","BACK","CHEST","SHIRT","TABARD","WRIST","HANDS","WAIST","LEGS","FEET","FINGER_1","FINGER_2","TRINKET_1","TRINKET_2","MAIN_HAND","OFF_HAND","RANGED"}
    for i,slot in ipairs(slots) do
      local b=CreateFrame("Button",nil,f);b:SetSize(42,42)
      if i<=16 then b:SetPoint("TOPLEFT",i<=8 and 20 or 420,-90-((i-1)%8)*51)
      else b:SetPoint("BOTTOMLEFT",180+(i-17)*55,15) end
      b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetAllPoints()
      b:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(self.item and self.item.name or (slot..": no cached item"))
        if self.item then GameTooltip:AddLine(self.item.detail,1,1,1,true) end
        GameTooltip:AddLine("Website snapshot; item bonuses may differ from live data.",.6,.7,.8,true);GameTooltip:Show()
      end)
      b:SetScript("OnLeave",function() GameTooltip:Hide() end)
      f.slots[slot]=b
    end
  end
  f.data=data;f.page=1;f.title:SetText(who.." - Level "..tostring(data.level or "?").." "..data.class)
  local function stamp(value) return value and date("%Y-%m-%d %H:%M",math.floor(value/1000)) or "unavailable" end
  f.age:SetText("Gear checked: "..stamp(data.equipmentAt)..(data.equipmentStale and " (stale)" or "").." | Stats checked: "..stamp(data.statisticsAt)..(data.statisticsStale and " (stale)" or ""))
  f.model:Hide();f.info:Show();f.info:SetText(data.race.." "..data.class.."\n\nCached armory from osrs.services\n\n3D appearance unavailable remotely.\nHover gear for recorded item details.\n\nSync and reload UI to refresh.")
  -- Never substitute the local player's model for a remote guildmate.
  local a,b=UnitName("target")
  if (not issecretvalue or (not issecretvalue(a) and not issecretvalue(b))) and type(a)=="string" then
    local full=b and b~="" and a.." "..b or a
    if full:lower()==who:lower() then f.model:SetUnit("target");f.model:Show();f.info:Hide() end
  end
  for slot,b in pairs(f.slots) do
    b.item=data.items[slot]
    local icon=b.item and GetItemIcon and GetItemIcon(b.item.id)
    b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark");b:SetAlpha(b.item and 1 or .3)
  end
  f.drawStats();f:Show();return "Showing cached armory for "..who.."."
end
