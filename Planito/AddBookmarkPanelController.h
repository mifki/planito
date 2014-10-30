//
//  AddBookmarkPanel.h
//  Planito
//
//  Created by Vitaliy Pronkin on 19.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BookmarkManager.h"

typedef enum {
    BookmarkTypeView,
    BookmarkTypeFeature,
    BookmarkTypeLocation
} BookmarkType;

@interface AddBookmarkPanelController : NSObject {
    
    IBOutlet NSTextField *label;
    
    IBOutlet NSPanel *panel;
    
    IBOutlet NSTextField *bookmarkNameField;
    
    IBOutlet NSPopUpButton *folderSelector;
    
    IBOutlet NSButton *addButton;

    Bookmark *bookmark;
}

-(void) addBookmarkWithProposedName: (NSString*)proposedName lat: (double)lat lon: (double)lon w: (double)w type: (BookmarkType)type;

-(IBAction) cancel: (id)sender;
-(IBAction) add: (id)sender;

@end
