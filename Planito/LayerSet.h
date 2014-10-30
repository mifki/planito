//
//  LayerSet.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Layer.h"

@interface LayerSet : Layer {
	@public
	NSMutableArray *layers;
    
    BOOL isGroup;
    BOOL exclusive;
    BOOL solid;
}

- (LayerSet*) initEmpty;
- (LayerSet*) initWithName: (NSString*) _name lid: (NSString*) _lid on: (BOOL) _on;

@end
