//
//  PathsTile.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct 
{
	int cnt;
	double *lat, *lon;
} path;

@class PathsLayer;

@interface PathsTile : NSObject {
	@public
	double lx, ly, rx, ry;
	int i, j;
	int level;
	double nextppd;
	BOOL loading;
	int cnt;
	BOOL nodata;
	path *paths;
	BOOL hasnext;
	PathsTile **childs;
	PathsLayer *layer;
	NSString *filename;
}

//- (PathsTile*)initWithCoords: (double)_lx : (double)_ly : (double)_rx : (double)_ry file: (NSString*) _fn;
- (PathsTile*)initWithLayer: (PathsLayer*)_layer level: (int)_level i: (int)_i j: (int)_j;
- (void)render;
- (void)update;

@end
