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
   for k in next,task do len = len + 1 end
   return len
end

local evaluate = function (task, scores, skill)
   if type(scores)~='table' then return false,
     ("bad value for scores: expected table, got "..
       type(scores)):format(type(scores))
   end
   skill = skill or {}
   local roster = {}
   local total, bound = 0, 0  
   for person,job in next,task do 
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
   for person, item in next,skill do
      if item>0 and not task[person] then return false,
         ("'%s' has a positive skill score but no job"):format(person)
      end
      bound = bound + item
   end
   for job,shortlist in next,scores do  
      local rating
      if type(shortlist)~='table' then return false,
         ("bad value for scores[%s]: expected table, got "..type(shortlist)):
            format(job,type(shortlist))
      end
      if not next(shortlist) then return false,
         ("the shortlist for job '%s' is empty"):format(job)
      end
      for person,item in next,shortlist do
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
end

local assign = function(scores,option)
   local total, bound = evaluate({},scores) -- check input
   if total~=0 then return nil,bound end
   local bottom = -bound-1
   local skill,task= {},{}
   for _,shortlist in next,scores do for person in next,shortlist do
      skill[person] = 0
   end end
   if count(scores) == 0 then goto done end
   if option~="partial" and count(scores)>count(skill) then 
      return nil,
         ("complete assignment impossible: %d jobs but only %d persons"):
         format(count(scores),count(skill))
   end

   if type(option)=="number" then 
      if option <= bottom then bottom = option-1 end
      option = "employ"
   elseif option and option~="partial" then  
      return nil,("bad option '%s' to 'assign'"):format(tostring(option))
   end 
   assert(bottom<bottom+1,"numerical problem: Inf, NaN or precision loss")

   if option == "employ" then
      local W = {}   -- calculate augmented scores
      for job, shortlist in next,scores do
         local s = {}
         for person,item in next,skill do 
            s[person] = shortlist[person] or bottom+1
         end
         W[job] = s
      end
      scores = W
   end

---- main loop
   for job, shortlist in next,scores do
      local best
      local rating = bottom 
      local buddy, score, seen = {}, {}, {}
      for person, item in next,shortlist do -- find the first `best`
         score[person] = item
         item = item - skill[person]
         if item>rating then 
            rating = item; best = person 
         end
      end
      while task[best] do  
         seen[best]=true; margin = bottom 
         shortlist = scores[task[best]]
         local rating = score[best] - shortlist[best] 
         local nextbest
         for person,ability in next,shortlist do if not seen[person] then
            local nu = ability + rating
            if not score[person] or nu > score[person] then 
               score[person], buddy[person] = nu, best    
            end 
         end end
         for person,utility in next,score do if not seen[person] then
            local nu = utility - skill[person]
            if nu>margin then margin, nextbest = nu, person end
         end end
         best = nextbest   
         if not best then 
            if option=="partial" then goto continue
            else return nil,
  "complete assignment impossible: found a subset with more jobs than persons",
               task, job
            end 
         end   
      end
-- recompute skill and reassign task
      for person in next,seen do skill[person] = score[person] - margin end
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
