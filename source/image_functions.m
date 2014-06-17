// bozo - image functions
// 
// Copyright (c) 2014 Samuel Baird
// refer to LICENCE (MIT)

#include <CoreFoundation/CoreFoundation.h>
#include <Quartz/Quartz.h>

#include "image_functions.h"

#pragma mark -
#pragma mark Required types and consts

static const char *metatable_name = "ImageData";

typedef struct {
	unsigned char *data;
	unsigned int width, height;
} ImageData;

typedef struct {
	unsigned char a;
	unsigned char r;
	unsigned char g;
	unsigned char b;
} ImagePixel;

static const ImagePixel empty_pixel = { 0, 0, 0, 0 };

#pragma mark -
#pragma mark ImageData c functions

static ImageData* ImageData_new(unsigned int width, unsigned int height) {
	unsigned char *data = (unsigned char *) calloc(width * 4, height);
	if (!data) {
		return 0;
	}
	
	ImageData *image_data = (ImageData *) calloc(1, sizeof(ImageData));
	image_data->data = data;
	image_data->width = width;
	image_data->height = height;
	return image_data;
}

static void ImageData_destroy(ImageData *image_data) {
	if (image_data->data) {
		free(image_data->data);
	}
	free(image_data);
}

static unsigned char *ImageData_get_data_clamped(ImageData *image_data, int x, int y) {
	if (x < 0) x = 0;
	if (x >= image_data->width) x = image_data->width - 1;
	if (y < 0) y = 0;
	if (y >= image_data->height) y = image_data->height - 1;
	return image_data->data + (x * 4) + (y * image_data->width * 4);
}
	 
static ImagePixel ImageData_get_imagepixel(ImageData *image_data, int x, int y) {
	if (image_data && image_data->data && x >= 0 && x < image_data->width && y >= 0 && y < image_data->height) {
		unsigned char *pixel_data = image_data->data + ((x * 4) + (y * 4 * image_data->width));
		ImagePixel pixel = { pixel_data[0], pixel_data[1], pixel_data[2], pixel_data[3] };
		return pixel;
	} else {
		return empty_pixel;
	}
}

static void ImageData_set_imagepixel(ImageData *image_data, int x, int y, ImagePixel pixel) {
	if (image_data && image_data->data && x >= 0 && x < image_data->width && y >= 0 && y < image_data->height) {
		unsigned char *pixel_data = image_data->data + ((x * 4) + (y * 4 * image_data->width));
		pixel_data[0] = pixel.a;
		pixel_data[1] = pixel.r;
		pixel_data[2] = pixel.g;
		pixel_data[3] = pixel.b;
	}
}

#pragma mark -
#pragma mark scaling functions

// General purpose filtering

typedef double (filter_function) (double mu);

static double clamp(double val, double min, double max) {
	return val < min ? min : (val > max ? max : val);
}

static void ImageData_scale_with_filter(ImageData *source, ImageData *dest, int filter_radius, filter_function weighting, bool super_sample) {
    // scale a single dimension at a time into a buffer
    // filter around the appropriate area to get weightings of related pixels
    // super_sample = when scaling down the filter size is scaled up
    
    const int dest_width = dest->width;
    const int dest_height = dest->height;
    const int source_width = source->width;
    const int source_height = source->height;
    
    const double scale_x = (float) dest_width / (float) source_width;
    const double scale_y = (float) dest_height / (float) source_height;
    
    ImageData *working = ImageData_new(dest_width, source_height);
    const int working_width = working->width;
    const int working_height = working->height;
    
    // scale the horizontal access first
    if (working_width == source_width) {
        // direct copy
        memcpy(working->data, source->data, working->height * working->width * 4);

    } else {
        const double window_scale = (working_width < source_width && super_sample) ? scale_x : 1.0;
        const double filter_width = filter_radius / window_scale;
        
        for (int y = 0; y < working_height; y++) {
            for (int x = 0; x < working_width; x++) {
                const double center = ((x + 0.5) / scale_x);
                const int left = (int)(center - filter_width);
                const int right = (int)(center + filter_width);
                double total_value[4] = { 0, 0, 0, 0 };
                double total_weighting[4] = { 0, 0, 0, 0 };
                
                for (int i = left; i < right; i++) {
                    if (i >= 0 && i < source_width) {
                        double mu = ((center - i) - 0.5) * window_scale;   // deviation from center
                        double w = (*weighting)(mu);                       // weighting at this deviation
                        ImagePixel pixel = ImageData_get_imagepixel(source, i, y);
                        unsigned char *pixel_data = &pixel.a;
                        for (int c = 0; c < 4; c++) {
                            double v = (double) *pixel_data;
                            total_value[c] = total_value[c] + (w * v);
                            total_weighting[c] = total_weighting[c] + w;
                            pixel_data++;
                        }
                    }
                }
                ImagePixel blended;
                blended.a = clamp(total_value[0] / total_weighting[0], 0, 255);
                blended.r = clamp(total_value[1] / total_weighting[1], 0, 255);
                blended.g = clamp(total_value[2] / total_weighting[2], 0, 255);
                blended.b = clamp(total_value[3] / total_weighting[3], 0, 255);
                ImageData_set_imagepixel(working, x, y, blended);
            }
        }
    }
    
    // now scale vertically from the working copy
    if (dest_height == working_height) {
        // direct copy
        memcpy(dest->data, working->data, working->height * working->width * 4);

    } else {
        const double window_scale = (dest_height < working_height && super_sample) ? scale_y : 1.0;
        const double filter_height = filter_radius / window_scale;
        
        for (int x = 0; x < dest_width; x++) {
            for (int y = 0; y < dest_height; y++) {
                const double center = ((y + 0.5) / scale_y);
                const int top = (int)(center - filter_height);
                const int bottom = (int)(center + filter_height);
                double total_value[4] = { 0, 0, 0, 0 };
                double total_weighting[4] = { 0, 0, 0, 0 };
                for (int i = top; i < bottom; i++) {
                    if (i >= 0 && i < working_height) {
                        double mu = ((center - i) - 0.5) * window_scale;   // deviation from center
                        double w = (*weighting)(mu);                // weighting at this deviation
                        ImagePixel pixel = ImageData_get_imagepixel(working, x, i);
                        unsigned char *pixel_data = &pixel.a;
                        for (int c = 0; c < 4; c++) {
                            double v = (double) *pixel_data;
                            total_value[c] = total_value[c] + (w * v);
                            total_weighting[c] = total_weighting[c] + w;
                            pixel_data++;
                        }
                    }
                }
                ImagePixel blended;
                blended.a = clamp(total_value[0] / total_weighting[0], 0, 255);
                blended.r = clamp(total_value[1] / total_weighting[1], 0, 255);
                blended.g = clamp(total_value[2] / total_weighting[2], 0, 255);
                blended.b = clamp(total_value[3] / total_weighting[3], 0, 255);
                ImageData_set_imagepixel(dest, x, y, blended);
            }
        }
     }

    
    ImageData_destroy(working);
}

double nearest(double x) {
    return 1.0;
}

double linear(double x) {
    x = x < 0 ? -x : x;
    if (x < 1) {
        return 1.0 - x;
    } else {
        return 0;
    }
}

double cubic(double x) {
    x = x < 0 ? -x : x;
    
    if (x < 1) {
        double temp = x * x;
        return (0.5 * temp * x - temp + (2.0 / 3.0));
    } else if (x < 2) {
        x = 2.0 - x;
        return ((x * x * x) / 6.0);
    } else {
        return 0;
    }
}

double lanczos3(double x) {
    if (x == 0) {
        return 1.0;
    } else if (x < 3) {
        return (1.0 * sin(x * M_PI) * sin((x * M_PI) / 3.0)) / (x * x * M_PI * M_PI);
    } else {
        return 0;
    }
}

double lanczos2(double x) {
    if (x == 0) {
        return 1.0;
    } else if (x < 2) {
        return (1.0 * sin(x * M_PI) * sin((x * M_PI) / 2.0)) / (x * x * M_PI * M_PI);
    } else {
        return 0;
    }
}

double lanczos8(double x) {
    if (x == 0) {
        return 1.0;
    } else if (x < 8) {
        return (1.0 * sin(x * M_PI) * sin((x * M_PI) / 8.0)) / (x * x * M_PI * M_PI);
    } else {
        return 0;
    }
}

double catmullrom(double x) {
    x = x < 0 ? -x : x;
    double temp = x * x;

    if (x <= 1) return (1.5 * temp * x - 2.5 * temp + 1);
    if (x <= 2) return (- 0.5 * temp * x + 2.5 * temp - 4 * x + 2);
    return 0;
}

#pragma mark -
#pragma mark ImageData lua methods

static void pushImageData(lua_State *L, ImageData *data) {
	void *user_data = lua_newuserdata(L, sizeof(ImageData *));
	memcpy(user_data, &data, sizeof(ImageData *));
	
	luaL_getmetatable(L, metatable_name);
	lua_setmetatable(L, -2);
}

static int ImageData_width(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	if (image_data) {
		lua_pushinteger(L, image_data->width);
	} else {
		lua_pushinteger(L, 0);
	}
	return 1;
}

static int ImageData_height(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	if (image_data) {
		lua_pushinteger(L, image_data->height);
	} else {
		lua_pushinteger(L, 0);
	}
	return 1;
}

static int ImageData_cropped_to(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	int width = luaL_checkinteger(L, 4);
	int height = luaL_checkinteger(L, 5);
	
	ImageData *new_image = ImageData_new(width, height);
	
	int line_width = width;
	if (x + line_width > image_data->width) {
		line_width = image_data->width - x;
	}
	
	for (int y_line = 0; y_line < height; y_line++) {
		memcpy(new_image->data + (y_line * width * 4),
			   image_data->data + ((x + ((y + y_line) * image_data->width)) * 4), 
			   line_width * 4);
	}
	
	pushImageData(L, new_image);
	return 1;
}

static int ImageData_resized_to(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	int width = luaL_checkinteger(L, 2);
	int height = luaL_checkinteger(L, 3);
	
	const char *methods[] = { "default", "nearest", "linear", "bicubic", "lanzos", "lanczos2", "lanczos3", "lanczos8", "catmullrom" };
	int method = luaL_checkoption(L, 4, "default", methods);

    BOOL super_sample = false;
    if (lua_gettop(L) >= 5) {
        super_sample = lua_toboolean(L, 5);
    }
    
    ImageData *new_image = ImageData_new(width, height);
    switch (method) {
        case 1:         // nearest
            ImageData_scale_with_filter(image_data, new_image, 0.5, nearest, super_sample);
            break;
        case 2:         // linear
            ImageData_scale_with_filter(image_data, new_image, 1, linear, super_sample);
            break;
        case 3:         // bicubic
            ImageData_scale_with_filter(image_data, new_image, 2, catmullrom, super_sample);
            break;
        case 4:         // lanczos default
        case 6:         // lanczos 3
            ImageData_scale_with_filter(image_data, new_image, 3, lanczos3, super_sample);
            break;
        case 5:         // lanczos 2
            ImageData_scale_with_filter(image_data, new_image, 2, lanczos2, super_sample);
            break;
        case 7:         // lanczos 8
            ImageData_scale_with_filter(image_data, new_image, 8, lanczos8, super_sample);
            break;
        case 8:         // catmullrom spline
            ImageData_scale_with_filter(image_data, new_image, 2, catmullrom, super_sample);
            break;
        default:
            if (width < image_data->width || height < image_data->height) {
                // default to lancos downscaling
                ImageData_scale_with_filter(image_data, new_image, 3, lanczos3, super_sample);
            } else {
                // catmullrom upscaling
                ImageData_scale_with_filter(image_data, new_image, 2, catmullrom, super_sample);
            }
            break;
    }

	pushImageData(L, new_image);
	return 1;
}

static int ImageData_padded_to(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	int width = luaL_checkinteger(L, 2);
	int height = luaL_checkinteger(L, 3);
	int x = luaL_checkinteger(L, 4);
	int y = luaL_checkinteger(L, 5);
	
	ImageData *new_image = ImageData_new(width, height);
	
	int line_width = width;
	if (x + line_width > width) {
		line_width = width - x;
	}
	if (line_width > image_data->width) {
		line_width = image_data->width;
	}
	
	for (int y_line = 0; ((y + y_line) < height) && (y_line < image_data->height); y_line++) {
		memcpy(new_image->data + (x * 4) + ((y + y_line) * width * 4),
			   image_data->data + (y_line * image_data->width * 4), 
			   line_width * 4);
	}
	
	pushImageData(L, new_image);
	return 1;
}

static int ImageData_blit_copy(lua_State *L) {
	ImageData *destination_image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	ImageData *source_image_data = *(ImageData **) luaL_checkudata(L, 2, metatable_name);
	int x = luaL_optinteger(L, 3, 0);
	int y = luaL_optinteger(L, 4, 0);
	
	int width = source_image_data->width;
	int height = source_image_data->height;
	
	if (x + width > destination_image_data->width) {
		width = destination_image_data->width - x;
	}
	if (y + height > destination_image_data->height) {
		height = destination_image_data->height - y;
	}
	
	if (width > 0 && height > 0) {
		for (int copy_y = 0; copy_y < height; copy_y++) {
			for (int copy_x = 0; copy_x < width; copy_x++) {
				ImageData_set_imagepixel(destination_image_data, copy_x + x, copy_y + y, ImageData_get_imagepixel(source_image_data, copy_x, copy_y));
			}
		}
	}
	
	return 0;
}

static int ImageData_get_pixel(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);

	ImagePixel pixel = ImageData_get_imagepixel(image_data, x, y);
	lua_pushinteger(L, pixel.r);
	lua_pushinteger(L, pixel.g);
	lua_pushinteger(L, pixel.b);
	lua_pushinteger(L, pixel.a);
	
	return 4;
}

static int ImageData_get_pixelf(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	
	ImagePixel pixel = ImageData_get_imagepixel(image_data, x, y);
	lua_pushnumber(L, (float) pixel.r / 255.0);
	lua_pushnumber(L, (float) pixel.g / 255.0);
	lua_pushnumber(L, (float) pixel.b / 255.0);
	lua_pushnumber(L, (float) pixel.a / 255.0);
	
	return 4;
}

static int ImageData_set_pixel(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	int r = luaL_checkinteger(L, 4);
	int g = luaL_checkinteger(L, 5);
	int b = luaL_checkinteger(L, 6);
	int a = luaL_checkinteger(L, 7);
	
	ImagePixel pixel = { a, r, g, b };
	ImageData_set_imagepixel(image_data, x, y, pixel);
	return 0;
}

unsigned char float_to_char(float value) {
	int val = value * 255.0;
	if (val < 0) {
		return 0;
	} else if (val > 255) {
		return 255;
	} else {
		return val;
	}
}

static int ImageData_set_pixelf(lua_State *L) {
	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	float r = luaL_checknumber(L, 4);
	float g = luaL_checknumber(L, 5);
	float b = luaL_checknumber(L, 6);
	float a = luaL_checknumber(L, 7);
	
	ImagePixel pixel = { float_to_char(a), float_to_char(r), float_to_char(g), float_to_char(b) };
	ImageData_set_imagepixel(image_data, x, y, pixel);
	return 0;
}

static int ImageData_save(lua_State *L) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	ImageData *image_data = *(ImageData **) luaL_checkudata(L, 1, metatable_name);
	if (!image_data || !image_data->data) {
		lua_pushboolean(L, 0);
		[pool drain];
		return 1;
	}
	
	const char *filename = luaL_checkstring(L, 2);	
	NSURL *fileURL = [NSURL fileURLWithPath: [NSString stringWithCString: filename encoding: NSUTF8StringEncoding]];
	NSString *extension = [[fileURL pathExtension] lowercaseString];
	
	//detect PNG or JPEG, otherwise invalid
	CFStringRef type = 0;
	if ([extension isEqualToString: @"png"]) {
		type = kUTTypePNG;
	} else if ([extension isEqualToString: @"jpg"] || [extension isEqualToString: @"jpeg"]) {
		type = kUTTypeJPEG;
	} else {
		[pool drain];
		lua_pushstring(L, "Unrecognised file type");
		lua_error(L);
		return 1;
	}
	
	CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, image_data->data, image_data->width * image_data->height * 4, NULL);
	CGColorSpaceRef colorRef = CGColorSpaceCreateDeviceRGB();		
	CGImageRef imageRef = CGImageCreate(image_data->width, image_data->height, 8, 32, image_data->width * 4, colorRef, kCGImageAlphaPremultipliedFirst, dataProvider, NULL, NO, kCGRenderingIntentDefault);
	CGColorSpaceRelease(colorRef);

	unsigned char *convert_data = nil;
	
	//if extension is PNG then check for channels parameter (0, 1, 3) and alpha parameter true/false
	if (type == kUTTypePNG) {
		int channels = luaL_optinteger(L, 3, 3);
		BOOL alpha = YES;
		if (lua_gettop(L) >= 4) {
			alpha = lua_toboolean(L, 4);
		}
		int bit_depth = 8; //luaL_optinteger(L, 5, 8); only 8 works
		
		//if not RGBA then create a new image in the required format, draw and discard the one above
		if (!alpha || (channels != 3) || (bit_depth != 8)) {
			float bytes_per_pixel = ((channels + (alpha ? 1 : 0)) * bit_depth) / 8.0;
			convert_data = calloc(bytes_per_pixel, image_data->width * image_data->height);
			CGImageAlphaInfo alpha_component = kCGImageAlphaPremultipliedFirst;
			if (!alpha) {
				alpha_component = kCGImageAlphaNone;
			} else if (channels == 0) {
				alpha_component = kCGImageAlphaOnly;
			}
			
			CGColorSpaceRef colorRef = channels != 3 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB();		
			CGContextRef context = CGBitmapContextCreate(convert_data,
														 image_data->width,
														 image_data->height,
														 bit_depth,      // bits per component
														 image_data->width * bytes_per_pixel,
														 colorRef,
														 alpha_component
														 );
			
			//draw the original image into the new data format
			CGContextDrawImage(context, CGRectMake(0, 0, image_data->width, image_data->height), imageRef);
			CGContextRelease(context);
			
			CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, convert_data, image_data->width * image_data->height * bytes_per_pixel, NULL);
			CGImageRef convertImageRef = CGImageCreate(image_data->width, image_data->height, bit_depth, bytes_per_pixel * 8, image_data->width * bytes_per_pixel, colorRef, alpha_component, dataProvider, NULL, NO, kCGRenderingIntentDefault);
			CGColorSpaceRelease(colorRef);
			CGDataProviderRelease(dataProvider);
			
			//swap convertImageRef
			if (convertImageRef) {
				CGImageRelease(imageRef);
				imageRef = convertImageRef;
			}
		}
	}
	
	CGImageDestinationRef imageDestination = CGImageDestinationCreateWithURL((CFURLRef) fileURL, type, 1, NULL);
    if (!imageDestination) {
		CGImageRelease(imageRef);
		CGDataProviderRelease(dataProvider);
		if (convert_data) {
			free(convert_data);
			convert_data = 0;
		}
		
		lua_pushboolean(L, 0);
		[pool drain];
		return 1;
    }
	
    CGImageDestinationAddImage(imageDestination, imageRef, NULL);
    BOOL success = CGImageDestinationFinalize(imageDestination);
    CFRelease(imageDestination);
	CGImageRelease(imageRef);
	CGDataProviderRelease(dataProvider);

	if (convert_data) {
		free(convert_data);
		convert_data = 0;
	}
	
	lua_pushboolean(L, success);
	[pool drain];
	return 1;
}

static int ImageData_dispose(lua_State *L) {
	ImageData **image_data = (ImageData **) luaL_checkudata(L, 1, metatable_name);
	if (*image_data) {
		ImageData_destroy(*image_data);
	}
	image_data = nil;
	return 0;
}

#pragma mark -
#pragma mark Public lua interface and constructors

static const struct luaL_Reg image_data_metatable [] = {
	{ "width", ImageData_width },				// -> width
	{ "height", ImageData_height },				// -> height
	
	{ "cropped_to", ImageData_cropped_to },		// x, y, width, height -> image
	{ "resized_to", ImageData_resized_to },		// width, height, (method), (iterate) -> image
	{ "padded_to", ImageData_padded_to },		// width, height, (offsetx), (offsety) -> image
	
	{ "blit_copy", ImageData_blit_copy },					// source, destination, x, y
	
	{ "get_pixel", ImageData_get_pixel },		//x, y -> r, g, b, a
	{ "get_pixelf", ImageData_get_pixelf },		//x, y -> r, g, b, a
	{ "set_pixel", ImageData_set_pixel },		//x, y, r, g, b, a
	{ "set_pixelf", ImageData_set_pixelf },		//x, y, r, g ,b, a

	//region_is_empty							//x, y, width, height, (color = alpha0)
	
	{ "save", ImageData_save },					//name, channels, alpha -> boolean
	{ "dispose", ImageData_dispose },			//
	{ NULL, NULL }
};

static ImageData *imageDataFromFile(lua_State *L, const char *filename) {
	//Get a handle to loading the image
	CGDataProviderRef provider = CGDataProviderCreateWithFilename(filename);
    CGImageRef imageRef = CGImageCreateWithPNGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
	if (imageRef == nil) {
		// had a problem with JPG masquerading as PNG files
		imageRef = CGImageCreateWithJPEGDataProvider(provider, NULL, true, kCGRenderingIntentDefault);
	}
    CGDataProviderRelease(provider);
	
	size_t imageWidth = CGImageGetWidth(imageRef);
	size_t imageHeight = CGImageGetHeight(imageRef);
	
	//Get the ImageData ready
	ImageData *image_data = ImageData_new(imageWidth, imageHeight);
	if (!image_data) {
		CGImageRelease(imageRef);
		luaL_error(L, "Unable to allocate image data");
		return 0;
	}
	
	CGColorSpaceRef colorRef = CGColorSpaceCreateDeviceRGB();
	
	// Create the bitmap context.
	CGContextRef context = CGBitmapContextCreate(image_data->data,
									imageWidth,
									imageHeight,
									8,      // bits per component
									imageWidth * 4,
									colorRef,
									kCGImageAlphaPremultipliedFirst
									);
	CGColorSpaceRelease(colorRef);
	
	if (context == NULL) {
		ImageData_destroy(image_data);
		luaL_error(L, "Could not create image context %s %d x %d", filename, imageWidth, imageHeight);
		return 0;
	}
	
	//draw the image into the data
	CGRect imageFullRect = {{0, 0}, {imageWidth, imageHeight}};
	CGContextSetBlendMode(context, kCGBlendModeCopy);
	CGContextDrawImage(context, imageFullRect, imageRef); 
	CGContextRelease(context);
	CGImageRelease(imageRef);

	return image_data;
}

static ImageData *imageDataWithSize(unsigned int width, unsigned int height) {
	return ImageData_new(width, height);
}

int image(lua_State *L) {
	//argument should either be a file name or dimensions
	//create a 32bit ARGB bitmap as specified
	
	if (lua_isnumber(L, 1)) {
		int width = luaL_optinteger(L, 1, 0);
		int height = luaL_optinteger(L, 2, 0);
		if (width && height) {
			ImageData *new_image = imageDataWithSize(width, height);
			if (new_image) {
				pushImageData(L, new_image);
				return 1;
			} else {
				return 0;
			}
		}
	}
	
	if (lua_isstring(L, 1)) {
		const char *filename = luaL_optlstring(L, 1, nil, 0);
		if (filename) {
			ImageData *load_image = imageDataFromFile(L, filename);
			if (load_image) {
				pushImageData(L, load_image);
				return 1;
			} else {
				return 0;
			}
		}
	}
	
	return 0;
}

void init_image_functions(lua_State *L) {
	//create the metatable that is associated with this class
	luaL_newmetatable(L, metatable_name);
	
	//set up index self-ref
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");
	
	//register methods directly on the metatable
	luaL_register(L, NULL, image_data_metatable);	
	lua_pop(L, 1);
}