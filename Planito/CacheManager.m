//
//  CacheManager.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/4/07.
//  Copyright 2007 mifki. All rights reserved.
//

#import "CacheManager.h"
#import "Globals.h"
#import "Tile.h"
#import "MapLayer.h"

@implementation CacheManager

- (CacheManager*)init
{
    if (self=[super init])
    {
        high = [[NSUserDefaults standardUserDefaults] integerForKey:@"MemoryCacheHigh"] * 1024*1024;
        low = high / 2; //[[NSUserDefaults standardUserDefaults] integerForKey:@"MemoryCacheLow"];
    }
    
	return self;
}

-(void) reset
{
    qhead = qtail = nil;
}

-(void) registerTile: (Tile*)t
{
    @synchronized(self)
    {
        cachesize += t->datasize;
        
        if (!qtail)
        {
            qhead = qtail = t;
            return;
        }
        
        qhead->qnext = t;
        qhead = t;
    }
}

-(void) cleanup
{
    @synchronized(self)
    {
        Tile *prev = NULL;
        for (Tile *t = qtail; t != qhead && cachesize > low; t = t->qnext) //qhead will not be freed but that's ok, will free next time
        {
            if (mapView->curtimestamp -  t->lastRenderTimestamp > 1 && (t->level > 0 || ![t layer]->on)) //not rendered for 1 sec
            {
                cachesize -= t->datasize;
                [t free];

                if (t == qtail)
                    qtail = t->qnext;
                else
                    prev->qnext = t->qnext;
            }
            else
                prev = t;
        }
        
        NSLog(@"tcache size = %u", (unsigned int)cachesize/1024/1024);
    }
}

@end
