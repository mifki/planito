//
//  QuadTile.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#include <OpenGL/CGLMacro.h> 
#import <math.h>
#import "QuadTile.h"
#import "QuadTileLayer.h"
#import "Globals.h"
#import "Helpers.h"
#import "ImageLoader.h"
#import "CacheManager.h"

extern CGLContextObj CGL_MACRO_CONTEXT;

@implementation QuadTile

-(QuadTile*) initWithLayer: (QuadTileLayer*) _layer level: (int) _level i: (int) _i j: (int) _j;
{
    if (self=[super init])
    {
        layer = _layer;
        level = _level;
        i = _i;
        j = _j;
        
        degx = layer->zeroLevelDegX / (1 << level);
        
        lx = layer->originX + degx * i;
        rx = lx + degx;
        
        if (layer->isMercator)
        {
            double pp = (2*2*layer->zeroLevelDegY/180.0*M_PI) / (2 << level);
            //double l2 = 2*atan(exp((j)*pp-M_PI))-M_PI_2;        
            double l1 = 2*atan(exp((j+1)*pp-M_PI))-M_PI_2;
            
            //TODO: alloate arrays dynamically (8 vs 8*10) ?
            //TODO: convert to quad_strip
            //TODO: swap l1 and l2
            double dy = 1.0/10;
            double lon1 = l1/M_PI*180.0;
            double l2, y2, lon2, y1 = 0;
            
            int m = 0;
            for (int kk = 1; kk <= 10; kk++) {
                y2 = y1+dy;
                l2 = 2*atan(exp((j+1-y2)*pp-M_PI))-M_PI_2;
                lon2 = l2/M_PI*180.0;
                
                vs_merc[m++] = lx;
                vs_merc[m++] = lon2;
                vs_merc[m++] = lx;
                vs_merc[m++] = lon1;
                vs_merc[m++] = rx;
                vs_merc[m++] = lon1;
                vs_merc[m++] = rx;
                vs_merc[m++] = lon2;
                
                y1 = y2;
                lon1 = lon2;
            }            
            
            ly = l2/M_PI*180.0;
            ry = l1/M_PI*180.0;
        }
        else
        {
            ly = layer->originY + (layer->zeroLevelDegY / (1 << level))*j;
            ry = ly + degx;
        }
        
        cx = (lx+rx)/2;
        cy = (ly+ry)/2;
        
        GLdouble _vs[8] = { lx, ry, lx, ly, rx, ly, rx, ry };
        //vs = _vs;
        memcpy(vs, _vs, sizeof(vs));
                
        //localDataPath = [DATA_PATH(layer.lid, "%d/%04d/%d_%04d_%04d", level, j, level, j, i) retain];
    }
    
    return self;
}
-(void) initChilds
{
    _childs[0] = [[QuadTile alloc] initWithLayer: layer level: level+1 i: 2*i j: 2*j];
    _childs[1] = [[QuadTile alloc] initWithLayer: layer level: level+1 i: 2*i+1 j: 2*j];
    _childs[2] = [[QuadTile alloc] initWithLayer: layer level: level+1 i: 2*i j: 2*j+1];
    _childs[3] = [[QuadTile alloc] initWithLayer: layer level: level+1 i: 2*i+1 j: 2*j+1];
    
    childs = _childs;
}

-(void) render
{
    lastRenderTimestamp = mapView->curtimestamp;
    
	int w = mapView->ppd * degx;
	if (w >= layer->nextTileSize && level < layer->maxLevel) //draw child tiles when zooming out until current tile [down]loaded
    {
		if (!childs)
			[self initChilds];
        
        if (childs[0]->rx >= layer->lx1 && childs[0]->ry >= layer->ly1 && childs[0]->lx <= layer->rx1 && childs[0]->ly <= layer->ry1)
            [childs[0] render];
        if (childs[1]->rx >= layer->lx1 && childs[1]->ry >= layer->ly1 && childs[1]->lx <= layer->rx1 && childs[1]->ly <= layer->ry1)
            [childs[1] render];
        if (childs[2]->rx >= layer->lx1 && childs[2]->ry >= layer->ly1 && childs[2]->lx <= layer->rx1 && childs[2]->ly <= layer->ry1)
            [childs[2] render];
        if (childs[3]->rx >= layer->lx1 && childs[3]->ry >= layer->ly1 && childs[3]->lx <= layer->rx1 && childs[3]->ly <= layer->ry1)
            [childs[3] render];
    }    
	
    //if at least one child can't be rendered
	if (!(w >= layer->nextTileSize && childs && childs[0]->tex && childs[1]->tex && childs[2]->tex && childs[3]->tex) && !nodata)
	{
		if (!tex && imgdata)
		{
            for (int k = 0; k < TEXCACHESIZE; k++)
            {
                if (layer->texscache[k] != 0)
                {
                    if (!layer->texsusage[k])
                    {
                        tex = layer->texscache[k];
                        texind = k;
                        layer->texsusage[k] = YES;
                        break;
                    }
                }
                else
                {
                    glGenTextures(1, &tex);
                    layer->texscache[k] = tex;
                    texind = k;
                    layer->texsusage[k] = YES;
                    break;
                }
            }
            if (!tex)
            {
                glGenTextures(1, &tex);
                texind = -1;
            }
            
			glBindTexture(layer->textarget, tex);

            glTexParameteri(layer->textarget, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
            glPixelStorei(GL_UNPACK_ROW_LENGTH, layer->tileSize);
            glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            
            glTexImage2D(layer->textarget, 0, layer->glformat, layer->tileSize, layer->tileSize, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, imgdata);
            
			//glTexParameterf(layer->textarget, GL_TEXTURE_MAX_ANISOTROPY_EXT, 4); //shouldn't do anything for 2D view
			glTexParameteri(layer->textarget, GL_TEXTURE_MIN_FILTER,GL_LINEAR);
			glTexParameteri(layer->textarget, GL_TEXTURE_MAG_FILTER,GL_LINEAR);
			glTexParameteri(layer->textarget, GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
			glTexParameteri(layer->textarget, GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
		}
		
		if (tex)
		{
			glBindTexture(layer->textarget, tex);
			if (layer->isMercator && mapView->w > 0.01)
            {
                static GLfloat tcs_merc[] = { 0.000000,0.100000,0.000000,0.000000,1.000000,0.000000,1.000000,0.100000,0.000000,0.200000,0.000000,0.100000,1.000000,0.100000,1.000000,0.200000,0.000000,0.300000,0.000000,0.200000,1.000000,0.200000,1.000000,0.300000,0.000000,0.400000,0.000000,0.300000,1.000000,0.300000,1.000000,0.400000,0.000000,0.500000,0.000000,0.400000,1.000000,0.400000,1.000000,0.500000,0.000000,0.600000,0.000000,0.500000,1.000000,0.500000,1.000000,0.600000,0.000000,0.700000,0.000000,0.600000,1.000000,0.600000,1.000000,0.700000,0.000000,0.800000,0.000000,0.700000,1.000000,0.700000,1.000000,0.800000,0.000000,0.900000,0.000000,0.800000,1.000000,0.800000,1.000000,0.900000,0.000000,1.000000,0.000000,0.900000,1.000000,0.900000,1.000000,1.000000 };
                glVertexPointer(2, GL_DOUBLE, 0, vs_merc);
                glTexCoordPointer(2, GL_FLOAT, 0, tcs_merc);
                glDrawArrays(GL_QUADS, 0, 4*10);
			}
			else
			{
                //glVertexPointer(2, GL_DOUBLE, 0, vs);
                glBegin(GL_QUADS);

                if (layer->textarget == GL_TEXTURE_RECTANGLE_ARB)
                {
                    //GLfloat tcs_rect[] = { 0, 0, 0, layer->tileSize, layer->tileSize, layer->tileSize, layer->tileSize, 0 };                    
                    //glTexCoordPointer(2, GL_FLOAT, 0, tcs_rect);

                    glTexCoord2f(0, 0);
                    glVertex2d(lx, ry);
                    glTexCoord2f(0, layer->tileSize);
                    glVertex2d(lx, ly);
                    glTexCoord2f(layer->tileSize, layer->tileSize);
                    glVertex2d(rx, ly);
                    glTexCoord2f(layer->tileSize, 0);
                    glVertex2d(rx, ry);
                }
                else
                {
                    //static GLfloat tcs_2d[] = { 0, 0, 0, 1, 1, 1, 1, 0 };
                    //glTexCoordPointer(2, GL_FLOAT, 0, tcs_2d);

                    glTexCoord2f(0, 0);
                    glVertex2d(lx, ry);
                    glTexCoord2f(0, 1);
                    glVertex2d(lx, ly);
                    glTexCoord2f(1, 1);
                    glVertex2d(rx, ly);
                    glTexCoord2f(1, 0);
                    glVertex2d(rx, ry);
                }

                glEnd();
                //glDrawArrays(GL_QUADS, 0, 4);
			}
		}
        /*else if (downloading)
        {
            glStencilFunc(GL_ALWAYS, 1, 1);
            //glDisable(GL_STENCIL_TEST);
            //glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);       
            double d = 1 / mapView->ppd;				
            glDisable(layer->textarget);
            glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
            glColor4f(1,1,1,0.5);
            glBegin(GL_QUADS);
            glVertex2d(lx + d, ly + d);
            glVertex2d(lx + d, ry - d);
            glVertex2d(rx - d, ry - d);
            glVertex2d(rx - d, ly + d);				
            glEnd();
            glEnable(layer->textarget);		
            glColor4f(1,1,1,layer->opacity);		
            glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
            //glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);       
            //glEnable(GL_STENCIL_TEST);
            glStencilFunc(GL_NOTEQUAL, 1, 1);
        }*/
	}
    
    if (!tex && !imgdata && !downloading && !nodata && layer->curupdqueue->updcnt < UPD_QUEUE_LEN && !uflag && !(nolocal && workOffline))
    {
        struct UPDQUEUE *q = layer->curupdqueue;
        q->queue[q->updcnt++] = self;
        uflag = YES;
        udist = 0;
    }
}

-(void) update
{
	if (!nolocal && layer->docache)
    {
        if (tile_cache_valid(self, NULL))
        {
            char k[32];
            int s;
            sprintf(k, "%d_%d_%d/data", level, j, i);
            void *data = tchdbget(layer->cachedb2, k, strlen(k), &s);
            
            if (data)
            {
                ImageLoader *il = [[ImageLoader alloc] initWithData:[NSData dataWithBytesNoCopy:data length:s freeWhenDone:YES]];
                il->format = layer->formatHint;

                if ([il load])
                {
                    imgdata = il->imgdata;
                    layer->formatHint = il->format;
                    layer->glformat = il->hasAlpha ? GL_RGBA : GL_RGB;

                    datasize = layer->tileSize * layer->tileSize * 4;
                    [cacheManager registerTile:self];
                    
                    [il release];
                    return;
                }
            
                [il release];
            }
        }

        nolocal = YES;
    }

    if ([layer->provider canProvide])
    { 
		downloading = YES;
        [layer->provider provideAsync: self];
	}
}

-(BOOL) gotDataFromProvider: (NSData*)data canRetry: (BOOL)canRetry
{
    if (!downloading)
        return NO;
    dlretries++;
    
    if (data)
    {
        ImageLoader *il = [[ImageLoader alloc] initWithData:data];
        il->format = layer->formatHint;
        
        if ([il load])
        {
            imgdata = il->imgdata;
            layer->formatHint = il->format;
            layer->glformat = il->hasAlpha ? GL_RGBA : GL_RGB;
            
            datasize = layer->tileSize * layer->tileSize * 4;
            [cacheManager registerTile:self];
            
            if (layer->docache)
            {
                char k[32];

                sprintf(k, "%d_%d_%d/data", level, j, i);
                tchdbput(layer->cachedb2, k, strlen(k), [data bytes], [data length]);

                sprintf(k, "%d_%d_%d/info", level, j, i);
                TILEINFO ti = { 0, mapView->curtimestamp };
                tchdbput(layer->cachedb2, k, strlen(k), &ti, sizeof(ti));
            }
        }
        else
            nodata = (dlretries == MAX_DL_RETRIES || !canRetry);

        [il release];
    }
    else
        nodata = (dlretries == MAX_DL_RETRIES || !canRetry);
    
    downloading = NO;
    
    return imgdata != nil;
}

-(QuadTileLayer*) layer
{
    return layer;
}

-(void) free
{
    downloading = NO;
    void *_imgdata = imgdata;
    GLuint _tex = tex;
        
    imgdata = NULL;
    tex = 0;

    if (_tex)
        if (texind != -1)
            layer->texsusage[texind] = NO;
        else
            mapView->texs[mapView->tcnt++] = _tex;

    if (_imgdata)
        free(_imgdata);
        
    nodata = NO;
    nolocal = NO;
    dlretries = 0;
    datasize = 0;
    uflag = NO;
}

-(void) dealloc
{
    cacheManager->cachesize -= datasize;
    
    [self free];
    
    if (childs)
    {
        [childs[0] release];
        [childs[1] release];
        [childs[2] release];
        [childs[3] release];
    }
    
    [super dealloc];
}

@end
