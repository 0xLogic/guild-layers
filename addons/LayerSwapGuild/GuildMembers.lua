-- Local LayerSwap extension. Layer identity is observed, never derived from roster position.
function LayerSwapGuildMembers(api)
  local G = { reports = {}, members = {}, page = 1, lastAsk = -100, lastSend = -100,
    stockEnabled=true, stockAsked={}, stockNext=0 }
  local PREFIX, TTL, PAGE = "LSGuild1", 120, 10
  local labels={}
  function G.layerLabel(id,zone)
    if not id or not zone then return "Unknown" end
    local list=labels[zone]
    if not list then list={}; labels[zone]=list end
    local index
    for i,known in ipairs(list) do if api.same(id,known) then index=i; break end end
    if not index then list[#list+1]=id; index=#list end
    local letters=""
    repeat
      index=index-1; letters=string.char(65+index%26)..letters; index=math.floor(index/26)
    until index==0
    return "Layer "..letters
  end
  function G.rememberDestination(name)
    G.layerLabel(api.current(),api.zone())
    for _,r in ipairs(G.rows()) do
      if r.name==name then
        G.destination={name=name,layer=r.layer,zone=r.zone,from=api.current(),fromZone=api.zone(),at=GetTime()}
        G.layerLabel(r.layer,r.zone)
        return
      end
    end
  end
  function G.transitionText()
    local here=G.layerLabel(api.current(),api.zone())
    local d=G.destination
    if not d then return "You: "..here.."  |  Destination: select a guildmate" end
    local target=G.layerLabel(d.layer,d.zone)
    local state="Requested"
    if d.zone~=api.zone() then state="Different zone"
    elseif d.layer and api.current() and api.same(d.layer,api.current()) then
      state=d.from and d.fromZone==d.zone and not api.same(d.from,d.layer) and "Layer change observed" or "Same layer"
    elseif GetTime()-d.at>30 then state="Switch unconfirmed" end
    return "You: "..here.."  →  Destination: "..target.." · "..state
  end
  if api.guildRequest then G.stockEnabled=false end
  local function key(name)
    if type(name)~="string" then return "" end
    return (api.normalize and api.normalize(name) or name):lower()
  end
  function G.roster()
    G.members = {}
    for i=1,GetNumGuildMembers() do
      local name,_,_,level,class,zone,_,_,online = GetGuildRosterInfo(i)
      if name and online and key(name)~=key(api.name()) then
        G.members[key(name)]={name=name,level=level,class=class,zone=zone}
      end
    end
  end
  function G.receive(prefix,text,channel,sender)
    if prefix=="LayerSwap" then
      if (channel~="GUILD" and channel~="WHISPER") or not G.members[key(sender)] or type(text)~="string" or #text>255 then return end
      local target,layer,zone,hosting=text:match("^heard (.-)|([^|]*)|([^|]*)|([h%-])$")
      if not target or (channel=="WHISPER" and key(target)~=key(api.name())) then return end
      if api.observeStock then api.observeStock(sender,hosting=="h") end
      if layer:match("^%d+%-%d+$") or layer:match("^%d+$") then
        G.reports[key(sender)]={layer=layer,zone=api.zoneName(zone),at=GetTime()}
      else
        G.reports[key(sender)]={at=GetTime()}
      end
      return
    end
    if prefix~=PREFIX or channel~="GUILD" or not G.members[key(sender)] or type(text)~="string" or #text>200 then return end
    if text=="?" then G.send(); return end
    local layer,zone=text:match("^L|([%d%-]+)|([^|]+)$")
    if layer and #layer<=32 then G.reports[key(sender)]={layer=layer,zone=zone,at=GetTime()} end
  end
  function G.send()
    if not IsInGuild() or GetTime()-G.lastSend<30 then return end
    local layer,zone=api.current(),api.zone()
    if not layer or not zone then return end
    G.lastSend=GetTime()
    pcall(C_ChatInfo.SendAddonMessage,PREFIX,"L|"..layer.."|"..zone,"GUILD")
  end
  -- Read-only discovery: never use stock "inv layer" as an automatic probe.
  function G.poll()
    if not IsInGuild() or (G.lastQuery and GetTime()-G.lastQuery<30) then return end
    G.lastQuery=GetTime()
    if api.discoverPresence then api.discoverPresence() end
    if api.rescan then api.rescan() end
    if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() elseif GuildRoster then GuildRoster() end
    G.roster()
    local ok,result=pcall(C_ChatInfo.SendAddonMessage,PREFIX,"?","GUILD")
    G.queryFailed=not ok or (result~=nil and result~=0)
    G.send()
  end
  function G.stockTick()
    if not G.stockEnabled or not G.frame:IsShown() or not IsInGuild() then return end
    if GetTime()<G.stockNext then return end
    local allowed,reason=api.canProbe()
    if not allowed then G.stockStatus=reason; return end
    if G.inviteUntil and GetTime()<G.inviteUntil then
      G.stockStatus="Invitation received; discovery paused briefly."; return
    end
    G.stockNext=GetTime()+5
    G.roster()
    local candidates={}
    for k,m in pairs(G.members) do
      if not G.stockAsked[k] or GetTime()-G.stockAsked[k]>=120 then
        candidates[#candidates+1]=m.name
      end
    end
    table.sort(candidates)
    G.stockStatus="Waiting for standard LayerSwap replies. Hosts may invite you."
    for i=1,math.min(2,#candidates) do
      local name=candidates[i]
      -- Attempts are rate limited even if the client refuses delivery.
      G.stockAsked[key(name)]=GetTime()
      local ok,result=pcall(api.probe,name)
      if not ok or result~=0 then
        G.stockStatus="Game refused or throttled LayerSwap requests; retrying in 30 seconds."
        G.stockNext=GetTime()+30
        return
      end
    end
  end
  function G.rows()
    G.layerLabel(api.current(),api.zone())
    local rows={}
    for k,m in pairs(G.members) do
      if not api.filterEnabled or not api.filterEnabled() or api.installed(m.name) then
      local r=G.reports[k]
      if not r or GetTime()-r.at>TTL then
        local b=api.book(m.name)
        r=b and b.at and time()-b.at>=0 and time()-b.at<=TTL and b or nil
      end
      local state="Layer unknown"
      if r and r.layer then
        if r.zone~=api.zone() then state="Different zone"
        elseif not api.current() then state="Your layer unknown"
        elseif api.same(r.layer,api.current()) then state="Same layer"
        else state="Ask to join" end
      end
      rows[#rows+1]={name=m.name,level=m.level,class=m.class,layer=r and r.layer,
        zone=r and r.zone or m.zone,state=state,addon=api.addonKind and api.addonKind(m.name)}
      end
    end
    table.sort(rows,function(a,b)
      if (a.state=="Ask to join")~=(b.state=="Ask to join") then return a.state=="Ask to join" end
      return a.name<b.name
    end)
    return rows
  end
  function G.ask(name)
    G.roster()
    if api.guildRequest then
      local message,accepted=api.guildRequest(name)
      if accepted then G.rememberDestination(name) end
      return message
    end
    if IsInGroup() then return "Leave your group before requesting a switch." end
    local allowed,reason=api.canProbe()
    if not allowed then return reason end
    if GetTime()-G.lastAsk<10 then return "Wait a moment before asking again." end
    for _,r in ipairs(G.rows()) do
      if r.name==name then
        G.lastAsk=GetTime()
        G.stockAsked[key(name)]=GetTime()
        G.stockNext=GetTime()+10
        local ok,result=pcall(api.probe,name,r.layer)
        if not ok or result~=0 then return "Request refused or throttled by the game. Try again shortly." end
        api.sent(name,r.layer)
        G.rememberDestination(name)
        return "Invite requested from "..name..". Waiting for their response; hosting must allow it."
      end
    end
    return "That guildmate is no longer online."
  end
  local f=CreateFrame("Frame","LayerSwapGuildPanel",UIParent)
  G.frame=f
  local extra=api.setRadius and 24 or 0
  f:SetSize(490,450+extra); f:SetPoint("CENTER"); f:SetClampedToScreen(true)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart",f.StartMoving); f:SetScript("OnDragStop",f.StopMovingOrSizing)
  local bg=f:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(.04,.05,.07,.95)
  local function label(y)
    local t=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    t:SetPoint("TOPLEFT",12,y); t:SetWidth(466); t:SetJustifyH("LEFT"); return t
  end
  local title=label(-12); title:SetWidth(290); title:SetText("GUILD LAYERS · ONLINE MEMBERS")
  if api.toggleAuto then
    local auto=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
    auto:SetSize(24,24); auto:SetPoint("TOPRIGHT",-142,-4)
    auto:SetChecked(api.autoEnabled())
    local caption=auto:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    caption:SetPoint("LEFT",auto,"RIGHT",2,0); caption:SetText("Auto Horde escape")
    auto:SetScript("OnClick",function(self) self:SetChecked(api.toggleAuto()) end)
  end
  local subtitle=label(-34)
  if api.toggleFilter then
    subtitle:SetWidth(300)
    local filter=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
    filter:SetSize(24,24); filter:SetPoint("TOPRIGHT",-142,-28)
    filter:SetChecked(api.filterEnabled())
    local caption=filter:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    caption:SetPoint("LEFT",filter,"RIGHT",2,0); caption:SetText("Addon only")
    filter:SetScript("OnClick",function(self) self:SetChecked(api.toggleFilter()); G.render() end)
  end
  subtitle:SetText(api.guildRequest and "Click to join · GL / LS supported" or "Click any guildmate to request an invite · hosts may invite you")
  local transition=label(-55); transition:SetHeight(34)
  if api.setRadius then
    local caption=label(-91); caption:SetWidth(125); caption:SetText("Horde radius (yards)")
    local input=CreateFrame("EditBox",nil,f,"InputBoxTemplate")
    input:SetSize(55,22); input:SetPoint("TOPLEFT",150,-84)
    input:SetAutoFocus(false); input:SetMaxLetters(5); input:SetText(tostring(api.radius()))
    input:SetScript("OnEnterPressed",function(self)
      local valid=api.setRadius(self:GetText())
      self:SetText(tostring(api.radius())); self:ClearFocus()
      G.setStatus(valid and "Horde distance saved." or "Enter a distance from 5 to 100 yards.")
    end)
    input:SetScript("OnEscapePressed",function(self) self:SetText(tostring(api.radius())); self:ClearFocus() end)
    if api.toggleAccept then
      local accept=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
      accept:SetSize(24,24); accept:SetPoint("TOPLEFT",225,-84); accept:SetChecked(api.acceptEnabled())
      local text=accept:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
      text:SetPoint("LEFT",accept,"RIGHT",2,0); text:SetText("Accept guild invites")
      accept:SetScript("OnClick",function(self) self:SetChecked(api.toggleAccept()) end)
    end
  end
  local status=label(-394-extra); status:SetHeight(42)
  local function notice(text)
    G.noticeUntil=GetTime()+15; status:SetText(text)
  end
  G.setStatus=notice
  local buttons={}
  for i=1,PAGE do
    local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    b:SetSize(466,27); b:SetPoint("TOPLEFT",12,-94-extra-(i-1)*29)
    b:SetScript("OnClick",function(self) notice(G.ask(self.member)); G.render() end)
    buttons[i]=b
  end
  function G.render()
    local rows=G.rows(); local pages=math.max(1,math.ceil(#rows/PAGE))
    transition:SetText(G.transitionText())
    G.page=math.min(G.page,pages)
    for i,b in ipairs(buttons) do
      local r=rows[(G.page-1)*PAGE+i]
      if r then
        b.member=r.name
        local addon=r.addon and (r.addon=="LayerSwap" and " [LS]" or " [GL]") or ""
        b:SetText(r.name..addon.." · "..tostring(r.level or "?").." "..(r.class or "").." · "..G.layerLabel(r.layer,r.zone).." · "..r.state)
        b:SetEnabled(true); b:Show()
      else b:Hide() end
    end
    if not G.noticeUntil or GetTime()>=G.noticeUntil then
      local known=0
      for _,r in ipairs(rows) do if r.layer then known=known+1 end end
      if #rows==0 then status:SetText(api.filterEnabled and api.filterEnabled() and
        "No online guildmates with a recent Guild Layers or LayerSwap report yet." or "No other online guildmates in the current roster.")
      else status:SetText(known.." / "..#rows.." layers reported. "..
        (api.guildRequest and "Click a member to join. Layer transfer depends on zone and server rules." or
         (not G.stockEnabled and "Automatic requests stopped." or G.stockStatus or "Discovering guild layers…"))) end
    end
  end
  local function button(text,x,callback)
    local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
    b:SetSize(100,22); b:SetPoint("BOTTOMLEFT",x,6); b:SetText(text); b:SetScript("OnClick",callback)
  end
  button("Previous",12,function() G.page=math.max(1,G.page-1); G.render() end)
  button("Next",122,function() G.page=G.page+1; G.render() end)
  button(api.guildRequest and "Guild hosting" or "Start / Stop",232,function(self)
    if api.toggleHosting then
      local enabled=api.toggleHosting()
      self:SetText(enabled and "Hosting: On" or "Hosting: Off")
      notice(enabled and "Guildmates can request automatic invites." or "Automatic guild invites disabled.")
      return
    end
    G.stockEnabled=not G.stockEnabled
    G.stockTick(); G.render()
  end)
  button("Close",378,function() f:Hide() end)
  f:Hide()
  f:SetScript("OnShow",function() G.poll(); G.roster(); G.stockTick(); G.render() end)
  f:RegisterEvent("GUILD_ROSTER_UPDATE"); f:RegisterEvent("CHAT_MSG_ADDON")
  f:RegisterEvent("PLAYER_GUILD_UPDATE")
  f:RegisterEvent("PARTY_INVITE_REQUEST")
  f:SetScript("OnEvent",function(_,ev,...)
    if ev=="CHAT_MSG_ADDON" then G.receive(...)
    elseif ev=="PARTY_INVITE_REQUEST" then G.inviteUntil=GetTime()+30
    else
      G.roster()
      if ev=="PLAYER_GUILD_UPDATE" then G.reports={}; G.lastQuery=nil; G.poll() end
    end
    if f:IsShown() then G.poll(); G.stockTick(); G.render() end
  end)
  pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX)
  pcall(C_ChatInfo.RegisterAddonMessagePrefix,"LayerSwap")
  SLASH_LAYERSWAPGUILD1="/lsguild"
  SlashCmdList.LAYERSWAPGUILD=function() f:SetShown(not f:IsShown()) end
  C_Timer.NewTicker(5,function()
    G.send()
    if LayerSwapPanel and not G.openButton then
      local b=CreateFrame("Button",nil,LayerSwapPanel,"UIPanelButtonTemplate")
      b:SetSize(130,24); b:SetPoint("TOPRIGHT",LayerSwapPanel,"BOTTOMRIGHT",0,-4)
      b:SetText("Guild layers"); b:SetScript("OnClick",SlashCmdList.LAYERSWAPGUILD)
      G.openButton=b
    end
    if f:IsShown() then G.poll(); G.stockTick(); G.render() end
  end)
  G.roster()
  return G
end
