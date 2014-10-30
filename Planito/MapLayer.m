//
//  MapLayer.m
//  Planito
//
//  Created by Vitaliy Pronkin on 11.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "MapLayer.h"
#import "Helpers.h"
#import "Globals.h"

#import "Updater.h"

@implementation MapLayer

-(void) openCache
{
    if (on && !cachedb2 && docache)
    {
        cachedb2 = tchdbnew();
        tchdbsetmutex(cachedb2);
        
        [[NSFileManager defaultManager] createDirectoryAtPath:DATA_PATH(lid,"") withIntermediateDirectories:YES attributes:nil error:NULL];
        
        bool res = tchdbopen(cachedb2, [DATA_PATH(lid, "tilecache.tch") fileSystemRepresentation], HDBOWRITER|HDBOCREAT|HDBOTSYNC|HDBTLARGE); //HDBONOLCK
        
        //TODO: don't just recreate cache here. attempt to repair, notify user, do something
        if (!res)
        {
            NSLog(@"recreating corrupted cache db: %@", DATA_PATH(lid, "tilecache.tch"));
            [[NSFileManager defaultManager] removeItemAtPath:DATA_PATH(lid, "tilecache.tch") error:NULL];
            tchdbopen(cachedb2, [DATA_PATH(lid, "tilecache.tch") fileSystemRepresentation], HDBOWRITER|HDBOCREAT|HDBOTSYNC|HDBTLARGE); //HDBONOLCK
        }
    }    
}

-(void) closeCache
{
    if (cachedb2)
    {
        TCHDB *_cachedb = cachedb2;
        cachedb2 = NULL;
        
        tchdbclose(_cachedb);
        tchdbdel(_cachedb);
    }
}

-(void) dealloc
{
    [provider release];
    [credits release];
    
    [super dealloc];
}

@end
