//
//  CacheManager.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

@class QuadTile;
@class Tile;

@interface CacheManager : NSObject {
    Tile *qhead;
    Tile *qtail;
    
@public
    NSUInteger cachesize;
    
    NSUInteger high, low;
}

-(void) registerTile: (Tile*)t;

-(void) reset;

-(void) cleanup;


@end
