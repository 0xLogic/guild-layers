function GuildLayersEscape(api)
  local E={nextAt=0,failed={}}
  function E.tick()
    local now=api.now()
    if not api.enabled() then E.pending=nil; return end
    if E.pending then
      if api.same(api.layer(),E.pending.layer) then
        api.status("Layer change observed after automatic guild join."); E.pending=nil
      elseif now>E.pending.untilAt then
        api.status("Automatic switch unconfirmed; waiting before another attempt."); E.pending=nil
      end
      return
    end
    if now<E.nextAt or api.blocked() or not api.hostileNear() then return end
    local candidates=api.candidates()
    table.sort(candidates,function(a,b) return a.name<b.name end)
    for _,c in ipairs(candidates) do
      if not E.failed[c.name] or now>=E.failed[c.name] then
        E.nextAt=now+60; E.failed[c.name]=now+120
        if api.request(c.name) then
          E.pending={layer=c.layer,untilAt=now+30}
          api.status("Horde nearby: requesting "..c.name.." on another layer.")
        else api.status("Automatic invite request could not start.") end
        return
      end
    end
    E.nextAt=now+10
    api.status("Horde nearby; no available guildmate on another known layer in this zone.")
  end
  return E
end
