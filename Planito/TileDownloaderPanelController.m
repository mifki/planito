//
//  TileDownloaderPanelController.m
//  Planito
//
//  Created by Vitaliy Pronkin on 23.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "TileDownloaderPanelController.h"
#import "Globals.h"
#import "MapLayer.h"
#import "QuadTileLayer.h"
#import "FeaturesLayer.h"
#import "TileDownloadOperation.h"
#import "Helpers.h"

@interface TileDownloaderPanelController ()
-(void) buildLayerList;
-(NSUInteger) countTiles;
-(void) rebuildOperationViews;
-(void) updateDockProgress;
@end

@implementation TileDownloaderPanelController

-(void) awakeFromNib
{
    height = 377 - 164 - 4;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelAll) name:@"WorldWillChange" object:NSApp];
}

- (void)popoverWillShow:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(countTiles) name:@"MapViewChanged" object:mapView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buildLayerList) name:@"ActiveLayersChanged" object:mapView];
    
    if (!queue)
    {
        queue = [NSOperationQueue new];
        [queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    }
    
    [self buildLayerList]; //will also count tiles
    
    [ourPopover setContentSize:NSMakeSize(self.view.frame.size.width, height)];
}

- (void)popoverWillClose:(NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"MapViewChanged" object:mapView];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"ActiveLayersChanged" object:mapView];
}

-(void) cancelAll
{
    NSArray *ops = [queue operations];
    for (TileDownloadOperation *op in ops)
        [op->view removeFromSuperview];
    
    [queue cancelAllOperations];
    [self rebuildOperationViews];
}

-(void) buildLayerList
{
    NSString *seltitle = [layerSelector selectedItem].title;
    
    NSMenu *m = [layerSelector menu];
    
    [m removeAllItems];

    for (int k = 0; k < mapView->lcnt; k++)
    {
        MapLayer *l = mapView->layers[k];
        if (!l->docache)
            continue;
        
        NSMenuItem *mi = [m addItemWithTitle:[l fullName] action:NULL keyEquivalent:@""];
        mi.tag = k;
    }
    
    if (!mapView->lcnt)
        [layerSelector setTitle:@""];
    else
        [layerSelector selectItemWithTitle:seltitle];
    
    [self layerChanged:nil];
}

-(void) useCurrentLevel: (id)sender
{
    NSInteger k = [layerSelector selectedTag];
    if (k == -1)
        return;
    
    double lvl = 0;

    MapLayer *l = mapView->layers[k];
    if ([l isKindOfClass:[QuadTileLayer class]])
    {
        lvl = floor(log2(mapView->ppd * l->zeroLevelDegX / ((QuadTileLayer*)l)->nextTileSize));
        if (lvl > l->maxLevel)
            lvl = l->maxLevel;
    }
    else if ([l isKindOfClass:[FeaturesLayer class]])
    {
        lvl = floor(log2(mapView->ppd / ((FeaturesLayer*)l)->minppd));
        if (lvl > l->maxLevel)
            lvl = l->maxLevel;
    }
    
    [levelSlider setDoubleValue:lvl];
    
    [self countTiles];
}

-(void) layerChanged:(id)sender
{
    NSInteger k = [layerSelector selectedTag];
    if (k == -1)
    {
        [levelSlider setEnabled:NO];
        [startButton setEnabled:NO];
        [useCurrentLevelButton setEnabled:NO]; 
        [totalTilesLabel setStringValue: [NSLocalizedString(@"total-tiles-to-cache", @"") stringByAppendingString:@"—"]];
    }
    else
    {
        [levelSlider setEnabled:YES];
        [startButton setEnabled:YES];
        [useCurrentLevelButton setEnabled:YES];

        MapLayer *l = mapView->layers[k];
        [levelSlider setMaxValue:l->maxLevel];
        [levelSlider setNumberOfTickMarks:l->maxLevel+1];
        
        [self countTiles];
    }
}

-(void) levelChanged: (id)sender
{
    [self countTiles];
}

-(NSUInteger) countTiles
{
    NSUInteger totaltiles = 0;
    
    NSInteger k = [layerSelector selectedTag];
    if (k == -1) //this actually can't happen
        return 0;
    
    int maxlevel = [levelSlider doubleValue];
    
    MapLayer *l = mapView->layers[k];

    if (IS_REGION_VISIBLE(l))
    {
        //TODO: fix counting duplicate tiles
        if ([l isKindOfClass:[QuadTileLayer class]])
        {
            QuadTileLayer *qtl = (QuadTileLayer*)l;
            
            for (int level = 0; level <= maxlevel; level++)
            {
                double degx = (l->zeroLevelDegX / (1 << level));
                double degy = (l->zeroLevelDegY / (1 << level));
                
                double ly1 = _maxd(mapView->ly, l->ly);
                double ry1 = _mind(mapView->ry, l->ry);

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
                
                if (mapView->lx < -180)
                {
                    if (mapView->rx > l->lx)
                    {
                        double lx1 = l->lx;
                        double rx1 = _mind(mapView->rx, l->rx);
                        
                        int i_beg = (int) ((lx1-qtl->originX) / degx);
                        int i_end = (int) ceil((rx1-qtl->originX) / degx);
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    }
                    
                    if (360+mapView->lx < l->rx)
                    {
                        double lx1 = _maxd(360+mapView->lx, l->lx);
                        
                        int i_beg = (int) ((lx1-qtl->originX) / degx);
                        int i_end = l->cols << level;
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    }
                }
                else if (mapView->rx > 180)
                {
                    if (mapView->rx-360 > l->lx)
                    {
                        double lx1 = l->lx;
                        double rx1 = _mind(mapView->rx - 360, l->rx);
                        int i_beg = (int) ((lx1-qtl->originX) / degx);
                        int i_end = (int) ceil((rx1-qtl->originX) / degx);
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    } 
                    
                    if (mapView->lx < l->rx)
                    {
                        double lx1 = _maxd(mapView->lx, l->lx);
                        
                        int i_beg = (int) ((lx1-qtl->originX) / degx);
                        int i_end = l->cols << level;
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    }
                }
                else
                {
                    double lx1 = _maxd(mapView->lx, l->lx);
                    double rx1 = _mind(mapView->rx, l->rx);

                    int i_beg = (int) ((lx1-qtl->originX) / degx);
                    int i_end = (int) ceil((rx1-qtl->originX) / degx);
                    
                    totaltiles += (i_end-i_beg)*(j_end-j_beg);
                }
            }            
        }
        else if ([l isKindOfClass:[FeaturesLayer class]])
        {
            for (int level = 0; level <= maxlevel; level++)
            {
                double degx = (l->zeroLevelDegX / (1 << level));
                double degy = (l->zeroLevelDegY / (1 << level));
                
                double ly1 = _maxd(mapView->ly, l->ly);
                double ry1 = _mind(mapView->ry, l->ry);

                int j_beg = (int) ((ly1+90) / degy);
                int j_end = (int) ceil((ry1+90) / degy);
                
                if (mapView->lx < -180)
                {
                    if (mapView->rx > l->lx)
                    {
                        double lx1 = l->lx;
                        double rx1 = _mind(mapView->rx, l->rx);
                        
                        int i_beg = (int) ((lx1+180) / degx);
                        int i_end = (int) ceil((rx1+180) / degx);
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    }
                    
                    if (360+mapView->lx < l->rx)
                    {
                        double lx1 = _maxd(360+mapView->lx, l->lx);
                        
                        int i_beg = (int) ((lx1+180) / degx);
                        int i_end = l->cols << level;
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    }
                }
                else if (mapView->rx > 180)
                {
                    if (mapView->rx-360 > l->lx)
                    {
                        double lx1 = l->lx;
                        double rx1 = _mind(mapView->rx - 360, l->rx);
                        
                        int i_beg = (int) ((lx1+180) / degx);
                        int i_end = (int) ceil((rx1+180) / degx);
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    } 
                    
                    if (mapView->lx < l->rx)
                    {
                        double lx1 = _maxd(mapView->lx, l->lx);
                        
                        int i_beg = (int) ((lx1+180) / degx);
                        int i_end = l->cols << level;
                        
                        totaltiles += (i_end-i_beg)*(j_end-j_beg);
                    }
                }
                else
                {
                    double lx1 = _maxd(mapView->lx, l->lx);
                    double rx1 = _mind(mapView->rx, l->rx);

                    int i_beg = (int) ((lx1+180) / degx);
                    int i_end = (int) ceil((rx1+180) / degx);
                    
                    totaltiles += (i_end-i_beg)*(j_end-j_beg);
                }
            }            
        }
    }
    
    if (totaltiles > 1000000)
    {
        [totalTilesLabel setStringValue: [NSLocalizedString(@"total-tiles-to-cache", @"") stringByAppendingString:NSLocalizedString(@"too-many", @"")]];
        [startButton setEnabled:NO];
        return 0;
    }

    [startButton setEnabled:YES];
    [totalTilesLabel setStringValue: [NSLocalizedString(@"total-tiles-to-cache", @"") stringByAppendingString:[[NSNumber numberWithUnsignedInteger: totaltiles] stringValue]]];

    return totaltiles;
}

-(void) start: (id)sender
{
    NSInteger k = [layerSelector selectedTag];
    if (k == -1)
        return;
    
    NSUInteger count = [self countTiles];
    if (!count)
        return;
    
    TileDownloadOperation *tdo = [TileDownloadOperation new];
    tdo->tdpc = self;

    [NSBundle loadNibNamed:@"TileDownloadOperationView" owner:tdo];
    [tdo->view retain];
    
    [tdo->progressIndicator setUsesThreadedAnimation:YES];
    
    MapLayer *l = mapView->layers[k];
    tdo->l = [l retain];
    
    [tdo->label setStringValue:[l fullName]];
    
    tdo->lx = mapView->lx;
    tdo->ly = mapView->ly;
    tdo->rx = mapView->rx;
    tdo->ry = mapView->ry;
    
    tdo->maxlevel = [levelSlider doubleValue];
    
    [tdo->progressIndicator setMaxValue:count];

    [queue addOperation:tdo];
    [tdo release];
    
    [self rebuildOperationViews];
}

-(void) operationFinished: (TileDownloadOperation*)op
{
    [op->view removeFromSuperview];
    
    [self rebuildOperationViews];
}

-(void) cancelOperation: (TileDownloadOperation*)op
{
    [op cancel];
    
    [op->view removeFromSuperview];
    
    [self rebuildOperationViews];
    [self updateDockProgress];
}

-(void) resizeContainer
{
    
}

-(void) rebuildOperationViews
{
    float y = 0;
    float w = operationsBox.bounds.size.width;

    NSArray *ops = [queue operations];
    for (TileDownloadOperation *op in ops)
    {
        if (op->finished || [op isCancelled])
            continue; 
        
        float h = op->view.frame.size.height;
        op->view.frame = NSMakeRect(0, y, w, h);
        y += h;
        
        if (![op->view superview])
        {
            [op->view setAutoresizingMask:NSViewMaxYMargin];
            [operationsBox addSubview:op->view];
        }
    }
    
    //For some reason controls will be positioned incorrectly if reized when hidden, so we just save new height in this case
    height = y + (377-164+(y ? 0 : -4));
    if ([ourPopover isShown])
        [ourPopover setContentSize:NSMakeSize(self.view.frame.size.width, height)];
    
    if (!ind && y > 0)
    {
        ind = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 10, 128, 20)];
        ind.autoresizingMask = NSViewWidthSizable;
        [ind setStyle:NSProgressIndicatorBarStyle];
        [ind setControlTint:NSBlueControlTint];
        [ind setBezeled:NO];
        [ind setMinValue:0];
        [ind setMaxValue:1];
        [ind setIndeterminate:NO];
        
        NSImageView *iv = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 128, 128)];
        iv.image = [NSApp applicationIconImage];
        iv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [iv addSubview:ind];
        [ind release];
        
        [[NSApp dockTile] setContentView:iv];
        [[NSApp dockTile] display];
        [iv release];
        
        [ourButton setImage:[NSImage imageNamed:@"57-download-on.png"]];
    }
    else if (ind && y == 0)
    {
        [[NSApp dockTile] setContentView:nil];
        ind = nil;
        
        [ourButton setImage:[NSImage imageNamed:@"57-download.png"]];
    }
}

-(void) updateProgress: (TileDownloadOperation*)op
{
    [op->progressIndicator setDoubleValue:op->dltiles];
    
    [self updateDockProgress];
}

-(void) updateDockProgress
{
    double total=0, cur=0;
    NSArray *ops = [queue operations];
    for (TileDownloadOperation *op in ops)
    {
        total += [op->progressIndicator maxValue];
        cur += op->dltiles;
    }    
    
    [ind setDoubleValue:cur/total];
    [[NSApp dockTile] display];
}

-(void) dealloc
{
    [self cancelAll];
    [queue release];
    
    [super dealloc];
}

@end
