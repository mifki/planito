//
//  Downloader.h
//  Planito
//
//  Created by Vitaliy Pronkin on 31.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Downloader : NSObject {
    
    NSMutableData *dldata;
    NSURLConnection *conn;
    id delegate;
    
@public
    id obj;
}

+(NSData*) getDataSync: (NSString*)urlstr status: (int*)status;

-(id) initWithURLString: (NSString*)urlstr delegate: (id)_delegate;// object: (id)_obj

-(void) cancel;

@end
