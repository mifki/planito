//
//  BookmarkManager.m
//  Planito
//
//  Created by Vitaliy Pronkin on 18.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "BookmarkManager.h"
#import "Globals.h"
#import "Helpers.h"

#define TOP_MENU_ITEMS 3

@implementation NSMutableDictionary (PlanitoBookmark)
@dynamic bookmarkName, bookmarkFolder;

+(Bookmark*) bookmarkWithName: (NSString*)name lat: (double)lat lon: (double)lon w: (double)w;
{
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSString stringWithUUID], @"Id",
            name, @"Name",
            [NSNumber numberWithDouble:lat], @"Lat",
            [NSNumber numberWithDouble:lon], @"Lon",
            [NSNumber numberWithDouble:w], @"W",
            nil];
}

+(Bookmark*) bookmarkWithEmptyFolderAndName: (NSString*)name;
{
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            [NSString stringWithUUID], @"Id",
            name, @"Name",
            [NSMutableArray array], @"Folder",
            nil];
}

-(NSString*) bookmarkId
{
    return [self objectForKey:@"Id"];
}

-(void) setBookmarkId: (NSString*)Id
{
    [self setObject:Id forKey:@"Id"];
}

-(NSString*) bookmarkName
{
    return [self objectForKey:@"Name"];
}

-(void) setBookmarkName: (NSString*)name
{
    [self setObject:name forKey:@"Name"];
}

-(double) bookmarkLat
{
    return [[self objectForKey:@"Lat"] doubleValue];
}

-(double) bookmarkLon
{
    return [[self objectForKey:@"Lon"] doubleValue];
}

-(double) bookmarkW
{
    return [[self objectForKey:@"W"] doubleValue];
}

-(NSMutableArray*) bookmarkFolder
{
    return [self objectForKey:@"Folder"];
}

@end

@implementation BookmarkManager
@dynamic bookmarks;

static BookmarkManager *me = nil;

+(BookmarkManager*) get
{
    return me;
}

-(void) awakeFromNib
{
    me = self;
}

-(void) load
{
    if (!world)
        return;
    
    if (_bookmarks)
        [_bookmarks release];
    
    NSString *fn = [APPSUPP_PATH() stringByAppendingPathComponent: [NSString stringWithFormat:@"Favorites-%@.plist", world.name]];

    NSInputStream *s = [NSInputStream inputStreamWithFileAtPath:fn];
    [s open];
    _bookmarks = [[NSPropertyListSerialization propertyListWithStream:s options:NSPropertyListMutableContainers format:NULL error:NULL] retain];

    if (!_bookmarks || ![_bookmarks isKindOfClass:[NSMutableArray class]])
        _bookmarks = [NSMutableArray new];
}

-(void) save
{
    if (!_bookmarks)
        return;
    
    NSString *fn = [APPSUPP_PATH() stringByAppendingPathComponent: [NSString stringWithFormat:@"Favorites-%@.plist", world.name]];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:APPSUPP_PATH() withIntermediateDirectories:YES attributes:NULL error:NULL];
    [_bookmarks writeToFile:fn atomically:YES];
}

-(void) reset
{
    [_bookmarks release];
    _bookmarks = nil;
}

-(NSMutableArray*) bookmarks
{
    if (!_bookmarks)
        [self load];
    
    return _bookmarks;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu *)menu
{
    NSMenu *supermenu = [menu supermenu];
    NSInteger index = [supermenu indexOfItemWithSubmenu:menu];
    NSMenuItem *parentitem = [supermenu itemAtIndex:index];
    
    NSArray *folder = [parentitem representedObject];
    if (folder)
        return [folder count];
    else
    {
        if (!_bookmarks)
            [self load];
        
        return [_bookmarks count] + TOP_MENU_ITEMS;
    }
}

- (BOOL)menu:(NSMenu *)menu updateItem:(NSMenuItem *)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    Bookmark *b;
    
    NSMenuItem *parentitem = [item parentItem];
    NSArray *folder = [parentitem representedObject];

    if (folder)
        b = [folder objectAtIndex:index];
    else
    {
        if (index < TOP_MENU_ITEMS)
            return YES;
        
        index -= TOP_MENU_ITEMS;
        b = [_bookmarks objectAtIndex:index];
    }
    
    [item setTitle: b.bookmarkName];
    
    NSMutableArray *fld = b.bookmarkFolder;
    if (fld)
    {
        NSMenu *m = [NSMenu new];
        [m setAutoenablesItems:NO];
        m.delegate = self;
        [item setSubmenu:m];
        [m release];

        [item setRepresentedObject:fld];
        [item setImage:[NSImage imageNamed:@"favfolder-16.png"]];
    }
    else
    {
        item.tag = index;
        [item setTarget:self];
        [item setAction:@selector(goToBookmark:)];
        [item setSubmenu:nil];
        [item setRepresentedObject:fld];
        [item setImage:nil];
    }
    
    return YES;
}

-(void) goToBookmark: (NSMenuItem*)sender
{
    NSArray *folder = [[sender parentItem] representedObject];
    if (!folder)
        folder = _bookmarks;
    
    Bookmark *b = [folder objectAtIndex:sender.tag];
    [mapView goToLon:b.bookmarkLon lat:b.bookmarkLat w: ([NSEvent modifierFlags] & NSAlternateKeyMask) ? 0 : b.bookmarkW];
}

@end
