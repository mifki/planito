//
//  ReverseGeocoder.h
//  Planito
//
//  Created by Vitaliy Pronkin on 22.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ReverseGeocoder <NSObject>

-(id<ReverseGeocoder>) initWithParameters: (NSDictionary*)params;

-(void) reverseGeocodeLat: (double)lat lon: (double)lon level: (int)level withDelegate: (id)delegate;

-(void) cancel;

@end
