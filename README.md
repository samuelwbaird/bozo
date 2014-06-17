# bozo _image processing module for Lua_

Includes an example Lua project that processes assets and prepares a sprite atlas, and an example Lua script that generates new images from a formula.

## dependencies

Builds with the Lua 5.1 headers and depends on Cocoa and Quartz.
Lua headers are included under the terms of their original licence.

## building

Building of the module is currently only supported via an Xcode project. After the library is built it will need to be moved into the LUA_CPATH before it can be used.

## usage

	-- make sure bozo.so is available in the LUA_CPATH
	local bozo = require('bozo')

	-- iterate files, all png and jpeg files recursively at path
	local files = bozo.files('path', 'png|jpg|jpeg', true)
	for _, file in ipairs(files) do
		print(file.name)
		print(file.filename)
		print(file.filepath)
		print(file.absolute)
	end

	-- load an existing image
	img = bozo.image('path/to/file.png')

	-- create a new image
	img = bozo.image(1024, 768)

	-- save an image
	img:save('path/to/file.png')

	-- free memory associated with an iamge
	img:dispose()

## reference

At the top level there are three main operations:

* iterating files
* loading an image
* creating a blank image

After that there are operations on image objects:

* width & height
* get and set pixels
* resize, crop, pad and copy
* save and dispose

### iterating files

#### bozo.files _(path, extensions, recursive) -> array_

_parameter_ | usage
:---- | :-----
_path_ | relative path to the running script
_extensions_ | optional pipe delimited list of extensions to include, not case sensitive
_recursive_ | recursively search the folder, true by default

	-- iterate the current folder for all loadable images
	local files = bozo.files('.', 'png|jpg|jpeg', true)
	for _, file in ipairs(files) do
		print(file.name)
		-- show all properties available
		for key, value in pairs(file) do
			print('\t' .. key .. '\t' .. tostring(value) or '')
		end
	end

Each entry in the array has the following properties available.
	
property | description
:---- | :----
name | the name of this file without the extension
extension | the extension of this file
filename | the name and extension of this file
filepath | the relative path to this file from the search path
absolute | the absoute path to this file
path | the relative path of the folder this file is in from the search path
absolute_path | the absolute path to the folder this file is in
directory | true if this is a directory not a file


### loading an image

#### bozo.image _(filename) -> image_

	-- load a png or jpeg file
	local image = bozo.image('example_file.png')

### creating an image

#### bozo.image _(width, height) -> image_

	-- create a new image
	local image = bozo.image(480, 320)

### operations on images

#### image:width _(filename) -> int_

#### image:height _(filename) -> int_

#### image:get_pixel _(x, y) -> r, g, b, a_

get a specific pixel's colour values as integers from 0 to 255

#### image:get_pixelf _(x, y) -> r, g, b, a_

get a specific pixel's colour values as floats from 0 to 1

#### image:set_pixel _(x, y, r, g, b, a)_

set a specific pixel's colour values as integers from 0 to 255

	-- set the top left pixel green
	image:set_pixel(0, 0, 0, 255, 0, 255)

#### image:set_pixelf _(x, y, r, g, b, a)_

set a specific pixel's colour values as floats from 0 to 255

	-- set the top left pixel blue
	image:set_pixel(0, 0, 0, 0, 1.0, 1.0)

#### image:resized_to _(width, height, filter, supersample) -> image_

create a new image that is a resized version of the original.

_parameter_ | usage
:---- | :-----
width | the width of the new image
height | the height of the new image
filter | optionally specify the sampling filter, default is lanczos3 for downscale or catmullrom for upscale, possible values are default, nearest, linear, bicubic, lanzos, lanczos2, lanczos3, lanczos8, catmullrom
supersample | optionally request supersampling when downscaling, if super sampled then the filter is applied to all pixels in the source range rather than the destination range

	-- create a downscaled version
	local halved = image:resized_to(image:width() * 0.5, image:height() * 0.5)
	-- create a supersampled (smoother) downscaled version
	local halved_smooth = image:resized_to(image:width() * 0.5, image:height() * 0.5, 'lanczos3', true)

#### image:cropped_to _(x, y, width, height) -> image_

create a new image cropped from the original image at the specified position.

#### image:padded_to _(width, height, x, y) -> image_

pad an image to a new width and height, with an optional offset.

#### image:blit_copy _(source_image, at_x, at_y)_

blit copy a source image into the receiver at the specified position.

#### image:save _(filename, colour_channels, alpha)_

_parameter_ | usage
:---- | :-----
filename | path to the output file, which should be either a png or jpeg file
colour_channels | number of channels of colour information, either 0, 1 or 3, default is 3
alpha | whether or not to include an alpha channel, default is true

	-- save the image as a jpeg (channel & alpha options not available)
	image:save('default.jpeg')
	-- save out a greyscale version also
	image:save('greyscale.png', 1, false)


#### image:dispose _()_

Frees the memory associated with this image. This may be useful if you are processing many images in a long running script.

## limitations

No build scripts exist for other platforms and this module depends on native OSX frameworks to load and manipulate images. I would be happy to receive patches to expand this into a cross platform module.

Images are kept in memory as 32bit RGBA regardless of the original image format.