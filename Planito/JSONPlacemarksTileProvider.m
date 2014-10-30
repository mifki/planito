//
//  JSONPlacemarksTileProvider.m
//  Planito
//
//  Created by Vitaliy Pronkin on 13.12.11.
//  Copyright (c) 2011 mifki. All rights reserved.
//

#import "JSONPlacemarksTileProvider.h"
#import "Globals.h"
#import "Tile.h"

@interface JSONPlacemarksTileProvider ()
    -(void) _appendObject: (id)obj toElement: (NSXMLElement*)root;
@end

@implementation JSONPlacemarksTileProvider

- (id) initWithParameters: (NSDictionary*) params
{
    if (self = [super initWithParameters: params])
    {
        NSString *builtinxsl = [params objectForKey: @"BuiltinTransformation"];
        if (builtinxsl)
            xsl = [[NSString alloc] initWithContentsOfFile: [[NSBundle mainBundle] pathForResource: builtinxsl ofType: @"xsl"] encoding: NSUTF8StringEncoding error:NULL];
        else
            xsl = [[params objectForKey: @"Transformation"] retain];
    }
    
	return self;
}

- (void)gotRemoteData: (NSData*)data forTile: (Tile*)t
{
    if (data)
    {
        id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        
        NSXMLElement *root = [NSXMLElement elementWithName:@"root"];
        [self _appendObject: obj toElement:root];
        NSXMLDocument *doc = [NSXMLDocument documentWithRootElement:root];

        if (xsl)
        {
            id obj = [doc objectByApplyingXSLTString: xsl arguments: nil error:NULL];

            if ([obj isKindOfClass: [NSXMLDocument class]])
            {
                //TODO: dirty workaround to reprocess CDATA sections
                [t gotDataFromProvider: [obj XMLData] canRetry: NO];
            }
            else
                [t gotDataFromProvider: nil canRetry: NO];
            
        }
        else
            [t gotDataFromProvider: doc canRetry: NO];
    }
    else
        [t gotDataFromProvider: nil canRetry: NO];
}

-(void) _appendObject: (id)obj toElement: (NSXMLElement*)root
{
    if ([obj isKindOfClass:[NSDictionary class]])
    {
        for (NSString *key in obj)
        {
            id val = [obj objectForKey:key];
            NSXMLElement *el = [NSXMLElement elementWithName:key];
            [self _appendObject:val toElement:el];
            [root addChild:el];
        }
    }
    else if ([obj isKindOfClass:[NSArray class]])
    {
        for (NSString *item in obj)
        {
            NSXMLElement *el = [NSXMLElement elementWithName:@"item"];
            [self _appendObject:item toElement:el];
            [root addChild:el];
        }
    }
    else
        [root addChild:[NSXMLNode textWithStringValue:[obj description]]];
}


@end
