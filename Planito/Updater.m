//
//  Updater.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 mifki. All rights reserved.
//

#import "Updater.h"
#import "Globals.h"
#import "MapLayer.h"

NSRunLoop *updrunloop;

@implementation Updater
NSTimer *t;
-(void) runLoop
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    [[NSThread currentThread] setName:@"Updater"];
    
    updrunloop = [NSRunLoop currentRunLoop];
	
    stopsignal = NO;
    running = YES;

	//[NSThread setThreadPriority: 0.4];
	//NSLog(@"updater started %f", [NSThread threadPriority]);
    
    //t = [NSTimer scheduledTimerWithTimeInterval:0.02 target:self selector:@selector(kk) userInfo:nil repeats:YES];
    
	while(!stopsignal)
	{
        NSAutoreleasePool *pool2 = [NSAutoreleasePool new];
        
        mapView->curtimestamp = [NSDate timeIntervalSinceReferenceDate];
        
        for (int i = 0; i < mapView->lcnt; i++)
            [mapView->layers[i] update];
        
        if (cacheManager->cachesize > cacheManager->high && !(mapView->zoom || mapView->move))
            [cacheManager cleanup];

        //[self kk];      
        //[updrunloop runUntilDate:[[NSDate date] dateByAddingTimeInterval:0.02]];
        //[updrunloop run];
       // [updrunloop runUntilDate:[NSDate distantP]];
        //if (![updrunloop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantPast]])
//        [updrunloop acceptInputForMode:NSDefaultRunLoopMode beforeDate:[NSDate distantPast]];
            usleep(40000); //TODO: sleep less if processing took much time ?
        //[updrunloop run];
        //NSLog(@"!");
        [pool2 release];		
	}
	
	[pool release];
    running = NO;
}

-(void) kk
{
    //return;
    if (stopsignal)
    {
        [t invalidate];
        return;
    }
    //NSAutoreleasePool *pool2 = [NSAutoreleasePool new];
    
    mapView->curtimestamp = [NSDate timeIntervalSinceReferenceDate];
    
    //for (int i = 0; i < mapView->lcnt; i++)
    //    [mapView->layers[i] update];
    
    [layer update];
    
    //if (cacheManager->cachesize > cacheManager->high && !(mapView->zoom || mapView->move))
    //    [cacheManager cleanup];

    //[pool2 release];
}

@end
