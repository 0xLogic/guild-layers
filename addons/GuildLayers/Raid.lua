function GuildLayersRaid(api)
  local r={reports={},lastPing=-100}
  local function groupUnit(sender)
    for i=1,40 do
      local unit=IsInRaid() and ("raid"..i) or (i<=4 and "party"..i or nil)
      if unit then
        local n=UnitName(unit)
        if api.public(n) and api.key(n)==api.key(sender) then return unit end
      end
    end
  end
  function r.receive(text,sender)
    if not api.member(sender) or not groupUnit(sender) or type(text)~="string" or #text>110 then return false end
    local target=text:match("^PING|([^|%c]+)$")
    if not target then return false end
    local previous=r.reports[api.key(sender)]
    if previous and api.now()-previous.at<2 then return false end
    r.reports[api.key(sender)]={target=target,at=api.now()}
    print("Guild Layers: "..sender.." pinged "..target);return true
  end
  function r.ping()
    if not IsInGroup() or api.now()-r.lastPing<2 then return end
    local target=UnitName("target")
    if not api.public(target) or type(target)~="string" or #target>100 or target:find("[|%c]") then return end
    r.lastPing=api.now()
    pcall(C_ChatInfo.SendAddonMessage,"GuildLayers1","PING|"..target,IsInRaid() and "RAID" or "PARTY")
    print("Guild Layers: target ping sent for "..target)
  end
  local panel=CreateFrame("Frame","GuildLayersRaidPanel",UIParent,"BackdropTemplate")
  panel:SetSize(620,400);panel:SetPoint("CENTER");panel:SetMovable(true);panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton");panel:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
  panel:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
  panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});panel:SetBackdropColor(.025,.04,.05,.9)
  local title=panel:CreateFontString(nil,"OVERLAY","GameFontNormal");title:SetPoint("TOPLEFT",12,-10)
  title:SetText("GUILD RAID TARGETS - Left click: target / Right click: focus")
  local rows={}
  for i=1,40 do
    local b=CreateFrame("Button",nil,panel,"SecureActionButtonTemplate")
    b:SetSize(296,17);b:SetPoint("TOPLEFT",12+math.floor((i-1)/20)*302,-34-((i-1)%20)*18)
    b:RegisterForClicks("AnyUp");b:SetAttribute("type1","target");b:SetAttribute("type2","focus")
    b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");b.text:SetAllPoints();b.text:SetJustifyH("LEFT")
    rows[i]=b
  end
  panel:Hide()
  function r.tick()
    for i,b in ipairs(rows) do
      local unit=IsInRaid() and "raid"..i or (i<=4 and "party"..i or nil)
      if not InCombatLockdown() then b.unit=unit;b:SetAttribute("unit",unit and unit.."target" or "none") end
      local who=b.unit and UnitName(b.unit)
      if not api.public(who) then who=nil end
      local target=b.unit and UnitName(b.unit.."target")
      if not api.public(target) then target=nil end
      local ping=who and r.reports[api.key(who)]
      local suffix=ping and api.now()-ping.at<10 and " [PING]" or ""
      b.text:SetText(who and (who.." > "..(target or "No visible target")..suffix) or "-")
    end
  end
  function r.toggle()
    if InCombatLockdown() then print("Guild Layers: open or close raid targets outside combat.");return end
    r.tick();panel:SetShown(not panel:IsShown())
  end
  return r
end
BINDING_HEADER_GUILDLAYERS="Guild Layers"
BINDING_NAME_GUILDLAYERS_PING="Ping my target to guild raid/party"
BINDING_NAME_GUILDLAYERS_RAID="Toggle raid targets (outside combat)"
