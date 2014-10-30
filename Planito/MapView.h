//
//  MapView.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/GL.h>
#import <WebKit/WebKit.h>
#import <CoreLocation/CoreLocation.h>
#import <QuartzCore/QuartzCore.h>
#import "Features.h"

#define MAX_LABEL_LEN     100
#define MAX_TITLE_LEN     200
#define GMAX_STRINGS      20000
#define MAX_ACTIVE_LAYERS 99

struct MAPREGION
{
    double lx, ly, rx, ry;
};

@class MapLayer;

@interface MapView : NSOpenGLView <CLLocationManagerDelegate> {

    IBOutlet NSPopover *infoPopover;
    IBOutlet NSViewController *bigPopoverViewController;
    IBOutlet NSTextField *bigPopoverTitleLabel;
    IBOutlet NSTextField *bigPopoverCoordsLabel;
    IBOutlet WebView *bigPopoverWebView;
    IBOutlet NSProgressIndicator *bigPopoverWaitIndicator;
    IBOutlet NSButton *bigPopoverActionsButton;
    
    NSMenu *_featureActionsMenu;
    
    CVDisplayLinkRef displayLink;
    
@public
	BOOL zoom, move, reshape;

	double w, targetw, ppd, cphi1;
	double cx, cy, targetcx, targetcy;
	double lx, ly, rx, ry;
    
    double flat, flon;
    
    float lmx, lmy;
	
	int w_px, h_px, hw_px, hh_px;
	
    GLdouble wndprojmatrix[16];
	enum { PROJ_OTHER=-1, PROJ_WORLD=0, PROJ_WINDOW=1 } projmode;
	
	GLuint *texs;
	int tcnt;
	
	MapLayer* layers[MAX_ACTIVE_LAYERS];
	int lcnt;
    
    unsigned long rstep;
    BOOL rendering;
    //BOOL stopsignal, running;
    
    NSTimeInterval curtimestamp;
    
    PLACEMARK *curpm;
    POLYLINE *curpl;
    
    double userloc_lat, userloc_lon, userloc_accuracy;
    BOOL userloc_valid;
}

@property(nonatomic,retain) NSMenu* featureActionsMenu;

-(IBAction) showFeatureActionsMenu: (id)sender;
-(IBAction) openFeatureExternalLink: (id)sender;
-(void) openInExternalViewer: (NSMenuItem*)sender;
-(IBAction) copyLinkToFeature: (id)sender;

-(void) startRendering;
-(void) stopRendering;

-(void) unregister3DMouse;

-(void) savePosition;

-(void) loadPosition;

-(void) goToLon: (double)lon lat: (double)lat w: (double)_w;

-(NSString*) linkToCurrentView;

-(BOOL) parseAndGo: (NSString*)str;

-(void) addViewToFavorites;
-(void) addSelectionToFavorites;

-(void) zoomToWorld;
-(void) zoomIn;
-(void) zoomOut;

@end
