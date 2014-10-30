//
//  BookmarkManager.h
//  Planito
//
//  Created by Vitaliy Pronkin on 18.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSMutableDictionary Bookmark;

@interface NSMutableDictionary (PlanitoBookmark)

@property(nonatomic,retain) NSString *bookmarkId;
@property(nonatomic,retain) NSString *bookmarkName;
@property(nonatomic,readonly) double bookmarkLat;
@property(nonatomic,readonly) double bookmarkLon;
@property(nonatomic,readonly) double bookmarkW;
@property(nonatomic,readonly) NSMutableArray *bookmarkFolder;

+(Bookmark*) bookmarkWithName: (NSString*)name lat: (double)lat lon: (double)lon w: (double)w;
+(Bookmark*) bookmarkWithEmptyFolderAndName: (NSString*)name;

@end

@interface BookmarkManager : NSObject <NSMenuDelegate> {
    NSMutableArray *_bookmarks;
}

@property(readonly) NSMutableArray *bookmarks;

+(BookmarkManager*) get;

-(void) load;
-(void) save;

@end
