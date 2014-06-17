-- iterate a series of folder containing sprite assets and produce spritesheets for each source
-- generate a range of scaled output as required. Multiple sheets are generated per folder
-- if the assets do not fit the maximum sheet size
--
-- transparency is stripped from source images, but the specified registration of the original
-- image is preserved
--
-- json output is generated for each sheet given UV and display position/size for each sprite
--
-- naming convention
-- input
--   folder_name
--   folder_name
-- output
--   folder_name_1_x1.png
--   folder_name_1_x1_description.json
--   folder_name_1_x1.5.png
--   folder_name_1_x1.5_description.json

-- standard lua modules
require 'table'
require 'string'
require 'math'
require 'io'
require 'os'

-- SWB modules
local array = require('core.array')
local bozo = require('bozo')
local atlasbuilder = require('bozo.atlasbuilder')

--  settings

-- source art is considered to be at the following scale
local source_scale = 2

-- output is required at the following output_scales
local output_scales = { 1, 1.5, 2 }

-- maximum spritesheet size
local max_sheet_size = 2048

-- paths
local input_path = 'input/'
local output_path = 'output/'

-- generate spritesheets as required for a given input folder

function create_spritesheet(folder_name, anchor_x, anchor_y)

	-- this process runs once for each required output scale
	for _, scale in ipairs(output_scales) do
		-- create an atlas builder
		local atlas = atlasbuilder()
		
		-- get all the images together, using bozo it iterate all the input files		
		for _, file in ipairs(bozo.files(input_path .. folder_name, 'png')) do
			local image = bozo.image(file.absolute)
			if scale ~= source_scale then
				-- high quality downsizing if required
				local scaled = image:resized_to(math.floor(image:width() * scale / source_scale), math.floor(image:height() * scale / source_scale), 'lanczos3', true)
				image:dispose()
				image = scaled
			end
			-- add the image to the atlas, preserving the anchor and asset scale
			atlas:add_image(file.name, image, scale, anchor_x, anchor_y)
		end

		-- now 'solve' the layout at a given maximum sheet size
		local result = atlas:solve(scale, (scale * 1024 > max_sheet_size) and max_sheet_size or (scale * max_sheet_size))
		
		-- the output will be some number of sheets, however many are required to fit the assets
		for index, output in ipairs(result) do
			local basename = folder_name .. '_' .. index .. '_x' .. scale
			print(basename)
			
			-- describe the sprite sheet with some JSON data
			local description = assert(io.open(output_path .. basename .. '_description.json', 'w'))
			description:write('[')
			local first = true
			for _, entry in ipairs(output:entries()) do
				if not first then
					description:write(',\n')
				else
					description:write('\n')
				end
				-- xy is relative position at scale of 1 of corners of the sprite against the anchor
				-- uv is 0 - 1 position of the corners of the sprite in the sheet
				description:write('{ "name" : "' .. entry.name .. '", "xy" : [' .. entry.xy[1] .. ',' .. entry.xy[2] .. ',' .. entry.xy[3] .. ',' .. entry.xy[4] .. '], "uv" : [' .. entry.uv[1] .. ',' .. entry.uv[2] .. ',' .. entry.uv[3] .. ',' .. entry.uv[4] .. '] }')
				first = false
			end
			description:write('\n]')
			description:close()
			
			-- size specific image
			local image = output:image()
			image:save(output_path .. basename .. '.png')
			-- free up memory
			image:dispose()
		end
		
		-- free up memory
		atlas:dispose()
	end
end

-- now run the function on the input images
create_spritesheet('monsters',  0.5, 0.9)	-- monster images are registered near bottom middle
create_spritesheet('tokens', 0.5, 0.5)		-- token images are registered center
