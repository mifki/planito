//
//  DefaultURLTileProvider.m
//  Planito
//
//  Created by Vitaliy Pronkin on 8.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "BasicTileProvider.h"
#import "Globals.h"
#import "Tile.h"

static void getVETileKey(char *buf, int l, int i, int j)
{
	buf[l+1] = 0;
	
	int n;
	for (n = 0; n <= l; n++) {
		if (i % 2 == 0)
			if (j % 2 == 0)
				buf[l-n] = '2';
			else
				buf[l-n] = '0';
            else
                if (j % 2 == 0)
                    buf[l-n] = '3';
                else
                    buf[l-n] = '1';
		i = i / 2;
		j = j / 2;
	}
}

@implementation BasicTileProvider

- (id) initWithParameters: (NSDictionary*) params
{
    if (self = [super initWithParameters:params])
    {
        if ([_urlFormat rangeOfString:@"{VEk}"].location != NSNotFound)
            hasVE = YES;
    }
    
	return self;
}

-(NSString*) buildURLForTile: (Tile*)t
{
    if (hasVE)
    {
        NSMutableString *url = [NSMutableString stringWithString:_urlFormat];

        char buf[30];
        getVETileKey(buf, t->level, t->i, t->j);
        [url replaceOccurrencesOfString:@"{VEk}" withString:[NSString stringWithCString:buf encoding:NSASCIIStringEncoding] options:0 range:NSMakeRange(0, [url length])];
        [url replaceOccurrencesOfString:@"{VEq}" withString:[NSString stringWithCString:buf+t->level encoding:NSASCIIStringEncoding] options:0 range:NSMakeRange(0, [url length])];
        
        return url;
    }

    return [super buildURLForTile:t];
}

@end

/* Yandex
 NSString *hexTable[] = {@"0",@"1",@"2",@"3",@"4",@"5",@"6",@"7",@"8",@"9",@"A",@"B",@"C",@"D",@"E",@"F"};
 NSString *dirDelimiter = @"/";
 int eBitPerCoord = 31;
 #define eBitPerDir 4
 #define eBitPerTile 8
 int ePixelMask = (1<<eBitPerTile) - 1;
 int eDirMask = (1<<eBitPerDir) - 1;
 
 int getTileOffset ( int coord,  int zoom)
 {
 return (coord>>zoom) & ePixelMask;
 }
 
 NSString *getURL (int x, int y, int zoom)
 {
 int scaledX = x>>zoom, scaledY = y>>zoom;
 scaledX >>= eBitPerTile;
 scaledY >>= eBitPerTile;
 int bitsPerFileName = (eBitPerDir - 1) - (zoom & (eBitPerDir - 1)), fileNameMask = (1<<bitsPerFileName) - 1;
 
 NSString *filename = [NSString stringWithFormat: @"%@%@%@", hexTable[bitsPerFileName],hexTable[scaledX & fileNameMask],hexTable[scaledY & fileNameMask]];
 NSLog(filename);
 scaledX >>= bitsPerFileName;
 scaledY >>= bitsPerFileName;
 
 NSString *folderPath = @"";
 
 int dirLevels = (eBitPerCoord - zoom - eBitPerTile - bitsPerFileName) / eBitPerDir;
 
 int i;
 //	printf ("%d\n", dirLevels);
 
 
 for (i = 0; i < dirLevels; i++)
 {
 folderPath = [NSString stringWithFormat: @"%@%@%@%@", hexTable[scaledX & eDirMask], hexTable[scaledY & eDirMask],dirDelimiter,folderPath];
 NSLog(folderPath);
 scaledX >>= eBitPerDir;
 scaledY >>= eBitPerDir;
 }
 
 return [[NSString stringWithFormat: @"%@%@", folderPath, filename] retain];
 }
 
 int satScale(int scale){return 17 - scale;}
 
 int satX(int x){return (520000 + x)*32;}
 
 int satY(int y){return (520000 - y)*32;}
 
 - (YandexMapsTileProvider*) initWithParameters: (NSDictionary*) params
 {
 NSString *type = [params objectForKey: @"Type"];
 
 urlFormat = @"http://base.maps.yandex.net/100/00/%@.png";
 
 return self;
 }
 
 - (void)provide: (QuadTile*)qt
 {
 NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
 
 int zoom = satScale(qt->level+1);
 
 int uu = 1;
 int kk;
 for (kk = 0; kk < qt->level; kk++)
 uu *= 2;
 
 NSString *url = [NSString stringWithFormat: urlFormat, getURL(satX((((qt->i-(uu-1))<<eBitPerTile)<<zoom)/32)+1,satY((((qt->j-uu)<<eBitPerTile)<<zoom)/32)+1,zoom)];
*/