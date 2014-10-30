//
//  PlacemarksLayer.h
//  Planito
//
//  Created by Vitaliy Pronkin on 4/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <OpenGL/GL.h>
#import "MapLayer.h"
#import "Features.h"

@class FeaturesTile;

struct UPDQUEUE2 {
    FeaturesTile *queue[UPD_QUEUE_LEN];
    int updcnt;
};


@interface FeaturesLayer : MapLayer {

	BOOL downloading;
	BOOL loaded;
    
@public
	BOOL showOne;
    double minppd;
    
    double plx1;
    	    
	FEATURESTYLE *styles;
	int stylecnt;
    
    struct UPDQUEUE2 updqueues[2];
    struct UPDQUEUE2 *curupdqueue, *anotherupdqueue;
        
	BOOL newStyles;

    FEATURESTYLE *curstyle;
}

-(FeaturesLayer*) initWithName: (NSString*) _name lid: (NSString*)_lid on: (BOOL) _on opacity: (float) _opacity bbox: (double) _lx : (double) _ly : (double) _rx : (double) _ry zeroLevelDeg: (double) _zld maxLevel: (int) _maxl;

-(BOOL) findFeatureForLat: (double)mlat lon: (double)mlon;

@end
