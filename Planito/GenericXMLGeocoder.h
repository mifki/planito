//
//  GenericXMLGeocoder.h
//  Planito
//
//  Created by Vitaliy Pronkin on 11.1.12.
//  Copyright (c) 2012 mifki. All rights reserved.
//

#import "Geocoder.h"

@class Downloader;

@interface GenericXMLGeocoder : Geocoder {
    Downloader *downloader;
    
    id _delegate;
        
    NSString *urlFormat;
    NSString *resultsPath, *namePath, *latPath, *lonPath;
}

@end