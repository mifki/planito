//
//  PlanitoAppDelegate.h
//  Planito
//
//  Created by Vitaliy Pronkin on 30.7.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@class MapView;
@class Updater;
@class PlanitoWindowController;

@interface PlanitoAppDelegate : NSObject <NSApplicationDelegate>
{
    IBOutlet NSWindow *loadingWindow;
    IBOutlet NSProgressIndicator *loadingProgress;
    IBOutlet NSButton* cancelLoadingButton;
    
    IBOutlet PlanitoWindowController *mainWindowController;
    
    IBOutlet NSMenu *worldsMenu;
        
    NSMutableArray *worlds;
    
    Updater *updater;
}

-(IBAction) cancelUpdateDataSources: (id)sender;

-(void) switchWorldByIndex: (NSInteger)index;
-(BOOL) switchWorldByName: (NSString*)wname;

@end
