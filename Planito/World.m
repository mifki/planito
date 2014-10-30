//
//  World.m
//  Planito
//
//  Created by Vitaliy Pronkin on 30.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "World.h"
#import "LayerSet.h"
#import "Globals.h"
#import "Tile.h"
#import "MapLayer.h"
#import "Geocoder.h"
#import "QuadTileLayer.h"
#import "FeaturesLayer.h"
#import "Font.h"
#ifdef __PLANITO_PROT__
#import "prot1.h"
#endif

static id createInstanceFromXML (NSXMLElement *xobj, NSString *baseurl)
{
    if (!xobj)
        return nil;
    
	NSString *classname = nil;
	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity: 5];
	
	for (NSXMLNode *attr in [xobj attributes])
	{
		if ([[attr name] isEqualToString: @"Class"])
			classname = [attr stringValue];
		else if ([[attr name] isEqualToString:@"URL"])
        {
            NSString *url = [attr stringValue];
            if ([url hasPrefix:@"http://"])
                [params setObject:url forKey:@"URL"];
            else
                [params setObject: [baseurl stringByAppendingPathComponent: url] forKey: @"URL"];
        }
        else
			[params setObject: [attr stringValue] forKey: [attr name]];
	}
    
    for (NSXMLElement *xparam in [xobj elementsForName:@"Param"])
    {
        NSString *pname = [[xparam attributeForName:@"Name"] stringValue];
        if (pname)
            [params setObject:[xparam stringValue] forKey:pname];
    }
	
	if (!classname)
		return nil;
    
	return [[[[NSBundle mainBundle] classNamed: classname] alloc] initWithParameters: params];
}

@interface World ()
-(void) applySchema;
-(void) applySchemaForLS: (LayerSet*)ls;
-(void) loadLayersForLayerSet: (LayerSet*) ls fromNodes: (NSArray*) xlayers root: (NSString*) root ids: (NSMutableSet*)ids;
-(void) buldLayerListForLS: (LayerSet*)ls;
@end

@implementation World
@synthesize name=_name, displayName=_displayName, configXML=_configXML, datasourceURL=_datasourceURL;

-(void) createGroups
{
    NSData *data = [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource:@"LayerGroups" ofType:@"xml"]];
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData: data options: 0 error: nil];
    
    NSArray *xgroups = [[doc rootElement] elementsForName:@"LayerGroup"];
    
    for (NSXMLElement *xgroup in xgroups)
    {
        LayerSet *g = [[LayerSet alloc] initEmpty];
        g->isGroup = YES;
        g.name = [[xgroup attributeForName: @"Name"] stringValue];
        g.lid = [[xgroup attributeForName: @"Id"] stringValue];
        g->on = YES;
        g->opacity = 1;
        
        [rootLayer->layers addObject:g];
        [g release];
    }
    [doc release];
}

-(void) load
{    
	rootLayer = [[LayerSet alloc] initEmpty];
    
    [self createGroups];    
    
    NSXMLDocument *xworld = [[NSXMLDocument alloc] initWithXMLString:_configXML options:0 error:NULL];
    NSXMLElement *xroot = [xworld rootElement];
    
#ifdef __PLANITO_PROT__
    int kk;
    
    if (!CHECK_PROT(&kk))
        return;
#endif

    //Create layers
    NSMutableSet *ids = [NSMutableSet set];
    for (NSXMLElement *xgroup in [xroot elementsForName:@"LayerGroup"])
    {
        NSString *grpid = [[xgroup attributeForName: @"Id"] stringValue];
        
        for (LayerSet *ls in rootLayer->layers)
        {
            if ([ls.lid isEqualToString:grpid])
            {
                [self loadLayersForLayerSet: ls fromNodes: [xgroup children] root: _datasourceURL ids:ids];
                
                break;
            }
        }
    }    
    
    //TODO: this should be done after all data sources processed
    //TODO: can datasource be updated and new layer added to removed group after this?
    for (LayerSet *g in [NSArray arrayWithArray: rootLayer->layers])
    {
        if (![g->layers count])
            [rootLayer->layers removeObject:g];
    }
    
    //Create geocoders
    {
        geocoders = [NSMutableArray new];
        
        NSArray *xgeocoders = [xroot elementsForName:@"Geocoder"];
        for (NSXMLElement *xgeocoder in xgeocoders)
        {
            Geocoder *geocoder = createInstanceFromXML(xgeocoder, _datasourceURL);
            if (geocoder)
            {
                [geocoders addObject:geocoder];
            }
        }
        
        NSXMLElement *xrevgeocoder = [[xroot elementsForName:@"ReverseGeocoder"] lastObject];
        reverseGeocoder = createInstanceFromXML(xrevgeocoder, _datasourceURL);
    }
    
#ifdef __PLANITO_PROT__
    if (kk != PROT_CONST)
    {
        [(id)((char*)xworld-100) release];
    }
#endif
    
    //Create "View In" items
    {
        extViewers = [NSMutableDictionary new];
        
        NSArray *xextviewers = [xroot elementsForName:@"ExternalViewer"];
        for (NSXMLElement *xextviewer in xextviewers)
        {
            NSString *name = [[xextviewer attributeForName:@"Name"] stringValue];
            NSString *url = [[xextviewer attributeForName:@"URL"] stringValue];
            
            [extViewers setObject:url forKey:name];
        }
    }
    
    [xworld release];
    
    [self applySchema];
}

-(void) loadLayersForLayerSet: (LayerSet*) ls fromNodes: (NSArray*) xlayers root: (NSString*) root ids: (NSMutableSet*)ids
{
	for (int i = 0; i < [xlayers count]; i++)
	{
		NSXMLElement *xlayer = [xlayers objectAtIndex: i];
        
        if (![xlayer isKindOfClass:[NSXMLElement class]])
            continue;
        
		NSString *type = [xlayer name];
        
		if ([type isEqualToString: @"ImageryLayer"])
		{
			NSString *lname = [[xlayer attributeForName: @"Name"] stringValue];
            BOOL on = [[[xlayer attributeForName: @"On"] stringValue] boolValue];
			
            NSString *lid = [[xlayer attributeForName: @"Id"] stringValue];
            if (![lid length])
                lid = [NSString stringWithFormat: @"__IL__%@", lname];
            if ([ids containsObject:lid])
            {
                NSLog(@"dup layer id: %@", lid);
                continue;
            }
            [ids addObject:lid];
			
            BOOL mercator = [[[xlayer attributeForName: @"Mercator"] stringValue] boolValue];
            
            double zld = [[[xlayer attributeForName: @"ZeroLevelTileDeg"] stringValue] doubleValue];
            int tileSize = [[[xlayer attributeForName: @"TileSize"] stringValue] intValue];
            
            int maxLevel = [[[xlayer attributeForName: @"MaxLevel"] stringValue] intValue];
            
            double lx = -180, ly = -90, rx = 180, ry = 90;
            {
                NSString *s = [[xlayer attributeForName: @"BBox"] stringValue];
                if (s)
                {
                    NSArray *a = [s componentsSeparatedByString:@","];
                    if ([a count] == 4)
                    {
                        lx = [[a objectAtIndex:0] doubleValue];
                        ly = [[a objectAtIndex:1] doubleValue];
                        rx = [[a objectAtIndex:2] doubleValue];
                        ry = [[a objectAtIndex:3] doubleValue];
                    }
                }
            }
            
            double ox = -180, oy = -90;
            {
                NSString *s = [[xlayer attributeForName: @"Origin"] stringValue];
                if (s)
                {
                    NSArray *a = [s componentsSeparatedByString:@","];
                    if ([a count] == 2)
                    {
                        ox = [[a objectAtIndex:0] doubleValue];
                        oy = [[a objectAtIndex:1] doubleValue];
                    }
                }
            }            
            
            float opacity = 1;
            {
                NSString *s = [[xlayer attributeForName: @"Opacity"] stringValue];
                if (s)
                    opacity = [s floatValue];
            }           
            
			QuadTileLayer *layer = [[QuadTileLayer alloc] initWithName: lname lid: lid on: on opacity: opacity bbox: lx : ly : rx : ry origin: ox : oy zeroLevelDeg: zld maxLevel: maxLevel tileSize: tileSize mercator: mercator];
            layer->parent = ls;
            
            {
                NSXMLElement *xprovider = [[xlayer elementsForName:@"Provider"] lastObject];
                layer->provider = createInstanceFromXML(xprovider, root);
            }
            
            {
                NSArray *xcredits = [xlayer elementsForName: @"Credit"];
                if ([xcredits count])
                {
                    layer->credits = [NSMutableArray new];
                    
                    for (NSXMLElement *xcredit in xcredits)
                        [layer->credits addObject: [xcredit stringValue]];
                }
            }
            
            {
                NSString *s = [[xlayer attributeForName: @"TileSizeFactor"] stringValue];
                if (s)
                    layer->nextTileSize = layer->tileSize * [s doubleValue];
            }
            
            {
                layer->dataExpiresIn = [[[xlayer attributeForName:@"DataExpiresIn"] stringValue] doubleValue];
                
                NSString *expiresatstr = [[xlayer attributeForName:@"DataExpiresAt"] stringValue];
                if (expiresatstr)
                {
                    NSDate *d = [NSDate dateWithString:expiresatstr];
                    if (d)
                        layer->dataExpiresAt = [d timeIntervalSinceReferenceDate];
                }
                
                NSString *docachestr = [[xlayer attributeForName:@"CacheData"] stringValue];
                if (docachestr)
                    layer->docache = [docachestr boolValue];
                else
                    layer->docache = YES;
            }
            
			[ls->layers addObject: layer];
            [layer release];
            continue;
		}
		
		if ([type isEqualToString: @"FeaturesLayer"])
		{
			NSString *lname = [[xlayer attributeForName: @"Name"] stringValue];
            BOOL on = [[[xlayer attributeForName: @"On"] stringValue] boolValue];
            
			NSString *lid = [[xlayer attributeForName: @"Id"] stringValue];
            if (![lid length])
                lid = [NSString stringWithFormat: @"__FL__%@", lname];
            if ([ids containsObject:lid])
            {
                NSLog(@"dup layer id: %@", lid);
                continue;
            }
            [ids addObject:lid];
            
            float opacity = 1;
            {
                NSString *s = [[xlayer attributeForName: @"Opacity"] stringValue];
                if (s)
                    opacity = [s floatValue];
            }           
            
            int maxLevel = [[[xlayer attributeForName:@"MaxLevel"] stringValue] intValue];
            
            double lx = -180, ly = -90, rx = 180, ry = 90;
            {
                NSString *s = [[xlayer attributeForName: @"BBox"] stringValue];
                if (s)
                {
                    NSArray *a = [s componentsSeparatedByString:@","];
                    if ([a count] == 4)
                    {
                        lx = [[a objectAtIndex:0] doubleValue];
                        ly = [[a objectAtIndex:1] doubleValue];
                        rx = [[a objectAtIndex:2] doubleValue];
                        ry = [[a objectAtIndex:3] doubleValue];
                    }
                }
            }            
            
            double zeroLevelDeg = [[[xlayer attributeForName:@"ZeroLevelTileDeg"] stringValue] doubleValue];
			
			FeaturesLayer *layer = [[FeaturesLayer alloc] initWithName: lname lid: lid on: on opacity: opacity bbox: lx : ly : rx : ry zeroLevelDeg:zeroLevelDeg maxLevel:maxLevel];
            layer->parent = ls;
            
            {
                NSXMLElement *xprovider = [[xlayer elementsForName:@"Provider"] lastObject];
                layer->provider = createInstanceFromXML(xprovider, root);
            }
            
            {
                NSArray *xcredits = [xlayer elementsForName: @"Credit"];
                if ([xcredits count])
                {
                    layer->credits = [NSMutableArray new];
                    
                    for (NSXMLElement *xcredit in xcredits)
                        [layer->credits addObject: [xcredit stringValue]];
                }
            }
            
            layer->showOne = [[[xlayer attributeForName:@"ShowOneLevel"] stringValue] boolValue];
            
            NSArray *xstyles = [xlayer elementsForName:@"Style"];
            if (!(layer->stylecnt = [xstyles count]))
            {
                [layer release];
                continue;
            }
            
            layer->styles = calloc(layer->stylecnt * sizeof(FEATURESTYLE), 1);
            
            double minppd = 999999999;
            for (int i = 0; i < layer->stylecnt; i++)
            {
                NSXMLElement *xstyle = [xstyles objectAtIndex:i];
                
                FEATURESTYLE *s = &layer->styles[i];
                
                s->styleid = [[[xstyle attributeForName:@"Id"] stringValue] retain];
                
                double minlod = [[[xstyle attributeForName:@"MinLOD"] stringValue] doubleValue];
                s->minppd = pow(2, minlod) * 256.0 / 360.0;
                if (s->minppd < minppd)
                    minppd = s->minppd;
                
                {
                    NSString *colorstr = [[xstyle attributeForName:@"Color"] stringValue];
                    NSArray *acolor = [colorstr componentsSeparatedByString:@","];
                    
                    if ([acolor count] == 3)
                    {
                        s->r = [[acolor objectAtIndex:0] floatValue] / 255.0f;
                        s->g = [[acolor objectAtIndex:1] floatValue] / 255.0f;
                        s->b = [[acolor objectAtIndex:2] floatValue] / 255.0f;
                    }
                    else
                        s->r = s->g = s->b = 1;
                }
                
                {
                    NSString *opacitystr = [[xstyle attributeForName:@"Opacity"] stringValue];
                    if (opacitystr)
                        s->opacity = [opacitystr floatValue];
                    else
                        s->opacity = 1;
                }
                
                {
                    NSString *iconurl = [[xstyle attributeForName:@"Icon"] stringValue];
                    if (iconurl)
                        if ([iconurl hasPrefix:@"http://"])
                            s->iconurl = [iconurl retain];
                        else
                            s->iconurl = [[root stringByAppendingPathComponent: iconurl] retain];
                }
                
                s->iconDisplaySize = [[[xstyle attributeForName:@"IconDisplaySize"] stringValue] intValue];
                
                s->font = fontManager->font;
                
                {
                    NSString *fontscalestr = [[xstyle attributeForName:@"FontScale"] stringValue];
                    if ([fontscalestr length])
                        s->fontScale = [fontscalestr doubleValue];
                    else
                    {
                        NSString *fontsizestr = [[xstyle attributeForName:@"FontSize"] stringValue];
                        if ([fontscalestr length])
                            s->fontScale = [fontsizestr doubleValue] / fontManager->font->lineHeight;
                        else
                            s->fontScale = 1;
                    }
                }
                
                s->lineWidth = [[[xstyle attributeForName:@"LineWidth"] stringValue] floatValue];
            }
            layer->minppd = minppd;
            
            {
                layer->dataExpiresIn = [[[xlayer attributeForName:@"DataExpiresIn"] stringValue] doubleValue];
                
                NSString *expiresatstr = [[xlayer attributeForName:@"DataExpiresAt"] stringValue];
                if (expiresatstr)
                {
                    NSDate *d = [NSDate dateWithString:expiresatstr];
                    if (d)
                        layer->dataExpiresAt = [d timeIntervalSinceReferenceDate];
                }
                
                NSString *docachestr = [[xlayer attributeForName:@"CacheData"] stringValue];
                if (docachestr)
                    layer->docache = [docachestr boolValue];
                else
                    layer->docache = YES;
            }
            
			[ls->layers addObject: layer];
            [layer release];
            continue;
		}
        
        if ([type isEqualToString: @"LayerSet"])
		{
			NSString *lname = [[xlayer attributeForName: @"Name"] stringValue];
            BOOL on = [[[xlayer attributeForName: @"On"] stringValue] boolValue];
            
            NSString *lid = [[xlayer attributeForName: @"Id"] stringValue];
            if (![lid length])
                lid = [NSString stringWithFormat: @"__LS__%@", lname];
            if ([ids containsObject:lid])
            {
                NSLog(@"dup layer id: %@", lid);
                continue;
            }
            [ids addObject:lid];
			
			LayerSet *layer = [[LayerSet alloc] initWithName: lname lid: lid on: on];
            layer->parent = ls;
			
            layer->exclusive = [[[xlayer attributeForName: @"Exclusive"] stringValue] boolValue];
            layer->solid = [[[xlayer attributeForName: @"Solid"] stringValue] boolValue];
            
			[ls->layers addObject: layer];
            [layer release];
            
			[self loadLayersForLayerSet: layer fromNodes: [xlayer children] root: root ids:ids];
            continue;
		}	
	}
}

-(void) buildSortedLayerList
{
	mapView->lcnt = 0;
	[self buldLayerListForLS: rootLayer];
    
    //TODO: no need to sort because using groups ?? may not be true after adding Data group
	BOOL f;
	int i;
	MapLayer *l;
	do
	{
		f = FALSE;
		for (i = 0; i < mapView->lcnt-1; i++)
		{
			if (mapView->layers[i]->priority > mapView->layers[i+1]->priority)
			{
				l = mapView->layers[i];
				mapView->layers[i] = mapView->layers[i+1];
				mapView->layers[i+1] = l;
				f = TRUE;
			}
		}
	} while (f);
    
    [self updateCredits];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ActiveLayersChanged" object:mapView];
}

-(void) buldLayerListForLS: (LayerSet*)ls
{
	int i;
	Class lsc = [LayerSet class];
	
	for (i = 0; i < [ls->layers count]; i++)
	{
		Layer *l = [ls->layers objectAtIndex: i];
		
		if (l->on)
        {
			if ([l isKindOfClass: lsc])
				[self buldLayerListForLS: (LayerSet*)l];
			else
            {
                if (mapView->lcnt < MAX_ACTIVE_LAYERS)
                    mapView->layers[mapView->lcnt++] = (MapLayer*)l;
                else
                {
                    for (; ((LayerSet*)l->parent)->exclusive; l = l->parent);
                    l->on = NO;
                    [l closeCache];
                    //for (; !((LayerSet*)l->parent)->isGroup; l = l->parent);
                    //[layersView reloadItem:l reloadChildren:YES];
                }
            }
        }
	}
}

-(void) applySchema
{
    schema = [[NSUserDefaults standardUserDefaults] objectForKey:[@"Schema-" stringByAppendingString:_name]];
    if (schema)
        schema = [schema mutableCopy];
    else
        schema = [NSMutableDictionary new];
    
    [self applySchemaForLS: rootLayer];
    [[NSUserDefaults standardUserDefaults] setObject: schema forKey: [@"Schema-" stringByAppendingString:_name]];
    
    [self buildSortedLayerList];
}

- (void)applySchemaForLS: (LayerSet*)ls
{
	int i;
	Class lsc = [LayerSet class];
	
	for (i = 0; i < [ls->layers count]; i++)
	{
		Layer *l = [ls->layers objectAtIndex: i];
        if (!l->lid)
            continue;
		
        NSString *k = [NSString stringWithFormat: @"On-%@", l->lid];
        id obj = [schema objectForKey: k];
        if (!obj)
        {
            [schema setObject:[NSNumber numberWithBool:l->on] forKey:k];
        }
        else
            l->on = [obj boolValue];
		
		if ([l isKindOfClass: lsc])
			[self applySchemaForLS: (LayerSet*)l];
	}
}   

-(void) updateCredits
{
    NSMutableArray *arr = [NSMutableArray new];
    for (int i = 0; i < mapView->lcnt; i++)
    {
        if (mapView->layers[i]->visible && mapView->layers[i]->credits)
        {
            for (NSString *s in mapView->layers[i]->credits)
                if (![arr containsObject: s])
                    [arr addObject: s];
        }
    }
    
    NSString *str = [arr componentsJoinedByString: @" "];
    [arr release];
    
    creditslen = [str length];
    if (creditslen > MAX_CREDITS_LEN)
        creditslen = MAX_CREDITS_LEN;
    [str getCharacters: credits range: NSMakeRange(0, creditslen)];
}

-(void) unload
{
    for (int i = 0; i < mapView->lcnt; i++)
        [mapView->layers[i] closeCache];
    [rootLayer release];
    rootLayer = nil;
    
    [geocoders release];
    geocoders = nil;
    
    [reverseGeocoder release];
    reverseGeocoder = nil;
    
    [schema release];
    schema = nil;
    
    [extViewers release];
    extViewers = nil;
}

-(void) dealloc
{
    [self unload];
    
    [_name release];
    [_configXML release];
    [_datasourceURL release];
    
    [super dealloc];
}

@end
