//
//  Layer.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Layer.h"
#import "LayerSet.h"

@implementation Layer
@synthesize name, lid;

-(Layer*) initWithName: (NSString*) _name lid: (NSString*)_lid on: (BOOL) _on opacity: (float) _opacity
{
	if(self=[super init])
    {
        self.name = _name;
        self.lid = _lid;
        
        on = _on;
        opacity = _opacity;
    }
    
	return self;
}

-(NSString*) fullName
{
    if (!parent)
        return name;
    
    NSMutableArray *a = [NSMutableArray array];
    
    for (Layer *l = self; l != nil; l = l->parent)
    {
        if ([l isKindOfClass:[LayerSet class]] && ((LayerSet*)l)->isGroup)
            break;
        
        [a insertObject:l->name atIndex:0];
    }
    
    return [a componentsJoinedByString:@" - "];
}

-(void) dealloc
{
    [name release];
    [lid release];
    
    [super dealloc];
}

@end
