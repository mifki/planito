//
//  Layer.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//


@interface Layer : NSObject {
@public
    NSString *name, *lid;

	float opacity;
	BOOL on;
	int priority;    
    
    Layer *parent;
}

@property(nonatomic,retain) NSString *name;
@property(nonatomic,retain) NSString *lid;

-(Layer*) initWithName: (NSString*) _name lid: (NSString*)_lid on: (BOOL) _on opacity: (float) _opacity;

-(NSString*) fullName;

@end
