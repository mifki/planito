//
//  RemoteTileProvider.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TileProvider.h"

@interface RemoteTileProvider : NSObject<TileProvider> {
    NSString *_urlFormat;

    int ndown;
    int maxDownloads;
    
    enum { None, GZ, KMZ } compression;
}

@property(nonatomic,retain) NSString* urlFormat;

-(NSString*) buildURLForTile: (Tile*)t;

-(void) gotRemoteData: (NSData*)data forTile: (Tile*)t;

@end
