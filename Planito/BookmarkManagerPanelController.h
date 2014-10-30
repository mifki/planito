//
//  BookmarksPanel.h
//  Planito
//
//  Created by Vitaliy Pronkin on 19.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface BookmarkManagerPanelController : NSObject {
    IBOutlet NSPanel *panel;
    IBOutlet NSOutlineView *bookmarksView;
    
    IBOutlet NSMenu *bookmarkActionsMenuTemplate;
    
    NSMutableArray *draggingFrom;
    NSUInteger draggingFromIndex;
}

-(IBAction) addFolder: (id)sender;
-(IBAction) done: (id)sender;

-(IBAction) gotoBookmark: (id)sender;
-(IBAction) copyLink: (id)sender;
-(IBAction) editName: (id)sender;
-(IBAction) deleteBookmark: (id)sender;

-(void) showInWindow: (NSWindow*)window;

-(void) openInExternalViewer:(NSMenuItem*)sender;

@end
