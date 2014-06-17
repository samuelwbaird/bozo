// bozo - lua module
// 
// Copyright (c) 2014 Samuel Baird
// refer to LICENCE (MIT)

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

// establish the library
int luaopen_bozo(lua_State *L);

// file functions
int files(lua_State *L);

// image functions
int loadImageData(lua_State *L);
