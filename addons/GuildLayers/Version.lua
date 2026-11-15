GuildLayersVersion="1.4.0"
function GuildLayersNewerVersion(candidate,current)
  local function parse(v)
    if type(v)~="string" or #v>11 then return nil end
    local a,b,c=v:match("^(%d+)%.(%d+)%.(%d+)$")
    a,b,c=tonumber(a),tonumber(b),tonumber(c)
    if not a or a>999 or b>999 or c>999 then return nil end
    return {a,b,c}
  end
  local a,b=parse(candidate),parse(current)
  if not a or not b then return false end
  for i=1,3 do if a[i]~=b[i] then return a[i]>b[i] end end
  return false
end
