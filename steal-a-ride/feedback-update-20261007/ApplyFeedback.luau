-- Guarded, reversible source application in Edit mode.
assert(game.PlaceId == 123937616497204, "Wrong place")
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing")
local H, S = game:GetService("HttpService"), game:GetService("ServerStorage")
local stage = assert(S:FindFirstChild("FeedbackSources20261007"), "Stage manifest first")
local function signature(source)
 source = source:gsub("\r\n", "\n"):gsub("\n+$", "")
 local a,b=1,0
 for i=1,#source do a=(a+source:byte(i))%65521; b=(b+a)%65521 end
 return #source,b*65536+a
end
local function matches(source, sig)
 local n,c=signature(source)
 return sig and n==sig.length and c==sig.adler
end
local function find(path)
 local o=game
 for seg in path:gmatch("[^.]+") do o=o and o:FindFirstChild(seg) end
 return o
end
local rows={}
for _,value in stage:GetChildren() do
 local row=H:JSONDecode(value.Value)
 assert(matches(row.source,row.after),"Invalid staged source: "..row.path)
 local object=find(row.path)
 if object then
  assert(object.ClassName==row.class,"Class changed: "..row.path)
  assert(matches(object.Source,row.before) or matches(object.Source,row.after),"Source drift: "..row.path)
 else
  assert(not row.before,"Missing original: "..row.path)
  assert(find(row.path:match("^(.*)%.([^%.]+)$")),"Missing parent: "..row.path)
 end
 table.insert(rows,{record=row,object=object,old=object and object.Source})
end
assert(#rows==13,"Incomplete staging")
local backup=S:FindFirstChild("FeedbackBackup20261007") or Instance.new("Folder")
backup.Name="FeedbackBackup20261007"; backup.Parent=S
for _,entry in rows do
 if entry.object and not backup:FindFirstChild(entry.record.path) then
  local clone=entry.object:Clone(); clone.Name=entry.record.path; clone.Parent=backup
 end
end
local ok,err=pcall(function()
 for _,entry in rows do
  local row=entry.record
  if not entry.object then
   local parent,name=row.path:match("^(.*)%.([^%.]+)$")
   entry.object=Instance.new(row.class);entry.object.Name=name;entry.object.Parent=find(parent)
   entry.created=true
  end
  entry.object.Source=row.source
 end
end)
if not ok then
 for _,entry in rows do
  if entry.created then entry.object:Destroy()
  elseif entry.object then entry.object.Source=entry.old end
 end
 error("Rolled back source application: "..tostring(err))
end
for _,entry in rows do assert(matches(entry.object.Source,entry.record.after),"Applied source mismatch") end
return "PASS: installed 13 sources, backed up 11 originals; no publication"

