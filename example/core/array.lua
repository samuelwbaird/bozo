-- 2014 SWB core libraries
-- Module to give array tables some convenience functions

local table = require("table")
local math = require("math")
local coroutine = require("coroutine")

local class = require("core.class")

local pairs, ipairs = pairs, ipairs

-- return the array type directly as the module
return class(function (Array)

	function Array:with_each(fn)
		for i, v in ipairs(self) do
			fn(v)
		end
	end
	
	-- length as a function
	function Array:length()
		return #self
	end

	-- clone, shallow copy for now
	function Array:clone()
		local out = Array()
		for i, v in ipairs(self) do
			out[i] = v
		end
		return out
	end
	
	-- test for a given member
	function Array:contains(member)
		for i, v in ipairs(self) do
			if v == member then
				return true
			end
		end
		return false
	end

	-- map, return a transposed array
	function Array:map(fn)
		local out = Array()
		for i, v in ipairs(self) do
			out[i] = fn(v)
		end
		return out
	end

	-- filter (keep/remove from predicate, return new)
	function Array:filter(fn)
		local out = Array()
		for _, v in ipairs(self) do
			if fn(v) then
				out[#out + 1] = v
			end
		end
		return out
	end
	
	-- update (mutate or remove each entry from function)
	function Array:mutate(fn)
		local out = 0
		for i, v in ipairs(self) do
			local updated = fn(v)
			if updated then
				out = out + 1
				self[out] = updated
			end
		end
		local len = #self
		while len > out do
			self[len] = nil
			len = len - 1
		end
		return self
	end
	
	-- clear
	function Array:clear()
		local len = #self
		while len > 0 do
			self[len] = nil
			len = len - 1
		end
		return self
	end
	
	function Array:is_empty()
		return next(self) == nil
	end

	function Array:push_back(value)
		self[#self + 1] = value
		-- return self or return value?
	end
	
	function Array:push_front(value)
		table.insert(self, 1, value)
	end
	
	function Array:remove_element(element, more_than_once)
		for i, v in ipairs(self) do
			if v == element then
				table.remove(self.actions, i)
				if not more_than_once then
					return;
				end
			end
		end
	end
	
	function Array:collect(iterator_fn, state, ...)
		local vars = {...}
		local length = #self
		while true do
	        vars = { iterator_fn(state, vars[1]) }
	        if vars[1] == nil then 
				return self
			end
			length = length + 1
			self[length] = vars[1]
		end
	end
	
	-- return a coroutine that will iterate through all permutations of array ordering
	function Array:permutations()
		return coroutine.wrap(function()
			if #self == 1 then
				coroutine.yield(self);
			else
				-- permutation is equal to an element in each position, with all permutations of the other elements before and after
				local element = self[1]
				local the_rest = self:clone()
				the_rest:remove(1)

				for sub_permutation in the_rest:permutations() do
					for insert_index = 1, #sub_permutation + 1 do
						local permutation = sub_permutation:clone()
						permutation:insert(insert_index, element)
						coroutine.yield(permutation)
					end
				end
			end
			coroutine.yield(nil)
		end)
	end
	
	function Array:random_permutation()
		local out = Array.new()
		local working = self:clone()
		while #working > 0 do
			local random_index = math.random(1, #working)
			out:push(working[random_index])
			working:remove(random_index)
		end
		return out
	end

	-- aliases
	Array.add = Array.push_back
	Array.push = Array.push_back
	Array.size = Array.length
	
	Array.concat = table.concat
	Array.insert = table.insert
	Array.remove = table.remove
	Array.maxn = table.maxn
	Array.sort = table.sort

	function Array:__tostring()
		local strings = {}
	    for i, v in ipairs(self) do
			strings[i] = tostring(v)
		end
		return '[' .. table.concat(strings, ', ') .. ']'
	end
	
end)