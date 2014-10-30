//
//  FeaturesTileForDldr.h
//  Planito
//
//  Created by Vitaliy Pronkin on 27.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "Tile.h"

@class FeaturesLayer;

@interface FeaturesTileForDldr : Tile {
@public
    FeaturesLayer *layer;
}

-(id) initWithLayer: (FeaturesLayer*)_layer level: (int)_level i: (int)_i j: (int)_j;

@end
