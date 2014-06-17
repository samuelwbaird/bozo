// bozo - lua module
// 
// Copyright (c) 2014 Samuel Baird
// refer to LICENCE (MIT)

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
