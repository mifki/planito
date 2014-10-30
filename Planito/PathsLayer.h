//
//  PathsLayer.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MapLayer.h"

@class PathsTile;

@interface PathsLayer : MapLayer {
	@public
	PathsTile **zeroLevelTiles;	
	NSString *dataRoot;
	float minPPD, minPPD2;
	float r, g, b;
}

-(PathsLayer*) initWithName: (NSString*) _name lid: (NSString*) _lid on: (BOOL) _on opacity: (float) _opacity color: (float)_r:(float)_g:(float)_b dataRoot: (NSString*) _dataRoot provider: (id)_provider minPPD: (float)_minPPD;

@end
