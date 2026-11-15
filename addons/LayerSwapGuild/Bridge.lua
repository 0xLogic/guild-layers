
-- BEGIN DOGHOUSE GUILD LAYERS
LayerSwapGuild = LayerSwapGuildMembers({
  current=function() return current end,
  zone=Layer.zone, same=Layer.same,
  rescan=Who.rescan,
  canProbe=function()
    if IsInGroup() then return false,"Paused while grouped." end
    if Layer.instance() then return false,"Paused inside an instance." end
    if UnitAffectingCombat("player") then return false,"Paused during combat." end
    if not current or not zoneOf("player") then return false,"Reading your layer: target or mouse over an NPC." end
    return true
  end,
  probe=function(name,layer)
    -- Stock 1.14's direct-request transport. Hosts can answer with an invite.
    return Send.note("WHISPER",name,askText(layer,nil,true))
  end,
  name=function() return fullName("player") end,
  normalize=function(name) return FOREVER and (name:match("^([^%-]+)") or name) or withRealm(name) end,
  zoneName=function(zone) return tonumber(zone) and zoneName(tonumber(zone)) or zone end,
  book=function(name)
    local normalized=FOREVER and (name:match("^([^%-]+)") or name) or name
    local b=LayerSwapDB.book and LayerSwapDB.book[normalized]
    if b then return {layer=b.layer,zone=tonumber(b.zone) and zoneName(tonumber(b.zone)) or b.zone,at=b.at} end
  end,
  discover=function()
    if not IsInGuild() then return "You are not in a guild." end
    if IsInGroup() then return "Leave your group before requesting a switch." end
    requestGuild("guild layers")
    return "Check LayerSwap/chat for request status. Enter sends a prepared request; hosts may invite you."
  end,
  askText=function(layer) return askText(layer,nil,false) end,
  sent=function(name,layer)
    swap={at=GetTime(),from=current,want=layer,where="whisper",zone=Send.zoneKey()}
    log("ask","guildmate addon request queued",name,layer)
    refresh()
  end,
})
-- END DOGHOUSE GUILD LAYERS
