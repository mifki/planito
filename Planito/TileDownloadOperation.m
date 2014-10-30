//
//  TileDownloadOperation.m
//  Planito
//
//  Created by Vitaliy Pronkin on 27.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "TileDownloadOperation.h"
#import "Helpers.h"
#import "QuadTileLayer.h"
#import "FeaturesLayer.h"
#import "QuadTileForDldr.h"
#import "FeaturesTileForDldr.h"

@interface TileDownloadOperation ()
-(void) downloadQTL: (QuadTileLayer*)qtl;
-(void) downloadFL: (FeaturesLayer*)fl;
@end

@implementation TileDownloadOperation

-(void) stop: (id)sender
{
    finished = YES;
    [tdpc cancelOperation:self];
}

-(void) main
{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    if ([l isKindOfClass:[QuadTileLayer class]])
        [self downloadQTL: (QuadTileLayer*)l];
    else if ([l isKindOfClass:[FeaturesLayer class]])
        [self downloadFL: (FeaturesLayer*)l];
    
    finished = YES;
    
    if (![self isCancelled])
        [tdpc performSelectorOnMainThread:@selector(operationFinished:) withObject:self waitUntilDone:NO];
    
    [pool release];    
}

#define DL_QTL \
for (int j = j_beg; j < j_end; j++) \
{ \
    for (int i = i_beg; i < i_end; i++) \
    { \
        if ([self isCancelled]) \
            return; \
\
        NSAutoreleasePool *pool = [NSAutoreleasePool new]; \
\
        QuadTileForDldr *qt = [[QuadTileForDldr alloc] initWithLayer:qtl level:level i:i j:j]; \
\
        if (!tile_cache_valid(qt, NULL)) \
            [l->provider provideSync:qt]; \
\
        [qt release]; \
\
        dltiles++; \
        if (!(dltiles % 10)) \
            [tdpc performSelectorOnMainThread:@selector(updateProgress:) withObject:self waitUntilDone:NO]; \
\
        [pool release]; \
    } \
}

-(void) downloadQTL: (QuadTileLayer*)qtl
{
    for (int level = 0; level <= maxlevel; level++)
    {
        double degx = (l->zeroLevelDegX / (1 << level));
        double degy = (l->zeroLevelDegY / (1 << level));
        
        double ly1 = _maxd(ly, l->ly);
        double ry1 = _mind(ry, l->ry);
        
        int j_beg, j_end;
        if (qtl->isMercator)
        {
            double u = atan(sinh(M_PI)) / M_PI * 180.0;
            if (ry1 > u)
                ry1 = u;
            if (ly1 < -u)
                ly1 = -u;
            
            double pp = (2*2*l->zeroLevelDegY/180.0*M_PI) / (2 << level);
            double l1 = ly1 / 180.0 * M_PI;
            double l2 = ry1 / 180.0 * M_PI;
            
            j_beg = (log(tan((l1+M_PI_2)/2))+M_PI) / pp;
            j_end = ceil((log(tan((l2+M_PI_2)/2))+M_PI) / pp);
        }
        else
        {
            j_beg = (int) ((ly1-qtl->originY) / degy);
            j_end = (int) ceil((ry1-qtl->originY) / degy);
        }
        
        if (lx < -180)
        {
            if (rx > l->lx)
            {
                double lx1 = l->lx;
                double rx1 = _mind(rx, l->rx);
                
                int i_beg = (int) ((lx1-qtl->originX) / degx);
                int i_end = (int) ceil((rx1-qtl->originX) / degx);
                
                DL_QTL
            }
            
            if (360+lx < l->rx)
            {
                double lx1 = _maxd(360+lx, l->lx);
                
                int i_beg = (int) ((lx1-qtl->originX) / degx);
                int i_end = l->cols << level;
                
                DL_QTL
            }
        }
        else if (rx > 180)
        {
            if (rx-360 > l->lx)
            {
                double lx1 = l->lx;
                double rx1 = _mind(rx - 360, l->rx);
                int i_beg = (int) ((lx1-qtl->originX) / degx);
                int i_end = (int) ceil((rx1-qtl->originX) / degx);
                
                DL_QTL
            } 
            
            if (lx < l->rx)
            {
                double lx1 = _maxd(lx, l->lx);
                
                int i_beg = (int) ((lx1-qtl->originX) / degx);
                int i_end = l->cols << level;
                
                DL_QTL
            }
        }
        else
        {
            double lx1 = _maxd(lx, l->lx);
            double rx1 = _mind(rx, l->rx);
            
            int i_beg = (int) ((lx1-qtl->originX) / degx);
            int i_end = (int) ceil((rx1-qtl->originX) / degx);
            
            DL_QTL
        }
    } 
}

#define DL_FL \
for (int j = j_beg; j < j_end; j++) \
{ \
    for (int i = i_beg; i < i_end; i++) \
    { \
        if ([self isCancelled]) \
            return; \
    \
        NSAutoreleasePool *pool = [NSAutoreleasePool new]; \
    \
        FeaturesTileForDldr *ft = [[FeaturesTileForDldr alloc] initWithLayer:fl level:level i:i j:j]; \
    \
        if (!tile_cache_valid(ft, NULL)) \
            [l->provider provideSync:ft]; \
    \
        [ft release]; \
    \
        dltiles++; \
        if (!(dltiles % 10)) \
            [tdpc performSelectorOnMainThread:@selector(updateProgress:) withObject:self waitUntilDone:NO]; \
    \
        [pool release]; \
    } \
}

-(void) downloadFL: (FeaturesLayer*)fl
{
    for (int level = 0; level <= maxlevel; level++)
    {
        double degx = (l->zeroLevelDegX / (1 << level));
        double degy = (l->zeroLevelDegY / (1 << level));
        
        double ly1 = _maxd(ly, l->ly);
        double ry1 = _mind(ry, l->ry);
        
        int j_beg = (int) ((ly1+90) / degy);
        int j_end = (int) ceil((ry1+90) / degy);
        
        if (lx < -180)
        {
            if (rx > l->lx)
            {
                double lx1 = l->lx;
                double rx1 = _mind(rx, l->rx);
                
                int i_beg = (int) ((lx1+180) / degx);
                int i_end = (int) ceil((rx1+180) / degx);
                
                DL_FL
            }
            
            if (360+lx < l->rx)
            {
                double lx1 = _maxd(360+lx, l->lx);
                
                int i_beg = (int) ((lx1+180) / degx);
                int i_end = l->cols << level;
                
                DL_FL
            }
        }
        else if (rx > 180)
        {
            if (rx-360 > l->lx)
            {
                double lx1 = l->lx;
                double rx1 = _mind(rx - 360, l->rx);
                
                int i_beg = (int) ((lx1+180) / degx);
                int i_end = (int) ceil((rx1+180) / degx);
                
                DL_FL
            } 
            
            if (lx < l->rx)
            {
                double lx1 = _maxd(lx, l->lx);
                
                int i_beg = (int) ((lx1+180) / degx);
                int i_end = l->cols << level;
                
                DL_FL
            }
        }
        else
        {
            double lx1 = _maxd(lx, l->lx);
            double rx1 = _mind(rx, l->rx);
            
            int i_beg = (int) ((lx1+180) / degx);
            int i_end = (int) ceil((rx1+180) / degx);
            
            DL_FL
        }
    }       
}

-(void) dealloc
{
    [l release];
    [view release];
}

@end