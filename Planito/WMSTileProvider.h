//
//  WMSTileProvider.h
//  Planito
//
//  Created by Vitaliy Pronkin on 10.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "BasicTileProvider.h"

@interface WMSTileProvider : BasicTileProvider {
    NSString* _layers;
    NSString* _styles;
    NSString* _format;
    NSString* _version;
    NSString* _parameters;
}

@property(nonatomic,retain) NSString* layers;
@property(nonatomic,retain) NSString* styles;
@property(nonatomic,retain) NSString* format;
@property(nonatomic,retain) NSString* version;
@property(nonatomic,retain) NSString* parameters;

@end
