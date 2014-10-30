//
//  TileProvider.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Tile;

@protocol TileProvider <NSObject>

- (id<TileProvider>) initWithParameters: (NSDictionary*) params;

-(BOOL) canProvide;
-(void) provideAsync: (Tile*)t;
-(void) provideSync: (Tile*)t;

@end
