//
//  GenericXMLReverseGeocoder.h
//  Planito
//
//  Created by Vitaliy Pronkin on 14.1.12.
//  Copyright (c) 2012 mifki. All rights reserved.
//

#import "ReverseGeocoder.h"

@class Downloader;

@interface GenericXMLReverseGeocoder : NSObject<ReverseGeocoder> {
    Downloader *downloader;
    
    id _delegate;
    
    NSString *urlFormat;
    NSString *addressPath;
}

-(id<ReverseGeocoder>) initWithParameters: (NSDictionary*)params;
-(void) reverseGeocodeLat: (double)lat lon: (double)lon level: (int)level withDelegate: (id)delegate;

@end
