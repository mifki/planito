//
//  Helpers.h
//  Planito
//
//  Created by Vitaliy Pronkin on 5/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

@class Tile;

@interface NSString (PlanitoAdditions)
+(NSString*) stringWithUUID;
-(NSString*) valueForURLParameter: (NSString*)param;
@end


static inline double _mind (double a, double b)
{
    return (a<b) ? a : b;
}

static inline double _maxd (double a, double b)
{
    return (a<b) ? b : a;
}


NSString* APPSUPP_PATH();
NSString* CACHE_PATH();
#define DATA_PATH(lid,format,args...) ([NSString stringWithFormat: (@"%@/%@/%@/" format), CACHE_PATH(), world.name, lid, ## args])

#define PLANITO_LINK(lat,lon,w) [NSString stringWithFormat:@"%@world=%@&lat=%f&lon=%f&view=%f", ([[NSUserDefaults standardUserDefaults] boolForKey:@"UseHTTPInLinks"]?@"http://go.planitoapp.com/#":@"planito://goto/"), world.name, lat, lon, w]

#define FORMAT_LATLON(lat,lon) [NSString stringWithFormat:@"%f %@ %f %@", fabs(lat), (lat >= 0 ? @"N" : @"S"), fabs(lon), (lon >= 0 ? @"E" : @"W")]

//BOOL cache_file_valid(NSString *path, NSTimeInterval expiresIn, NSTimeInterval expiresAt, NSTimeInterval *filetimestamp);
BOOL tile_cache_valid(Tile *t, NSTimeInterval *timestamp);

#define IS_REGION_VISIBLE(t) (t->ry > mapView->ly && t->ly < mapView->ry && \
((mapView->rx > 180 && (t->rx > mapView->lx || t->lx < mapView->rx-360)) || \
(mapView->lx < -180 && (t->lx < mapView->rx || t->rx > mapView->lx+360)) || \
(t->rx > mapView->lx && t->lx < mapView->rx)))

BOOL check_GZ_header(NSData *data);
NSData* decompress_GZ (NSData *data);

NSString* format_distance_from_meters(double d);