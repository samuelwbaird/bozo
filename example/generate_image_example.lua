-- using bozo to create an empty image and then draw pixels and save the output
-- using simple 1 colour drawing, followed by high quality down-scaling to get a nice anti-aliased result

require 'math'
require 'bozo'

local radius = 512
local bar_width = radius / 3
local line_width = bar_width / 4

local image = bozo.image(radius * 2 + 1, radius * 2 + 1)
local mask = bozo.image(radius * 2 + 1, radius * 2 + 1)

for y = 0, radius * 2 do
	local oy = y - radius
	for x = 0, radius * 2 do
		local ox = x - radius
		local oy = y - radius
		local distance = ((ox * ox) + (oy * oy)) ^ 0.5
		local angle = (math.atan2(oy, ox) + math.pi) / (math.pi * 2)
		
		if distance >= radius then
			image:set_pixel(x, y, 0, 0, 0, 0)
			mask:set_pixel(x, y, 0, 0, 0, 0)
		else
			local phase = ((distance / bar_width) + angle) % 1.0
			if phase > 1.0 - (line_width / bar_width) then
				image:set_pixel(x, y, 255, 255, 255, 255)
			else
				image:set_pixel(x, y, 0, 0, 0, 0)
			end
			if distance < radius - (bar_width * (1 - phase)) then
				mask:set_pixel(x, y, 255, 255, 255, 255)
			else
				-- fade out the tail
				local left = distance - (radius - (bar_width * (1 - phase)))
				if left <= line_width then
					mask:set_pixel(x, y, 255, 255, 255, 255 - math.floor((left / line_width) * 255))
				end
			end
			
		end
	end
end

image:save('output/reference_scallop.png')
image:resized_to(radius, radius, null, true):save('output/reference_scallop_smooth.png')
image:resized_to(radius * 0.5, radius * 0.5, null, true):save('output/reference_scallop_smooth_half.png')

mask:save('output/reference_mask.png')
mask:resized_to(radius, radius, null, true):save('output/reference_mask_smooth.png')
mask:resized_to(radius * 0.5, radius * 0.5, null, true):save('output/reference_mask_half.png')