//
//  PathsLayer.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <OpenGL/GL.h>
#import "PathsLayer.h"
#import "PathsTile.h"
#import "Globals.h"

@implementation PathsLayer

-(PathsLayer*) initWithName: (NSString*) _name lid: (NSString*) _lid on: (BOOL) _on opacity: (float) _opacity color: (float)_r:(float)_g:(float)_b dataRoot: (NSString*) _dataRoot provider: (id)_provider minPPD: (float)_minPPD
{
	[super initWithName: _name lid: _lid on: _on opacity: _opacity];
	priority = 1;
	dataRoot = [_dataRoot retain];
	
	cols = 2;//(int) ceil(360.0 / 180);
	rows = 1;//(int) ceil(180.0 / 180);
	zeroLevelTiles = malloc (cols*rows * sizeof(PathsTile*));
	int i;
	for (i = 0; i < cols*rows; i++)
		zeroLevelTiles[i] = nil;
	
	minPPD = _minPPD;
	minPPD2 = minPPD / 2;
	r = _r;
	g = _g;
	b = _b;
	
	if (_provider)
		provider = _provider;
	else
		provider = self;
	
	return self;
}

-(void) render
{
	glDisable(GL_TEXTURE_2D);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glEnable(GL_BLEND);
	glEnable(GL_LINE_SMOOTH);
	glLineWidth(1.5f);
    glDisable(GL_STENCIL_TEST);	
	
	if (mapView->projmode != 0) {
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(mapView->lx, mapView->rx, mapView->ly, mapView->ry, 0, 1);
		mapView->projmode = 0;
	}
	
	if (mapView->ppd < minPPD2)
		return;
	
	if (mapView->ppd < minPPD)
	{
		double op = opacity*(1-(minPPD-mapView->ppd)/(minPPD-minPPD2));
		glColor4f(r, g, b, op);
	} else
		glColor4f(r, g, b, opacity);
	
	if (zeroLevelTiles[0] != nil)
		[zeroLevelTiles[0] render];
    if (zeroLevelTiles[1] != nil)
        [zeroLevelTiles[1] render];
    
    return;

	
	double lx1, ly1, rx1, ry1;
	lx1 = mapView->lx;
	ly1 = mapView->ly;
	rx1 = mapView->rx;
	ry1 = mapView->ry;
	if (lx1 < -180)
		lx1 = -180;
	if (ly1 < -90)
		ly1 = -90;
	if (rx1 > 180)
		rx1 = 180;
	if (ry1 > 90)
		ry1 = 90;
	int i_beg = (int) ((lx1+180.0) / 180.0);
	int j_beg = (int) ((ly1+90.0) / 180.0);
	int i_end = (int) ceil((rx1+180.0) / 180.0);
	int j_end = (int) ceil((ry1+90.0) / 180.0);
	if (i_end > cols) i_end = cols;
	if (j_end > rows) j_end = rows;
	int i, j;
	for (i = i_beg; i < i_end; i++) {
		for (j = j_beg; j < j_end; j++) {
			if (zeroLevelTiles[j*cols+i] != nil)
				[zeroLevelTiles[j*cols+i] render];
		}
	}	
}

-(void) update
{
	//TODO: targetlx here
    //	if (mapView->lx > rx || mapView->rx < lx || mapView->ly > ry || mapView->ry < ly)
    //		return;
	
    //	w2 = mapView->ppd * zeroLevelDegX;
	
    //	if (w2 < minTileSize)
    //		return;
	
	if (zeroLevelTiles[0] == nil)
		zeroLevelTiles[0] = [[PathsTile alloc] initWithLayer: self level: 0 i: 0 j: 0];
	if (zeroLevelTiles[1] == nil)
		zeroLevelTiles[1] = [[PathsTile alloc] initWithLayer: self level: 0 i: 1 j: 0];
    
	[zeroLevelTiles[0] update];
    [zeroLevelTiles[1] update];	
    
	return;
	
	double lx1 = mapView->lx;
	double ly1 = mapView->ly;
	double rx1 = mapView->rx;
	double ry1 = mapView->ry;
	
	if (lx1 < -180)
		lx1 = -180;
	if (ly1 < -90)
		ly1 = -90;
	if (rx1 > 180)
		rx1 = 180;
	if (ry1 > 90)
		ry1 = 90;
	int i_beg = (int) ((lx1+180.0) / 180.0);
	int j_beg = (int) ((ly1+90.0) / 180.0);
	int i_end = (int) ceil((rx1+180.0) / 180.0);
	int j_end = (int) ceil((ry1+90.0) / 180.0);
	if (i_end > cols) i_end = cols;
	if (j_end > rows) j_end = rows;
	int i, j;
	for (i = i_beg; i < i_end; i++) {
		for (j = j_beg; j < j_end; j++) {
			if (zeroLevelTiles[j*cols+i] == nil)
				zeroLevelTiles[j*cols+i] = [[PathsTile alloc] initWithLevel: 0 i: i j: j];
			[zeroLevelTiles[j*cols+i] update];
		}
	}	
}

- (void)provide: (PathsTile*)pt
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	NSString *url = [NSString stringWithFormat: @"%@/%d_%d_%d.txt.gz", dataRoot, pt->level, pt->j, pt->i];
	NSURLRequest *req = [NSURLRequest requestWithURL: [NSURL URLWithString: url]];
	NSURLResponse *resp;
	NSError *err;
	NSData *dat = [NSURLConnection sendSynchronousRequest: req returningResponse: &resp error: &err];	
	
	if ([resp statusCode] == 200)
	{
		[pt loadFromData: dat];
		@try
		{
			//TODO: write only if locally cached
            [[NSFileManager defaultManager] createDirectoryAtPath:[pt->filename stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
            
			[dat writeToFile: pt->filename atomically: YES];
		}
		@catch (NSException *e)
		{
		}
	}
	else
	{
		pt->nodata = TRUE;
		pt->loading = FALSE;
	}
	
	[pool release];	
}

-(void) dealloc
{
    NSLog(@"PL dealloc");
    
    if (zeroLevelTiles)
    {
        for (int i = 0; i < cols*rows; i++)
            [zeroLevelTiles[i] release];
    }
    
    [super dealloc];
}

@end
