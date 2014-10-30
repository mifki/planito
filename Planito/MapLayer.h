//
//  MapLayer.h
//  Planito
//
//  Created by Vitaliy Pronkin on 11.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "Layer.h"
#import "TileProvider.h"
#import "tokyo/tchdb.h"

#define UPD_QUEUE_LEN 100 //50

@class Tile;

@interface MapLayer : Layer {
@public
	double zeroLevelDegX, zeroLevelDegY;
	Tile **zeroLevelTiles;
	int cols, rows;
    int maxLevel;
    BOOL fullworld;    

	double lx, ly, rx, ry;
	double lx1, ly1, rx1, ry1;    
    
    id<TileProvider> provider;

    NSTimeInterval dataExpiresIn, dataExpiresAt;
    BOOL docache;

    BOOL visible;
    NSMutableArray *credits;
    
    TCHDB *cachedb2;
}

-(void) render;
-(void) update;

-(void) openCache;
-(void) closeCache;

@end
