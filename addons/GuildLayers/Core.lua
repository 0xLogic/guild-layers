local PREFIX="GuildLayers1"
local layer,mapID,samples,sampleAt=nil,nil,{},0
local ui,party,escape
local peers={}
local notifiedVersion
local lastPresenceQuery=-100
local presenceReplies={}
local presenceStats={received=0,sent=0,lastResult="not sent"}
local presenceAsked={}
local stockAsked={}
local function public(v) return not issecretvalue or not issecretvalue(v) end
local function key(n)
  if not public(n) or type(n)~="string" then return "" end
  return (n:match("^([^%-]+)") or n):lower()
end
local function name(unit)
  local a,b=UnitName(unit)
  if not public(a) or not public(b) or type(a)~="string" then return nil end
  return b and b~="" and (a.." "..b) or a
end
local function member(n)
  if not IsInGuild() or key(n)=="" then return false end
  for i=1,GetNumGuildMembers() do
    local who,_,_,_,_,_,_,_,online=GetGuildRosterInfo(i)
    if public(who) and public(online) and online and key(who)==key(n) then return true end
  end
  return false
end
local function scan()
  local m=C_Map and C_Map.GetBestMapForUnit("player")
  if not public(m) then m=nil end
  if m~=mapID or GetTime()-sampleAt>120 then layer=nil; samples={}; sampleAt=GetTime() end
  mapID=m
  if not m then return end
  local counts={}
  local units={"target","mouseover"}
  for i=1,40 do units[#units+1]="nameplate"..i end
  for _,unit in ipairs(units) do
    local guid=UnitGUID(unit)
    if public(guid) and type(guid)=="string" then
      local server,zone=guid:match("^Creature%-0%-(%d+)%-%d+%-(%d+)%-")
      if server then samples[guid]={id=server.."-"..zone,server=server,at=GetTime()} end
    end
  end
  for guid,v in pairs(samples) do
    if GetTime()-v.at>10 then samples[guid]=nil
    else
      counts[v.server]=(counts[v.server] or 0)+1
      if counts[v.server]>=2 then layer=v.id; sampleAt=GetTime() end
    end
  end
end
local function zoneName(id)
  if not tonumber(id) then return id end
  local info=C_Map and C_Map.GetMapInfo(tonumber(id))
  return info and info.name or nil
end
local function status(s) if ui and ui.setStatus then ui.setStatus(s) end end
local function send(target,text)
  local ok,result=pcall(C_ChatInfo.SendAddonMessage,PREFIX,text,"WHISPER",target)
  return ok and public(result) and result==0
end
local function action(fn,...)
  if type(fn)~="function" then return false end
  local ok=pcall(fn,...); return ok
end
local function canHost()
  if not GuildLayersDB.hosting then return false,"Guild hosting is off" end
  if IsInRaid() then return false,"Host is in a raid" end
  if IsInGroup() and not UnitIsGroupLeader("player") then return false,"Host is not party leader" end
  if GetNumGroupMembers()>=5 then return false,"Party is full" end
  return true
end
local function hostileNear()
  local radius=GuildLayersDB.hordeRadius or 40
  local units={"target","mouseover"}
  for i=1,40 do units[#units+1]="nameplate"..i end
  for _,u in ipairs(units) do
    local player,faction,attackable=UnitIsPlayer(u),UnitFactionGroup(u),UnitCanAttack("player",u)
    if public(player) and public(faction) and public(attackable) and player and faction=="Horde" and attackable then
      local ok,distance,checked=pcall(UnitDistanceSquared,u)
      if ok and public(distance) and public(checked) and checked and type(distance)=="number" and distance>=0 and distance<=radius*radius then return true end
      -- Duel-interaction distance is about ten yards: a useful close-range
      -- fallback when the client withholds exact hostile-unit distance.
      if radius>=10 and type(CheckInteractDistance)=="function" then
        local nearOK,near=pcall(CheckInteractDistance,u,3)
        if nearOK and public(near) and near==true then return true end
      end
    end
  end
  return false
end
local function advertise(target)
  if not IsInGuild() then return end
  local channel=target and "WHISPER" or "GUILD"
  local ok,result=pcall(C_ChatInfo.SendAddonMessage,PREFIX,canHost() and "CAP|1" or "CAP|0",channel,target)
  presenceStats.lastResult=ok and public(result) and tostring(result) or "error/restricted"
  presenceStats.sent=presenceStats.sent+1
  pcall(C_ChatInfo.SendAddonMessage,PREFIX,"VER|"..GuildLayersVersion,channel,target)
end
local function queryPresence()
  if not IsInGuild() or GetTime()-lastPresenceQuery<15 then return end
  lastPresenceQuery=GetTime()
  pcall(C_ChatInfo.SendAddonMessage,PREFIX,"PING|1","GUILD")
  advertise()
end
local function requestStock(target,wanted)
  if not layer or not mapID or IsInGroup() or (IsInInstance and IsInInstance()) then return false end
  local route=wanted and ("want "..wanted) or ("not "..layer)
  local text="inv layer <LS "..tostring(mapID).." "..route..">"
  local ok,result=pcall(C_ChatInfo.SendAddonMessage,"LayerSwap",text,"WHISPER",target)
  return ok and public(result) and result==0
end
local function presenceSweep()
  if not ui or not ui.frame:IsShown() or not IsInGuild() then return end
  ui.roster()
  local names={}
  for k,m in pairs(ui.members) do
    local p=peers[k]
    if (not p or GetTime()-p.at>60) and (not presenceAsked[k] or GetTime()-presenceAsked[k]>=60) then
      names[#names+1]=m.name
    end
  end
  table.sort(names)
  for i=1,math.min(2,#names) do
    local n=names[i]; presenceAsked[key(n)]=GetTime()
    pcall(C_ChatInfo.SendAddonMessage,PREFIX,"PING|1","WHISPER",n)
    -- Stock LayerSwap has no presence-only query. A real request elicits its
    -- standard heard reply and can provoke an invitation; never auto-accept it.
    local p=peers[key(n)]
    if not party.pending and (not p or p.kind=="LayerSwap" or GetTime()-p.at>90) and
       (not stockAsked[key(n)] or GetTime()-stockAsked[key(n)]>=120) then
      if requestStock(n) then stockAsked[key(n)]=GetTime() end
    end
  end
end
local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent",function(_,event,...)
  if event=="PLAYER_LOGIN" then
    GuildLayersDB=type(GuildLayersDB)=="table" and GuildLayersDB or {}
    if GuildLayersDB.hosting==nil then GuildLayersDB.hosting=true end
    if GuildLayersDB.addonOnly==nil then GuildLayersDB.addonOnly=true end
    if GuildLayersDB.autoAcceptGuild==nil then GuildLayersDB.autoAcceptGuild=true end
    local radius=tonumber(GuildLayersDB.hordeRadius)
    GuildLayersDB.hordeRadius=radius and radius==radius and math.max(5,math.min(100,radius)) or 40
    party=GuildLayersParty({now=GetTime,key=key,member=member,grouped=IsInGroup,send=send,status=status,
      autoAcceptGuild=function() return GuildLayersDB.autoAcceptGuild==true end,
      sendJoin=function(n,token)
        local p=peers[key(n)]
        if p and p.kind=="LayerSwap" and GetTime()-p.at<=90 then
          local wanted
          for _,r in ipairs(ui.rows()) do if key(r.name)==key(n) then wanted=r.layer; break end end
          return requestStock(n,wanted)
        end
        return send(n,"JOIN|"..token)
      end,
      canHost=canHost,
      invite=function(n) return action(C_PartyInfo and C_PartyInfo.InviteUnit or InviteUnit,n) end,
      accept=function() return action(AcceptGroup) end,
      joined=function(n)
        for i=1,4 do if key(name("party"..i))==key(n) then return true end end
        return false
      end})
    scan()
    ui=LayerSwapGuildMembers({current=function() return layer end,zone=function() return zoneName(mapID) end,
      same=function(a,b) return a:match("^%d+")==b:match("^%d+") end,
      rescan=scan,name=function() return name("player") end,normalize=function(n) return n:match("^([^%-]+)") or n end,
      zoneName=zoneName,book=function() end,canProbe=function() return false,"Use Guild Layers on both players." end,
      guildRequest=party.request,
      discoverPresence=queryPresence,
      observeStock=function(n,ready)
        if not member(n) then return end
        presenceStats.received=presenceStats.received+1
        local p=peers[key(n)]
        if not p or p.kind=="LayerSwap" or GetTime()-p.at>90 then
          peers[key(n)]={kind="LayerSwap",ready=ready,at=GetTime()}
        end
      end,
      addonKind=function(n) local p=peers[key(n)]; return p and GetTime()-p.at<=90 and p.kind or nil end,
      canSwitchPeer=function(n) local p=peers[key(n)]; return p~=nil and p.ready and GetTime()-p.at<=90 end,
      installed=function(n) local p=peers[key(n)]; return p~=nil and GetTime()-p.at<=90 end,
      filterEnabled=function() return GuildLayersDB.addonOnly end,
      toggleFilter=function() GuildLayersDB.addonOnly=not GuildLayersDB.addonOnly; return GuildLayersDB.addonOnly end,
      autoEnabled=function() return GuildLayersDB.autoEscape==true end,
      toggleAuto=function() GuildLayersDB.autoEscape=not GuildLayersDB.autoEscape; return GuildLayersDB.autoEscape end,
      radius=function() return GuildLayersDB.hordeRadius end,
      acceptEnabled=function() return GuildLayersDB.autoAcceptGuild==true end,
      toggleAccept=function() GuildLayersDB.autoAcceptGuild=not GuildLayersDB.autoAcceptGuild; return GuildLayersDB.autoAcceptGuild end,
      setRadius=function(value)
        local n=tonumber(value)
        if not n or n~=n or n<5 or n>100 then return false end
        GuildLayersDB.hordeRadius=n; return true
      end,
      toggleHosting=function() GuildLayersDB.hosting=not GuildLayersDB.hosting; return GuildLayersDB.hosting end,
      hosting=function() return GuildLayersDB.hosting end})
    GuildLayers=ui
    escape=GuildLayersEscape({now=GetTime,enabled=function() return GuildLayersDB.autoEscape==true end,
      layer=function() return layer end,
      same=function(a,b) return a and b and a:match("^%d+")==b:match("^%d+") end,
      blocked=function() return IsInGroup() or party.pending~=nil or not layer or
        UnitIsDeadOrGhost("player") or (IsInInstance and IsInInstance()) end,
      hostileNear=hostileNear,status=status,
      candidates=function()
        ui.roster(); local result={}
        for _,r in ipairs(ui.rows()) do
          local peer=peers[key(r.name)]
          if r.state=="Ask to join" and peer and peer.ready and GetTime()-peer.at<=90 then result[#result+1]=r end
        end
        return result
      end,
      request=function(n)
        local _,accepted=party.request(n)
        if accepted then ui.rememberDestination(n) end
        return accepted==true
      end})
    pcall(C_ChatInfo.RegisterAddonMessagePrefix,PREFIX)
    for _,e in ipairs({"CHAT_MSG_ADDON","PARTY_INVITE_REQUEST","GROUP_ROSTER_UPDATE","ZONE_CHANGED_NEW_AREA","SHARD_TRANSFER"}) do pcall(f.RegisterEvent,f,e) end
    SLASH_GUILDLAYERS1="/guildlayers"
    SlashCmdList.GUILDLAYERS=function(msg)
      if msg=="status" then
        print("Guild Layers "..GuildLayersVersion..": presence attempts="..presenceStats.sent..
          ", received="..presenceStats.received..", last send result="..presenceStats.lastResult.." (0=accepted)")
      else SlashCmdList.LAYERSWAPGUILD(msg) end
    end
    queryPresence()
    -- Presence must not depend on layer scanning, combat or escape callbacks.
    C_Timer.NewTicker(30,function() advertise() end)
    C_Timer.NewTicker(5,presenceSweep)
    C_Timer.NewTicker(1,function()
      scan(); party.tick(); escape.tick()
    end)
  elseif event=="CHAT_MSG_ADDON" then
    local prefix,text,channel,sender=...
    if public(prefix) and public(channel) and public(text) and public(sender) and prefix==PREFIX then
      if (channel=="GUILD" or channel=="WHISPER") and member(sender) and text=="PING|1" then
        local k=key(sender)
        if k~=key(name("player")) and (not presenceReplies[k] or GetTime()-presenceReplies[k]>=15) then
          presenceReplies[k]=GetTime(); advertise(sender)
        end
      elseif (channel=="GUILD" or channel=="WHISPER") and member(sender) and (text=="CAP|1" or text=="CAP|0") then
        presenceStats.received=presenceStats.received+1
        peers[key(sender)]={kind="Guild Layers",ready=text=="CAP|1",at=GetTime()}
        if ui.frame:IsShown() then ui.render() end
      elseif (channel=="GUILD" or channel=="WHISPER") and member(sender) and type(text)=="string" and text:match("^VER|") then
        local version=text:match("^VER|(.+)$")
        if GuildLayersNewerVersion(version,notifiedVersion or GuildLayersVersion) then
          notifiedVersion=version
          local line="Guildmate reports Guild Layers "..version.." (installed "..GuildLayersVersion.."). Updates: github.com/0xLogic/guild-layers/releases/latest"
          print(line); status(line)
        end
      elseif channel=="WHISPER" then party.receive(text,sender)
      end
    end
  elseif event=="PARTY_INVITE_REQUEST" then
    local sender=...; if public(sender) then party.invitation(sender) end
  elseif event=="GROUP_ROSTER_UPDATE" then party.tick()
  else layer=nil; samples={}; scan() end
end)
