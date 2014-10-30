//
//  RemoteTileProvider.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "RemoteTileProvider.h"
#import "Tile.h"
#import "Globals.h"
#import "minizip/unzip.h"
#import "Downloader.h"
#import "Helpers.h"
#import "MapLayer.h"

@interface RemoteTileProvider()
-(NSData*) decompress: (NSData*)data;
@end

@implementation RemoteTileProvider
@synthesize urlFormat=_urlFormat;

-(id) initWithParameters: (NSDictionary*)params
{
    if (self = [super init])
    {
        NSString *url = [params objectForKey: @"URL"];

        do {
            NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"\\{D:([^}]+?)(?:\\|([^}]+))?\\}" options:0 error:NULL];
            NSTextCheckingResult *match = [re firstMatchInString:url options:0 range:NSMakeRange(0, [url length])];
            
            if (!match)
                break;

            NSString *s = [[NSUserDefaults standardUserDefaults] stringForKey:[url substringWithRange:[match rangeAtIndex:1]]];
            if (!s)
            {
                NSRange r = [match rangeAtIndex:2];
                if (r.location != NSNotFound)
                    s = [url substringWithRange:r];
                else
                    s = @"";
            }
            url = [url stringByReplacingCharactersInRange:[match range] withString:s];
        } while (1);
        
        self.urlFormat = url;
        
        NSString *compr = [[params objectForKey: @"Compression"] lowercaseString];
        if ([compr isEqualToString:@"gz"])
            compression = GZ;
        else if ([compr isEqualToString:@"kmz"])
            compression = KMZ;
        
        maxDownloads = 2;
    }
    
    return self;
}

-(BOOL) canProvide
{
    return ndown < maxDownloads && !workOffline;
}

-(NSString*) buildURLForTile: (Tile*)t
{
    NSMutableString *url = [NSMutableString stringWithString:_urlFormat];
    
    [url replaceOccurrencesOfString:@"{l}" withString:[[NSNumber numberWithInt:t->level] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{x}" withString:[[NSNumber numberWithInt:t->i] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{y}" withString:[[NSNumber numberWithInt:t->j] stringValue] options:0 range:NSMakeRange(0, [url length])];
    
    NSRange r = [url rangeOfString:@"{Y}"];
    if (r.location != NSNotFound)
    {
        NSString *s = [[NSNumber numberWithInt: ([t layer]->rows << t->level) - 1 - t->j] stringValue];
        [url replaceCharactersInRange:r withString:s];
    }
    
    [url replaceOccurrencesOfString:@"{lx}" withString:[[NSNumber numberWithDouble:t->lx] stringValue] options:0 range:NSMakeRange(0, [url length])];    
    [url replaceOccurrencesOfString:@"{rx}" withString:[[NSNumber numberWithDouble:t->rx] stringValue] options:0 range:NSMakeRange(0, [url length])];    
    [url replaceOccurrencesOfString:@"{ly}" withString:[[NSNumber numberWithDouble:t->ly] stringValue] options:0 range:NSMakeRange(0, [url length])];    
    [url replaceOccurrencesOfString:@"{ry}" withString:[[NSNumber numberWithDouble:t->ry] stringValue] options:0 range:NSMakeRange(0, [url length])];    
    
    return url;
}

-(void) provideAsync: (Tile*)t
{
    ndown++;
    
    [[t layer] retain];
    [NSThread detachNewThreadSelector: @selector(_provide:) toTarget: self withObject: t];	
    //gdownloading++;
    //NSString *url = [self buildURLForTile:t];
    //Downloader *dldr = [[Downloader alloc] initWithURLString:url delegate:self];
    //dldr->obj = t;
}

-(void) downloader: (Downloader*)dl didFinishWithData: (NSData*)data
{
    ndown--;
    if (compression && data)
        data = [self decompress: data];
    Tile *t = dl->obj;
    
    [self gotRemoteData: data forTile: t];    
    gdownloading--;
    [dl release];
}

-(void) downloader: (Downloader*)dl didFailWithStatus: (int)status
{
    ndown--;
    gdownloading--;

    Tile *t = dl->obj;
    [t gotDataFromProvider: nil canRetry: YES];    
    [dl release];
}

-(void) provideSync: (Tile*)t
{
    //gdownloading++;
    NSString *url = [self buildURLForTile:t];
        
    int statusCode;
    NSData *data = [Downloader getDataSync:url status:&statusCode];
        
    if (statusCode == 200)
    {
        if (compression && data)
            data = [self decompress: data];

        [self gotRemoteData: data forTile: t];
    }
    else
        [t gotDataFromProvider: nil canRetry: YES];    
    //gdownloading--;
}

- (void)_provide: (Tile*)t
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    gdownloading++;
    
    NSString *url = [self buildURLForTile:t];
    
    //NSLog(@"%d %d %d %@", t->level, t->i, t->j, url);
        
    int statusCode;
    NSData *data = [Downloader getDataSync:url status:&statusCode];
    ndown--;
    
    if (statusCode == 200)
    {
        if (compression && data)
            data = [self decompress: data];

        [self gotRemoteData: data forTile: t];
    }
    else
        [t gotDataFromProvider: nil canRetry: YES];

    [[t layer] release];

    gdownloading--;
	[pool release];
}

struct datareaderstate {
    NSData *data;
    uLong pos;
    uLong size;
};

static voidpf zopen_file_func (voidpf opaque, const char* filename, int mode)
{
    struct datareaderstate *drs = malloc(sizeof(struct datareaderstate));

    drs->data = filename;
    drs->size = [drs->data length];
    drs->pos = 0;

    return drs;
}

static uLong zread_file_func (voidpf opaque, voidpf stream, void* buf, uLong size)
{
    struct datareaderstate *drs = stream;

    uLong len;
    if (size > drs->size-drs->pos)
        len = drs->size-drs->pos;
    else
        len = size;
    
    [drs->data getBytes: buf range: NSMakeRange(drs->pos, len)];
    drs->pos += len;
    
    return len;
}

static uLong zwrite_file_func (voidpf opaque, voidpf stream, const void* buf, uLong size)
{
    return 0;
}

static long ztell_file_func (voidpf opaque, voidpf stream)
{
    struct datareaderstate *drs = stream;

    return drs->pos;
}

static long zseek_file_func (voidpf opaque, voidpf stream, uLong offset, int origin)
{
    struct datareaderstate *drs = stream;

    switch (origin)
    {
        case ZLIB_FILEFUNC_SEEK_CUR:
            drs->pos += offset;
            break;
        case ZLIB_FILEFUNC_SEEK_SET:
            drs->pos = offset;
            break;
        case ZLIB_FILEFUNC_SEEK_END:
            drs->pos = drs->size + offset;
            break;
    }
    
    if (drs->pos > drs->size)
        drs->pos = drs->size;

    return 0;
}

static int zclose_file_func (voidpf opaque, voidpf stream)
{
    struct datareaderstate *drs = stream;
    free(drs);

    return 0;
}

static int zerror_file_func (voidpf opaque, voidpf stream)
{
    //NSInputStream *is = stream;
    return 0;//[is streamError] != nil;
}

-(NSData*) decompress: (NSData*)data
{
    if (compression == GZ)
        return decompress_GZ(data);
    
    if (compression == KMZ)
    {
        NSMutableData *outdata = nil;
        
        zlib_filefunc_def filefuncs;
        filefuncs.zclose_file = zclose_file_func;
        filefuncs.zerror_file = zerror_file_func;
        filefuncs.zopen_file = zopen_file_func;
        filefuncs.zread_file = zread_file_func;
        filefuncs.zseek_file = zseek_file_func;
        filefuncs.ztell_file = ztell_file_func;
        filefuncs.zwrite_file = zwrite_file_func;
        
        unzFile unzf = unzOpen2(data, &filefuncs);
        if (unzf)
        {
            int ret = unzGoToFirstFile(unzf);
            if (ret == UNZ_OK)
            {
                do {
                    ret = unzOpenCurrentFile(unzf);
                    if (ret != UNZ_OK)
                        break;
                    
                    char filename[255];
                    unz_file_info finfo;
                    
                    ret = unzGetCurrentFileInfo(unzf, &finfo, filename, 255, NULL, 0, NULL, 0);
                    if (ret != UNZ_OK)
                    {
                        unzCloseCurrentFile(unzf);
                        ret = unzGoToNextFile(unzf);
                        continue;
                    }
                    filename[finfo.size_filename] = '\0';

                    int l = finfo.size_filename;
                    if (l > 4 && !strcmp(filename+l-4, ".kml"))
                    {
                        char *buf = malloc(finfo.uncompressed_size);
                        
                        int read = unzReadCurrentFile(unzf, buf, finfo.uncompressed_size);
                        if (read == finfo.uncompressed_size)
                            outdata = [NSData dataWithBytesNoCopy:buf length:read freeWhenDone:YES];
                            
                        unzCloseCurrentFile(unzf);
                        break;
                    }
                    
                    unzCloseCurrentFile(unzf);
                    ret = unzGoToNextFile(unzf);
                } while(ret == UNZ_OK);
            }
        
            unzClose(unzf);
        }
        
        return outdata;
    }
    
    return data;
}

- (void)gotRemoteData: (NSData*)data forTile: (Tile*)t
{
    [t gotDataFromProvider: data canRetry: NO]; //status was 200=OK, so why retry?
}

-(void) dealloc
{
    [_urlFormat release];
    
    [super dealloc];
}

@end
