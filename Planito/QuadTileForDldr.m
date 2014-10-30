//
//  QuadTileForDldr.m
//  Planito
//
//  Created by Vitaliy Pronkin on 27.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "QuadTileForDldr.h"
#import "QuadTileLayer.h"
#import "Helpers.h"
#import "Globals.h"

@implementation QuadTileForDldr

-(id) initWithLayer: (QuadTileLayer*) _layer level: (int) _level i: (int) _i j: (int) _j
{
    if (self=[super init])
    {
        layer = _layer;
        level = _level;
        i = _i;
        j = _j;
        
        double degx = layer->zeroLevelDegX / (1 << level);
        
        lx = layer->originX + degx * i;
        rx = lx + degx;
        
        if (layer->isMercator)
        {
            double pp = (2*2*layer->zeroLevelDegY/180.0*M_PI) / (2 << level);
            double l1 = 2*atan(exp((j)*pp-M_PI))-M_PI_2;        
            double l2 = 2*atan(exp((j+1)*pp-M_PI))-M_PI_2;        
            
            ly = l1/M_PI*180.0;
            ry = l2/M_PI*180.0;
        }
        else
        {
            ly = layer->originY + (layer->zeroLevelDegY / (1 << level))*j;
            ry = ly + degx;
        }
                
        //localDataPath = [DATA_PATH(layer.lid, "%d/%04d/%d_%04d_%04d", level, j, level, j, i) retain];
    }
    
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

        return YES;
    }
    
    return NO;
}

-(QuadTileLayer*) layer
{
    return layer;
}

@end
