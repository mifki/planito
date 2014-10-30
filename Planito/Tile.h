//
//  Tile.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

#define MAX_DL_RETRIES 3

typedef struct {
    unsigned char ver;
    NSTimeInterval timestamp;
} TILEINFO;

@class MapLayer;

@interface Tile : NSObject {
@public
    //MapLayer *layer;

	double lx, ly, rx, ry;
	int i, j, level;
 
    //NSString *localDataPath;
    
    BOOL nodata;
    BOOL nolocal;
    BOOL downloading;
    short dlretries;
    
    NSTimeInterval lastRenderTimestamp;
    
    NSUInteger datasize;
    
    Tile *qnext;
}

-(MapLayer*) layer;

-(void) render;
-(void) update;

-(void) initChilds;

-(void) free;

-(BOOL) gotDataFromProvider: (NSData*)data canRetry: (BOOL)canRetry;

@end
