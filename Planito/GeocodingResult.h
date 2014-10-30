//
//  GeocodingResult.h
//  Planito
//
//  Created by Vitaliy Pronkin on 29.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GeocodingResult : NSObject {
    NSString *_displayName;
    double _lat, _lon;
}

@property(nonatomic,retain) NSString* displayName;
@property(nonatomic) double lat;
@property(nonatomic) double lon;

@end
