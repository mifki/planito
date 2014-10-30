//
//  PathsTile.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <zlib.h>
#import <OpenGL/GL.h>
#import "PathsTile.h"
#import "PathsLayer.h"
#import "Globals.h"
#import "CacheAndRemoteUtils.h"

static inline int getInt(const char *data, long *ppos)
{
	long pos = *ppos;
	int i = (int) (data[pos+3] & 0xff) | (int) (data[pos+2] & 0xff) << 8 |
		((int) (data[pos+1] & 0xff)) << 16 | ((int) (data[pos] & 0xff)) << 24;
	
	(*ppos) += 4;
	
	return i;
}

static inline double getDouble(const char *data, long *ppos)
{
	long pos = *ppos;
	
	long long l = (long long) (data[pos+7] & 0xff)| (long long) (data[pos+6] & 0xff) << 8 |
		(long long) (data[pos+5] & 0xff) << 16 | (long long) (data[pos+4] & 0xff) << 24 |
		(long long) (data[pos+3] & 0xff) << 32 | (long long) (data[pos+2] & 0xff) << 40 |
		((long long) (data[pos+1] & 0xff)) << 48 | ((long long) (data[pos] & 0xff)) << 56;
	
	(*ppos) += 8;
	
	return *(double*)&l;
}

@implementation PathsTile

- (PathsTile*)initWithLayer: (PathsLayer*)_layer level: (int)_level i: (int)_i j: (int)_j;
{
	i = _i;
	j = _j;
	layer = _layer;
	level = _level;
	
	double deg = 180;
	int k;
	for (k = 0; k < level; k++)
		deg /= 4.0;
	lx = -180.0+ ((double) i) * deg;
	rx = lx + deg;
	ly = -90.0 + ((double) j) * deg;
	ry = ly + deg;
	
	nextppd = 16; //layer->minPPD*4;
	for (k = 0; k < level; k++)
	{
		nextppd *= 4;
	}
	
	paths = NULL;
	loading = FALSE;
	childs = NULL;
	hasnext = FALSE;
	
	filename = [DATA_PATH(layer.lid, "%d_%d_%d.txt.gz", level, j, i) retain];
	
	return self;
}

-(void) initChilds
{
	PathsTile **_childs = malloc(16 * sizeof(PathsTile*));
	
	/*
	 _childs[0] = [[PathsTile alloc] initWithLayer: layer level: level+1 i: 2*i j: 2*j];
	 _childs[1] = [[PathsTile alloc] initWithLayer: layer level: level+1 i: 2*i+1 j: 2*j];
	 _childs[2] = [[PathsTile alloc] initWithLayer: layer level: level+1 i: 2*i j: 2*j+1];
	 _childs[3] = [[PathsTile alloc] initWithLayer: layer level: level+1 i: 2*i+1 j: 2*j+1];
	 */
	int k, l;
	for (k = 0; k < 4; k++)
		for (l = 0; l < 4; l++)
			_childs[4*k+l] = [[PathsTile alloc] initWithLayer: layer level: level+1 i: 4*i+k j: 4*j+l];
	
	childs = _childs;
}

- (void)render
{
	if (rx < mapView->lx || ry < mapView->ly || lx > mapView->rx || ly > mapView->ry)
		return;
	
	if (mapView->ppd >= nextppd && childs /*&&
		((childs[0]->paths && !childs[0]->loading) || childs[0]->nodata || childs[0]->rx < mapView->lx || childs[0]->ry < mapView->ly || childs[0]->lx > mapView->rx || childs[0]->ly > mapView->ry) &&
		((childs[1]->paths && !childs[1]->loading) || childs[1]->nodata || childs[1]->rx < mapView->lx || childs[1]->ry < mapView->ly || childs[1]->lx > mapView->rx || childs[1]->ly > mapView->ry) &&
		((childs[2]->paths && !childs[2]->loading) || childs[2]->nodata || childs[2]->rx < mapView->lx || childs[2]->ry < mapView->ly || childs[2]->lx > mapView->rx || childs[2]->ly > mapView->ry) &&
		((childs[3]->paths && !childs[3]->loading) || childs[3]->nodata || childs[3]->rx < mapView->lx || childs[3]->ry < mapView->ly || childs[3]->lx > mapView->rx || childs[3]->ly > mapView->ry)		
		
		&& (childs[0]->paths||childs[1]->paths||childs[2]->paths||childs[3]->paths)*/
		&& hasnext
		){
		
		int k;
		BOOL f = YES;
		
		for (k = 0; k < 16; k++)
			if (!(childs[k]->paths || childs[k]->nodata || childs[k]->rx < mapView->lx || childs[k]->ry < mapView->ly || childs[k]->lx > mapView->rx || childs[k]->ly > mapView->ry))
			{
				f = NO;
				break;
			}
				
				if (f)
				{
					for (k = 0; k < 16; k++)
						[childs[k] render];
					
					/*			
					[childs[0] render];
					[childs[1] render];
					[childs[2] render];
					[childs[3] render];*/
					return;
				}
	}	
		
		if (!paths || loading || nodata)
			return;
		
		int k;
		for (k = 0; k < cnt; k++)
		{
			glBegin(GL_LINE_STRIP);
			int l;
			for (l = 0; l < paths[k].cnt; l++)
			{		
				glVertex2d(paths[k].lon[l],paths[k].lat[l]);
			}
			glEnd();
		}
		
}

- (void)update
{
	if (rx < mapView->lx || ry < mapView->ly || lx > mapView->rx || ly > mapView->ry)
		return;
	
	if (mapView->ppd >= nextppd && hasnext)
	{
		if (!childs)
			[self initChilds];
		int k;
		for (k = 0; k < 16; k++)
			[childs[k] update];
		/*
		 [childs[0] update];
		 [childs[1] update];
		 [childs[2] update];
		 [childs[3] update];*/
		//		return;
	}		
	
	if (paths || loading || nodata)
		return;
	
	loading = TRUE;
	
	if (cache_file_valid(filename, layer->dataExpiresIn, layer->dataExpiresAt))
	{
		NSData *data = [NSData dataWithContentsOfFile: filename];
		if (data)
			[self loadFromData: data];
		else
		{
			nodata = TRUE;
			loading = FALSE;
		}
	} else //TODO: ndown here
		[NSThread detachNewThreadSelector: @selector(provide:) toTarget: layer->provider withObject: self];
}	

- (void)loadFromData: (NSData*)data	
{	
	unsigned char *cdata = (char*) [data bytes];
	
	////////////
	
	hasnext = (BOOL)((char*)[data bytes])[0];
	z_streamp astream = malloc(sizeof(z_stream));
	
    int result, zresult;
    NSMutableData *outData;
	
    astream->zalloc = Z_NULL;
    astream->zfree = Z_NULL;
    astream->opaque = Z_NULL;
    astream->next_in = ((char*)[data bytes])+1;
	astream->avail_in = [data length]-1;
	
	unsigned char *buf = malloc(16384);
	outData = [NSMutableData dataWithCapacity: 1000000];
	
	result = inflateInit (astream);
	
	do {
		astream->next_out = buf;
		astream->avail_out = 16384;	
		zresult = inflate (astream, Z_NO_FLUSH);
		[outData appendBytes:buf length:(16384-astream->avail_out)];
	} while(astream->avail_out == 0);
	
	result = inflateEnd(astream);
	//if (result != Z_OK) return NO;
	//TODO: check for errors here!
	
	free(astream);
	free(buf);
	
	///////////
	
	const char *ddata = [outData mutableBytes];
	
	
	long pos = 0;
	
	
	cnt = getInt(ddata, &pos);
	paths = malloc(cnt*sizeof(path));
	int k;
	for (k = 0; k < cnt; k++)
	{
		paths[k].cnt = getInt(ddata, &pos);
		paths[k].lat = malloc(paths[k].cnt*sizeof(double));
		paths[k].lon = malloc(paths[k].cnt*sizeof(double));		
		
		int l;
		for (l = 0; l < paths[k].cnt; l++)
		{
			paths[k].lon[l] = getDouble(ddata, &pos);
			paths[k].lat[l] = getDouble(ddata, &pos);
		}
	}	
	
	loading = FALSE;
}

-(void) dealloc
{
    NSLog(@"PT dealloc");
    
    if (childs)
    {
        for (int i = 0; i < 16; i++)
            [childs[i] dealloc];
    }
    
    [super dealloc];
}

@end
