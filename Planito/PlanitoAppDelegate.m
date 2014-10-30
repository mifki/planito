//
//  PlanitoAppDelegate.m
//  Planito
//
//  Created by Vitaliy Pronkin on 30.7.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "PlanitoAppDelegate.h"
#import "Globals.h"
#import "Updater.h"
#import "FontManager.h"
#import "Helpers.h"
#import "Downloader.h"
#import "World.h"
#import "BookmarkManager.h"
#import "PreferencesPanelController.h"
#import "PlanitoWindowController.h"

CacheManager *cacheManager;
FontManager *fontManager;

World *world;

BOOL workOffline;
BOOL autorefresh;
extern BOOL useMultitouch;
extern BOOL fixDistortion;
extern NSString *urlToOpen;

@interface PlanitoAppDelegate ()
-(void) updateMainDataSource;
-(void) loadMainDataSource: (NSData*)newdata;
-(void) stop;
@end

@implementation PlanitoAppDelegate

+(void) initialize
{
    [[NSUserDefaults standardUserDefaults] registerDefaults: [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    [loadingProgress startAnimation:nil];
    	
	[NSColor setIgnoresAlpha: FALSE];
	
	cacheManager = [[CacheManager alloc] init];
	fontManager = [[FontManager alloc] init];
    updater = [Updater new];
    
    worlds = [NSMutableArray new];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"UseMultitouch" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"Autorefresh" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
        
    //Migrate
    /*
    {
        NSString *p = [@"~/Library/Containers/com.mifki.Planito" stringByExpandingTildeInPath];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:p])
        {
            NSLog(@"migrating...");

            //App Support
            NSString *p2 = [p stringByAppendingPathComponent:@"Data/Library/Application Support/Planito"];
            [fm copyItemAtPath:[p2 stringByAppendingPathComponent:@"Favorites-Earth.plist"] toPath:[APPSUPP_PATH() stringByAppendingPathComponent:@"Favorites-Earth.plist"] error:NULL];
            [fm copyItemAtPath:[p2 stringByAppendingPathComponent:@"Favorites-Moon.plist"] toPath:[APPSUPP_PATH() stringByAppendingPathComponent:@"Favorites-Moon.plist"] error:NULL];
            [fm copyItemAtPath:[p2 stringByAppendingPathComponent:@"Favorites-Mars.plist"] toPath:[APPSUPP_PATH() stringByAppendingPathComponent:@"Favorites-Mars.plist"] error:NULL];
            
            //Caches
            //NSString *p3 = [p stringByAppendingPathComponent:@"Data/Library/Caches/com.mifki.Planito"];
            
            [fm removeItemAtPath:p error:NULL];
        }
    }
    */
        
	[self updateMainDataSource];
}

-(void) applicationWillTerminate:(NSNotification *)notification
{
    [mapView savePosition];
    [mapView unregister3DMouse];
    
    [[NSUserDefaults standardUserDefaults] synchronize];        

    if (mapView)
    {
    //Stop render and updater threads
    [self stop];
    
    //Close cache databases
    for (int i = 0; i < mapView->lcnt; i++)
        [mapView->layers[i] closeCache];
    }
}

static Downloader *dldr;
static int dsdlstep;
-(void) downloadMainDataSource
{
    //NSString *datasourceURL = [NSString stringWithFormat: @"%@/_datasource_dev.xml", [[NSBundle mainBundle] objectForInfoDictionaryKey: @"DataSource"]];
    //dl = [[Downloader alloc] initWithURLString:datasourceURL delegate:self];
    
    NSString *datasourceURL = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"DataSource"];
    
#ifdef __PLANITO_DEMO__
    char a[4];
    a[1] = 4;
    a[0] = 12;
    a[2] = 3;
    a[3] = 14;
    for (int i = 0; i < 4; i++)
        a[i]+='a';
    if ([datasourceURL rangeOfString:[NSString stringWithFormat:@"%c%c%c%c", a[2],a[1],a[0],a[3]]].location == NSNotFound)
    {
        exit(0);
        [datasourceURL release];
    }
#endif
    
    NSString *lang = [[NSLocale preferredLanguages] objectAtIndex:0];
    NSString *country = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
    
    switch (dsdlstep)
    {
        case 0:
            datasourceURL = [datasourceURL stringByReplacingOccurrencesOfString:@"{LANG}" withString:[NSString stringWithFormat:@"%@_%@", lang, country]];
            break;
        case 1:
            datasourceURL = [datasourceURL stringByReplacingOccurrencesOfString:@"{LANG}" withString:lang];
            break;
        case 2:
            datasourceURL = [datasourceURL stringByReplacingOccurrencesOfString:@"{LANG}" withString:@"def"];
            break;
    }

    dldr = [[Downloader alloc] initWithURLString:datasourceURL delegate:self];
}

-(void) downloader: (Downloader*)dl didFinishWithData: (NSData*)data
{
    if (check_GZ_header(data))
        data = decompress_GZ(data);
    
    [self loadMainDataSource: data];
    
    [dl release];
    dl = nil;
}

-(void) downloader: (Downloader*)dl didFailWithStatus: (int)status
{
    [dl release];
    dl = nil;

    if ((status == 404 || status == 403) && dsdlstep < 2)
    {
        dsdlstep++;
        [self downloadMainDataSource];
    }
    else
        [self loadMainDataSource: nil];
}

-(void) updateMainDataSource
{
    [cancelLoadingButton setEnabled:YES];

    dsdlstep = 0;
    [self downloadMainDataSource];
}

-(IBAction) cancelUpdateDataSources: (id)sender
{
	[dldr cancel];
    [dldr release];
    dldr = nil;
	
	[self loadMainDataSource: nil];
}

-(void) loadMainDataSource: (NSData*)newdata
{
    [cancelLoadingButton setEnabled:NO];
    
    NSError *err = nil;
           
    NSXMLDocument *xds = nil;
    if (newdata && (xds = [[NSXMLDocument alloc] initWithData: newdata options: 0 error: &err]))
    {
        if ([[[xds rootElement] name] isEqualToString:@"DataSource"])
        {
            int reqver = [[[[xds rootElement] attributeForName:@"RequiredAppVersion"] stringValue] intValue];
            int appver = [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] intValue];
            
            if (appver >= reqver)
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:CACHE_PATH() withIntermediateDirectories:YES attributes:nil error:NULL];
                [newdata writeToFile:[CACHE_PATH() stringByAppendingPathComponent: @"_datasource.xml"] atomically:YES];        
            }
            else
            {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText: NSLocalizedString(@"update-required", @"")];
                [alert setInformativeText: NSLocalizedString(@"update-required-full", @"")];
                [alert addButtonWithTitle: @"OK"];
                [alert runModal];      
                [alert release];
                
                [xds release];
                xds = nil;
            }
        }
        else
        {
            [xds release];
            xds = nil;
        }
    } else if (err)
        NSLog(@"%@", err);
    

    if (!xds)
    {
        NSData *data = [NSData dataWithContentsOfFile: [CACHE_PATH() stringByAppendingPathComponent: @"_datasource.xml"]];
        if (data)
        {
            err = nil;
            xds = [[NSXMLDocument alloc] initWithData: data options: 0 error: &err];
        }

        if (!xds)
        {
            if (err)
                NSLog(@"%@", err);
            
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText: NSLocalizedString(@"main-ds-unavailable", @"")];
            [alert setInformativeText: NSLocalizedString(@"main-ds-unavailable-full", @"")];
            [alert addButtonWithTitle: @"Retry"];
            [alert addButtonWithTitle: @"Exit"];
            [[[alert buttons] objectAtIndex:1] setKeyEquivalent:@"\E"];
            
            if ([alert runModal] == NSAlertFirstButtonReturn)
                [self updateMainDataSource];
            else
                [NSApp terminate: nil];
            return;
        }
    }

    for (NSXMLElement *xworld in [[xds rootElement] elementsForName:@"World"])
    {
        NSString *wname = [[xworld attributeForName: @"Name"] stringValue];
        
        World *w = nil;
        for (World *_w in worlds)
        {
            if ([_w.name isEqualToString:wname])
            {
                w = _w;
                break;
            }
        }
        
        if (!w)
        {
            w = [[World alloc] init];
            w.name = wname;
            
            NSString *wdispname = [[xworld attributeForName: @"DisplayName"] stringValue];
            w.displayName = wdispname ? wdispname : wname;
            
            w.datasourceURL = [[[NSBundle mainBundle] objectForInfoDictionaryKey: @"DataSource"] stringByDeletingLastPathComponent];
            
            w->eqRadius = [[[xworld attributeForName:@"EqRadius"] stringValue] doubleValue];
            w->polarRadius = [[[xworld attributeForName:@"PolarRadius"] stringValue] doubleValue];
            
            [worlds addObject:w];
            [w release];
        }
        
        //TODO: should append here to support multiple datasources!!!
        w.configXML = [xworld XMLString];
    }
    
    [xds release];
    
    //Populate Switch World menu
    int i = 100;
    for (World *w in worlds)
    {
        NSMenuItem *it = [worldsMenu addItemWithTitle:w.displayName action:@selector(switchWorldByItem:) keyEquivalent:@""];
        [it setTarget:nil];
        it.tag = i++;
    }
    
    [mainWindowController showWindow:nil];
    [loadingWindow close];   
    
    if (![self switchWorldByName: [[NSUserDefaults standardUserDefaults] stringForKey:@"World"]])
        if ([worlds count])
            [self switchWorldByIndex: 0];
    
    //here so that it won't set title to Planito - (null) because no world loaded yet
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"WorkOffline" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];    

    //here so that mapView->move = YES won't crash
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"FixProjectionDistortion" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionInitial context:nil];
}

-(BOOL) switchWorldByName: (NSString*)wname
{
    //if ([world.name isEqualToString:wname])
    //    return YES;

    NSString *lcwname = [wname lowercaseString];
    
    int i = 0;
    for (World *w in worlds)
    {
        if ([[w.name lowercaseString] isEqualToString:lcwname])
        {
            [self switchWorldByIndex:i];
            return YES;
        }

        i++;
    }

    return NO;
}
                          
-(void) switchWorldByIndex: (NSInteger)index
{
    if ([mainWindowController.window attachedSheet])
        return;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WorldWillChange" object:NSApp];
    
    if (world)
    {
        //Stop render and updater threads
        [self stop];
        [mapView clear];
        
        [mapView savePosition];
        [[worldsMenu itemWithTitle:world.displayName] setState:NSOffState];

        [world unload];
        world = nil;
    }
    
    [cacheManager reset];
    //[[BookmarkManager get] reset];
    
    //Now loading new world
    world = [worlds objectAtIndex:index];
    
    [[NSUserDefaults standardUserDefaults] setObject:world.name forKey:@"World"];
    [[worldsMenu itemAtIndex:index] setState:NSOnState];
    [mainWindowController updateWindowTitle];
    
    [world load];
    
    [[BookmarkManager get] load];
    [mainWindowController worldChanged];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"WorldDidChange" object:NSApp];
    
    [NSThread detachNewThreadSelector:@selector(runLoop) toTarget: updater withObject: nil];
    [mapView startRendering];
    
    [mapView loadPosition];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"UseMultitouch"])
    {
        useMultitouch = [(NSUserDefaults*)object boolForKey:keyPath];
        
        return;
    }

    if ([keyPath isEqualToString:@"FixProjectionDistortion"])
    {
        fixDistortion = [(NSUserDefaults*)object boolForKey:keyPath];
        mapView->move = YES;
        
        return;
    }
    
    if ([keyPath isEqualToString:@"WorkOffline"])
    {
        workOffline = [(NSUserDefaults*)object boolForKey:keyPath];
        [mainWindowController updateWindowTitle];
        
        return;
    }

    if ([keyPath isEqualToString:@"Autorefresh"])
    {
        autorefresh = [(NSUserDefaults*)object boolForKey:keyPath];
        
        return;
    }
}

-(void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    
    if (world)
        [mapView parseAndGo: url];
    else
        urlToOpen = [[url stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] retain];
}

-(void) stop
{
    updater->stopsignal = YES;
    [mapView stopRendering];
    while (updater->running || mapView->rendering)
        usleep(10000);
}


@end
