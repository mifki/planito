//
//  FeaturesTileForDldr.m
//  Planito
//
//  Created by Vitaliy Pronkin on 27.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "FeaturesTileForDldr.h"
#import "FeaturesLayer.h"
#import "Helpers.h"
#import "Globals.h"

@implementation FeaturesTileForDldr

-(id) initWithLayer: (FeaturesLayer*)_layer level: (int)_level i: (int)_i j: (int)_j
{
	i = _i;
	j = _j;
	layer = _layer;
	level = _level;
    
    double degx = layer->zeroLevelDegX / (1 << level);
    double degy = layer->zeroLevelDegY / (1 << level);
    
	lx = -180 + degx * i;
	rx = lx + degx;
	
    ly = -90 + degy*j;
    ry = ly + degy;
    
	//localDataPath = [DATA_PATH(layer.lid, "%d/%04d/%d_%04d_%04d", level, j, level, j, i) retain];
	
	return self;
}

-(BOOL) gotDataFromProvider: (NSData*)data canRetry: (BOOL)canRetry
{
    if (data)
    {
        char k[32];
        
        sprintf(k, "%d_%d_%d/data", level, j, i);
        tchdbput(layer->cachedb2, k, strlen(k), [data bytes], [data length]);
        sprintf(k, "%d_%d_%d/info", level, j, i);
        TILEINFO ti = { 0, [NSDate timeIntervalSinceReferenceDate] };
        tchdbput(layer->cachedb2, k, strlen(k), &ti, sizeof(ti));
        
        /*[[NSFileManager defaultManager] createDirectoryAtPath:[localDataPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
        [data writeToFile:localDataPath atomically:NO];*/
        
        return YES;
    }
    
    return NO;
}

-(FeaturesLayer*) layer
{
    return layer;
}

@end
