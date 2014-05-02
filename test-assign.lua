local assign = require "lua-assign"

local test_full = function(nj,np,nc)
--- generates `nj` shortlists with `np` persons and simulated aptitude scores
   nc = nc or 10  -- number of topics in aptitude test
   local matmul = function(profile,aptitude)
      local scores = {}
      local inner = function(x,y)
         local sum = 0
         for k=1,#x do sum = sum+x[k]*y[k] end
         return sum
      end
      for k,x in pairs(profile) do
         local s={}
         for j,y in pairs(aptitude) do
             s[j] = inner(x,y)
         end
         scores[k] = s
      end
      return scores
   end
--
   local profile, aptitude = {}, {}
   local roll = function(nc)
      local x={}
      for k=1,nc do x[k]=math.random(100) end
      return x
   end
   for j=1,nj do profile[j]=roll(nc) end
   for p=1,np do aptitude[p]=roll(nc) end
   return matmul(profile,aptitude)
end

nj, np, nc = table.unpack(arg)
if not nj then io.write "Number of jobs? "; nj = tonumber(io.read()) end
if not np then io.write "Number of persons? "; np = tonumber(io.read()) end
scores = test_full (nj,np,nc)
time = os.time(); task, skill = assign(scores)
time = os.difftime(os.time(),time)
if task then
   print (("#task = %s, time = %.2f, total = %s, bound = %s"):
      format(#task,time,task(scores,skill)))
else
print(skill)
end
