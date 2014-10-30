//
//  FeaturesTile.m
//  Planito
//
//  Created by Vitaliy Pronkin on 4/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#include <OpenGL/CGLMacro.h> 

#import "FeaturesTile.h"
#import "FeaturesLayer.h"
#import "Globals.h"
#import "Font.h"
#import "Helpers.h"
#import "fribidi.h"

extern CGLContextObj CGL_MACRO_CONTEXT;

extern PLACEMARK *_curpm;
extern POLYLINE *_curpl;
extern Features *curfeatures;

extern struct MAPREGION *gstrings;
extern int gstrcnt;

extern BOOL autorefresh;

static inline BOOL regions_intersect(struct MAPREGION a, struct MAPREGION b)
{
    return (b.lx < a.rx && b.rx > a.lx &&
            b.ly < a.ry && b.ry > a.ly);
}

@interface FeaturesTile ()
-(BOOL) loadFromData: (NSData*)data;
-(BOOL) loadFromXML: (NSXMLDocument*)doc;
@end

@implementation FeaturesTile

- (FeaturesTile*)initWithLayer: (FeaturesLayer*)_layer level: (int)_level i: (int)_i j: (int)_j;
{
	i = _i;
	j = _j;
	layer = _layer;
	level = _level;

    double degx = layer->zeroLevelDegX / (1 << level);
    double degy = layer->zeroLevelDegY / (1 << level);
    
	flx = lx = -180 + degx * i;
	frx = rx = lx + degx;
	
    fly = ly = -90 + degy*j;
    fry = ry = ly + degy;
    	
	//localDataPath = [DATA_PATH(layer.lid, "%d/%04d/%d_%04d_%04d", level, j, level, j, i) retain];
	
	return self;
}

- (BOOL) render
{
    lastRenderTimestamp = mapView->curtimestamp;

	if (level < layer->maxLevel && mapView->ppd >= layer->minppd*(1 << (level+1)))
	{
		if (!childs)
			[self initChilds];

        BOOL f = NO;

        if (childs[0]->frx >= layer->lx1 && childs[0]->fry >= layer->ly1 && childs[0]->flx <= layer->rx1 && childs[0]->fly <= layer->ry1)
            f |= [childs[0] render];
        if (childs[1]->frx >= layer->lx1 && childs[1]->fry >= layer->ly1 && childs[1]->flx <= layer->rx1 && childs[1]->fly <= layer->ry1)
            f |= [childs[1] render];
        if (childs[2]->frx >= layer->lx1 && childs[2]->fry >= layer->ly1 && childs[2]->flx <= layer->rx1 && childs[2]->fly <= layer->ry1)
            f |= [childs[2] render];
        if (childs[3]->frx >= layer->lx1 && childs[3]->fry >= layer->ly1 && childs[3]->flx <= layer->rx1 && childs[3]->fly <= layer->ry1)
            f |= [childs[3] render];
		
		if (f && layer->showOne)
        {
            rendered = NO;
			return YES;
        }
	}
    
    rendered = YES;
    
    if (layer->dataExpiresIn && datatimestamp && mapView->curtimestamp - datatimestamp > layer->dataExpiresIn && autorefresh)
    {
        if (!downloading && layer->curupdqueue->updcnt < UPD_QUEUE_LEN && !uflag && !workOffline)
        {
            nolocal = YES;
            
            struct UPDQUEUE2 *q = layer->curupdqueue;
            q->queue[q->updcnt++] = self;
            uflag = 1;
        }        
    } 
	
	if (!features)
    {
        if (!nodata && !downloading && layer->curupdqueue->updcnt < UPD_QUEUE_LEN && !uflag && !(nolocal && workOffline))
        {
            struct UPDQUEUE2 *q = layer->curupdqueue;
            q->queue[q->updcnt++] = self;
            uflag = 1;
        }
        
		return NO;
    }
	
    //TODO: fix scaling - individually for each style/minppd
	/*if (mapView->ppd < layer->levels[level].minPPD)
	{
		scale = 1 - (layer->levels[level].minPPD-mapView->ppd) / (layer->levels[level].minPPD*0.1);
		hs *= scale;
	}*/
    
    if (features->lx > layer->rx1 || features->rx < layer->lx1 || features->ly > layer->ry1 || features->ry < layer->ly1)
        return YES;
    
    Features *_features = [features retain];
    
    //Render polylines
    if (_features->plcnt)
    {
        glDisable(GL_TEXTURE_2D);
        glEnable(GL_LINE_SMOOTH);
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);

        for (int k = 0; k < _features->plcnt; k++)
        {
            POLYLINE *p = &_features->polylines[k];
            if (p->style->minppd > mapView->ppd || p->rx < layer->lx1 || p->ry < layer->ly1 || p->lx > layer->rx1 || p->ly > layer->ry1 || !p->ptcnt)
                continue;
                                        
            glVertexPointer(2, GL_DOUBLE, 0, p->ptcoords);

            if (_curpl == p)
            {
                glLineWidth(p->style->lineWidth + 1.5);
                glColor4f(p->style->r, p->style->g, p->style->b, 1);

                glDrawArrays(GL_LINE_STRIP, 0, p->ptcnt);

                if (layer->curstyle)
                {
                    glLineWidth(layer->curstyle->lineWidth);
                    glColor4f(layer->curstyle->r, layer->curstyle->g, layer->curstyle->b, layer->curstyle->opacity*layer->opacity);
                }
            }
            else
            {
                if (layer->curstyle != p->style)
                {
                    layer->curstyle = p->style;
                    
                    glColor4f(layer->curstyle->r, layer->curstyle->g, layer->curstyle->b, layer->curstyle->opacity*layer->opacity);
                    glLineWidth(layer->curstyle->lineWidth);
                }

                glDrawArrays(GL_LINE_STRIP, 0, p->ptcnt);
            }
        }
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        glDisable(GL_LINE_SMOOTH);
    }
	
    //Render placemarks
    if (_features->pmcnt)
    {
        glEnable(GL_TEXTURE_2D);
        /*glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);*/
        
        for (int k = 0; k < _features->pmcnt; k++)
        {
            PLACEMARK *p = &_features->placemarks[k];
            if (p->style->minppd > mapView->ppd || p->lat > layer->ry1 || p->lat < layer->ly1 || p->lon > layer->rx1 || p->lon < layer->lx1)
                continue;
                        
            if (_curpm != p)
            {
                if (layer->curstyle != p->style)
                {
                    layer->curstyle = p->style;

                    if (p->style->tex)
                    {
                        glBindTexture(GL_TEXTURE_2D, layer->curstyle->tex);
                        glPointSize(p->style->iconDisplaySize);
                    }
                    
                    glColor4f(layer->curstyle->r, layer->curstyle->g, layer->curstyle->b, layer->curstyle->opacity*layer->opacity);
                }

                if (p->style->tex)
                {
                    glBegin(GL_POINTS);
                    glVertex2d(p->lon, p->lat);
                    glEnd();
                } 
            }
            
            if (p->label && gstrcnt < GMAX_STRINGS)
            {
                p->x = (p->lon-layer->plx1) * mapView->ppd;
                p->y = (p->lat-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;

                if (!p->labellen)
                {
                    p->labellen = [p->label length];
                    if (p->labellen > MAX_LABEL_LEN)
                        p->labellen = MAX_LABEL_LEN;
                    
                    //TODO: allocate unititle buffer dynamically
                    unichar buf[MAX_LABEL_LEN];
                    [p->label getCharacters:buf range:NSMakeRange(0, p->labellen)];
                    
                    FriBidiParType type = FRIBIDI_PAR_ON;
                    fribidi_log2vis(buf, p->labellen, &type, p->unilabel, NULL, NULL, NULL);

                    p->labelrtl = (type == FRIBIDI_PAR_RTL);
                    p->labelw = measureString(p->style->font, p->unilabel, p->labellen, p->style->fontScale);
                }            
                
                if (_curpm == p)
                    renderString(p->style->font, p->unilabel, p->labellen, gstrings[0].lx, p->y, A_CENTER, p->style->r, p->style->g, p->style->b, 1, p->style->fontScale);
                else
                {
                    double labelw = p->labelw;
                    double labelx = p->x;
                    
                    if (p->style->tex)
                    {
                        if (p->labelrtl)
                            labelx -= labelw + p->style->iconDisplaySize/2 + 2;
                        else
                            labelx += p->style->iconDisplaySize/2 + 3;
                    }
                    else
                        labelx -= labelw/2;
                    
                    struct MAPREGION r = { labelx, p->y - p->style->font->lineHeight*layer->curstyle->fontScale/2, labelx+labelw, p->y + p->style->font->lineHeight*layer->curstyle->fontScale/2 };
                    BOOL f = YES;
                    for (int m = 0; m < gstrcnt; m++)
                    {
                        if (regions_intersect(gstrings[m], r))
                        {
                            f = NO;
                            break;
                        }
                    }
                    
                    if (f)
                    {
                        renderString(p->style->font, p->unilabel, p->labellen, labelx, p->y, A_CENTER, layer->curstyle->r, layer->curstyle->g, layer->curstyle->b, layer->curstyle->opacity*layer->opacity, layer->curstyle->fontScale);
                        gstrings[gstrcnt++] = r;
                    }
                }
            }
        }
        
        /*glVertexPointer(2, GL_DOUBLE, sizeof(PLACEMARK), &_features->placemarks[0].lon);
        glDrawArrays(GL_POINTS, 0, _features->pmcnt);
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);*/
	}
    
    [_features release];
    return YES;    
}

- (void) update
{
	if (!nolocal && layer->docache)
    {
        if (tile_cache_valid(self, &datatimestamp))
        {
            char k[32];
            int s;
            sprintf(k, "%d_%d_%d/data", level, j, i);
            void *data = tchdbget(layer->cachedb2, k, strlen(k), &s);

            if (data)
            {
                if ([self loadFromData: [NSData dataWithBytesNoCopy:data length:s freeWhenDone:YES]])
                    return;
            }
        } 

        nolocal = YES;
    }
    
    if ([layer->provider canProvide])
    {
        downloading = TRUE;
        [layer->provider provideAsync: self];
    }
}

-(BOOL) findFeatureForLat: (double)mlat lon: (double)mlon
{
    double maxmaxd = 10.0 / mapView->ppd;
    
    if (level < layer->maxLevel && mapView->ppd >= layer->minppd*(1 << (level+1)) && childs)
    {
        for (int k = 0; k < 4; k++)
        {
            if (mlon >= childs[k]->flx-maxmaxd && mlon <= childs[k]->frx+maxmaxd && mlat >= childs[k]->fly-maxmaxd && mlat <= childs[k]->fry+maxmaxd) 
            {
                if ([childs[k] findFeatureForLat:mlat lon:mlon])
                    return YES;
            }
        }
    }
    
    if (features && rendered)
    {
        if (mlon < features->lx-maxmaxd || mlon > features->rx+maxmaxd || mlat < features->ly-maxmaxd || mlat > features->ry+maxmaxd)
            return NO;

        Features *_f = [features retain];
        
        double maxdx = 9.0 / mapView->ppd;
        double maxdy = 9.0 / mapView->ppd * mapView->cphi1;
    
        for (int k = _f->pmcnt-1; k >= 0; k--)
        {
            PLACEMARK *p = &_f->placemarks[k];
            
            if (p->style->tex && mapView->ppd >= p->style->minppd && fabs(mlat-p->lat) < maxdy && fabs(mlon-p->lon) < maxdx)
            {
                mapView->curpl = NULL;
                if (mapView->curpm != p)
                    mapView->curpm = NULL;
                
                if (_f == curfeatures)
                    [_f release];
                else
                {
                    [curfeatures release];
                    curfeatures = _f;
                }
                                
                if (p->lon < mapView->lx)
                    p->x = (p->lon-mapView->lx+360) * mapView->ppd;
                else if (p->lon > mapView->rx)
                    p->x = (p->lon-mapView->lx-360) * mapView->ppd;
                else
                    p->x = (p->lon-mapView->lx) * mapView->ppd;
                p->y = (p->lat-mapView->cy) * mapView->ppd/mapView->cphi1 + mapView->hh_px;
                
                mapView->curpm = p;
                return YES;
            }
        }
        
        //TODO: should take cphi1 into account for y distance
        double maxd = 5.0 / mapView->ppd;
        
        for (int m = _f->plcnt-1; m >= 0; m--)
        {
            POLYLINE *p = &_f->polylines[m];
            
            if (mlon < p->lx-maxmaxd || mlon > p->rx+maxmaxd || mlat < p->ly-maxmaxd || mlat > p->ry+maxmaxd || !(p->title || p->descr))
                continue;
            
            for (int n = 0; n < p->ptcnt-1; n++)
            {
                double x1 = p->ptcoords[n*2];
                double y1 = p->ptcoords[n*2+1];
                double x2 = p->ptcoords[n*2+2];
                double y2 = p->ptcoords[n*2+3];
                
                double dx = x2-x1;
                double dy = (y2-y1);//*mapView->cphi1;
                
                double dmx1 = mlon-x1;
                double dmy1 = (mlat-y1);//*mapView->cphi1;

                double dmx2 = mlon-x2;
                double dmy2 = (mlat-y2); 
                
                double q = (dmx1*dx + dmy1*dy) * (dmx2*dx + dmy2*dy);
                if (q < 0) //if mouse is between points
                {
                    //TODO: take cphi1 into account here
                    double distdeg = fabs((dy*dmx1 - dx*dmy1) / sqrt(dx*dx+dy*dy));
                    
                    if (distdeg <= maxd)
                    {
                        mapView->curpm = NULL;
                        if (mapView->curpl != p)
                            mapView->curpl = NULL;
                        
                        if (_f == curfeatures)
                            [_f release];
                        else
                        {
                            [curfeatures release];
                            curfeatures = _f;
                        }
                        
                        mapView->curpl = p;
                        return YES;
                    }
                }
            }
        }
    
        [_f release];
    }
    
    return NO;
}

-(BOOL) gotDataFromProvider: (id)data canRetry: (BOOL)canRetry
{
    if (!downloading)
        return NO;

    dlretries++;

    if ([data isKindOfClass:[NSData class]])
    {
        if ([self loadFromData: data])
        {
            datatimestamp = mapView->curtimestamp;    

            if (layer->docache)
            {
                char k[32];
                
                sprintf(k, "%d_%d_%d/data", level, j, i);
                tchdbput(layer->cachedb2, k, strlen(k), [data bytes], [data length]);
                
                sprintf(k, "%d_%d_%d/info", level, j, i);
                TILEINFO ti = { 0, datatimestamp };
                tchdbput(layer->cachedb2, k, strlen(k), &ti, sizeof(ti));
            }
            
            downloading = NO;
            return YES;
        }
    }
    else if ([data isKindOfClass:[NSXMLDocument class]])
    {
        if ([self loadFromXML: data])
        {
            datatimestamp = mapView->curtimestamp;    

            if (layer->docache)
            {
                NSData *d = [data XMLData];
                char k[32];
                
                sprintf(k, "%d_%d_%d/data", level, j, i);
                tchdbput(layer->cachedb2, k, strlen(k), [d bytes], [d length]);
                
                sprintf(k, "%d_%d_%d/info", level, j, i);
                TILEINFO ti = { 0, datatimestamp };
                tchdbput(layer->cachedb2, k, strlen(k), &ti, sizeof(ti));
            }
            
            downloading = NO;
            return YES;
        }
    }

    nodata = (dlretries == MAX_DL_RETRIES || !canRetry);
    if (nodata)
        datatimestamp = mapView->curtimestamp;
    downloading = NO;
    
    return NO;
}

- (BOOL) loadFromData: (NSData*) data
{
    NSError *err;
    NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData: data options: 0 error: &err];

	if (doc)
    {
        BOOL r = [self loadFromXML: doc];
        [doc release];
        
        return r;
    }
    else
        NSLog(@"%@", err);
    
    
    return NO;
}

- (BOOL) loadFromXML: (NSXMLDocument*)doc
{
    NSXMLElement *root = [doc rootElement];
    if (![[root name] isEqualToString:@"features"])
        return NO;

    NSArray *pms = [root elementsForName: @"pm"];
    int _pmcnt = [pms count];

    NSArray *pls = [root elementsForName: @"pl"];
    int _plcnt = [pls count];
    
    if (_pmcnt || _plcnt)
    {
        Features *_features = [Features new];
        NSUInteger _datasize = 0;
        
        double _flx = 999, _fly = 999, _frx = -999, _fry = -999;

        //Placemarks
        if (_pmcnt)
        {
            PLACEMARK *_placemarks = (PLACEMARK*)calloc(_pmcnt*sizeof(PLACEMARK), 1);
            _datasize += _pmcnt*sizeof(PLACEMARK);
            
            for (int k = 0; k < _pmcnt; k++)
            {
                NSXMLElement *el = [pms objectAtIndex: k];
                PLACEMARK *pm = &_placemarks[k];
                
                pm->title = [[[[el elementsForName:@"t"] lastObject] stringValue] retain];
                _datasize += [pm->title length]*2;

                pm->label = [[[[el elementsForName: @"l"] lastObject] stringValue] retain];
                if (pm->label && ![pm->label length])
                {
                    [pm->label release];
                    pm->label = nil;
                }
                else
                    _datasize += [pm->label length]*2;
                            
                pm->descr = [[[[el elementsForName:@"d"] lastObject] stringValue] retain];
                _datasize += [pm->descr length]*2;

                pm->url = [[[el attributeForName:@"u"] stringValue] retain];
                _datasize += [pm->url length]*2;
                    
                pm->style = &layer->styles[0];
                NSString *style = [[el attributeForName: @"s"] stringValue];
                if (style)
                {
                    for (int l = 0; l < layer->stylecnt; l++)
                    {
                        if ([layer->styles[l].styleid isEqualToString: style])
                        {
                            pm->style = &layer->styles[l];
                            break;
                        }
                    }
                }
                if (pm->label && !pm->title && !pm->style->fontScale)
                {
                    pm->title = pm->label;
                    pm->label = nil;
                }
                
                //TODO: should remove PMs without valid coords
                NSArray *coords = [[[el attributeForName: @"c"] stringValue] componentsSeparatedByString: @","];
                if ([coords count] == 2)
                {
                    pm->lat = [[coords objectAtIndex: 0] doubleValue];				
                    pm->lon = [[coords objectAtIndex: 1] doubleValue];
                }
                
                if (pm->lon < _flx)
                    _flx = pm->lon;
                if (pm->lon > _frx)
                    _frx = pm->lon;
                if (pm->lat < _fly)
                    _fly = pm->lat;
                if (pm->lat > _fry)
                    _fry = pm->lat;
            }
            
            _features->placemarks = _placemarks;
            _features->pmcnt = _pmcnt;
        }
            
        //Polylines
        if (_plcnt)
        {
            POLYLINE *_polylines = (POLYLINE*)calloc(_plcnt*sizeof(POLYLINE), 1);
            _datasize += _plcnt*sizeof(POLYLINE);
            
            for (int k = 0; k < _plcnt; k++)
            {
                NSXMLElement *el = [pls objectAtIndex: k];
                POLYLINE *pl = &_polylines[k];
                
                pl->title = [[[[el elementsForName:@"t"] lastObject] stringValue] retain];
                _datasize += [pl->title length]*2;
                            
                pl->descr = [[[[el elementsForName:@"d"] lastObject] stringValue] retain];
                _datasize += [pl->descr length]*2;
                
                pl->url = [[[el attributeForName:@"u"] stringValue] retain];
                _datasize += [pl->url length]*2;

                pl->style = &layer->styles[0];
                NSString *style = [[el attributeForName: @"s"] stringValue];
                if (style)
                {
                    for (int l = 0; l < layer->stylecnt; l++)
                    {
                        if ([layer->styles[l].styleid isEqualToString: style])
                        {
                            pl->style = &layer->styles[l];
                            break;
                        }
                    }
                }
                
                //TODO: should remove PLs without valid coords
                NSString *coords = [[el attributeForName: @"c"] stringValue];
                if (coords)
                {
                    NSArray *cs = [coords componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",; "]];

                    int cnt = [cs count];
                    if (![[cs lastObject] length]) //delete last empty component
                        cnt--;
                    
                    double _lx = 999, _ly = 999, _rx = -999, _ry = -999;

                    if (!(cnt & 1))
                    {
                        pl->ptcnt = cnt / 2;
                        pl->ptcoords = malloc(cnt*sizeof(double));
                        
                        for (int u = 0; u < cnt; u+=2)
                        {
                            double lat = [[cs objectAtIndex: u] doubleValue];
                            double lon = [[cs objectAtIndex: u+1] doubleValue];

                            pl->ptcoords[u] = lon;
                            pl->ptcoords[u+1] = lat;
                            
                            if (lat < _ly)
                                _ly = lat;
                            if (lat > _ry)
                                _ry = lat;

                            if (lon < _lx)
                                _lx = lon;
                            if (lon > _rx)
                                _rx = lon;
                        }

                        pl->lx = _lx;
                        pl->ly = _ly;
                        pl->rx = _rx;
                        pl->ry = _ry;
                        
                        if (_lx < _flx)
                            _flx = _lx;
                        if (_rx > _frx)
                            _frx = _rx;
                        if (_ly < _fly)
                            _fly = _ly;
                        if (_ry > _fry)
                            _fry = _ry;
                        
                    }
                }
            }
            
            _features->polylines = _polylines;
            _features->plcnt = _plcnt;
        }
        
        _features->lx = _flx;
        _features->ly = _fly;
        _features->rx = _frx;
        _features->ry = _fry;
        
        flx = MIN(lx, _flx);
        fly = MIN(ly, _fly);
        frx = MAX(rx, _frx);
        fry = MAX(ry, _fry);

        if (features)
        {
            if (curfeatures == features)
            {
                mapView->curpm = NULL;
                mapView->curpl = NULL;
                [curfeatures release];
                curfeatures = nil;
            }

            id __f = features;
            features = _features;
            [__f release];
            cacheManager->cachesize += _datasize - datasize;
            datasize = _datasize;
        }
        else
        {
            features = _features;
            datasize = _datasize;
            [cacheManager registerTile:self];
        }
    }
    else
    {
        if (features)
        {
            if (curfeatures == features)
            {
                mapView->curpm = NULL;
                mapView->curpl = NULL;
                [curfeatures release];
                curfeatures = nil;
            }
            
            id __f = features;
            features = nil;
            [__f release];
            cacheManager->cachesize -= datasize;
            datasize = 0;
            
            flx = lx;
            fly = ly;
            frx = rx;
            fry = ry;
        }   
        
        nodata = YES;
    }
    
    return YES;
}

- (void) initChilds
{
    _childs[0] = [[FeaturesTile alloc] initWithLayer: layer level: level+1 i: 2*i j: 2*j];
    _childs[1] = [[FeaturesTile alloc] initWithLayer: layer level: level+1 i: 2*i+1 j: 2*j];
    _childs[2] = [[FeaturesTile alloc] initWithLayer: layer level: level+1 i: 2*i j: 2*j+1];
    _childs[3] = [[FeaturesTile alloc] initWithLayer: layer level: level+1 i: 2*i+1 j: 2*j+1];
    childs = _childs;
}

-(FeaturesLayer*) layer
{
    return layer;
}

-(void) free
{
    downloading = NO;
    
    [features release];
    features = nil;

    nodata = NO;
    nolocal = NO;
    dlretries = 0;
    datasize = 0;
    datatimestamp = 0;
    uflag = 0;
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
