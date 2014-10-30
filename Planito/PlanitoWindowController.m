//
//  PlanitoWindowController.m
//  Planito
//
//  Created by Vitaliy Pronkin on 18.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "PlanitoWindowController.h"
#import "Globals.h"
#import "AddBookmarkPanelController.h"
#import "Features.h"
#import "Helpers.h"
#import "BookmarkManagerPanelController.h"
#import "LayersPanelController.h"
#import "Geocoder.h"
#import "GeocodingResult.h"
#import "INAppStoreWindow.h"
#import "PreferencesPanelController.h"

extern BOOL showCoordGrid;
extern BOOL showDistanceGrid;
extern BOOL showUserLoc;

@interface PlanitoWindowController ()
-(void) updateSearchMenu;
-(void) positionSearchResultsPanel;
@end

@implementation PlanitoWindowController

- (NSString *)windowNibName
{
    return @"MainWindow";
}

-(void) windowDidLoad
{
    INAppStoreWindow *window = (INAppStoreWindow*)self.window;
    window.titleBarHeight = 40;
    toolbarView.frame = window.titleBarView.bounds;
    [window.titleBarView addSubview:toolbarView];
    [window setInitialFirstResponder:mapView];
    
    [searchResultsView setTarget:self];
    [searchResultsView setDoubleAction: @selector(gotoResult:)];  
    
    [searchResultsPanel setOpaque:NO];
    [searchResultsPanel setBackgroundColor:[NSColor colorWithCalibratedWhite:1 alpha:0.96]];
    
    showCoordGrid = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowCoordGrid"];
    if (showCoordGrid)
        [gridsBtn setImage:[NSImage imageNamed:@"grid-on.png"] forSegment:0];
    else
        [gridsBtn setImage:[NSImage imageNamed:@"grid.png"] forSegment:0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchFieldFocused) name:@"DidReceiveFocus" object:searchField];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchFieldUnfocused) name:NSControlTextDidEndEditingNotification object:searchField];
}

-(void) windowDidMiniaturize:(NSNotification *)notification
{
    [mapView stopRendering];
}

-(void) windowDidDeminiaturize:(NSNotification *)notification
{
    [mapView startRendering];
}

- (void)windowDidResize:(NSNotification *)notification
{
    [self positionSearchResultsPanel];
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	[NSApp terminate: nil];
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    rect.origin.y = mapView.frame.size.height;
    
    return rect;
}

-(void) updateWindowTitle
{
    if (workOffline)
        [self.window setTitle: [NSString stringWithFormat: @"Planito - %@ (%@)", world.displayName, NSLocalizedString(@"offline-in-title", @"")]];
    else
        [self.window setTitle: [NSString stringWithFormat: @"Planito - %@", world.displayName]];
}

-(void) switchWorldByItem: (NSMenuItem*)sender
{
    [[NSApp delegate] switchWorldByIndex: sender.tag-100];
}

-(void) showPreferences:(id)sender
{
    PreferencesPanelController *ppc = [PreferencesPanelController new];
    [ppc showInWindow: self.window];
    [ppc release];
}

-(void) copyLinkToCurrentView:(id)sender
{
    NSString *s = [mapView linkToCurrentView];
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb writeObjects:[NSArray arrayWithObject:[NSURL URLWithString:s]]];
}

-(void) pasteAndGo:(id)sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    if (![pb availableTypeFromArray: [NSArray arrayWithObject: NSStringPboardType]])
        return;
    
    NSString *str = [pb stringForType: NSStringPboardType];
    str = [str stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    str = [str stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
    [mapView parseAndGo:str];
}

-(void) showUserLocation: (NSButton*)sender
{
    if ([NSEvent modifierFlags] & NSAlternateKeyMask)
    {
        if (showUserLoc && mapView->userloc_valid)
            [mapView goToLon:mapView->userloc_lon lat:mapView->userloc_lat w:0];
        
        sender.state = !sender.state;
        return;
    }
    
    if (sender.state == NSOnState)
    {
        if (!locman)
        {
            locman = [CLLocationManager new];
            locman.delegate = self;
        }
        
        showUserLoc = YES;
        mapView->userloc_valid = NO;
        [locman startUpdatingLocation];
    }
    else
    {
        showUserLoc = NO;
        [locman stopUpdatingLocation];
        mapView->userloc_valid = NO;
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    CLLocationCoordinate2D coord = newLocation.coordinate;

    mapView->userloc_lat = coord.latitude;
    mapView->userloc_lon = coord.longitude;
    mapView->userloc_accuracy = newLocation.horizontalAccuracy;

    if (!mapView->userloc_valid)
    {
        mapView->userloc_valid = YES;
        [mapView goToLon:coord.longitude lat:coord.latitude w:0];
    }
}

-(void) addViewToFavorites:(id)sender
{
    [mapView addViewToFavorites];
}

-(void) addSelectionToFavorites:(id)sender
{
    [mapView addSelectionToFavorites];
}

-(void) manageBookmarks: (id)sender
{
    if ([self.window attachedSheet])
        return;

    static BookmarkManagerPanelController *bmpc = nil;
    if (!bmpc)
        bmpc = [BookmarkManagerPanelController new];

    [bmpc showInWindow: self.window];
}

-(void) helpLinkHomepage: (id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://planitoapp.com"]];
}

-(void) helpLinkPlacesGallery: (id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://planito.tumblr.com"]];
}

-(void) worldAndLayersBtnClick:(NSSegmentedControl*)sender
{
    switch (sender.selectedSegment)
    {
        case 0:
            [worldsMenu popUpMenuPositioningItem:[worldsMenu itemWithTitle:world.displayName] atLocation:NSMakePoint(0, 0) inView:sender];
            break;
        case 1:
            [self showLayers:sender];
            break;
    }
}

-(void) showLayers: (id)sender
{
    [layersPanelController view];
    [layersPanelController resizeContainer];

    if (![layersPopover isShown])
    {
        NSRect r = worldAndLayersBtn.bounds;
        r.origin.x += r.size.width/2 + 2;
        r.size.width = r.size.width/2 - 2;
        
        [layersPopover showRelativeToRect:r ofView:worldAndLayersBtn preferredEdge:NSMinYEdge];
    }
}

-(void) gridsBtnClick: (NSSegmentedControl*)sender
{
    switch (sender.selectedSegment)
    {
        case 0:
            [self toggleCoordGrid:sender];
            break;
        case 1:
            [self toggleDistanceGrid:sender];
            break;
    }
}

-(void) toggleCoordGrid: (id)sender
{
    showCoordGrid = !showCoordGrid;
    [[NSUserDefaults standardUserDefaults] setBool:showCoordGrid forKey:@"ShowCoordGrid"];
    if (showCoordGrid)
        [gridsBtn setImage:[NSImage imageNamed:@"grid-on.png"] forSegment:0];
    else
        [gridsBtn setImage:[NSImage imageNamed:@"grid.png"] forSegment:0];
}

-(void) toggleDistanceGrid:(id)sender
{
    showDistanceGrid = !showDistanceGrid;
    [[NSUserDefaults standardUserDefaults] setBool:showDistanceGrid forKey:@"ShowDistanceGrid"];
    if (showDistanceGrid)
        [gridsBtn setImage:[NSImage imageNamed:@"grid2-on.png"] forSegment:1];
    else
        [gridsBtn setImage:[NSImage imageNamed:@"grid2.png"] forSegment:1];    
}

-(void) showTileDownloader:(id)sender
{
    [tileDownloaderPopover showRelativeToRect:showTileDownloaderBtn.bounds ofView:showTileDownloaderBtn preferredEdge:NSMinYEdge];
}

-(void) showFavorites:(NSButton *)sender
{
    [favoritesMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, 0) inView:sender];
}

-(void) worldChanged
{
    showUserLoc = NO;
    [locman stopUpdatingLocation];
    [locman release];
    locman = nil;
    mapView->userloc_valid = NO;
    
    //remove this when people will live on other planets :)
    [showUserLocationBtn setEnabled:[world.name isEqualToString:@"Earth"]];

    if (!world->eqRadius || !world->polarRadius)
    {
        [gridsBtn setEnabled:NO forSegment:1];
        showDistanceGrid = NO;
    }
    else
    {
        [gridsBtn setEnabled:YES forSegment:1];
        showDistanceGrid = [[NSUserDefaults standardUserDefaults] boolForKey:@"ShowDistanceGrid"];
    }
    if (showDistanceGrid)
        [gridsBtn setImage:[NSImage imageNamed:@"grid2-on.png"] forSegment:1];
    else
        [gridsBtn setImage:[NSImage imageNamed:@"grid2.png"] forSegment:1];    
        
    [searchResults removeAllObjects];
    [searchResultsView reloadData];    
    [searchField.cell setRecentSearches: [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"SearchRecents-%@", world.name]]];
    [self updateSearchMenu];

    [worldAndLayersBtn setLabel:world.displayName forSegment:0];
    
    //Populate "View In" menu
    {
        NSMenu *m = [featureActionsMenuTemplate copy];
        [m removeItem:[m itemWithTag:1001]]; //remove placeholder
        
        if ([world->extViewers count])
        {
            for (NSString *n in [world->extViewers allKeys])
            {
                NSMenuItem *mi = [m addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"view-in", @""), n] action:@selector(openInExternalViewer:) keyEquivalent:@""];
                mi.target = mapView;
                mi.representedObject = [world->extViewers objectForKey:n];
            }
        }
        else
            [m removeItem:[m itemWithTag:1000]]; //remove separator if no items added
        
        mapView.featureActionsMenu = m;
        [m release];
    }
}

-(void) updateSearchMenu
{
    NSMenu *searchMenu = [searchMenuTemplate copy];
    
    int i = [searchMenu indexOfItemWithTag:2000];
    
    if ([world->geocoders count])
    {
        [searchMenu removeItemAtIndex:i];
        
        NSString *geocoderid = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat: @"Geocoder-%@", world.name]];
        
        for (Geocoder *geocoder in world->geocoders)
        {
            NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:geocoder.name action:@selector(setActiveGeocoder:) keyEquivalent:@""];
            mi.target = self;
            mi.representedObject = geocoder;
            
            if ([geocoder.Id isEqualToString:geocoderid])
                [mi setState:NSOnState];
            
            [searchMenu insertItem:mi atIndex:i++];
            [mi release];
        }
    }
    
    [searchField.cell setSearchMenuTemplate:searchMenu];
    [searchMenu release];
}

-(void) setActiveGeocoder: (NSMenuItem*)sender
{
    Geocoder *geocoder = sender.representedObject;
    [[NSUserDefaults standardUserDefaults] setObject:geocoder.Id forKey:[NSString stringWithFormat: @"Geocoder-%@", world.name]];
    
    [self updateSearchMenu];
}

-(void) searchFieldFocused
{
    if ([searchResults count])
        [self.window addChildWindow:searchResultsPanel ordered:NSWindowAbove];
}

-(void) searchFieldUnfocused
{
    [searchResultsPanel close];
}

-(void) positionSearchResultsPanel
{
    NSPoint pt = NSMakePoint(0, searchField.frame.size.height);
    //NSPoint pt = NSMakePoint(searchField.frame.size.width, searchField.frame.size.height);
    pt = [searchField convertPoint:pt toView:nil];
    
    float h = MIN([searchResults count]*19, 400);//searchResultsView.rowHeight;
    
    NSRect r = NSMakeRect(pt.x+6, pt.y-h-2, searchField.frame.size.width-11, h);
    //NSRect r = NSMakeRect(pt.x-400, pt.y-h-2, 400, h);
    r = [self.window convertRectToScreen:r];
    
    [searchResultsPanel setFrame:r display:NO];        
}

-(void) performFindPanelAction:(id)sender
{
    [self.window makeFirstResponder:searchField];
}

-(void) search: (id)sender
{
    if (!world)
        return;
    
    [[NSUserDefaults standardUserDefaults] setObject:[searchField.cell recentSearches] forKey:[NSString stringWithFormat:@"SearchRecents-%@", world.name]];
    
    NSString *q = [searchField stringValue];
    
    if (!searchResults)
        searchResults = [NSMutableArray new];
    else
    {
        [searchResults removeAllObjects];
        [searchResultsView reloadData];
    }
    
    if (![q length] || [mapView parseAndGo: q])
    {        
        [searchResultsPanel close];
        return;
    }
    
    [curGeocoder cancel];
    curGeocoder = nil;
    
    if ([world->geocoders count])
    {
        NSString *geocoderid = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat: @"Geocoder-%@", world.name]];
        
        for (Geocoder *g in world->geocoders)
        {
            if ([g.Id isEqualToString:geocoderid])
            {
                curGeocoder = [g retain];
                break;
            }
        }
        
        if (!curGeocoder)
        {
            curGeocoder = [[world->geocoders objectAtIndex:0] retain];
            [[NSUserDefaults standardUserDefaults] setObject:curGeocoder.Id forKey:[NSString stringWithFormat: @"Geocoder-%@", world.name]];
            [self updateSearchMenu];
        }
        
        [curGeocoder geocodeString: q withDelegate:self];
    }
}

-(void) geocoder: (Geocoder*)geocoder didFinishWithResults: (NSArray*)_results
{
    [searchResults addObjectsFromArray:_results];
    [searchResultsView reloadData];
        
    if ([searchResults count])
    {
        [self positionSearchResultsPanel];
        [self.window addChildWindow:searchResultsPanel ordered:NSWindowAbove];
    }
    else
        [searchResultsPanel close];
        
    [curGeocoder release];
    curGeocoder = nil;
}

-(void) geocoderDidFail: (Geocoder*)geocoder
{
    [curGeocoder release];
    curGeocoder = nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [searchResults count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if ([[aTableColumn identifier] isEqualToString: @"name"])
        return [[searchResults objectAtIndex: rowIndex] displayName];
    
    return nil;
}

-(void) gotoResult: (id)sender
{
    NSInteger row = [searchResultsView clickedRow];
    if (row == -1)
        return;
    
    GeocodingResult *gr = [searchResults objectAtIndex: row];
    [mapView goToLon: gr.lon lat: gr.lat w:0];
}

-(void) zoomToWorld:(id)sender
{
    [mapView zoomToWorld];
}

-(void) zoomIn:(id)sender
{
    [mapView zoomIn];
}

-(void) zoomOut:(id)sender
{
    [mapView zoomOut];
}

@end
