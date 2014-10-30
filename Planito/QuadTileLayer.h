//
//  QuadTileLayer.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MapLayer.h"
#import "Layer.h"

#define TEXCACHESIZE 75

@class QuadTile;

struct UPDQUEUE {
    QuadTile *queue[UPD_QUEUE_LEN];
    int updcnt;
};

@interface QuadTileLayer : MapLayer {
@public
    double originX, originY;
	
	BOOL isMercator;
	
    int tileSize;
	int minTileSize;
    double nextTileSize;
    
    //QuadTile *updQueue[UPD_QUEUE_LEN];
    //int updcnt;
    struct UPDQUEUE updqueues[2];
    struct UPDQUEUE *curupdqueue, *anotherupdqueue;
    
    int textarget;
    int glformat;
    
    short formatHint;
    
    GLuint *texscache;
    BOOL *texsusage;
}

-(QuadTileLayer*) initWithName: (NSString*) _name lid: (NSString*)_lid on: (BOOL) _on opacity: (float) _opacity bbox: (double) _lx : (double) _ly : (double) _rx : (double) _ry origin: (double) _ox : (double) _oy zeroLevelDeg: (double) _zld maxLevel: (int) _maxl tileSize: (int)_tileSize mercator: (BOOL) _merc;

@end
