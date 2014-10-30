//
//  QuadTileLayer.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 mifki. All rights reserved.
//

#include <OpenGL/CGLMacro.h> 
#import "QuadTileLayer.h"
#import "QuadTile.h"
#import "Globals.h"
#import "Helpers.h"

extern CGLContextObj CGL_MACRO_CONTEXT;

@implementation QuadTileLayer

-(QuadTileLayer*) initWithName: (NSString*) _name lid: (NSString*)_lid on: (BOOL) _on opacity: (float) _opacity bbox: (double) _lx : (double) _ly : (double) _rx : (double) _ry origin: (double) _ox : (double) _oy zeroLevelDeg: (double) _zld maxLevel: (int) _maxl tileSize: (int)_tileSize mercator: (BOOL) _merc
{
	if (self=[super initWithName: _name lid: _lid on: _on opacity: _opacity])
    {
        priority = 0;
        lx = _lx;
        ly = _ly;
        rx = _rx;
        ry = _ry;
            
        isMercator = _merc;
        
        originX = _ox;
        originY = _oy;
        
        zeroLevelDegX = _zld;
        zeroLevelDegY = (isMercator || _zld==360)  ? _zld/2.0 : _zld;
            
        cols = (int) ceil((rx-originX) / zeroLevelDegX);
        rows = (int) ceil((ry-originY) / zeroLevelDegY);
                
        tileSize = _tileSize;
        minTileSize = tileSize / 2.0;
        nextTileSize = tileSize * 1.25;
        maxLevel = _maxl;
        
        fullworld = (rx-lx == 360) && (ry-ly == 180);
        
        textarget = (tileSize&(tileSize-1)) ? GL_TEXTURE_RECTANGLE_ARB : GL_TEXTURE_2D;
        
        curupdqueue = &updqueues[0];
        anotherupdqueue = &updqueues[1];
    }
    
	return self;
}

-(void) render
{
	if (!visible)
		return;

    if (glformat != GL_RGB || opacity != 1)
    {
        glEnable(GL_BLEND);
        glColor4f(1, 1, 1, opacity);
    }
    else
    {
        glDisable(GL_BLEND);
        glColor4f(1, 1, 1, 1);
    }

	glEnable(textarget);
	    
	glClear(GL_STENCIL_BUFFER_BIT);
    glStencilFunc(GL_NOTEQUAL, 1, 1);
    glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);       
    glEnable(GL_STENCIL_TEST);
    
    if (!fullworld)
        glEnable(GL_SCISSOR_TEST);
    
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    glEnableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);
    
    /*if (mapView->projmode != PROJ_WORLD)
    {
        glLoadIdentity();
        glOrtho(mapView->lx, mapView->rx, mapView->ly, mapView->ry, 0, 1);
        mapView->projmode = PROJ_WORLD;
    }*/
    
    ly1 = _maxd(mapView->ly, ly);
    ry1 = _mind(mapView->ry, ry);    

	int j_beg = (int) ((ly1-originY) / zeroLevelDegY);
	int j_end = (int) ceil((ry1-originY) / zeroLevelDegY);
    
    if (mapView->lx < -180)
    {
        if (mapView->rx > lx)
        {
            if (!fullworld)
            {
                int plx = (lx-mapView->lx) * mapView->ppd;
                int prx = (rx-mapView->lx) * mapView->ppd;
                int ply = (ly-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                int pry = (ry-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                glScissor(plx, ply, prx-plx, pry-ply);
            }
            
            lx1 = lx;
            rx1 = _mind(mapView->rx, rx);

            int i_beg = (int) ((lx1-originX) / zeroLevelDegX);
            int i_end = (int) ceil((rx1-originX) / zeroLevelDegX);

            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[QuadTile alloc] initWithLayer: self level: 0 i: i j: j];
                    [zeroLevelTiles[j*cols+i] render];
                }
            }
        }
        
        if (360+mapView->lx < rx)
        {
            if (!fullworld)
            {
                int plx = (lx-360-mapView->lx) * mapView->ppd;
                int prx = (rx-360-mapView->lx) * mapView->ppd;
                int ply = (ly-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                int pry = (ry-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                glScissor(plx, ply, prx-plx, pry-ply);
            }

            lx1 = _maxd(360+mapView->lx, lx);
            rx1 = rx;
            
            int i_beg = (int) ((lx1-originX) / zeroLevelDegX);
            int i_end = cols;
            
            glTranslatef(-360, 0, 0);
            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[QuadTile alloc] initWithLayer: self level: 0 i: i j: j];
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
            if (!fullworld)
            {
                int plx = (lx+360-mapView->lx) * mapView->ppd;
                int prx = (rx+360-mapView->lx) * mapView->ppd;
                int ply = (ly-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                int pry = (ry-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                glScissor(plx, ply, prx-plx, pry-ply);
            }

            lx1 = lx;
            rx1 = _mind(mapView->rx - 360, rx);
            
            int i_beg = (int) ((lx1-originX) / zeroLevelDegX);
            int i_end = (int) ceil((rx1-originX) / zeroLevelDegX);
            
            glTranslatef(360, 0, 0);
            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[QuadTile alloc] initWithLayer: self level: 0 i: i j: j];
                    [zeroLevelTiles[j*cols+i] render];
                }
            }   
            glTranslatef(-360, 0, 0);        
        } 
        
        if (mapView->lx < rx)
        {
            if (!fullworld)
            {
                int plx = (lx-mapView->lx) * mapView->ppd;
                int prx = (rx-mapView->lx) * mapView->ppd;
                int ply = (ly-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                int pry = (ry-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                glScissor(plx, ply, prx-plx, pry-ply);
            }

            lx1 = _maxd(mapView->lx, lx);
            rx1 = rx;
            
            int i_beg = (int) ((lx1-originX) / zeroLevelDegX);
            int i_end = cols;
            
            for (int i = i_beg; i < i_end; i++) {
                for (int j = j_beg; j < j_end; j++) {
                    if (!zeroLevelTiles[j*cols+i])
                        zeroLevelTiles[j*cols+i] = [[QuadTile alloc] initWithLayer: self level: 0 i: i j: j];
                    [zeroLevelTiles[j*cols+i] render];
                }
            }
        }
    }
    else
    {
        if (!fullworld)
        {
            int plx = (lx-mapView->lx) * mapView->ppd;
            int prx = (rx-mapView->lx) * mapView->ppd;
            int ply = (ly-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
            int pry = (ry-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
            glScissor(plx, ply, prx-plx, pry-ply);
        }
    		
        lx1 = _maxd(mapView->lx, lx);
        rx1 = _mind(mapView->rx, rx);
        
        int i_beg = (int) ((lx1-originX) / zeroLevelDegX);
        int i_end = (int) ceil((rx1-originX) / zeroLevelDegX);
        
        for (int i = i_beg; i < i_end; i++) {
            for (int j = j_beg; j < j_end; j++) {
                if (!zeroLevelTiles[j*cols+i])
                    zeroLevelTiles[j*cols+i] = [[QuadTile alloc] initWithLayer: self level: 0 i: i j: j];
                [zeroLevelTiles[j*cols+i] render];
            }
        }
    }
            
    if (!fullworld)
        glDisable(GL_SCISSOR_TEST);
    glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);       
    glDisable(GL_STENCIL_TEST);
    glDisable(textarget);
    
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_COLOR_ARRAY);
}

-(void) update
{
	//TODO: use target bounds in updater ???
    
    if ((fullworld || IS_REGION_VISIBLE(self)) && mapView->ppd * zeroLevelDegX >= minTileSize)
    {
        if (!visible)
        {
            [self openCache];
            
            if (!zeroLevelTiles)
                zeroLevelTiles = calloc (cols*rows * sizeof(QuadTile*), 1);

            if (!texscache)
            {
                texscache = calloc(TEXCACHESIZE*sizeof(GLuint), 1);
                texsusage = calloc(TEXCACHESIZE*sizeof(BOOL), 1);
            }
            
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
	
    struct UPDQUEUE *qu = curupdqueue;
    if (qu->updcnt)
    {
        curupdqueue = anotherupdqueue;
        anotherupdqueue = qu;
    
        //NSLog(@"%d", qu->updcnt);
                
        BOOL t = qu->updcnt > 1;
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
        }
        
        for (int i = 0; i < qu->updcnt; i++)
        {
            QuadTile *t = qu->queue[i];
            
            if (IS_REGION_VISIBLE(t) && (t->level == 0 || mapView->ppd*t->degx*2 >= nextTileSize))
                [t update];
            t->uflag = 0;
        }
        
        qu->updcnt = 0;
    }
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
    
    if (texscache)
    {
        for (int k = 0; k < TEXCACHESIZE; k++)
        {
            if (texsusage[k])
                mapView->texs[mapView->tcnt++] = texscache[k];
        }
        
        free(texscache);
        texscache = NULL;
        free(texsusage);
        texsusage = NULL;
    }
    
    [super dealloc];
}

@end
