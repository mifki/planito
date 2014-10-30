//
//  FeaturesLayer.m
//  Planito
//
//  Created by Vitaliy Pronkin on 4/23/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <OpenGL/CGLMacro.h>
#import "FeaturesLayer.h"
#import "FeaturesTile.h"
#import "Globals.h"
#import "Helpers.h"
#import "Downloader.h"

extern CGLContextObj CGL_MACRO_CONTEXT;

@implementation FeaturesLayer

-(FeaturesLayer*) initWithName: (NSString*) _name lid: (NSString*)_lid on: (BOOL) _on opacity: (float) _opacity bbox: (double) _lx : (double) _ly : (double) _rx : (double) _ry zeroLevelDeg: (double) _zld maxLevel: (int) _maxl
{
	if (self=[super initWithName: _name lid: _lid on: _on opacity: _opacity])
    {
        priority = 2;
        lx = _lx;
        ly = _ly;
        rx = _rx;
        ry = _ry;
        
        zeroLevelDegX = _zld;
        zeroLevelDegY = (_zld == 360) ? _zld/2.0 : _zld;
        
        cols = (int) ceil((rx+180) / zeroLevelDegX);
        rows = (int) ceil((ry+90) / zeroLevelDegY);
        
        maxLevel = _maxl;
        
        fullworld = (rx-lx == 360) && (ry-ly == 180);
        
        curupdqueue = &updqueues[0];
        anotherupdqueue = &updqueues[1];
    }
    
	return self;
}	

-(void) render
{
	if (!visible)
		return;

	if (!loaded)
		return;
	
	//glEnable(GL_TEXTURE_2D);
	glEnable(GL_BLEND);
    
    glEnable(GL_POINT_SPRITE_ARB);
    glTexEnvf(GL_POINT_SPRITE_ARB, GL_COORD_REPLACE_ARB, GL_TRUE);

    if (mapView->projmode != PROJ_WORLD)
    {
        glLoadIdentity();
        glOrtho(mapView->lx, mapView->rx, mapView->ly, mapView->ry, 0, 1);
        mapView->projmode = PROJ_WORLD;
    }
        
	if (newStyles)
	{
		int k;
		for (k = 0; k < stylecnt; k++)
		{
			if(!styles[k].tex && styles[k].img)
			{
				GLuint tt;
				glGenTextures(1, &tt);
				styles[k].tex = tt;
				
                GLenum type = [styles[k].img bitsPerSample] == 8 ? GL_UNSIGNED_BYTE : GL_UNSIGNED_SHORT;
				
				glBindTexture(GL_TEXTURE_2D, tt);
				glPixelStorei(GL_UNPACK_ROW_LENGTH, [styles[k].img pixelsWide]);
                glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

                glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
                
                glTexImage2D(GL_TEXTURE_2D, 0, [styles[k].img hasAlpha]?GL_RGBA:GL_RGB, [styles[k].img size].width, [styles[k].img size].height, 0, ([styles[k].img bitsPerPixel]/[styles[k].img bitsPerSample] == 4)?GL_RGBA:GL_RGB,type,[styles[k].img bitmapData]);
				//glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 4);  //shouldn't do anything for 2D view
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
				glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
				
				[styles[k].img release];
				styles[k].img = nil;
			}
		}
		
		newStyles = FALSE;
	}
    
    curstyle = NULL;
    
    ly1 = _maxd(mapView->ly, ly);
    ry1 = _mind(mapView->ry, ry);    

	int j_beg = (int) ((ly1+90) / zeroLevelDegY);
	int j_end = (int) ceil((ry1+90) / zeroLevelDegY);
    
    if (mapView->lx < -180)
    {
        if (mapView->rx > lx)
        {
            lx1 = lx;
            rx1 = _mind(mapView->rx, rx);
            
            plx1 = mapView->lx;
            
            int i_beg = (int) ((lx1+180) / zeroLevelDegX);
            int i_end = (int) ceil((rx1+180) / zeroLevelDegX);
            
            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[FeaturesTile alloc] initWithLayer: self level: 0 i: i j: j];
                    [zeroLevelTiles[j*cols+i] render];
                }
            }
        }
        
        if (360+mapView->lx < rx)
        {
            lx1 = _maxd(360+mapView->lx, lx);
            rx1 = rx;
            
            plx1 = 360+mapView->lx;
            
            int i_beg = (int) ((lx1+180) / zeroLevelDegX);
            int i_end = cols;
            
            glTranslatef(-360, 0, 0);
            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[FeaturesTile alloc] initWithLayer: self level: 0 i: i j: j];
                    [zeroLevelTiles[j*cols+i] render];
                }
            }   
            glTranslatef(360, 0, 0);        
        }
    }
    else if (mapView->rx > 180)
    {
        if (mapView->rx-360 > lx)
        {
            lx1 = lx;
            rx1 = _mind(mapView->rx - 360, rx);
            
            plx1 = mapView->lx - 360;
            
            int i_beg = (int) ((lx1+180) / zeroLevelDegX);
            int i_end = (int) ceil((rx1+180) / zeroLevelDegX);
            
            glTranslatef(360, 0, 0);
            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[FeaturesTile alloc] initWithLayer: self level: 0 i: i j: j];
                    [zeroLevelTiles[j*cols+i] render];
                }
            }   
            glTranslatef(-360, 0, 0);        
        } 
        
        if (mapView->lx < rx)
        {
            lx1 = _maxd(mapView->lx, lx);
            rx1 = rx;
            
            plx1 = mapView->lx;
            
            int i_beg = (int) ((lx1+180) / zeroLevelDegX);
            int i_end = cols;
            
            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[FeaturesTile alloc] initWithLayer: self level: 0 i: i j: j];
                    [zeroLevelTiles[j*cols+i] render];
                }
            }
        }
    }
    else
    {
        lx1 = _maxd(mapView->lx, lx);
        rx1 = _mind(mapView->rx, rx);
        
        plx1 = mapView->lx;
        
        int i_beg = (int) ((lx1+180) / zeroLevelDegX);
        int i_end = (int) ceil((rx1+180) / zeroLevelDegX);
        
        for (int i = i_beg; i < i_end; i++) {
            for (int j = j_beg; j < j_end; j++) {
                if (!zeroLevelTiles[j*cols+i])
                    zeroLevelTiles[j*cols+i] = [[FeaturesTile alloc] initWithLayer: self level: 0 i: i j: j];
                [zeroLevelTiles[j*cols+i] render];
            }
        }
    }
    
    glDisable(GL_POINT_SPRITE_ARB);
}

-(void) update
{
	//TODO: use target bounds in updater ???

    if ((fullworld || IS_REGION_VISIBLE(self)) && mapView->ppd >= minppd)
    {
        if (!visible)
        {
            [self openCache];
            
            if (!zeroLevelTiles)
                zeroLevelTiles = calloc (cols*rows * sizeof(FeaturesTile*), 1);
            
            visible = YES;
            [world updateCredits];
        }
    }
    else
    {
        if (visible)
        {
            visible = NO;
            [world updateCredits];
        }
        return;
    }    
    
    if (downloading)
        return;
    
	if (!loaded)
	{
		downloading = TRUE;
		[NSThread detachNewThreadSelector: @selector(load) toTarget: self withObject: nil];

        return;
	}
    
    struct UPDQUEUE2 *qu = curupdqueue;
    if (qu->updcnt)
    {
        curupdqueue = anotherupdqueue;
        anotherupdqueue = qu;
        
        /*BOOL t = qu->updcnt > 1;
        while (t)
        {
            t = NO;
            for (int i = 0; i < qu->updcnt-1; i++)
            {
                QuadTile *qt = qu->queue[i];
                QuadTile *qt2 = qu->queue[i+1];
                
                if (!qt->udist)
                {
                    double dx1 = qt->cx - mapView->cx;
                    double dy1 = qt->cy - mapView->cy;
                    if (dx1 > 180)
                        dx1 = 360-dx1;
                    if (dx1 < -180)
                        dx1 = 360+dx1;
                    qt->udist = dx1*dx1 + dy1*dy1;
                }
                if (!qt2->udist)
                {
                    double dx2 = qt2->cx - mapView->cx;
                    double dy2 = qt2->cy - mapView->cy;
                    if (dx2 > 180)
                        dx2 = 360-dx2;
                    if (dx2 < -180)
                        dx2 = 360+dx2;
                    qt2->udist = dx2*dx2 + dy2*dy2;
                }
                
                if (qt2->level > qt->level || (qt2->udist < qt->udist && qt2->level >= qt->level))
                {
                    qu->queue[i+1] = qt;
                    qu->queue[i] = qt2;
                    
                    t = YES;
                }
            }
        }*/
        
        for (int i = 0; i < qu->updcnt; i++)
        {
            FeaturesTile *t = qu->queue[i];
            
            if (IS_REGION_VISIBLE(t) && mapView->ppd >= minppd*(1 << t->level))
                [t update];
            t->uflag = 0;
        }
        
        qu->updcnt = 0;
    }
}

-(BOOL) findFeatureForLat: (double)mlat lon: (double)mlon
{
    if (!visible || mlon < lx || mlon > rx || mlat < ly || mlat > ry)
        return NO;
    
    int i = (mlon+180) / zeroLevelDegX;
    int j = (mlat+90) / zeroLevelDegY;
    
    if (zeroLevelTiles[j*cols+i])
        return [zeroLevelTiles[j*cols+i] findFeatureForLat: mlat lon: mlon];
    else
        return NO;
}

-(void) load
{
	NSAutoreleasePool *pool = [NSAutoreleasePool new];

    for (int i = 0; i < stylecnt; i++)
    {
        FEATURESTYLE *s = &styles[i];
        if (!s->iconurl)
            continue;
        
        NSString *iconfn = [s->iconurl lastPathComponent];
        NSString *localfpath = DATA_PATH(lid, "%@", iconfn);
        NSBitmapImageRep *b = nil;

        if ([[NSFileManager defaultManager] fileExistsAtPath:localfpath])
            b = [[NSBitmapImageRep alloc] initWithData:[NSData dataWithContentsOfFile:localfpath]];

        if (!b)
        {
            //remove corrupted local copy
            [[NSFileManager defaultManager] removeItemAtPath: localfpath error:NULL];

            NSData *data = [Downloader getDataSync:s->iconurl status:NULL];
            if (data)
                b = [NSBitmapImageRep imageRepWithData: data];
        
            if (b)
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:[localfpath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
                [data writeToFile:localfpath atomically:NO];
            }
            else
                b = [NSBitmapImageRep imageRepWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:@"defaultpmicon.png"]];
        }
        
        s->img = [b retain];

        [s->iconurl release];
        s->iconurl = nil;
    }
    
    newStyles = YES;
	loaded = YES;
	downloading = NO;
	
	[pool release];
}

-(void) dealloc
{
    if (zeroLevelTiles)
    {
        for (int i = 0; i < cols*rows; i++)
            [zeroLevelTiles[i] release];
        
        free(zeroLevelTiles);
        zeroLevelTiles = NULL;
    }
    
    if (styles)
    {
        for (int i = 0; i < stylecnt; i++)
        {
            [styles[i].styleid release];
            [styles[i].iconurl release];
            [styles[i].img release];
            
            if (styles[i].tex)
                mapView->texs[mapView->tcnt++] = styles[i].tex;
        }
        
        free(styles);
        styles = NULL;
    }
    
    [super dealloc];
}


@end
