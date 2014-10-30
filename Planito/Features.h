//
//  Features.h
//  Planito
//
//  Created by Vitaliy Pronkin on 17.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Font;

typedef struct
{
    //General
	NSString *styleid;
    
    double minppd;
    
    float r, g, b;
    float opacity;
    
    //Icon
    NSString *iconurl;
	NSBitmapImageRep *img;
    int tex;
    int iconDisplaySize;
    
    //Text
    Font *font;
    double fontScale;
    
    //Line
    float lineWidth;
} FEATURESTYLE;

#define FEATURE_COMMON \
NSString *title, *descr; \
NSString *url; \
FEATURESTYLE *style; \

typedef struct 
{
    FEATURE_COMMON
    
    NSString *label;
    unichar unilabel[200];
    NSUInteger labellen;
    BOOL labelrtl;
    double labelw;
    
	double lon, lat;
	double x, y;
} PLACEMARK;

typedef struct
{
    FEATURE_COMMON
    
    double lx, ly, rx, ry;
    
    double *ptcoords;
    unsigned short ptcnt;
} POLYLINE;

@interface Features : NSObject {
@public
    PLACEMARK *placemarks;
	int pmcnt;
    
    POLYLINE *polylines;
    int plcnt;
    
    double lx, ly, rx, ry;
}
@end

