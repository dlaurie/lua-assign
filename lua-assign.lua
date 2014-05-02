-- assign.lua   Find the best way of assigning jobs to persons. 
-- (c) Dirk Laurie 2014 (Lua-style MIT licence)  

-- ## Usage: 
--
--     assign = require "lua-assign"
--     task, skill = assign(scores[,option])
-- 
-- scores: A table with pairs `job,shortlist`, where `shortlist` is a table
--   with pairs `person,score`, and `score` is a number. 
-- task: Normally, a table with pairs `person,job` where `person` is a key 
--   in `scores[job]` and each key in `scores` appears as `job` exactly once. 
--   The total of `scores[job][person]` over the pairs in `task` is a maximum. 
--   The table `task` has a metatable so that `#task` counts the actual number
--   of items and `task(scores,skill)` returns the actual total and an upper 
--   bound for it (which should be equal).  
-- skill: A table of numbers whose keys all appear in `task`, needed when
--     calling `task`. If `task==nil`, `skill` is a message.
-- option: May be `"partial"`, `"employ"` or a number.
--
-- Full details are in README.md.

local count = function (task) 
   local len = 0
   for k in pairs(task) do len = len + 1 end
   return len
end;

local evaluate = function (task, scores, skill)
   if type(scores)~='table' then return false,
     ("bad value for scores: expected table, got "..
       type(scores)):format(type(scores))
   end
   skill = skill or {}
   local roster = {}
   local total, bound = 0, 0  
   for person,job in pairs(task) do 
      local item = scores[job][person]
      if type(item)~='number' then return false, 
         ("'%s' is not shortlisted for job '%s'"):format(job)
      end
      if roster[job] then return false,
         ("job '%s' is assigned to both '%s' and '%s'"):
         format(job,person,roster[job])
      end
      total = total + item
   end
   for person, item in pairs(skill) do
      if item>0 and not task[person] then return false,
         ("'%s' has a positive skill score but no job"):format(person)
      end
      bound = bound + item
   end
   for job,shortlist in pairs(scores) do  
      local rating
      if type(shortlist)~='table' then return false,
         ("bad value for scores[%s]: expected table, got "..type(shortlist)):
            format(job,type(shortlist))
      end
      if not next(shortlist) then return false,
         ("the shortlist for job '%s' is empty"):format(job)
      end
      for person,item in pairs(shortlist) do
         if type(item)~='number' then return false,
            ("bad value for item[%s][%s]: expected number, got "..
              type(item)):format(job,person,type(item))
         end
         local r = item - (skill[person] or 0)
         if not rating or rating<r then rating = r end
      end
      bound = bound + rating
   end
   return total, bound 
end;

local assign = function(scores,option)   
   local total, bound = evaluate({},scores) -- check input
   if total~=0 then error(bound) end
   local skill, task = {}, {}
   local bottom = -bound-1
   if count(scores) == 0 then goto done end
   if option ~= "partial" then
      local low
      if option == "employ" then low = -bound-1
      elseif type(option)=="number" then 
         low=option
         if low <= bottom then bottom = low-1 end
      elseif option then return nil, 
         ("bad option '%s' to 'assign'"):format(tostring(option))
      end 
      local people = {}
      for _,shortlist in pairs(scores) do for person in pairs(shortlist) do
         people[person] = true
      end end
      if count(scores)>count(people) then return nil,
            "complete assignment impossible: more jobs than persons"
      else goto main
      end
      local W = {}   -- calculate augmented scores
      for job, shortlist in pairs(scores) do
         local s = {}
         for person,item in pairs(people) do 
            s[person] = shortlist[person] or low
         end
         W[job] = s
      end
      scores = W
   end
::main::
   assert(bottom<bottom+1,"numerical problem: Inf, NaN or precision loss")
   for job, shortlist in pairs(scores) do  -- main loop
      local best
      local rating = bottom 
      local buddy, score, seen = {}, {}, {}
      for person, item in pairs(shortlist) do -- find the first best
         score[person] = item
         item = item - (skill[person] or 0)
         if item>rating then 
            rating = item; best = person 
         end
      end
      while task[best] do -- until `best` is unemployed 
         seen[best]=true; rating = bottom 
         local shortlist = scores[task[best]]
         local delta = score[best] - shortlist[best]
         local nextbest
         for person in pairs(score) do if not seen[person] then
             local nu = shortlist[person] + delta   
             if nu > score[person] then
                score[person] = nu; buddy[person] = best    
             end
             nu = score[person] - (skill[person] or 0)
             if nu>rating then
                rating = nu; nextbest = person
             end
         end end
         best = nextbest   
         if not best then 
            if option=="partial" then goto continue
            else return nil,
  "complete assignment impossible: found a subset with more jobs than persons"
            end 
         end   
      end
-- recompute skill and reassign task
      for person in pairs(seen) do skill[person] = score[person] - rating end
      while true do 
         local nextbest = buddy[best] 
         if not nextbest then break end
         task[best] = task[nextbest] 
         best = nextbest
      end
      task[best] = job    
::continue::
   end
::done::
   return setmetatable(task,{__len = count; __call = evaluate}), skill
end

return assign
