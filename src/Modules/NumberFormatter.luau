local suffixes={'K','M','B','T','Qa','Qi','Sx','Sp','Oc','No','Dc','Ud','Dd','Td','Qad','Qid'}
local N={}
function N.Integer(value) return string.format('%.0f',value) end
function N.Multiplier(value) return (string.format('%.2f',value):gsub('0+$',''):gsub('%.$','')) end
function N.Format(value)
 local v=tonumber(value) or 0
 if v~=v then return '0' end
 if v==math.huge then return '∞' end
 local sign=v<0 and '-' or ''; v=math.abs(v)
 if v<1000 then return sign..(string.format('%.1f',v):gsub('%.0$','')) end
 local power=math.floor(math.log10(v)/3)
 if power<=#suffixes then return sign..string.format('%.2f',v/1000^power)..suffixes[power] end
 local exponent=math.floor(math.log10(v))
 return sign..string.format('%.2f',v/10^exponent)..'e'..exponent
end
return N
