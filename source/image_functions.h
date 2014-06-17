/*
 *  bozo
 *
 *  Just whatever I want in a lua module for images and utilities on mac
 *
 *  Created by Samuel Baird on 18/11/10.
 *  Copyright 2010 Samuel Baird. All rights reserved.
 *
 */


#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

// image functions
//int loadImageData(lua_State *L);

int image(lua_State *L);
void init_image_functions(lua_State *L);