//
//  PlacemarksTile.h
//  Planito
//
//  Created by Vitaliy Pronkin on 4/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Features.h"
#import "Tile.h"

@class FeaturesLayer;

@interface FeaturesTile : Tile {
@public
    double flx, fly, frx, fry;

    FeaturesTile **childs;
    FeaturesTile *_childs[4];
    int childcols, childrows;
    
	FeaturesLayer *layer;
    
    Features *features;
    
    NSTimeInterval datatimestamp;

    BOOL uflag;
    BOOL rendered;
}

-(FeaturesTile*) initWithLayer: (FeaturesLayer*)_layer level: (int)_level  i: (int)_i j: (int)_j;

-(BOOL) gotDataFromProvider: (id)data canRetry: (BOOL)canRetry;

-(BOOL) render; //redefined as BOOL

-(BOOL) findFeatureForLat: (double)mlat lon: (double)mlon;

@end
