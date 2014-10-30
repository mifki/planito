//
//  Helpers.m
//  Planito
//
//  Created by Vitaliy Pronkin on 5/21/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "Helpers.h"
#import "Globals.h"
#import "Tile.h"
#import "MapLayer.h"
#import <zlib.h>

@implementation NSString (PlanitoAdditions)
+(NSString*) stringWithUUID {
    CFUUIDRef uuidRef = CFUUIDCreate(kCFAllocatorDefault);
    CFStringRef strRef = CFUUIDCreateString(kCFAllocatorDefault, uuidRef);
    NSString *uuidString = [NSString stringWithString:(NSString*)strRef];
    CFRelease(strRef);
    CFRelease(uuidRef);
    return uuidString;
}

-(NSString*) valueForURLParameter: (NSString*)param
{
    NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"(?:^|[^\\w])%@=([^&]+)", param] options:NSRegularExpressionCaseInsensitive error:NULL];
    NSTextCheckingResult *match = [re firstMatchInString:self options:0 range:NSMakeRange(0, [self length])];

    if (match)
        return [self substringWithRange:[match rangeAtIndex:1]];

    return nil;
}
@end

/*BOOL cache_file_valid(NSString *path, NSTimeInterval expiresIn, NSTimeInterval expiresAt, NSTimeInterval *filetimestamp)
{
    if ((expiresIn == 0 && expiresAt == 0) || workOffline)
        return [[NSFileManager defaultManager] fileExistsAtPath: path];
    
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    
    if (attrs)
    {
        NSDate *fdate = [attrs objectForKey: NSFileModificationDate];
        
        NSTimeInterval ftime = [fdate timeIntervalSinceReferenceDate];
        if (filetimestamp)
            *filetimestamp = ftime;

        return (!expiresAt || ftime > expiresAt) && (!expiresIn || mapView->curtimestamp-ftime < expiresIn);
    }
    
    return NO;
}*/

BOOL tile_cache_valid(Tile *t, NSTimeInterval *timestamp)
{
    char k[32];
    int s;
    
    MapLayer *l = [t layer];
    
    sprintf(k, "%d_%d_%d/info", t->level, t->j, t->i);
    TILEINFO *ti = tchdbget(l->cachedb2, k, strlen(k), &s);
    if (!ti)
        return NO;

    BOOL ret;
    if ((l->dataExpiresIn == 0 && l->dataExpiresAt == 0) || workOffline)
        ret = YES;
    else
    {
        NSTimeInterval ftime = ti->timestamp;
        if (timestamp)
            *timestamp = ftime;
        
        ret = (!l->dataExpiresAt || ftime > l->dataExpiresAt) && (!l->dataExpiresIn || mapView->curtimestamp-ftime < l->dataExpiresIn);        
    }
    
    free(ti);
    return ret;
}


NSString* APPSUPP_PATH()
{
    static NSString *path = nil;
    if (!path)
        path = [[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, 1) objectAtIndex:0] stringByAppendingPathComponent:@"Planito"] retain];
    
    return path;
}

NSString* CACHE_PATH()
{
    static NSString *path = nil;
    if (!path)
        path = [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, 1) objectAtIndex:0] stringByAppendingPathComponent:@"com.mifki.Planito"] retain];
    
    return path;
}

BOOL check_GZ_header(NSData *data)
{
    const unsigned char *bytes = [data bytes];

    return (bytes[0] == 0x1f && bytes[1] == 0x8b);
}

NSData* decompress_GZ (NSData *data)
{
    z_stream astream;
    astream.zalloc = Z_NULL;
    astream.zfree = Z_NULL;
    astream.opaque = Z_NULL;
    astream.next_in = (Byte*)[data bytes];
    astream.avail_in = [data length];
    
    int outspace = [data length]*4;
    Byte *outbuf = malloc(outspace);
    
    inflateInit2 (&astream, 16+MAX_WBITS);
    int zresult;
    while(1)
    {
        astream.next_out = outbuf + astream.total_out;
        astream.avail_out = outspace;	
        zresult = inflate (&astream, Z_NO_FLUSH);
        
        if (zresult == Z_OK && !astream.avail_out)
        {
            outspace = 65536;
            outbuf = realloc(outbuf, astream.total_out+outspace);
        }
        else
            break;
    } 
    inflateEnd(&astream);
    
    if (zresult == Z_STREAM_END)
        return [NSData dataWithBytesNoCopy:outbuf length:astream.total_out freeWhenDone:YES];
    
    free(outbuf);
    return nil;
}

NSString *format_distance_from_meters(double d)
{
    static int msys = 0;
    if (!msys)
    {
        msys = [[[NSLocale currentLocale] objectForKey:NSLocaleUsesMetricSystem] boolValue] ? 1 : 2;
    }

    if (msys == 1)
    {
        static NSString *m, *km;
        if (!m)
        {
            m = NSLocalizedString(@"m", @"");
            km = NSLocalizedString(@"km", @"");
        }
        
        if (d > 100*1000)
            return [NSString stringWithFormat:@"%.0f %@", d/1000, km];
        else if (d > 10*1000)
            return [NSString stringWithFormat:@"%.1f %@", d/1000, km];
        else if (d > 100)
            return [NSString stringWithFormat:@"%.0f %@", d, m];
        else if (d > 10)
            return [NSString stringWithFormat:@"%.1f %@", d, m];
        else
            return [NSString stringWithFormat:@"%.2f %@", d, m];
    }
    else
    {
        d /= 0.3048;
        
        static NSString *mi, *ft;
        if (!mi)
        {
            mi = NSLocalizedString(@"mi", @"");
            ft = NSLocalizedString(@"ft", @"");
        }
        
        if (d > 100*5280)
            return [NSString stringWithFormat:@"%.0f %@", d/5280, mi];
        else if (d > 10*5280)
            return [NSString stringWithFormat:@"%.1f %@", d/5280, mi];
        else if (d > 1*5280)
            return [NSString stringWithFormat:@"%.2f %@", d/5280, mi];
        else if (d > 100)
            return [NSString stringWithFormat:@"%.0f %@", d, ft];
        else if (d > 10)
            return [NSString stringWithFormat:@"%.1f %@", d, ft];
        else
            return [NSString stringWithFormat:@"%.2f %@", d, ft];
    }
}