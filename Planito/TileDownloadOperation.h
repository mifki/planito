//
//  TileDownloadOperation.h
//  Planito
//
//  Created by Vitaliy Pronkin on 27.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MapLayer;

@interface TileDownloadOperation : NSOperation {
@public
    
    IBOutlet NSView *view;
    IBOutlet NSTextField *label;
    IBOutlet NSProgressIndicator *progressIndicator;
    
    id tdpc;
    
    MapLayer *l;
    
    int maxlevel;
    double lx, ly, rx, ry;
    NSUInteger dltiles;
    
    BOOL finished;
}

-(IBAction) stop: (id)sender;

@end