//
//  Downloader.m
//  Planito
//
//  Created by Vitaliy Pronkin on 31.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "Downloader.h"

#define TIMEOUT 10.0

static NSString *userAgent;

@interface DownloaderSyncDelegate : NSObject {
@public
    BOOL running;
    NSMutableData *dldata;
    int statusCode;
}
@end

@implementation DownloaderSyncDelegate

-(id) init
{
    if (self=[super init])
    {
        running = YES;
    }
    
    return self;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    statusCode = [response statusCode];
    if (statusCode != 200)
        running = NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (!dldata)
        dldata = [data mutableCopy];
    else
        [dldata appendData: data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    statusCode = 0;
    running = NO;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    running = NO;
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

-(void) dealloc
{
    [dldata release];
    
    [super dealloc];
}
@end

@implementation Downloader

+(void) initialize
{
    NSDictionary *d = [[NSBundle mainBundle] infoDictionary];
    
    userAgent = [[NSString stringWithFormat:@"%@ %@ (%@)", [d objectForKey:@"CFBundleName"], [d objectForKey:@"CFBundleShortVersionString"], [d objectForKey:@"CFBundleVersion"]] retain];
}

+(NSData*) getDataSync: (NSString*)urlstr status: (int*)status
{
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlstr]];
    [req setTimeoutInterval:TIMEOUT];
    [req setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    
    DownloaderSyncDelegate *state = [[DownloaderSyncDelegate alloc] init];
    NSURLConnection *connection=[[NSURLConnection alloc] initWithRequest:req delegate:state];
    
    NSDate *future = [NSDate distantFuture];
    NSRunLoop *loop = [NSRunLoop currentRunLoop];    
    while (state->running)
        [loop runMode:NSDefaultRunLoopMode beforeDate:future];

    [connection release];
    
    NSData *data = [[state->dldata retain] autorelease];
    
    int _status = state->statusCode;
    
    if (status)
        *status = _status;

    [state release];
    
    if (_status == 200)
        return data;
    else
        return nil;
}

- (id)initWithURLString: (NSString*)urlstr delegate: (id)_delegate// object: (id)_obj
{
    if (self = [super init]) {
        delegate = _delegate;
        //obj = _obj;
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString: urlstr]];
        [req setTimeoutInterval:TIMEOUT];
        [req setValue:userAgent forHTTPHeaderField:@"User-Agent"];
        [req setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        
        conn = [[NSURLConnection alloc] initWithRequest: req delegate: self];
    }
    
    return self;
}

-(void) cancel
{
    [conn cancel];
}

-(void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    int status = [response statusCode];
    if (status != 200)
    {
        [connection cancel];
        [delegate downloader: self didFailWithStatus: status];
        [conn release];
        conn = nil;
    }
}

-(void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (!dldata)
        dldata = [data mutableCopy];
    else
        [dldata appendData: data];
}

-(void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [delegate downloader: self didFailWithStatus: 0];

    [conn release];
    conn = nil;
}

-(void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    [delegate downloader: self didFinishWithData: dldata];

    [conn release];
    conn = nil;
}

-(NSCachedURLResponse*) connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return nil;
}

-(void) dealloc
{
    [dldata release];
    [conn release];
    
    [super dealloc];
}

@end
