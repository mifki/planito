//
//  GenericXMLGeocoder.m
//  Planito
//
//  Created by Vitaliy Pronkin on 11.1.12.
//  Copyright (c) 2012 mifki. All rights reserved.
//

#import "GenericXMLGeocoder.h"
#import "Downloader.h"
#import "GeocodingResult.h"
#import "Globals.h"

@implementation GenericXMLGeocoder

-(Geocoder*) initWithParameters: (NSDictionary*)params
{
    if (self = [super initWithParameters:params])
    {
        NSString *purl = [params objectForKey: @"URL"];
        NSString *presultspath = [params objectForKey: @"ResultsPath"];
        NSString *pnamepath = [params objectForKey: @"NamePath"];
        NSString *platpath = [params objectForKey: @"LatPath"];
        NSString *plonpath = [params objectForKey: @"LonPath"];
        
        if (!purl || !presultspath || !pnamepath || !platpath || !plonpath)
        {
            [self release];
            return nil;
        }
        
        do {
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\{D:([^}]+?)(?:\\|([^}]+))?\\}" options:0 error:NULL];
            NSTextCheckingResult *match = [re firstMatchInString:purl options:0 range:NSMakeRange(0, [purl length])];
            
            if (!match)
                break;
            
            NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:[purl substringWithRange:[match rangeAtIndex:1]]];
            if (!s)
            {
                NSRange r = [match rangeAtIndex:2];
                if (r.location != NSNotFound)
                    s = [purl substringWithRange:r];
                else
                    s = @"";
            }
            purl = [purl stringByReplacingCharactersInRange:[match range] withString:s];
        } while (1);
                
        urlFormat = [purl retain];
        resultsPath = [presultspath retain];
        namePath = [pnamepath retain];
        latPath = [platpath retain];
        lonPath = [plonpath retain];
    }
    
    return self;
}

-(void) geocodeString: (NSString*)str withDelegate: (id)delegate
{
    _delegate = [delegate retain];
    
    NSMutableString *url = [urlFormat mutableCopy];
    [url replaceOccurrencesOfString:@"{cx}" withString:[[NSNumber numberWithDouble: mapView->cx] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{cy}" withString:[[NSNumber numberWithDouble: mapView->cy] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{q}" withString:[str stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] options:0 range:NSMakeRange(0, [url length])];

    downloader = [[Downloader alloc] initWithURLString:url delegate:self];
    [url release];
}

-(void) cancel
{
    [downloader cancel];
    [downloader release];
    downloader = nil;
}

-(void) downloader: (Downloader*)dl didFinishWithData: (NSData*)data
{
    NSMutableArray *results = nil;
    
    if (data)
    {
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:0 error:NULL];
        if (doc)
        {
            NSArray *nodes = [doc nodesForXPath:resultsPath error:NULL];
            results = [NSMutableArray arrayWithCapacity:[nodes count]];
            
            for (NSXMLNode *node in nodes)
            {
                NSString *name = [[[node objectsForXQuery:namePath error:NULL] lastObject] stringValue];
                NSString *lat = [[[node objectsForXQuery:latPath error:NULL] lastObject] stringValue];
                NSString *lon = [[[node objectsForXQuery:lonPath error:NULL] lastObject] stringValue];

                if (name && lat && lon)
                {
                    GeocodingResult *gr = [GeocodingResult new];
                    gr.displayName = name;
                    gr.lat = [lat doubleValue];
                    gr.lon = [lon doubleValue];
                    [results addObject:gr];
                    [gr release];
                }
            }
                        
            [doc release];
        }
    }
    
    [downloader release];
    downloader = nil;
    
    if (results)
    {
        if ([_delegate respondsToSelector: @selector(geocoder:didFinishWithResults:)])
            [_delegate geocoder: self didFinishWithResults: results];
    }
    else
    {
        if ([_delegate respondsToSelector: @selector(geocoderDidFail:)])
            [_delegate geocoderDidFail: self];
    }
    
    [_delegate release];
}

-(void) downloader: (Downloader*)dl didFailWithStatus: (int)status
{
    [downloader release];
    downloader = nil;
    
    if ([_delegate respondsToSelector: @selector(geocoderDidFail:)])
        [_delegate geocoderDidFail: self];
    
    [_delegate release];
}

-(void) dealloc
{
    [self cancel];
    
    [urlFormat release];
    [resultsPath release];
    [namePath release];
    [latPath release];
    [lonPath release];
        
    [super dealloc];
}
@end
