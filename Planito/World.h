//
//  World.h
//  Planito
//
//  Created by Vitaliy Pronkin on 30.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ReverseGeocoder.h"

#define MAX_CREDITS_LEN 1000

@class LayerSet;

@interface World : NSObject {
    NSString *_name;
    NSString *_displayName;
    NSString *_configXML;
    NSString *_datasourceURL;

@public
    LayerSet *rootLayer;
    
    NSMutableArray *geocoders;
    id<ReverseGeocoder> reverseGeocoder;

    unichar credits[MAX_CREDITS_LEN];
    int creditslen;
    
    double eqRadius, polarRadius;
    
    NSMutableDictionary *schema;
    
    NSMutableDictionary *extViewers;
}

@property(nonatomic,retain) NSString* name;
@property(nonatomic,retain) NSString* displayName;
@property(nonatomic,retain) NSString* configXML;
@property(nonatomic,retain) NSString* datasourceURL;

-(void) updateCredits;

-(void) load;
-(void) unload;

@end
