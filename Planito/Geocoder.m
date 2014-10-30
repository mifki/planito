//
//  Geocoder.m
//  Planito
//
//  Created by Vitaliy Pronkin on 11.1.12.
//  Copyright (c) 2012 mifki. All rights reserved.
//

#import "Geocoder.h"
#import "GeocodingResult.h"

@implementation Geocoder
@synthesize name=_name, Id=_Id;

-(Geocoder*) initWithParameters: (NSDictionary*)params
{
    if (self = [super init])
    {
        NSString *pname = [params objectForKey: @"Name"];
        NSString *pid = [params objectForKey: @"Id"];
        
        if (!pname)
        {
            [self release];
            return nil;
        }

        if (![pid length])
            pid = [@"__G__" stringByAppendingString:pname];
                
        self.name = pname;
        self.Id = pid;
    }
    
    return self;
}

-(void) dealloc
{
    [_name release];
    [_Id release];
    
    [super dealloc];
}

@end;