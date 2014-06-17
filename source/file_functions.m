/*
 *  bozo
 *
 *  Just whatever I want in a lua module for images and utilities on mac
 *
 *  Created by Samuel Baird on 18/11/10.
 *  Copyright 2010 Samuel Baird. All rights reserved.
 *
 */


#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>

#include "file_functions.h"

int files(lua_State *L) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSFileManager *fileManager = [NSFileManager defaultManager];

	// path = "."
	const char *path = luaL_optlstring (L, 1, nil, 0);
	if (!path || strlen(path) == 0) {
		path = ".";
	}
	
	//optional extensions filter "exe|txt|png", simple extension matching, no wildcards, separate with bar or comma
	const char *extension = luaL_optlstring(L, 2, nil, 0);
	NSArray *check_extensions = nil;
	if (extension) {
		NSString *extensions = [NSString stringWithCString: extension encoding: NSUTF8StringEncoding];
		if (![extensions isEqualToString: @"*"] && ![extensions isEqualToString: @"*.*"]) {
			NSArray *components = [extensions componentsSeparatedByCharactersInSet: [NSCharacterSet characterSetWithCharactersInString: @",| "]];
			NSMutableArray *mutable = [NSMutableArray array];
			for (NSString *ext in components) {
				if ([ext hasPrefix: @"."]) {
					ext = [ext stringByReplacingCharactersInRange: NSMakeRange(0, 1) withString: @""];
				}
				if ([ext hasPrefix: @"*."]) {
					ext = [ext stringByReplacingCharactersInRange: NSMakeRange(0, 2) withString: @""];
				}
				if (ext && [ext length] > 0) {
					[mutable addObject: [ext lowercaseString]];
				}
			}
			check_extensions = [NSArray arrayWithArray: mutable];
		}
	}
	
	//optionally recursive, default true
	bool recursive = true;
	if (lua_gettop(L) >= 3) {
		recursive = lua_toboolean(L, 3);
	}
	
	NSError *error = nil;
	NSArray *paths = nil;
	NSString *base_path = [NSString stringWithCString: path encoding: NSUTF8StringEncoding];
	if (![base_path hasPrefix: @"~"] && ![base_path hasPrefix: @"/"]) {
		base_path = [[fileManager currentDirectoryPath] stringByAppendingPathComponent: base_path];
	}
	base_path = [base_path stringByStandardizingPath];
					 
	if (recursive) {
		paths = [fileManager subpathsOfDirectoryAtPath: base_path error: &error];
	} else {
		paths = [fileManager contentsOfDirectoryAtPath: base_path error: &error];
	}
	if (error) {
		[pool drain];
		return 0;
	}
	
	NSMutableArray *path_components = [NSMutableArray array];
	[path_components addObject: base_path];
	
	int entryNo = 0;
	lua_newtable(L);
	
	for (NSString *filePath in paths) {
		// pull all the relevant parts of the path
		[path_components addObject: filePath];
		NSURL *url = [NSURL fileURLWithPathComponents: path_components];
		[path_components removeLastObject];
		NSString *relative = [filePath stringByDeletingLastPathComponent];
		NSString *extension = [url pathExtension];
		
		if (check_extensions && [check_extensions count] > 0) {
			BOOL matches_extension = NO;
			for (NSString *check_ext in check_extensions) {
				if ([[extension lowercaseString] isEqualToString: check_ext]) {
					matches_extension = YES;
					break;
				}
			}
			if (!matches_extension) {
				continue;
			}
		}
		
		// determine if it is a directory
		[path_components addObject: filePath];
		BOOL directory = NO;		
		[fileManager fileExistsAtPath: [NSString pathWithComponents: path_components] isDirectory: &directory];
		[path_components removeLastObject];
		
		
		//create a new entry
		lua_newtable(L);
		
		lua_pushstring(L, "absolute");
		lua_pushstring(L, [[url path] cStringUsingEncoding: NSUTF8StringEncoding]);
		lua_settable(L, -3);
		
		lua_pushstring(L, "absolute_path");
		lua_pushstring(L, [[[url path] stringByDeletingLastPathComponent] cStringUsingEncoding: NSUTF8StringEncoding]);
		lua_settable(L, -3);
		
		lua_pushstring(L, "path");
		lua_pushstring(L, [relative cStringUsingEncoding: NSUTF8StringEncoding]);
		lua_settable(L, -3);
		
		
		lua_pushstring(L, "filepath");
		lua_pushstring(L, [filePath cStringUsingEncoding: NSUTF8StringEncoding]);
		lua_settable(L, -3);
		
		lua_pushstring(L, "filename");
		lua_pushstring(L, [[filePath lastPathComponent] cStringUsingEncoding: NSUTF8StringEncoding]);
		lua_settable(L, -3);
		
		lua_pushstring(L, "name");
		lua_pushstring(L, [[[filePath lastPathComponent] stringByDeletingPathExtension] cStringUsingEncoding: NSUTF8StringEncoding]);
		lua_settable(L, -3);
		
		lua_pushstring(L, "extension");
		lua_pushstring(L, [extension cStringUsingEncoding: NSUTF8StringEncoding]);
		lua_settable(L, -3);
		
		lua_pushstring(L, "directory");
		lua_pushboolean(L, directory);
		lua_settable(L, -3);
		
		//add it sequentially to the main table
		lua_rawseti(L, -2, ++entryNo);		
	}	
	
	[pool drain];
	return 1;
}