//
//  TileDownloaderPanelController.h
//  Planito
//
//  Created by Vitaliy Pronkin on 23.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TileDownloaderPanelController : NSViewController {
@public
    IBOutlet NSSlider *levelSlider;
    IBOutlet NSButton *useCurrentLevelButton;
    IBOutlet NSTextField *totalTilesLabel;
    IBOutlet NSButton *startButton;
    
    IBOutlet NSView *operationsBox;
    
    IBOutlet NSPopUpButton *layerSelector;
    
    IBOutlet NSPopover *ourPopover;
    IBOutlet NSButton *ourButton;
    
    NSTimer *progressTimer;
    
    NSOperationQueue *queue;
    
    NSProgressIndicator *ind;
    
    float height;
}

-(IBAction) useCurrentLevel: (id)sender;

-(IBAction) layerChanged: (id)sender;
-(IBAction) levelChanged: (id)sender;

-(IBAction) start: (id)sender;

-(void) show;
-(void) hide;
-(void) didShow;
-(void) didHide;

-(void) cancelAll;

@end
