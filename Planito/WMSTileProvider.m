//
//  WMSTileProvider.m
//  Planito
//
//  Created by Vitaliy Pronkin on 10.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "WMSTileProvider.h"
#import "QuadTile.h"
#import "QuadTileLayer.h"

@implementation WMSTileProvider
@synthesize layers=_layers, styles=_styles, format=_format, version=_version, parameters=_parameters;

- (id) initWithParameters: (NSDictionary*) params
{
    if (self = [super initWithParameters: params])
    {
        self.layers = [params objectForKey: @"Layers"];
        self.styles = [params objectForKey: @"Styles"];
        if (!_styles)
            self.styles = @"";
        self.format = [params objectForKey: @"Format"];
        self.version = [params objectForKey: @"Version"];
        if (!_version)
            self.version = @"1.3";
        self.parameters = [params objectForKey: @"Other"];    
        if (!_parameters)
            self.parameters = @"";
    }
    
	return self;
}

-(NSString*) buildURLForTile: (Tile*)t
{
    int s = ((QuadTileLayer*)[t layer])->tileSize;
    
    return [NSString stringWithFormat:@"%@?service=WMS&request=GetMap&version=%@&layers=%@&format=%@&styles=%@&width=%d&height=%d&bbox=%f,%f,%f,%f&%@",
            _urlFormat, _version, _layers, _format, _styles, s, s, t->lx, t->ly, t->rx, t->ry, _parameters];
}

-(void) dealloc
{
    [_layers release];
    [_styles release];
    [_format release];
    [_version release];
    [_parameters release];
    
    [super dealloc];
}

@end
