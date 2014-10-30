//
//  ImageLoader.h
//  Planito
//
//  Created by Vitaliy Pronkin on 5.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/GL.h>

@interface ImageLoader : NSObject {
    jmp_buf	JpegJumpBuffer;
    
    FILE *srcf;
    NSData *srcdata;
    unsigned long srcpos;

@public
    unsigned char *imgdata;
    BOOL hasAlpha;
    short format;
}

-(ImageLoader*) initWithFile: (NSString*)filepath;
-(ImageLoader*) initWithData: (NSData*)data;

-(BOOL) load;

@end
