-- Guild-only, ephemeral position observations. No coordinates are persisted.
function GuildLayersMap(api)
  local m={reports={},pins={}}
  local function number(v,lo,hi)
    return type(v)=="number" and v==v and v>=lo and v<=hi
  end
  function m.receive(text,sender)
    if not api.member(sender) or type(text)~="string" or #text>120 then return false end
    local map,x,y,layer=text:match("^POS|(%d+)|(%d+)|(%d+)|([%d%-?]+)$")
    map,x,y=tonumber(map),tonumber(x),tonumber(y)
    if not number(map,1,100000) or not number(x,0,10000) or not number(y,0,10000) or #layer>32 then return false end
    m.reports[api.key(sender)]={name=sender,map=map,x=x/10000,y=y/10000,layer=layer,at=api.now()}
    return true
  end
  function m.rows(map)
    local rows={}
    for k,r in pairs(m.reports) do
      if api.now()-r.at>30 or not api.member(r.name) then m.reports[k]=nil
      elseif r.map==map then rows[#rows+1]=r end
    end
    table.sort(rows,function(a,b) return a.name<b.name end)
    return rows
  end
  function m.broadcast()
    if not GuildLayersDB.shareLocation or not IsInGuild() or (IsInInstance and IsInInstance()) then return end
    local ok,map,x,y=pcall(function()
      local id=C_Map.GetBestMapForUnit("player")
      if not api.public(id) or not id then return end
      local pos=C_Map.GetPlayerMapPosition(id,"player")
      if not pos then return end
      local a,b=pos:GetXY(); if not api.public(a) or not api.public(b) then return end
      return id,a,b
    end)
    if not ok or not number(map,1,100000) or not number(x,0,1) or not number(y,0,1) then return end
    local text=string.format("POS|%d|%d|%d|%s",map,math.floor(x*10000),math.floor(y*10000),api.layer() or "?")
    pcall(C_ChatInfo.SendAddonMessage,"GuildLayers1",text,"GUILD")
  end
  function m.draw()
    local map=WorldMapFrame
    for _,pin in ipairs(m.pins) do pin:Hide() end
    if not map or not map:IsShown() or not map.GetMapID or not map.GetCanvas then return end
    local canvas=map:GetCanvas(); if not canvas then return end
    for i,r in ipairs(m.rows(map:GetMapID())) do
      local pin=m.pins[i]
      if not pin then
        pin=CreateFrame("Button",nil,canvas);pin:SetSize(14,14)
        pin.icon=pin:CreateTexture(nil,"OVERLAY");pin.icon:SetAllPoints()
        pin.icon:SetTexture("Interface\\Minimap\\PartyRaidBlips");pin.icon:SetTexCoord(0,.125,0,.25)
        pin:SetScript("OnEnter",function(self)
          local row=self.report;GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText(row.name)
          GameTooltip:AddLine("Layer report: "..row.layer)
          GameTooltip:AddLine(string.format("Last seen %ds ago · %.1f, %.1f",api.now()-row.at,row.x*100,row.y*100))
          GameTooltip:Show()
        end)
        pin:SetScript("OnLeave",function() GameTooltip:Hide() end)
        m.pins[i]=pin
      end
      pin.report=r;pin:ClearAllPoints();pin:SetPoint("CENTER",canvas,"TOPLEFT",r.x*canvas:GetWidth(),-r.y*canvas:GetHeight());pin:Show()
    end
  end
  return m
end
