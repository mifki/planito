//
//  GenericXMLReverseGeocoder.m
//  Planito
//
//  Created by Vitaliy Pronkin on 14.1.12.
//  Copyright (c) 2012 mifki. All rights reserved.
//

#import "GenericXMLReverseGeocoder.h"
#import "Downloader.h"

@implementation GenericXMLReverseGeocoder

-(id<ReverseGeocoder>) initWithParameters: (NSDictionary*)params
{
    if (self=[super init])
    {
        NSString *purl = [params objectForKey: @"URL"];
        NSString *paddresspath = [params objectForKey: @"AddressPath"];
        
        if (!purl || !paddresspath)
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
        addressPath = [paddresspath retain];
    }
    
    return self;
}

-(void) reverseGeocodeLat: (double)lat lon: (double)lon level: (int)level withDelegate: (id)delegate
{
    _delegate = [delegate retain];
    
    NSMutableString *url = [urlFormat mutableCopy];
    [url replaceOccurrencesOfString:@"{x}" withString:[[NSNumber numberWithDouble: lon] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{y}" withString:[[NSNumber numberWithDouble: lat] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{z}" withString:[[NSNumber numberWithInt: level] stringValue] options:0 range:NSMakeRange(0, [url length])];
   
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
    NSString *address = nil;
    
    if (data)
    {
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:data options:0 error:NULL];
        if (doc)
        {
            NSString *addr = [[[doc objectsForXQuery:addressPath error:NULL] lastObject] stringValue];
            if ([addr length])
                address = addr;
            [doc release];
        }
    }
    
    [downloader release];
    downloader = nil;
    
    if (address)
    {
        if ([_delegate respondsToSelector: @selector(reverseGeocoder:didFinishWithAddress:)])
            [_delegate reverseGeocoder: self didFinishWithAddress: address];
    }
    else
    {
        if ([_delegate respondsToSelector: @selector(reverseGeocoderDidFail:)])
            [_delegate reverseGeocoderDidFail: self];
    }
    
    [_delegate release];
}

-(void) downloader: (Downloader*)dl didFailWithStatus: (int)status
{
    [downloader release];
    downloader = nil;
    
    if ([_delegate respondsToSelector: @selector(reverseGeocoderDidFail:)])
        [_delegate reverseGeocoderDidFail: self];
    
    [_delegate release];
}

-(void) dealloc
{
    [self cancel];

    [urlFormat release];
    [addressPath release];
    
    [super dealloc];
}

@end
