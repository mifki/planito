//
//  XmlXslPmTileProvider.m
//  Planito
//
//  Created by Vitaliy Pronkin on 1.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "XMLPlacemarksTileProvider.h"
#import "Globals.h"
#import "Tile.h"

@implementation XMLPlacemarksTileProvider

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
    if (xsl && data)
    {
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData: data options: 0 error: NULL];
        id obj = [doc objectByApplyingXSLTString: xsl arguments: nil error:NULL];
        [doc release];

        if ([obj isKindOfClass: [NSXMLDocument class]])
        {
            //TODO: dirty workaround to reprocess CDATA sections
            [t gotDataFromProvider: [obj XMLData] canRetry: NO];
        }
        else
            [t gotDataFromProvider: nil canRetry: NO];
    }
    else
        [t gotDataFromProvider: data canRetry: NO];
}

@end
