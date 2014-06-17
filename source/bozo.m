/*
 *  bozo
 *
 *  Just whatever I want in a lua module for images and utilities on mac
 *
 *  Created by Samuel Baird on 18/11/10.
 *  Copyright 2010 Samuel Baird. All rights reserved.
 *
 */


#include "file_functions.h"
#include "image_functions.h"

#include "bozo.h"


static const struct luaL_Reg bozo_lib [] = {
	{ "files", files },
	{ "image", image },
	{ NULL, NULL }
};

int luaopen_bozo(lua_State *L) {
	init_image_functions(L);
	luaL_register(L, "bozo", bozo_lib);
	return 1;
}
