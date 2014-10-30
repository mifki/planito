//
//  Geocoder.h
//  Planito
//
//  Created by Vitaliy Pronkin on 21.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Geocoder : NSObject {

    NSString *_name;
    NSString *_Id;
    
@public
    BOOL on;
}

@property(nonatomic,retain) NSString* name;
@property(nonatomic,retain) NSString* Id;

-(Geocoder*) initWithParameters: (NSDictionary*) params;

-(void) geocodeString: (NSString*)str withDelegate: (id)delegate;

-(void) cancel;

@end
