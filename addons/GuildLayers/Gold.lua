-- Integer copper, self-reported balances, ephemeral observations only.
function GuildLayersGold(api)
  local g={reports={},scope=nil,dirty=true,lastSend=-100,lastQuery=-100,page=1}
  local FRESH,EXPIRE=90,300
  local function scope()
    local current=api.scope()
    if current~=g.scope then
      g.reports={};g.scope=current;g.dirty=true;g.lastSend=-100;g.lastQuery=-100
    end
    return current
  end
  local function validMoney(value)
    return type(value)=="number" and value==value and value>=0 and value<=1000000000000 and value==math.floor(value)
  end
  function g.receive(text,sender)
    if not scope() or not api.member(sender) or type(text)~="string" or #text>32 then return false end
    if text=="GOLDQ|1" then g.dirty=true;return true end
    local k=api.key(sender)
    if text=="GOLD|1|OFF" then g.reports[k]=nil;return true end
    if k==api.key(api.name()) then return false end
    local raw=text:match("^GOLD|1|(%d+)$")
    local amount=raw and tonumber(raw)
    if not validMoney(amount) then return false end
    -- A relay can report only its own authenticated addon-message sender.
    g.reports[k]={name=sender,copper=amount,at=api.now()}
    return true
  end
  function g.broadcast()
    if not scope() or api.now()-g.lastSend<5 then return false end
    local ok,value=pcall(api.money)
    if not ok or not api.public(value) or not validMoney(value) then return false end
    g.lastSend=api.now();g.dirty=false
    local sent=api.send("GOLD|1|"..string.format("%.0f",value))
    -- Own money is observed locally; a send failure is not a peer receipt.
    g.reports[api.key(api.name())]={name=api.name(),copper=value,at=api.now()}
    g.sendFailed=not sent
    return sent
  end
  function g.request()
    if not scope() or api.now()-g.lastQuery<15 then return false end
    g.lastQuery=api.now();g.dirty=true;return api.send("GOLDQ|1")
  end
  function g.summary()
    scope()
    local result={total=0,fresh=0,stale=0,unknown=0,rows={}}
    if not g.scope then return result end
    local roster=api.roster();local included={}
    for _,who in ipairs(roster) do
      local k=api.key(who)
      if not included[k] then
        included[k]=true
        local r=g.reports[k];local age=r and math.max(0,api.now()-r.at)
        if age and age>EXPIRE then g.reports[k]=nil;r=nil end
        local row={name=who,age=r and age,copper=r and r.copper}
        if not r then result.unknown=result.unknown+1;row.state="Unknown"
        elseif age>FRESH then result.stale=result.stale+1;row.state="Stale"
        else result.fresh=result.fresh+1;result.total=result.total+r.copper;row.state="Fresh" end
        result.rows[#result.rows+1]=row
      end
    end
    for k in pairs(g.reports) do if not included[k] then g.reports[k]=nil end end
    table.sort(result.rows,function(a,b) return a.name<b.name end)
    return result
  end
  function g.tick()
    scope()
    if g.dirty or api.now()-g.lastSend>=30 then g.broadcast() end
    if g.frame and g.frame:IsShown() then g.render() end
  end
  function g.moneyText(copper)
    return string.format("%dg %ds %dc",math.floor(copper/10000),math.floor(copper/100)%100,copper%100)
  end
  return g
end

function GuildLayersGoldPanel(g,api)
  local f=CreateFrame("Frame","GuildLayersGoldPanel",UIParent,"BackdropTemplate");g.frame=f
  f:SetSize(580,480);f:SetPoint("CENTER");f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
  f:RegisterForDrag("LeftButton");f:SetScript("OnDragStart",f.StartMoving);f:SetScript("OnDragStop",f.StopMovingOrSizing)
  f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"});f:SetBackdropColor(.025,.045,.06,.96)
  local function label(x,y,width,text)
    local t=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall");t:SetPoint("TOPLEFT",x,y);t:SetSize(width,22);t:SetJustifyH("LEFT");t:SetText(text or "");return t
  end
  local function button(text,x,y,w,fn)
    local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");b:SetSize(w,24);b:SetPoint("TOPLEFT",x,y);b:SetText(text);b:SetScript("OnClick",fn);return b
  end
  label(16,-10,450,"GUILD GOLD - REPORTED CHARACTER BALANCES")
  local total=label(16,-40,548)
  local coverage=label(16,-65,548)
  label(16,-90,548,"Guild-visible reports. Bank, mail and unreported alts excluded.")
  label(16,-120,220,"Automatic reporting: ON")
  button("Refresh reports",250,-120,150,function() g.request();g.render() end)
  button("Close",450,-120,110,function() f:Hide() end)
  label(16,-153,240,"MEMBER");label(260,-153,160,"REPORTED GOLD");label(430,-153,130,"RECEIVED")
  local rows={}
  for i=1,10 do
    local y=-180-(i-1)*24
    rows[i]={label(16,y,240),label(260,y,160),label(430,y,130)}
  end
  button("Previous",16,-434,100,function() g.page=math.max(1,g.page-1);g.render() end)
  local page=label(130,-434,290)
  button("Next",450,-434,110,function() g.page=g.page+1;g.render() end)
  function g.render()
    local s=g.summary();local pages=math.max(1,math.ceil(#s.rows/10));g.page=math.min(g.page,pages)
    total:SetText(s.fresh>0 and ("Reported total: "..g.moneyText(s.total)) or "Reported total: no fresh reports")
    coverage:SetText(string.format("%d fresh / %d online - %d stale excluded - %d unknown%s",s.fresh,#s.rows,s.stale,s.unknown,g.sendFailed and " - Send failed" or ""))
    for i,c in ipairs(rows) do
      local r=s.rows[(g.page-1)*10+i]
      c[1]:SetText(r and r.name or "")
      c[2]:SetText(r and (r.copper and g.moneyText(r.copper) or "Unknown") or "")
      c[3]:SetText(r and (r.age and string.format("%ds%s",r.age,r.state=="Stale" and " (stale)" or "") or "No report") or "")
    end
    page:SetText(string.format("Page %d / %d - reports expire after 5 min",g.page,pages))
  end
  function g.toggle() f:SetShown(not f:IsShown());if f:IsShown() then g.request();g.render() end end
  f:Hide()
end
