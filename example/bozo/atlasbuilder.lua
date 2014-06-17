-- 2014 Samuel Baird
-- atlasbuilding by random attempts!
-- requires bozo
-- images have transparent padding removed when added

-- standard lua modules
require('math')

-- bozo image module
local bozo = require('bozo')

-- SWB core libraries
local class = require('core.class')
local array = require("core.array")

-- how many times to attempt building the atlas before giving up
local random_iterations = 1024 * 64

-- one public class, the atlas builder
return class(function (AtlasBuilder)
	local super = AtlasBuilder.new
	
	function AtlasBuilder.new(with_these_images)
		local self = super()
		self.source_images = array()
		self.source_pixels = 0
		
		-- load in constructor if required
		if with_these_images then
			for _, img in ipairs(with_these_images) do
				self:add_image(img, img.image)
			end
		end
		
		return self
	end
	
	function AtlasBuilder:solve(scale, max_size)
		-- default parameters
		if scale == nil then
			scale = 2
		end
		if max_size == nil then
			max_size = scale * 1024
		end
		
		-- start with the minimum size of atlas we will need
		local min_size = self.source_pixels ^ 0.5
		local size = 256
		while size < min_size do
			size = size * 2
		end
		
		-- the number of atlases to generate
		local count = 1
		while size > max_size do
			--count = count + 1
			size = size / 2
		end
		
		-- iterate, increasing the size of the atlases and then the count as required
		-- TODO: increase the size of each atlas incrementally (not all at once?)
		while true do
			local output = self:iteration(size, count, scale)
			if output then
				return output
			end
			
			if size >= max_size then
				size = max_size
				count = count + 1
			else
				size = size * 2
			end
		end
	end
	
	local AtlasRow = class(function (AtlasRow)
		local super = AtlasRow.new
		
		function AtlasRow.new(size, padding)
			local self = super()
			self.size = size
			self.padding = padding
			self.images = array()
			self.height = 0;
			self.width = 0;
			return self
		end
		
		function AtlasRow:add(image)
			local new_width = self.width + image.width
			if self.images:size() > 0 then
				new_width = new_width + self.padding
			end
			if new_width > self.size then
				return false
			end
			
			self.width = new_width
			self.images:push(image)
			
			if image.height > self.height then
				self.height = image.height
			end
			
			return true
		end
		
		function AtlasRow:space_to_add_image(image)
			local new_width = self.width + image.width
			if self.images:size() > 0 then
				new_width = new_width + self.padding
			end
			if new_width > self.size then
				return false
			end
			
			local current_size = self.width * self.height
			local new_height = self.height
			if new_height < image.height then
				new_height = image.height
			end
			local new_size = new_width * new_height
			return new_size - current_size
		end
	end)

	local Atlas = class(function (Atlas)
		local super = Atlas.new
	
		function Atlas.new(size, padding)
			local self = super()
			self.size = size
			self.atlas_width = size;
			self.atlas_height = size * 0.25
			self.padding = padding
			self.rows = array()
			self.height = 0;
			return self
		end
		
		function Atlas:add_to_row(row, image)
			row:add(image)
			self.height = self:calculate_height()
			while self.height > self.atlas_height do
				self.atlas_height = self.atlas_height * 2
			end
		end
		
		function Atlas:add_to_new_row(image)
			local new_height = self:calculate_height()
			if new_height > 0 then
				new_height = new_height + self.padding
			end
			new_height = new_height + image.height
			if new_height <= self.size then
				local new_row = AtlasRow.new(self.size, self.padding)
				if new_row:add(image) then
					self.rows:push(new_row)
					self.height = self:calculate_height()
					while self.height > self.atlas_height do
						self.atlas_height = self.atlas_height * 2
					end
					return true
				end
			end
			return false
		end
		
		function Atlas:calculate_height()
			local height = 0
			for _, row in ipairs(self.rows) do
				if height > 0 then
					height = height + self.padding
				end
				height = height + row.height
			end
			return height
		end
		
		function Atlas:entries()
			local out = array()
			local y = 0
			for _, row in ipairs(self.rows) do
				local x = 0
				for _, image in ipairs(row.images) do
					-- registration aligned sprite with nominal scale
					out:push {
						name = image.name,
						image = image.image,
						-- atlas relative co-ordinates for assembling the image
						x = x,
						y = y,
						-- sprite relative nominal co-ordinates, based on registration point
						xy = { -image.register_x / image.scale, -image.register_y / image.scale, (image.width - image.register_x) / image.scale, (image.height - image.register_y) / image.scale },
						-- texture co-ords uv1,uv2 (0 - 1 of texture)
						uv = { x / self.atlas_width, y / self.atlas_height, (x + image.width) / self.atlas_width, (y + image.height) / self.atlas_height },
					}
					x = x + image.width + self.padding
				end
				y = y + row.height + self.padding
			end
			return out
		end
		
		function Atlas:image()
			local img = bozo.image(self.atlas_width, self.atlas_height)
			for _, entry in ipairs(self:entries()) do
				img:blit_copy(entry.image, entry.x, entry.y)
			end
			
			return img
		end
	end)
	
	function AtlasBuilder:iteration(size, count, scale)
		for iteration = 1, random_iterations do
			-- first create a set of atlases to build
			local output = array()
			for add = 1, count do
				output:push(Atlas.new(size, scale))
			end
			
			local images = self.source_images:random_permutation()
			while #images > 0 do
				local image = images[1]
				images:remove(1)
				
				-- attempt to add the image to the existing rows
				local atlas_to_add = nil
				local row_to_add = nil
				local row_space_required = 0
				for _, atlas in ipairs(output) do
					for _, row in ipairs(atlas.rows) do
						-- is there enough height available to add this row
						if (row.height >= image.height) or (atlas:calculate_height() + (image.height - row.height) <= atlas.size) then
							local space_required = row:space_to_add_image(image)
							if space_required then
								if row_to_add == nil or space_required < row_space_required then
									atlas_to_add = atlas
									row_to_add = row
									row_space_required = space_required
								end
							end
						end
					end
				end
				-- add to existing row if it doesn't seem like a waste
				if row_to_add and row_space_required <= (image.width * image.height * 1.25) then
					atlas_to_add:add_to_row(row_to_add, image)
					image = nil;
				end
				
				-- if not good existing row then can we add it as a new row to the atlas?
				for _, atlas in ipairs(output) do
					if image then
						if atlas:add_to_new_row(image) then
							image = nil
						end
					end
				end
				
				-- add to existing row even if it is a waste
				if image and row_to_add then
					atlas_to_add:add_to_row(row_to_add, image)
					image = nil;
				end
				
				-- if nothing worked then signal a failure
				if image then
					images:push(image)
					break
				end
			end
			
			if #images == 0 then
				-- print("success at " .. iteration)
				return output
			end
		end
		-- print("failed at " .. random_iterations)
		return false
	end
	
	function AtlasBuilder:trimmed_rect(image, trim_at_scale)
		local function row_is_empty(image, y)
			for x = 0, image:width() - 1 do
				local r, g, b, a = image:get_pixel(x, y)
				if a ~= 0 then
					return false
				end
			end
			return true
		end
		
		local function column_is_empty(image, x)
			for y = 0, image:height() - 1 do
				local r, g, b, a = image:get_pixel(x, y)
				if a ~= 0 then
					return false
				end
			end
			return true
		end
		
		local x, y, width, height = 0, 0, image:width(), image:height()
		local found = false
		
		for tx = 0, image:width() - 1 do
			if not column_is_empty(image, tx) then
				x = tx
				found = true
				break
			end
		end
		if not found then
			return nil
		end
		for twidth = image:width() - x, 1, -1 do
			if not column_is_empty(image, x + twidth - 1) then
				width = twidth
				break
			end
		end
		for ty = 0, image:height() - 1 do
			if not row_is_empty(image, ty) then
				y = ty
				break
			end
		end
		for theight = image:height() - y, 1, -1 do
			if not row_is_empty(image, y + theight - 1) then
				height = theight
				break
			end
		end
		-- adjust to make boundaries even at scale
		local align = trim_at_scale * 1
		if x % align > 0 then
			width = width + (x % align)
			x = x - (x % align)
		end
		if y % align > 0 then
			height = height + (y % align)
			y = y - (y % align)
		end
		if width % align > 0 then
			width = width + (align - (width % align))
		end
		if height % align > 0 then
			height = height + (align - (height % align))
		end
		
		return x, y, width, height
	end
	
	function AtlasBuilder:add_image(name, image, trim_at_scale, anchor_x, anchor_y)
		trim_at_scale = trim_at_scale or 1
		anchor_x = anchor_x or 0.5
		anchor_y = anchor_y or 0.5
		if anchor_x <= 1 then	-- treat it as a ratio (dodgy magic)
			anchor_x = anchor_x * image:width()
		end
		if anchor_y <= 1 then
			anchor_y = anchor_y * image:height()
		end
		
		local x, y, width, height = self:trimmed_rect(image, trim_at_scale)
		if not x then
			print('could not add ' .. name)
			return
		end
		
		local cropped = image:cropped_to(x, y, width, height)
		image:dispose()
		
		-- add a trimmed version to the atlas, remembering a relative registration point at the previous center
		self.source_images:push({
			name = name,
			image = cropped,
			scale = trim_at_scale,
			register_x = anchor_x - x,
			register_y = anchor_y - y,
			width = width,
			height = height,
		})
		self.source_pixels = self.source_pixels + (width * height)
	end
	
	function AtlasBuilder:dispose()
		for _, source in ipairs(self.source_images) do
			source.image:dispose()
		end
	end
	
end)