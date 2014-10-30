//
//  AddBookmarkPanel.m
//  Planito
//
//  Created by Vitaliy Pronkin on 19.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "AddBookmarkPanelController.h"
#import "Globals.h"

@interface AddBookmarkPanelController ()
-(void) populateFoldersMenu;
-(void) populateFoldersMenuFromFolder: (NSArray*)folder level: (int)level;
@end

@implementation AddBookmarkPanelController

- (id)init
{
    if (self = [super init]) {
        [NSBundle loadNibNamed: @"AddBookmarkPanel" owner:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nameChanged) name:NSControlTextDidChangeNotification object:bookmarkNameField];

        
        [self populateFoldersMenu];
        
        NSInteger lastId = [[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"ABPLastFolder-%@", world.name]];
        [folderSelector selectItemWithTag:lastId];
    }
    
    return self;
}

-(void) populateFoldersMenu
{
    NSMutableArray *rootFolder = [BookmarkManager get].bookmarks;

    NSMenuItem *mi = [[folderSelector menu] addItemWithTitle:NSLocalizedString(@"favorites-menu", @"") action:NULL keyEquivalent:@""];
    [mi setImage: [NSImage imageNamed: @"favorites-16.png"]];
    
    [mi setRepresentedObject: rootFolder];
    
    [self populateFoldersMenuFromFolder: rootFolder level: 1];
}

-(void) populateFoldersMenuFromFolder: (NSArray*)folder level: (int)level
{
    for (Bookmark *b in folder)
    {
        NSArray *fld = b.bookmarkFolder;
        if (fld)
        {
            NSMenuItem *mi = [[folderSelector menu] addItemWithTitle:b.bookmarkName action:NULL keyEquivalent:@""];
            [mi setImage: [NSImage imageNamed: @"favfolder-16.png"]];
            [mi setIndentationLevel:level];
            [mi setRepresentedObject:fld];
            
            NSString *Id = b.bookmarkId;
            if (!Id)
                Id = b.bookmarkName;
            [mi setTag: [Id hash]];
            
            [self populateFoldersMenuFromFolder:fld level:level+1];
        }
    }
}

-(void) addBookmarkWithProposedName: (NSString*)proposedName lat: (double)lat lon: (double)lon w: (double)w type: (BookmarkType)type
{
    if ([[mapView window] attachedSheet])
        return;
    [self retain];
    
    if (!proposedName)
        proposedName = @"";
    
    bookmark = [[Bookmark bookmarkWithName:@"" lat:lat lon:lon w:w] retain];

    switch (type)
    {
        case BookmarkTypeView:
            [label setStringValue: NSLocalizedString(@"add-view-to", @"")];
            break;
        case BookmarkTypeFeature:
            [label setStringValue: NSLocalizedString(@"add-feature-to", @"")];
            break;
        case BookmarkTypeLocation:
            [label setStringValue: NSLocalizedString(@"add-location-to", @"")];
            break;
    }
        
    [bookmarkNameField setStringValue: proposedName];
    
    [addButton setEnabled: [proposedName length]>0];
    
    [panel setInitialFirstResponder:bookmarkNameField];

    [NSApp beginSheet: panel modalForWindow: [mapView window] modalDelegate: nil didEndSelector: nil contextInfo: nil];
}

-(void) cancel: (id)sender
{
    [NSApp endSheet: panel];
    [panel close];

    [self release];
}

-(void) add: (id)sender
{
    bookmark.bookmarkName = [bookmarkNameField stringValue];
    
    [[[folderSelector selectedItem] representedObject] addObject: bookmark];
    [[BookmarkManager get] save];
    
    NSInteger lastId = [folderSelector selectedTag];
    [[NSUserDefaults standardUserDefaults] setInteger:lastId forKey:[NSString stringWithFormat:@"ABPLastFolder-%@", world.name]];
    
    [NSApp endSheet: panel];    
    [panel close];

    [self release];
}

-(void) nameChanged
{
    [addButton setEnabled: [[bookmarkNameField stringValue] length]>0];
}

-(void) dealloc
{
    [bookmark release];
    
    [super dealloc];
}

@end
