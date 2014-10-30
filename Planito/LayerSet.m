//
//  LayerSet.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "LayerSet.h"

@implementation LayerSet

- (LayerSet*) initEmpty
{
	if (self=[super init])
    {
        layers = [[NSMutableArray alloc] init];
    }
	
	return self;
}

- (LayerSet*) initWithName: (NSString*) _name lid: _lid on: (BOOL) _on
{
	if (self=[super initWithName: _name lid: _lid on: _on opacity: 1])
    {
        layers = [[NSMutableArray alloc] init];
    }
		
	return self;
}

-(void) closeCache
{
    for (Layer *l in layers)
        [l closeCache];
}

-(void) dealloc
{
    [layers release];
    
    [super dealloc];
}

@end
