-- 2014 SWB core libraries
-- Convenience & convention around creating simple class types
-- no inheritance or data hiding built in

local pairs, ipairs = pairs, ipairs

local class_meta = {
	-- constructor callable directly off the class
	__call = function(class, ...)
		return class.new(...)
	end,
	-- class static meta methods
	__index = {
		mixin = function (self, other_class, names)
			local names_set = {}
			if names then
				for _, name in ipairs(names) do
					names_set[name] = true
				end
			end
			-- "inherit" the values if applicable
			for k, v in pairs(other_class) do
				if self[k] == nil then
					if names == nil or names_set[k] then
						self[k] = v
					end
				end
			end
		end,

		-- proxy functions on subobjects with these names and classes
		proxy = function (self, named_classes)
			-- gather unique names only
			local unique = {}
			for subobject_property_name, class in pairs(named_classes) do
				for method_name, method in pairs(class) do
					if unique[method_name] == nil then
						unique[method_name] = subobject_property_name
					else
						unique[method_name] = false
					end
				end
			end
			
			-- implement functions that proxy to that method of that class on that object
			for method_name, subobject_property_name in pairs(unique) do
				if self[method_name] == nil then
					self[method_name] = function (parent, ...)
						local sub = parent[subobject_property_name]
						sub[method_name](sub, ...)
					end
				end
			end

		end,
	}
}

local function class(class_constructor)
	local meta = {}
	meta.__index = meta
	
	-- explicit constructor
	function meta.new(init_state)
		return setmetatable(init_state or {}, meta)
	end
	
	function meta.is_member(obj)
		return obj and getmetatable(obj) == meta
	end
	
	setmetatable(meta, class_meta)
		
	if class_constructor then
		class_constructor(meta)
	end
	
	return meta
end

local function package(publish_these_classes_and_functions, default_constructor)
	local unique = {}
	local publish = {}
	
	for k, v in pairs(publish_these_classes_and_functions) do
		-- named entries are public as named
		if type(k) == "string" then
			publish[k] = v
		end
		-- entries that are tables are scanned for unique names and these are promoted to public
		if type(v) == "table" then
			for tk, tv in pairs(v) do
				if unique[tk] == nil then
					unique[tk] = tv
				else
					unique[tk] = false
				end
			end
		end
	end
	
	for k, v in pairs(unique) do
		if publish[k] == nil and v ~= false then
			publish[k] = v
		end
	end
	
	if default_constructor then
		setmetatable(publish, {
			__call = function (meta,  ...)
				return default_constructor(...)
			end
		})
	end
	
	return publish
end

return setmetatable({ new = class, package = package }, class_meta)
