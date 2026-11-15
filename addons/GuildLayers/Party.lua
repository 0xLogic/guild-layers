-- Sender identity comes from CHAT_MSG_ADDON, never from the payload.
function GuildLayersParty(api)
  local P={sequence=0,seen={},nextHost=0,nextRequest=0}
  function P.request(name)
    if not api.member(name) then return "Guildmate is offline or no longer in your guild." end
    if api.grouped() then return "Leave your current group first." end
    if api.now()<P.nextRequest then return "Please wait before requesting another invite." end
    P.sequence=P.sequence+1
    local token=tostring(math.floor(api.now()*1000)).."-"..P.sequence
    P.pending={name=name,token=token,untilAt=api.now()+20}
    P.nextRequest=api.now()+5
    local sent
    if api.sendJoin then sent=api.sendJoin(name,token) else sent=api.send(name,"JOIN|"..token) end
    if not sent then P.pending=nil; return "Game refused the request or required layer data is unavailable." end
    return "Requesting "..name.."; waiting for their addon to invite you.",true
  end
  function P.receive(text,sender)
    if type(text)~="string" or #text>160 or not api.member(sender) then return end
    local kind,token,detail=text:match("^(%u+)|([%d%-]+)|?(.*)$")
    if not kind or #token>40 then return end
    if kind=="JOIN" then
      for k,v in pairs(P.seen) do if api.now()-v>60 then P.seen[k]=nil end end
      local id=api.key(sender)..":"..token
      if P.seen[id] or api.now()<P.nextHost then return end
      P.seen[id]=api.now(); P.nextHost=api.now()+2
      local allowed,reason=api.canHost()
      if not allowed then api.send(sender,"NO|"..token.."|"..reason); return end
      if api.invite(sender) then api.send(sender,"ACK|"..token)
      else api.send(sender,"NO|"..token.."|Invite blocked by the game") end
      return
    end
    local p=P.pending
    if not p or api.now()>p.untilAt or api.key(sender)~=api.key(p.name) or token~=p.token then return end
    if kind=="ACK" then api.status("Invite attempted by "..p.name.."; waiting for the invitation.")
    elseif kind=="NO" then P.pending=nil; api.status("Cannot join: "..detail) end
  end
  function P.invitation(sender)
    if not api.member(sender) then return end
    if api.autoAcceptGuild and api.autoAcceptGuild() then
      if api.grouped() then api.status("Guild invitation received, but you are already grouped."); return end
      local existing=P.pending
      if existing and existing.accepted and api.key(existing.name)==api.key(sender) and api.now()<=existing.untilAt then return end
      P.pending={name=sender,untilAt=api.now()+20,accepted=true}
      if api.accept() then api.status("Guild invitation: accept requested; waiting for party confirmation.")
      else P.pending=nil; api.status("Game blocked acceptance; accept the guild invitation manually.") end
      return
    end
    local p=P.pending
    if not p or p.accepted or api.now()>p.untilAt or not api.member(sender) or
       api.key(sender)~=api.key(p.name) or api.grouped() then return end
    p.accepted=true
    if api.accept() then api.status("Accept requested; waiting for party confirmation.")
    else P.pending=nil; api.status("Game blocked automatic acceptance; accept the invitation manually.") end
  end
  function P.tick()
    local p=P.pending
    if not p then return end
    if api.joined(p.name) then
      P.pending=nil; api.status("Joined "..p.name..". Layer transfer is controlled by the server.")
    elseif api.now()>p.untilAt then
      P.pending=nil; api.status("No confirmed join. Guildmate may lack Guild Layers or the game blocked the invite.")
    end
  end
  return P
end
