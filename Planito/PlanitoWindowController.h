//
//  PlanitoWindowController.h
//  Planito
//
//  Created by Vitaliy Pronkin on 18.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class LayersPanelController;
@class TileDownloaderPanelController;
@class AddBookmarkPanelController;
@class Geocoder;

@interface PlanitoWindowController : NSWindowController <NSWindowDelegate, CLLocationManagerDelegate> {
    IBOutlet NSView *toolbarView;
    
    IBOutlet NSSegmentedControl *worldAndLayersBtn;

    IBOutlet NSMenu *worldsMenu;

    IBOutlet NSPopover *layersPopover;
    IBOutlet LayersPanelController *layersPanelController;
    
    IBOutlet NSSegmentedControl *gridsBtn;
    
    IBOutlet NSButton *showTileDownloaderBtn;
    IBOutlet NSPopover *tileDownloaderPopover;
    
    IBOutlet NSMenu *favoritesMenu;
    
    IBOutlet NSButton *showUserLocationBtn;

    IBOutlet NSSearchField *searchField;
    IBOutlet NSMenu *searchMenuTemplate;
    IBOutlet NSTableView *searchResultsView;
    IBOutlet NSPanel *searchResultsPanel;
    
    IBOutlet NSMenu *featureActionsMenuTemplate;
    
    Geocoder *curGeocoder;
    NSMutableArray *searchResults;
    
    CLLocationManager *locman;
}

//Edit
-(IBAction) copyLinkToCurrentView: (id)sender;
-(IBAction) pasteAndGo: (id)sender;

//View
-(IBAction) showUserLocation: (NSButton*)sender;

//Favorites
-(IBAction) addViewToFavorites: (id)sender;
-(IBAction) addSelectionToFavorites: (id)sender;
-(IBAction) manageBookmarks: (id)sender;

//Help menu links
-(IBAction) helpLinkHomepage: (id)sender;
-(IBAction) helpLinkPlacesGallery: (id)sender;

-(IBAction) worldAndLayersBtnClick: (NSSegmentedControl*)sender;

-(IBAction) showLayers: (id)sender;

-(IBAction) showTileDownloader: (id)sender;

-(IBAction) showFavorites: (NSButton*)sender;

-(IBAction) gridsBtnClick: (NSSegmentedControl*)sender;
-(IBAction) toggleCoordGrid: (id)sender;
-(IBAction) toggleDistanceGrid: (id)sender;

-(IBAction) performFindPanelAction: (id)sender;
-(IBAction) search:(id)sender;

-(IBAction) zoomIn:(id)sender;
-(IBAction) zoomOut:(id)sender;
-(IBAction) zoomToWorld:(id)sender;

-(IBAction) showPreferences:(id)sender;


@end
