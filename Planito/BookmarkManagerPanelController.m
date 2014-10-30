//
//  BookmarksPanel.m
//  Planito
//
//  Created by Vitaliy Pronkin on 19.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "BookmarkManagerPanelController.h"
#import "BookmarkManager.h"
#import "Globals.h"
#import "Helpers.h"

#define PlanitoBookmarkDataType @"PlanitoBookmarkDataType"

@implementation BookmarkManagerPanelController

- (id)init
{
    if (self = [super init]) {
        [NSBundle loadNibNamed: @"BookmarkManagerPanel" owner:self];

        [bookmarksView registerForDraggedTypes: [NSArray arrayWithObject:PlanitoBookmarkDataType]];    
        [bookmarksView setTarget:self];
        [bookmarksView setDoubleAction:@selector(gotoBookmark:)];
        [bookmarksView sizeToFit];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(worldChanged) name:@"WorldDidChange" object:NSApp];
        [self worldChanged];
    }
    
    return self;
}

-(void) showInWindow: (NSWindow*)window
{
    [self retain];
    
    [bookmarksView reloadData];
  
    //[panel orderFront:nil];
    [NSApp beginSheet: panel modalForWindow: window modalDelegate: nil didEndSelector: nil contextInfo: nil];
}

-(void) worldChanged
{
    //Populate "View In" menu
    {
        NSMenu *m = [bookmarkActionsMenuTemplate copy];
        int i = [m indexOfItemWithTag:1001];
        [m removeItem:[m itemWithTag:1001]]; //remove placeholder
        
        if ([world->extViewers count])
        {
            int k = 0;
            for (NSString *n in [world->extViewers allKeys])
            {
                NSMenuItem *mi = [m insertItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"view-in", @""), n] action:@selector(openInExternalViewer:) keyEquivalent:@"" atIndex:i+(k++)];
                mi.target = self;
                mi.representedObject = [world->extViewers objectForKey:n];
            }
        }
        //else
        //    [m removeItem:[m itemWithTag:1000]]; //remove separator if no items added
        
        [[[bookmarksView tableColumnWithIdentifier:@"name"] dataCell] setMenu:m];
        [[[bookmarksView tableColumnWithIdentifier:@"coords"] dataCell] setMenu:m];
        [m release];
    }    
}

-(void) addFolder: (id)sender
{
    Bookmark *bmk = [Bookmark bookmarkWithEmptyFolderAndName: @"new folder"];

    NSInteger row = [bookmarksView selectedRow];
    if (row == -1)
        [[BookmarkManager get].bookmarks addObject:bmk];
    else
    {
        Bookmark *selitem = [bookmarksView itemAtRow:row];

        if (selitem.bookmarkFolder != nil && [bookmarksView isItemExpanded:selitem])
            [selitem.bookmarkFolder insertObject:bmk atIndex:0];
        else
        {
            Bookmark *parent = [bookmarksView parentForItem:selitem];

            NSMutableArray *into;
            if (parent)
                into = parent.bookmarkFolder;
            else
                into = [BookmarkManager get].bookmarks;
            
            [into insertObject:bmk atIndex: [into indexOfObject:selitem]+1];
        }
    }
    
    [bookmarksView reloadData];
    [bookmarksView editColumn:0 row:[bookmarksView rowForItem:bmk] withEvent:nil select:YES];
}

-(void) done: (id)sender
{
    [[BookmarkManager get] save];
    
    [NSApp endSheet: panel];
    [panel close];
    
    [self release];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
    return item ? [((Bookmark*)item).bookmarkFolder objectAtIndex:index] : [[BookmarkManager get].bookmarks objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return ((Bookmark*)item).bookmarkFolder != nil;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return item ? [((Bookmark*)item).bookmarkFolder count] : [[BookmarkManager get].bookmarks count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString: @"name"])
        return ((Bookmark*)item).bookmarkName;

    if ([[tableColumn identifier] isEqualToString: @"coords"])
    {
        Bookmark *b = (Bookmark*)item;
        NSArray *folder = b.bookmarkFolder;
        
        if (folder)
            return [NSString stringWithFormat:@"(%d)", [folder count]];//[[NSNumber numberWithInt:[folder count]] stringValue];// [folder count] == 1 ? @"1 item" : [NSString stringWithFormat:@"%d items", [folder count]];
        else
            return FORMAT_LATLON(b.bookmarkLat, b.bookmarkLon);
    }
	
	return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString: @"name"])
        if ([object length] > 0)
            ((Bookmark*)item).bookmarkName = object;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
    id item = [items objectAtIndex:0];
    
    Bookmark *parent = [outlineView parentForItem:item];
    
    if (parent)
        draggingFrom = parent.bookmarkFolder;
    else
        draggingFrom = [BookmarkManager get].bookmarks;
    draggingFromIndex = [draggingFrom indexOfObject: item];
    
    [pboard declareTypes:[NSArray arrayWithObject:PlanitoBookmarkDataType] owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:item] forType:PlanitoBookmarkDataType];

    return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id < NSDraggingInfo >)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
    if (item && !((Bookmark*)item).bookmarkFolder)
        return NSDragOperationNone;
    
    return NSDragOperationMove;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id < NSDraggingInfo >)info item:(id)item childIndex:(NSInteger)index
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:PlanitoBookmarkDataType];
    
    NSDictionary *draggingItem = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    
    NSMutableArray *draggingTo;
    if (item)
        draggingTo = ((Bookmark*)item).bookmarkFolder;
    else
        draggingTo = [BookmarkManager get].bookmarks;

    [draggingItem retain];
    
    [draggingFrom removeObjectAtIndex:draggingFromIndex];
    if (index == NSOutlineViewDropOnItemIndex)
        [draggingTo addObject:draggingItem];
    else
    {
        if (draggingFrom == draggingTo && draggingFromIndex < index)
            index--;
        [draggingTo insertObject:draggingItem atIndex:index];
    }
    
    [draggingItem release];
    draggingFrom = nil;
        
    [outlineView reloadData];
    
    return YES;
}

- (void)menuWillOpen:(NSMenu *)menu
{
    Bookmark *item = [bookmarksView itemAtRow: [bookmarksView clickedRow]];
    
    if (item.bookmarkFolder != nil)
    {
        [[menu itemAtIndex:0] setEnabled:NO];
        [[menu itemAtIndex:3] setEnabled:NO];
        [[menu itemAtIndex:4] setEnabled:NO];
        [[menu itemAtIndex:5] setEnabled:NO];
    }
    else
    {
        [[menu itemAtIndex:0] setEnabled:YES];
        [[menu itemAtIndex:3] setEnabled:YES];
        [[menu itemAtIndex:4] setEnabled:YES];
        [[menu itemAtIndex:5] setEnabled:YES];
    }
}

-(void) gotoBookmark: (id)sender
{
    NSInteger row = [bookmarksView clickedRow];
    if (row == -1)
        return;
    
    Bookmark *b = [bookmarksView itemAtRow: row];
    if (b.bookmarkFolder)
        return;
    
    [mapView goToLon:b.bookmarkLon lat:b.bookmarkLat w: ([NSEvent modifierFlags] & NSAlternateKeyMask) ? 0 : b.bookmarkW];
    
    //TODO: close panel here?
    //[self done:nil];
}

-(void) copyLink: (id)sender
{
    Bookmark *b = [bookmarksView itemAtRow: [bookmarksView clickedRow]];
    NSString *s = PLANITO_LINK(b.bookmarkLat, b.bookmarkLon, b.bookmarkW);
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb writeObjects:[NSArray arrayWithObject:[NSURL URLWithString:s]]];
}

-(void) openInExternalViewer:(NSMenuItem*)sender
{
    Bookmark *b = [bookmarksView itemAtRow: [bookmarksView clickedRow]];
    
    NSMutableString *url = [sender.representedObject mutableCopy];
    [url replaceOccurrencesOfString:@"{x}" withString:[[NSNumber numberWithDouble: b.bookmarkLon] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{y}" withString:[[NSNumber numberWithDouble: b.bookmarkLat] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{z}" withString:[[NSNumber numberWithDouble: (int)floor(log2(1000.0/b.bookmarkW*360.0/256.0))] stringValue] options:0 range:NSMakeRange(0, [url length])];
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
    [url release];
}

-(void) editName: (id)sender
{
    id item = [bookmarksView itemAtRow: [bookmarksView clickedRow]];
    [bookmarksView editColumn:0 row:[bookmarksView rowForItem:item] withEvent:nil select:YES];
}

-(void) deleteBookmark: (id)sender
{
    NSInteger row = [bookmarksView clickedRow];
    if (row == -1)
        row = [bookmarksView selectedRow];
    if (row == -1)
        return;
    
    Bookmark *item = [bookmarksView itemAtRow: row];
    Bookmark *parent = [bookmarksView parentForItem:item];
    
    if (parent)
        [parent.bookmarkFolder removeObject:item];
    else
        [[BookmarkManager get].bookmarks removeObject:item];
    
    [bookmarksView reloadData];
    [bookmarksView deselectAll:nil];
}


@end
