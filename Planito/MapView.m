//
//  MapView.m
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 mifki. All rights reserved.
//


#import <OpenGL/CGLMacro.h> 
#import <3DConnexionClient/ConnexionClientAPI.h>
#import <QuartzCore/QuartzCore.h>
#import "MapView.h"
#import "LayerSet.h"
#import "Globals.h"
#import "Font.h"
#import "FeaturesLayer.h"
#import "ImageLoader.h"
#import "Downloader.h"
#import "fribidi.h"
#import "BookmarkManager.h"
#import "Helpers.h"
#import "AddBookmarkPanelController.h"

#define MAXPPD 400000.0
#define TITLE_FONT_SCALE 0.7
#define CREDITS_FONT_SCALE 0.65

MapView *mapView;
CGLContextObj CGL_MACRO_CONTEXT;

PLACEMARK *_curpm;
POLYLINE *_curpl;

Features *curfeatures;

struct MAPREGION *gstrings;
int gstrcnt;

static GLuint downloadingtex;
static float downloadingrot;
short gdownloading;

static NSString *fdescrtemplate;

extern OSErr InstallConnexionHandlers() __attribute__((weak_import));
static UInt16 fConnexionClientID;
static void ThreeDConnexionMessageHandler(io_connect_t connection, natural_t messageType, void *messageArgument);

BOOL useMultitouch;
BOOL fixDistortion;
BOOL showCoordGrid;
BOOL showDistanceGrid;
BOOL showUserLoc;
static BOOL activateFeaturesOnLeftClick;

NSString *urlToOpen;

#define CURSOR_HEIGHT 16

@interface MapView ()
-(void) render;
-(void) showInfoPopover;
-(void) findFeatureUnderMouse;
-(void) handle3DMouseMessageWithType: (natural_t)messageType argument: (void*)messageArgument;
@end

@implementation MapView
@synthesize featureActionsMenu=_featureActionsMenu;

- (void) awakeFromNib
{
    mapView = self;
    self.hidden = NO;
    self.layer.opaque = YES;

    NSTrackingArea *ta = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved|NSTrackingActiveAlways|NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:ta];
    [ta release];
    
    if(InstallConnexionHandlers != NULL)
	{
		InstallConnexionHandlers(ThreeDConnexionMessageHandler, 0L, 0L);
        fConnexionClientID = RegisterConnexionClient('PltO', "\pPlanito", kConnexionClientModeTakeOver, kConnexionMaskAll);
	}
    
    fdescrtemplate = [@"<html><body style='background-color:#eee;font-size:12px;font-family:Helvetica;margin:5px;text-align:justify;'>%@</body></html>" retain];
    
	texs = malloc(2048*sizeof(GLuint));
    gstrings = malloc(GMAX_STRINGS*sizeof(struct MAPREGION));
    
    activateFeaturesOnLeftClick = [[NSUserDefaults standardUserDefaults] boolForKey:@"ActivateFeaturesOnLeftClick"];
}

-(void) loadPosition
{
    targetw = w = 360;
	targetcx = cx = 0;
	targetcy = cy = 0;
    
    if (urlToOpen)
    {
        [self parseAndGo: urlToOpen];
        [urlToOpen release];
        urlToOpen = nil;
        
        if (!targetw)
        {
            NSDictionary *pos = [[NSUserDefaults standardUserDefaults] objectForKey: [NSString stringWithFormat:@"View-%@", world.name]];
            if (pos)
                targetw = [[pos objectForKey:@"W"] doubleValue];
        }
    }
    else
    {
        NSDictionary *pos = [[NSUserDefaults standardUserDefaults] objectForKey: [NSString stringWithFormat:@"View-%@", world.name]];
        if (pos)
        {
            targetcx = [[pos objectForKey:@"Lon"] doubleValue];
            targetcy = [[pos objectForKey:@"Lat"] doubleValue];

            targetw = [[pos objectForKey:@"W"] doubleValue];
        }
    }

    if (!targetw)
        targetw = 360;
    
    zoom = move = YES;
}

-(void) savePosition
{
    NSMutableDictionary *pos = [NSMutableDictionary dictionary];
    
    [pos setObject:[NSNumber numberWithDouble:cx] forKey:@"Lon"];
    [pos setObject:[NSNumber numberWithDouble:cy] forKey:@"Lat"];
    [pos setObject:[NSNumber numberWithDouble:w] forKey:@"W"];
    
    [[NSUserDefaults standardUserDefaults] setObject:pos forKey:[NSString stringWithFormat:@"View-%@", world.name]];
}

static CVReturn MyDisplayLinkCallback (CVDisplayLinkRef displayLink,
                                       const CVTimeStamp *inNow,
                                       const CVTimeStamp *inOutputTime,
                                       CVOptionFlags flagsIn,
                                       CVOptionFlags *flagsOut,
                                       void *displayLinkContext)
{
    static BOOL _div = NO;
    
    _div = !_div;
    if (_div)
    {
        mapView->rendering = YES;
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        
        [mapView render];
        
        [pool release];
        mapView->rendering = NO;
    }
    
    return kCVReturnSuccess;
}

-(void) startRendering
{
    CVDisplayLinkStart(displayLink);    
 //   [NSThread detachNewThreadSelector:@selector(aa) toTarget:self withObject:nil];
}

/*-(void) aa
{
    while(1)
    {
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        [self render];
        usleep(20000);
        [pool release];
    }
}*/

-(void) stopRendering
{
    CVDisplayLinkStop(displayLink);    
        
    curpm = NULL;
    curpl = NULL;
    [curfeatures release];
    curfeatures = nil;
}

-(void) clear
{
    CGLLockContext(CGL_MACRO_CONTEXT);
	glClear(GL_COLOR_BUFFER_BIT);
    CGLFlushDrawable(CGL_MACRO_CONTEXT);
    CGLUnlockContext(CGL_MACRO_CONTEXT);    
}

- (void)prepareOpenGL
{
	CGL_MACRO_CONTEXT = [[self openGLContext] CGLContextObj]; //By using CGLMacro.h there's no need to set the current OpenGL context

    // Enable the multi-threading
	CGLEnable(CGL_MACRO_CONTEXT, kCGLCEMPEngine);	
    
    //Enable VSync
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];
        
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, CGL_MACRO_CONTEXT, [[self pixelFormat] CGLPixelFormatObj]);
    CVDisplayLinkSetOutputCallback(displayLink, MyDisplayLinkCallback, NULL);

    glDisable(GL_DITHER);
    glDisable(GL_FOG);
    
	glDisable(GL_POINT_SMOOTH);
	glDisable(GL_POLYGON_SMOOTH);
    
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
    
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glClearColor(0.15f, 0.15f, 0.15f, 1);
	glClear(GL_COLOR_BUFFER_BIT);
    
	[self reshape];
    CGLFlushDrawable(CGL_MACRO_CONTEXT);

	//[NSThread setThreadPriority: 0.7];
}

- (void)reshape
{
	hw_px = (w_px=[self frame].size.width)/2;
	hh_px = (h_px=[self frame].size.height)/2;

    ppd = ((double)w_px) / w;
	if (w_px/targetw > MAXPPD)
		targetw = w_px / MAXPPD;

    zoom = YES;
    reshape = YES;
}

/*-(void) update
{
    CGLLockContext(CGL_MACRO_CONTEXT);
    CGLUpdateContext(CGL_MACRO_CONTEXT);
    CGLUnlockContext(CGL_MACRO_CONTEXT);
}*/

-(void) render
{
    CGLLockContext(CGL_MACRO_CONTEXT);

    if (reshape)
    {
        glViewport(0, 0, (GLsizei) w_px, (GLsizei) h_px);
        
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0, w_px, 0, h_px, 0, 1);
        glGetDoublev(GL_PROJECTION_MATRIX, wndprojmatrix);

        reshape = NO;
    }
	
	if (tcnt)
	{
		glDeleteTextures(tcnt, texs);
		tcnt = 0;
	}
	
    if (zoom || move)
    {
        if (zoom)
        {
            if (fabs(w - targetw) > 0.001 * w)
                w = w + (targetw - w) * 0.3;//0.5//0.7
            else
            {
                w = targetw;
                zoom = false;
            }

            ppd = ((double)w_px) / w;

            //		alt = 512.0 / 4.5 * w / 2.0 / 1/* tan(3.14*0.25) */;
            //double alt2 = w/360*2*Math.PI*6378/2/Math.tan(Math.PI/8);
            //double alt3 = Utils.distance(lx, 0, rx, 0, eqradius)/2/Math.tan(Math.PI/8);
            //System.out.println(alt+ " "+alt2+" "+alt3);
        }
        
        if (move)
        {
            if (fabs(cx - targetcx) > 0.001 * w || fabs(cy - targetcy) > 0.001 * w)
            {
                if (cx - targetcx > 180)
                {
                    cx = cx + (360-(cx-targetcx)) * 0.8;//0.2//0.7
                    if (cx > 180)
                        cx = cx - 360;
                }
                else if (targetcx-cx > 180)
                {
                    cx = cx - (360-(targetcx-cx)) * 0.8;//0.2//0.7
                    if (cx < -180)
                        cx = cx + 360;
                }
                else
                    cx = cx + (targetcx - cx) * 0.8;//0.2//0.7
                cy = cy + (targetcy - cy) * 0.8;
            }
            else
            {
                cx = targetcx;
                cy = targetcy;
                move = FALSE;
            }
        }
        
        if (fixDistortion)
        {
            cphi1 = w < 45 ? cos(cy / 180.0 * M_PI) : 1;
            if (w > 5)
            {
                double a = 1 - cphi1;
                cphi1 = 1 - a * (1-(w-5)/(45-5));
            }
            else if (cphi1 < 0.05)
                cphi1 = 0.05;
        }
        else
            cphi1 = 1;
                
        lx = cx - ((double) hw_px / ppd);
        ly = cy - ((double) hh_px / ppd)*cphi1;
        rx = cx + ((double) hw_px / ppd);
        ry = cy + ((double) hh_px / ppd)*cphi1;
        
        [self performSelectorOnMainThread:@selector(postChangeNotification) withObject:nil waitUntilDone:NO];
    }
		
	glClear(GL_COLOR_BUFFER_BIT);
	
	gstrcnt = 0;
    
    Features *_f = [curfeatures retain];
    _curpm = curpm;
    _curpl = curpl;
        
    //Ensure curpm label will be shown even if drawn after other overlapping labels
    double labelx;
    if (_curpm && _curpm->label)
    {
        double hs = _curpm->style->iconDisplaySize*1.5/2.0;
        double labelw = _curpm->labelw;
        labelx = _curpm->x;
        
        if (_curpm->labelrtl)
        {
            if (labelx+hs+3+labelw < hw_px*2 && labelw > labelx-hs-2)
                labelx += hs + 3;
            else
                labelx -= labelw + hs + 2;
        }
        else
        {
            if (labelx+hs+3+labelw > hw_px*2 && labelw < labelx-hs-2)
                labelx -= labelw + hs + 2;
            else
                labelx += hs + 3;
        }
        
        struct MAPREGION r = { labelx, _curpm->y - _curpm->style->font->lineHeight*_curpm->style->fontScale/2, labelx+labelw, _curpm->y + _curpm->style->font->lineHeight*_curpm->style->fontScale/2 };
        gstrings[gstrcnt++] = r;
    }
    
    //Ensure curpm/curpl title will be shown even if drawn after other overlapping labels    
    double titlex, titley;
    unichar titlebuf[MAX_TITLE_LEN];
    int titlelen = 0, titlealign;
    if ((_curpl || _curpm) && ![infoPopover isShown])
    {
        if (_curpm && _curpm->title)
        {
            titlelen = [_curpm->title length];
            if (titlelen)
            {
                if (titlelen > MAX_TITLE_LEN)
                    titlelen = MAX_TITLE_LEN;
                
                unichar buf[MAX_TITLE_LEN];
                [_curpm->title getCharacters:buf range:NSMakeRange(0, titlelen)];
                
                FriBidiParType type = FRIBIDI_PAR_ON;
                fribidi_log2vis(buf, titlelen, &type, titlebuf, NULL, NULL, NULL);
                
                double titlew = measureString(fontManager->font, titlebuf, titlelen, TITLE_FONT_SCALE);
                
                if (_curpm->x + titlew/2 > w_px - 5)
                    titlex = w_px - titlew - 5;
                else if (_curpm->x - titlew/2 < 5)
                    titlex = 5;
                else
                    titlex = _curpm->x - titlew/2;
                
                //TODO: move up/down with mouse cursor?
                if (_curpm->y - _curpm->style->iconDisplaySize/2 - 3 /*- fontManager->font->lineHeight*/ < 50)
                {
                    struct MAPREGION r = { titlex, _curpm->y + _curpm->style->iconDisplaySize/2 + 5, titlex + titlew, _curpm->y + _curpm->style->iconDisplaySize/2 + 5 + fontManager->font->lineHeight };
                    gstrings[gstrcnt++] = r;
                    titlealign = A_BOTTOM;
                    titley = _curpm->y + _curpm->style->iconDisplaySize/2 + 5;
                }
                else
                {
                    struct MAPREGION r = { titlex, _curpm->y - _curpm->style->iconDisplaySize/2 - 3 - fontManager->font->lineHeight*TITLE_FONT_SCALE, titlex + titlew, _curpm->y - _curpm->style->iconDisplaySize/2 - 3 };
                    gstrings[gstrcnt++] = r;                
                    titlealign = A_TOP;
                    titley = _curpm->y - _curpm->style->iconDisplaySize/2 - 3;
                }
            }
        }
        else if (_curpl && _curpl->title)
        {
            titlelen = [_curpl->title length];
            if (titlelen > MAX_TITLE_LEN)
                titlelen = MAX_TITLE_LEN;
            
            unichar buf[MAX_TITLE_LEN];
            [_curpl->title getCharacters:buf range:NSMakeRange(0, titlelen)];
            
            FriBidiParType type = FRIBIDI_PAR_ON;
            fribidi_log2vis(buf, titlelen, &type, titlebuf, NULL, NULL, NULL);
            
            double titlew = measureString(fontManager->font, titlebuf, titlelen, 0.7);
            
            if (lmx + titlew/2 > w_px - 5)
                titlex = w_px - titlew - 5;
            else if (lmx - titlew/2 < 5)
                titlex = 5;
            else
                titlex = lmx - titlew/2;
            
            if (lmy - 13 < 50)
            {
                struct MAPREGION r = { titlex, lmy+4, titlex + titlew, lmy+4 + fontManager->font->lineHeight };
                gstrings[gstrcnt++] = r;
                titlealign = A_BOTTOM;
                titley = lmy+4;
            }
            else
            {
                struct MAPREGION r = { titlex, lmy-CURSOR_HEIGHT+2 - fontManager->font->lineHeight*TITLE_FONT_SCALE, titlex + titlew, lmy-14 };
                gstrings[gstrcnt++] = r;                
                titlealign = A_TOP;
                titley = lmy-CURSOR_HEIGHT+2;
            }
        }
    }
        
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(mapView->lx, mapView->rx, mapView->ly, mapView->ry, 0, 1);
    mapView->projmode = PROJ_WORLD;
    
	int i;
    //Render imagery layers
	for (i = 0; i < lcnt; i++)
    {
        if (layers[i]->priority > 0)
            break;
		[layers[i] render];
    }
    
    if (showCoordGrid)
    {
        glDisable(GL_TEXTURE_2D);
        glDisable(GL_LINE_SMOOTH);
        glDisable(GL_BLEND);
        glEnable(GL_COLOR_LOGIC_OP);
        glLogicOp(GL_XOR);
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        
        glLineWidth(1);
        glColor4f(0.5, 0.5, 0.5, 1);

        double gstep;
        if (ppd*10 < 100)
            if (ppd*15 < 100)
                gstep = 30;
            else
                gstep = 15;
        else
            for (gstep = 10; gstep*ppd >= 200; gstep /= 2);
        
        NSString *fmt;
        if (gstep < 0.0001)
            fmt = @"%.6f°";
        else if (gstep < 0.001)
            fmt = @"%.5f°";
        else if (gstep < 0.01)
            fmt = @"%.4f°";
        else if (gstep < 1)
            fmt = @"%.2f°";
        else if (gstep < 5)
            fmt = @"%.1f°";
        else
            fmt = @"%.0f°";
        
        unichar buf[50];
        GLdouble gridpts[100], *ptr = gridpts;
        int gridlinecnt = 0;
        
        double glx = floor(lx/gstep) * gstep;
        double grx = floor(rx/gstep) * gstep;
        
        double _ly = _maxd(ly, -90);
        double _ry = _mind(ry, 90);

        double gly = floor(_ly/gstep) * gstep;
        double gry = floor(_ry/gstep) * gstep;
        
        double ypx = ry > 90 ? (90-cy) * ppd/cphi1 + hh_px : h_px-5;
        for (double x = glx; x <= grx; x+= gstep)
        {
            *(ptr++) = x;
            *(ptr++) = _ly;
            *(ptr++) = x;
            *(ptr++) = _ry;
            
            gridlinecnt++;
            
            NSString *s;
            if (x == 0)
                s = @"0°";
            else if (x == 180 || x == -180)
                s = @"±180°";
            else
                s = [NSString stringWithFormat:fmt, (x < -180 ? x+360 : (x > 180 ? x-360 : x))];
            [s getCharacters:buf];
            renderString(fontManager->font, buf, [s length], (x-lx)*ppd+3, ypx, A_TOP, 1, 1, 1, 0.7, 0.6);
        }

        for (double y = gly; y <= gry; y+= gstep)
        {
            *(ptr++) = lx;
            *(ptr++) = y;
            *(ptr++) = rx;
            *(ptr++) = y;
            
            gridlinecnt++;
            
            NSString *s;
            if (y == 0)
                s = @"0°";
            else if (y == 90)
                s = @"90°";
            else if (y == -90)
                s = @"-90°";
            else
                s = [NSString stringWithFormat:fmt, y];
            [s getCharacters:buf];
            renderString(fontManager->font, buf, [s length], 5, (y-cy) * ppd/cphi1 + hh_px, A_BOTTOM, 1, 1, 1, 0.7, 0.6);            
        }
        
        glVertexPointer(2, GL_DOUBLE, 0, gridpts);
        glDrawArrays(GL_LINES, 0, gridlinecnt*2);
                
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        glDisable(GL_COLOR_LOGIC_OP);
    }
    
    //Render feature layers
	for (; i < lcnt; i++)
    {
		[layers[i] render];
    }    
    
    /*//Render currently selected polyline - removed because we don't want to render polyline on top of placemark icons
    if (_curpl)
    {
        glDisable(GL_TEXTURE_2D);
        glEnable(GL_LINE_SMOOTH);
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);

        glVertexPointer(2, GL_DOUBLE, 0, _curpl->ptcoords);
        glLineWidth(_curpl->style->lineWidth + 1.5);
        glColor4f(_curpl->style->r, _curpl->style->g, _curpl->style->b, 1);
        
        glDrawArrays(GL_LINE_STRIP, 0, _curpl->ptcnt);
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        glDisable(GL_LINE_SMOOTH);
    }*/
        
    glEnable(GL_BLEND);
    
    if (showUserLoc && userloc_valid)
    {
        double ay = userloc_accuracy / (world->polarRadius*M_PI/180.0);
        if (userloc_lat-ay < ry && userloc_lat+ay > ly)
        {
            double ax = userloc_accuracy / (world->eqRadius*M_PI/180.0*cos(cy/180.0*M_PI));
            if (userloc_lon-ax < rx && userloc_lon+ax > lx)
            {
                glDisable(GL_TEXTURE_2D);

                if (ax*ppd > 8.0)
                {
                    GLdouble vs[65*2];
                    for (int i = 0; i < 64; i++)
                    {
                        vs[i*2+0] = userloc_lon+ax*cos(M_PI*2.0/64*i);
                        vs[i*2+1] = userloc_lat+ay*sin(M_PI*2.0/64*i);
                    }
                    vs[64*2+0] = vs[0];
                    vs[64*2+1] = vs[1];

                    glColor4f(0.5, 0.5, 1, 0.6);
                    
                    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
                    glEnableClientState(GL_VERTEX_ARRAY);
                    glDisableClientState(GL_COLOR_ARRAY);

                    glVertexPointer(2, GL_DOUBLE, 0, vs);
                    glDrawArrays(GL_POLYGON, 0, 64);
                    
                    glEnable(GL_LINE_SMOOTH);
                    glLineWidth(1.5f);
                    glColor4f(0.2, 0.2, 1, 0.6);
                    glDrawArrays(GL_LINE_STRIP, 0, 65);
                    glDisable(GL_LINE_SMOOTH);

                    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
                    glDisableClientState(GL_VERTEX_ARRAY);
                    glDisableClientState(GL_COLOR_ARRAY);
                }
                
                glColor4f(1, 1, 1, 1);
                glEnable(GL_POINT_SMOOTH);
                
                glPointSize(17);
                glBegin(GL_POINTS);
                glVertex2d(userloc_lon, userloc_lat);
                glEnd();

                glColor4f(0.2, 0.2, 1, 1);
                glPointSize(11);
                glBegin(GL_POINTS);
                glVertex2d(userloc_lon, userloc_lat);
                glEnd();
                
                glDisable(GL_POINT_SMOOTH);
            }
        }
    }    

    glEnable(GL_TEXTURE_2D);
    
    if (mapView->projmode != PROJ_WINDOW) {
        glLoadMatrixd(wndprojmatrix);
        mapView->projmode = PROJ_WINDOW;
    }

    if (showDistanceGrid)
    {
        [fontManager render];

        glDisable(GL_TEXTURE_2D);
        glDisable(GL_LINE_SMOOTH);
        glDisable(GL_BLEND);
        glEnable(GL_COLOR_LOGIC_OP);
        glLogicOp(GL_XOR);
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        
        glLineWidth(1);
        glColor4f(0.5, 0.5, 0.5, 1);
        
        unichar buf[50];
        GLdouble gridpts[100], *ptr = gridpts;
        int gridlinecnt = 0;
        
        double _lypx = (cy-_maxd(ly, -90)) * ppd/cphi1;
        double _rypx = (_mind(ry, 90)-cy) * ppd/cphi1;
        
        {
            *(ptr++) = hw_px;
            *(ptr++) = hh_px-20;
            *(ptr++) = hw_px;
            *(ptr++) = hh_px+20;

            *(ptr++) = hw_px-20;
            *(ptr++) = hh_px;
            *(ptr++) = hw_px+20;
            *(ptr++) = hh_px;
            
            gridlinecnt += 2;
        }
        
        double k = world->eqRadius*M_PI/180.0*cos(cy/180.0*M_PI)/ppd;
        for (double x = 100; x <= hw_px; x+= 100)
        {
            *(ptr++) = hw_px+x;
            *(ptr++) = hh_px-20;
            *(ptr++) = hw_px+x;
            *(ptr++) = hh_px+20;
            
            *(ptr++) = hw_px-x;
            *(ptr++) = hh_px-20;
            *(ptr++) = hw_px-x;
            *(ptr++) = hh_px+20;

            gridlinecnt += 2;
            
            double d = x*k;
            NSString *s = format_distance_from_meters(d);
            [s getCharacters:buf];
            
            renderString(fontManager->font, buf, [s length], hw_px+x+3, hh_px, A_BOTTOM, 1, 1, 1, 0.7, 0.6);
            renderString(fontManager->font, buf, [s length], hw_px-x+3, hh_px, A_BOTTOM, 1, 1, 1, 0.7, 0.6);
        }
        
        k = world->polarRadius*M_PI/180.0/ppd*cphi1;
        for (double y = 100; y <= hh_px; y+= 100)
        {
            double d = y*k;
            NSString *s = format_distance_from_meters(d);
            [s getCharacters:buf];
            
            if (y <= _rypx)
            {
                *(ptr++) = hw_px-20;
                *(ptr++) = hh_px+y;
                *(ptr++) = hw_px+20;
                *(ptr++) = hh_px+y;

                gridlinecnt++;

                renderString(fontManager->font, buf, [s length], hw_px, hh_px+y, A_BOTTOM, 1, 1, 1, 0.7, 0.6);
            }
            
            if (y <= _lypx)
            {
                *(ptr++) = hw_px-20;
                *(ptr++) = hh_px-y;
                *(ptr++) = hw_px+20;
                *(ptr++) = hh_px-y;
                gridlinecnt++;
                
                renderString(fontManager->font, buf, [s length], hw_px, hh_px-y, A_BOTTOM, 1, 1, 1, 0.7, 0.6);        
            }
        }
        
        glVertexPointer(2, GL_DOUBLE, 0, gridpts);
        glDrawArrays(GL_LINES, 0, gridlinecnt*2);
        
        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        glDisable(GL_COLOR_LOGIC_OP);
        
        glEnable(GL_TEXTURE_2D);
        glEnable(GL_BLEND);    
    }
    
    //Render title
    if (titlelen)
        renderString(fontManager->font, titlebuf, titlelen, titlex, titley, titlealign, 1, 1, 1, 1, TITLE_FONT_SCALE);

    //Render selected placemark icon on top of everything
    if (_curpm)
    {
        [fontManager render];
        
        glLoadIdentity();
        glOrtho(mapView->lx, mapView->rx, mapView->ly, mapView->ry, 0, 1);
        mapView->projmode = PROJ_WORLD;

        if (_curpm->lon < lx)
            glTranslated(360, 0, 0);
        else if (_curpm->lon > rx)
             glTranslated(-360, 0, 0);

        glEnable(GL_POINT_SPRITE_ARB);
        glTexEnvf(GL_POINT_SPRITE_ARB, GL_COORD_REPLACE_ARB, GL_TRUE);
        
        glPointSize(_curpm->style->iconDisplaySize*1.25);
        glColor4f(_curpm->style->r, _curpm->style->g, _curpm->style->b, 1);
        
        glBindTexture(GL_TEXTURE_2D, _curpm->style->tex);        
        
        glBegin(GL_POINTS);
        glVertex2d(_curpm->lon, _curpm->lat);
        glEnd();
        
        glDisable(GL_POINT_SPRITE_ARB);

        glLoadMatrixd(wndprojmatrix);
        mapView->projmode = PROJ_WINDOW;
    }
    
    [_f release];
    
    //Credits string
    {
        double strw = measureString(fontManager->font, world->credits, world->creditslen, CREDITS_FONT_SCALE);
        renderString(fontManager->font, world->credits, world->creditslen, w_px - strw - 10, 8, A_BOTTOM, 1, 1, 1, 0.7, CREDITS_FONT_SCALE);
    }
    
    //Render all text
    [fontManager render];
	
    //Render downloading indicator
    if (gdownloading > 0)
    {
        //glEnable(GL_TEXTURE_2D);
        if (!downloadingtex)
        {
            ImageLoader *il = [[ImageLoader alloc] initWithFile: [[NSBundle mainBundle] pathForImageResource:@"downloading-7.png"]];
            if ([il load])
            {
                glGenTextures(1, &downloadingtex);
                glBindTexture(GL_TEXTURE_2D, downloadingtex);
                
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
                glPixelStorei(GL_UNPACK_ROW_LENGTH, 32);
                glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
                glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
                
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 32, 32, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, il->imgdata);
                
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER,GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER,GL_LINEAR);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
                
            }
            [il release];
        }
        else
            glBindTexture(GL_TEXTURE_2D, downloadingtex);

        glTranslatef(10+8, 8+8, 0);
        glRotatef(downloadingrot, 0, 0, 1);
        glColor4f(1, 1, 1, 0.8);
        
        glEnableClientState(GL_TEXTURE_COORD_ARRAY);
        glEnableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        
        static GLdouble vs[] = { -8, -8, -8, 8, 8, 8, 8, -8 };
        static GLfloat tcs[] = { 0, 1, 0, 0, 1, 0, 1, 1 };
        
        glVertexPointer(2, GL_DOUBLE, 0, vs);
        glTexCoordPointer(2, GL_FLOAT, 0, tcs);
        glDrawArrays(GL_QUADS, 0, 4);

        glDisableClientState(GL_TEXTURE_COORD_ARRAY);
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_COLOR_ARRAY);
        
        downloadingrot -= 4;
        if (downloadingrot <= -360)
            downloadingrot = 0;
    }

    CGLFlushDrawable(CGL_MACRO_CONTEXT);
    CGLUnlockContext(CGL_MACRO_CONTEXT);
}

-(void) postChangeNotification
{
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:@"MapViewChanged" object:self] postingStyle:NSPostWhenIdle];
}

-(void) moveToX: (double)x Y: (double)y
{
    [infoPopover close];

	targetcx = x;
	targetcy = y;	
	if (targetcx > 180) targetcx -= 360;
	if (targetcy > 90) targetcy = 90;
	if (targetcx < -180) targetcx += 360;
	if (targetcy < -90) targetcy = -90;
	
	move = TRUE;
}

-(void) moveByDX: (double) dx dY: (double) dy
{
    [self moveToX: targetcx+dx Y: targetcy+dy*cphi1];
}

-(void) zoomTo: (double)_w
{
    curpm = NULL;
    curpl = NULL;
    [curfeatures release];
    curfeatures = nil;

    [infoPopover close];
        
	targetw = _w;
	if (targetw > 360.0)
		targetw = 360.0;
	if (targetw <= 0 || w_px/targetw > MAXPPD)
		targetw = w_px/MAXPPD;
    
	zoom = TRUE;
}

- (void)zoomBy: (double) dw
{
    [self zoomTo: targetw-dw];
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    NSPoint event_location = [theEvent locationInWindow];
    NSPoint local_point = [self convertPoint:event_location fromView:nil];

    lmx = local_point.x;
    lmy = local_point.y;
	
    //TODO: have to do this because of some inaccuracy when moving
    curpm = NULL;
    curpl = NULL;
    [curfeatures release];
    curfeatures = nil;

	[self moveByDX: -[theEvent deltaX]/ppd dY: [theEvent deltaY]/ppd];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    curpm = NULL;
    curpl = NULL;
    [curfeatures release];
    curfeatures = nil;
    
    
    BOOL precise = [theEvent hasPreciseScrollingDeltas];

	if (((useMultitouch && !([theEvent modifierFlags] & NSAlternateKeyMask)) ||
        (!useMultitouch && ([theEvent modifierFlags] & NSAlternateKeyMask))) && precise)
	{
        float dx = [theEvent scrollingDeltaX], dy = [theEvent scrollingDeltaY];
		[self moveByDX: -dx*0.0008*w dY: dy*0.0008*w]; //0.001
	}
	else
	{
		float t = [theEvent deltaY];
		if (!t)
			return;
        
        if ([theEvent isDirectionInvertedFromDevice])
            t = -t;
        
		if (t < 0)
			[self zoomBy: targetw*(precise?0.050:0.060)*t];
		else
			[self zoomBy: targetw*(1.0/(precise?0.950:0.940)-1)*t];
	}
}

- (void)magnifyWithEvent:(NSEvent *)theEvent
{
    curpm = NULL;
    curpl = NULL;
    [curfeatures release];
    curfeatures = nil;
    
    
    float t = [theEvent magnification]; 
    [self zoomBy: targetw*2*t];
}

NSTimer *kkk;
-(void) mouseEntered:(NSEvent *)theEvent
{
    if ([infoPopover isShown])
        return;

    NSPoint event_location = [theEvent locationInWindow];
    NSPoint local_point = [self convertPoint:event_location fromView:nil];
    
    if (!NSPointInRect(local_point, self.bounds))
        return;
    
    lmx = local_point.x;
    lmy = local_point.y;
    
    [self findFeatureUnderMouse];
}

-(void) mouseExited:(NSEvent *)theEvent
{
    if ([infoPopover isShown])
        return;

    [kkk invalidate];
    kkk = nil;
    
    curpl = NULL;
    curpm = NULL;
    [curfeatures release];
    curfeatures = nil;
}

-(void) mouseUp:(NSEvent *)theEvent
{
	if ([theEvent clickCount] == 2 && !([theEvent modifierFlags] & NSControlKeyMask))
	{
        [kkk invalidate];
        kkk = nil;

        NSPoint event_location = [theEvent locationInWindow];
        NSPoint local_point = [self convertPoint:event_location fromView:nil];

		double lat, lon;

		if (curpm)
		{
			lat = curpm->lat;
			lon = curpm->lon;
		}
		else
		{
            lat = (local_point.y - hh_px) * cphi1 / ppd + cy;
			lon = local_point.x / ppd + lx;
		}
        
        if (fabs(lat) > 90)
            return;
        if (lon > 180)
            lon -= 360;
        else if (lon < -180)
            lon += 360;
		
        curpm = NULL;
        curpl = NULL;
        [curfeatures release];
        curfeatures = nil;
        
        [self moveToX:lon Y:lat];
	}
    else if ([theEvent clickCount] == 1)
    {
        if ([infoPopover isShown])
            return;

        if ([theEvent modifierFlags] & NSControlKeyMask)
            [self showInfoPopover];
        else if ((curpm || curpl) && activateFeaturesOnLeftClick)
        {
            [kkk invalidate];
            kkk = [NSTimer scheduledTimerWithTimeInterval:[NSEvent doubleClickInterval] target:self selector:@selector(showInfoPopover) userInfo:theEvent repeats:NO];
        }
    }
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
	if ([theEvent clickCount] == 1 || !theEvent)
    {
        if ([infoPopover isShown])
            return;
        
        [self showInfoPopover];
    }
}

-(void) showInfoPopover
{
    [kkk invalidate];
    kkk = nil;
    
    if ([self.window attachedSheet])
        return;

    double x, y;

    if (curpm)
    {
        flat = curpm->lat;
        flon = curpm->lon;
        
        x = curpm->x;
        y = curpm->y;
        
        if ([curpm->title length])
            [[bigPopoverTitleLabel cell] setStringValue:curpm->title];
        else if ([curpm->label length])
            [[bigPopoverTitleLabel cell] setStringValue:curpm->label];
        else
            [[bigPopoverTitleLabel cell] setStringValue: @"—"];
        
        if (curpm->descr)
            [[bigPopoverWebView mainFrame] loadHTMLString: [NSString stringWithFormat:fdescrtemplate, curpm->descr] baseURL: nil];
    }
    else if (curpl)
    {
        x = lmx;//local_point.x;
        y = lmy;//local_point.y;
        
        flat = (y - hh_px) * cphi1 / ppd + cy;
        flon = x / ppd + lx;
        
        if ([curpl->title length])
            [[bigPopoverTitleLabel cell] setStringValue:curpl->title];
        else
            [[bigPopoverTitleLabel cell] setStringValue: @"—"];
        
        if (curpl->descr)
            [[bigPopoverWebView mainFrame] loadHTMLString: [NSString stringWithFormat:fdescrtemplate, curpl->descr] baseURL: nil];
    }
    else
    {
        x = lmx;//local_point.x;
        y = lmy;//local_point.y;
        
        flat = (y - hh_px) * cphi1 / ppd + cy;
        flon = x / ppd + lx;
        
        if (fabs(flat) > 90)
            return;
        if (flon > 180)
            flon -= 360;
        else if (flon < -180)
            flon += 360;
        
        [[bigPopoverTitleLabel cell] setStringValue: @"—"];
        
        if (world->reverseGeocoder)
        {
            [bigPopoverTitleLabel setHidden:YES];
            [bigPopoverWaitIndicator startAnimation:nil];
            
            [world->reverseGeocoder reverseGeocodeLat:flat lon:flon level:(int)ceil(log2(ppd*360.0/256.0)) withDelegate:self];
        }
        else
            [bigPopoverTitleLabel setHidden:NO];
    }
    
    [[bigPopoverCoordsLabel cell] setStringValue: FORMAT_LATLON(flat, flon)];
    [infoPopover showRelativeToRect:NSMakeRect(x, y, 1, 1) ofView:self preferredEdge:0];    
}

- (void)mouseMoved:(NSEvent *)theEvent
{
    if ([infoPopover isShown])
        return;

    [kkk invalidate];
    kkk = nil;
    
    NSPoint local_point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        
    if (!NSPointInRect(local_point, self.bounds))
        return;
    
    lmx = local_point.x;
    lmy = local_point.y;
    
    [self findFeatureUnderMouse];
}
    
-(void) findFeatureUnderMouse
{
    //TODO: +1/-1 really causes higher pixel accuracy here?
    double mlon = (lmx - 1)/ppd + lx;
    double mlat = (lmy - hh_px+1) * cphi1 / ppd + cy;
    
    if (fabs(mlat) > 90)
        return;
    if (mlon > 180)
        mlon -= 360;
    else if (mlon < -180)
        mlon += 360;

    if (curpm)
    {
        double maxdx = 9.0 / mapView->ppd;
        double maxdy = 9.0 / mapView->ppd * mapView->cphi1;

        if (fabs(mlat-curpm->lat) < maxdy && fabs(mlon-curpm->lon) < maxdx)
            return;
    }
    
    Class flc = [FeaturesLayer class];
    
    for (int i = lcnt-1; i >= 0; i--)
    {
        MapLayer *l = layers[i];
        if ([l isKindOfClass:flc])
        {
            if ([(FeaturesLayer*)l findFeatureForLat:mlat lon:mlon])
                return;
        }
    }
        
    curpm = NULL;
    curpl = NULL;
    [curfeatures release];
    curfeatures = nil;
}

-(void) reverseGeocoder: (id)obj didFinishWithAddress: (NSString*)address
{
    [bigPopoverTitleLabel setStringValue: address];
    
    [bigPopoverWaitIndicator stopAnimation:nil];
    [bigPopoverTitleLabel setHidden:NO];
}

-(void) reverseGeocoderDidFail: (id)obj
{
    [bigPopoverWaitIndicator stopAnimation:nil];
    [bigPopoverTitleLabel setHidden:NO];
}

- (void) goToLon: (double)lon lat: (double)lat w: (double)_w
{
    curpm = NULL;
    curpl = NULL;
    [curfeatures release];
    curfeatures = nil;
    
    if (_w)
        [self zoomTo: _w];
    
    [self moveToX:lon Y:lat];
}

-(void) zoomToWorld
{
    [self goToLon:0 lat:0 w:360];
}

-(void) zoomIn
{
    double k = 360;
    while(k >= targetw) k /= 2.0;
    [self zoomTo: k];
}

-(void) zoomOut
{
    double k = 360;
    while(k > targetw) k /= 2.0;
    [self zoomTo:k*2];
}

static void ThreeDConnexionMessageHandler(io_connect_t connection, natural_t messageType, void *messageArgument)
{
    [mapView handle3DMouseMessageWithType: messageType argument: messageArgument];
}

-(void) handle3DMouseMessageWithType: (natural_t)messageType argument: (void*)messageArgument
{
	if (messageType == kConnexionMsgDeviceState)
	{
        ConnexionDeviceState *state = (ConnexionDeviceState*) messageArgument;
        if(state->client == fConnexionClientID)
        {
            switch (state->command)
            {
                case kConnexionCmdHandleAxis:
                {
                    if ([self.window attachedSheet])
                        return;

                    double dx = state->axis[0] * 0.0015;
                    double dy = state->axis[2] * 0.0015;
                    double dz = state->axis[1] * 0.0015;
                                            
                    [self moveByDX: dx*0.01*w dY: dy*0.01*w];
                    if (dz < 0)
                        [self zoomBy: targetw*0.075*dz];
                    else
                        [self zoomBy: targetw*(1.0/0.960-1)*dz];

                    [self findFeatureUnderMouse];
                    break;
                }
                    
                case kConnexionCmdHandleButtons:
                    if ([infoPopover isShown])
                        return;

                    if (state->buttons == 1 || state->buttons == 2)
                        [self showInfoPopover];
                    break;
            }                
        }
	}
}

-(NSString*) linkToCurrentView
{
    return PLANITO_LINK(cy, cx, w);
}

- (void)popoverWillShow:(NSNotification *)notification
{
    if ([notification object] == infoPopover)
        [infoPopover setContentSize: NSMakeSize(400, (curpm && curpm->descr) ? 300 : 44)];
}

- (void)popoverDidClose:(NSNotification *)notification
{
    if ([notification object] == infoPopover)
    {
        curpm = NULL;
        curpl = NULL;
        [curfeatures release];
        curfeatures = nil;

        [[bigPopoverWebView mainFrame] loadHTMLString:@"" baseURL:nil];
        
        //Have to do this because we will not receive mouseMoved events until popover closed and now lmx/lmy are incorrect
        NSPoint local_point = [self convertPoint:[self.window mouseLocationOutsideOfEventStream] fromView:nil];
        lmx = local_point.x;
        lmy = local_point.y;
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (sender == bigPopoverWebView && frame == [bigPopoverWebView mainFrame] && [infoPopover isShown])
    {
        NSRect r = [[[bigPopoverWebView mainFrame] frameView] documentView].frame;
        
        float xmargin = 2, ymargin = 44 + 2;
        
        [infoPopover setContentSize: NSMakeSize(fmaxf(fminf(700,r.size.width)+xmargin, 400), fmaxf(fminf(r.size.height,700)+ymargin, 300))];
    }
}

- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener
{
    WebNavigationType navtype = [[actionInformation objectForKey:WebActionNavigationTypeKey] intValue];
    
    if (navtype == WebNavigationTypeLinkClicked || navtype == WebNavigationTypeFormSubmitted)
    {
        [listener ignore];
        [[NSWorkspace sharedWorkspace] openURL:[request URL]];
    }
    else
        [listener use];
}

-(void) showFeatureActionsMenu: (id)sender
{
    NSString *url = nil;
    
    if (curpl)
        url = curpl->url;
    else if (curpm)
        url = curpm->url;
    
    [[_featureActionsMenu itemAtIndex:0] setEnabled: url!=nil];
    
    NSRect r = bigPopoverActionsButton.frame;
    [_featureActionsMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(r.origin.x-1, r.origin.y+13) inView: bigPopoverViewController.view];
}

-(void) openFeatureExternalLink: (id)sender
{
    NSString *url = nil;
    
    if (curpl)
        url = curpl->url;
    else if (curpm)
        url = curpm->url;

    if (url)
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
}

-(void) openInExternalViewer:(NSMenuItem*)sender
{
    NSMutableString *url = [sender.representedObject mutableCopy];
    [url replaceOccurrencesOfString:@"{x}" withString:[[NSNumber numberWithDouble: flon] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{y}" withString:[[NSNumber numberWithDouble: flat] stringValue] options:0 range:NSMakeRange(0, [url length])];
    [url replaceOccurrencesOfString:@"{z}" withString:[[NSNumber numberWithDouble: (int)floor(log2(ppd*360.0/256.0))] stringValue] options:0 range:NSMakeRange(0, [url length])];
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:url]];
    [url release];
}

-(void) copyLinkToFeature:(id)sender
{
    NSString *s = PLANITO_LINK(flat, flon, w);
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb writeObjects:[NSArray arrayWithObject:[NSURL URLWithString:s]]];
}

-(void) addViewToFavorites
{
    AddBookmarkPanelController *abp = [AddBookmarkPanelController new];
    
    NSString *name;
    if ([infoPopover isShown])
    {
        name = [bigPopoverTitleLabel stringValue];
        if ([name isEqualToString:@"—"])
            name = FORMAT_LATLON(cy, cx);
    }
    else
        name = FORMAT_LATLON(cy, cx);
    
    [abp addBookmarkWithProposedName: name lat:cy lon:cx w:w type:BookmarkTypeView];
    [abp release];
}

-(void) addSelectionToFavorites
{
    AddBookmarkPanelController *abp = [AddBookmarkPanelController new];
    
    NSString *name;
    name = [bigPopoverTitleLabel stringValue];
    if ([name isEqualToString:@"—"])
        name = FORMAT_LATLON(flat, flon);
    
    BookmarkType type;
    if (curpm || curpl)
        type = BookmarkTypeFeature;
    else
        type = BookmarkTypeLocation;
    
    [abp addBookmarkWithProposedName: name lat:flat lon:flon w:w type:type];
    [abp release];
}

-(BOOL) parseAndGo: (NSString*)str
{
    //worldwind:// ww2d:// planito:// URLs
    {
        //planito://goto/world=Earth&lat=46.165496&lon=54.243478&view=164.802849
        //http://go.planitoapp.com/#world=Earth&lat=-21.805283&lon=-49.089858&view=0.003762
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^(?:worldwind|ww2d|planito)://goto/|(?:https?://)go\\.planitoapp\\.com/" options:NSRegularExpressionCaseInsensitive error:NULL];
        NSTextCheckingResult *match = [re firstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
        if (match)
        {
            NSString *wname = [str valueForURLParameter:@"world"];

            double lat = [[str valueForURLParameter:@"lat"] doubleValue];
            double lon = [[str valueForURLParameter:@"lon"] doubleValue];

            double _w = [[str valueForURLParameter:@"view"] doubleValue];

            if (wname && ![world.name isEqualToString:wname])
                if (![[NSApp delegate] switchWorldByName: wname])
                    return NO;

            [self goToLon: lon lat: lat w: _w];
            return YES;
        }
    }

    //Coordinates
    {
        if ([str hasPrefix:@"planito://"] && [str length] > 10)
            str = [str substringFromIndex:10];

        NSRange r_lat_deg, r_lat_min, r_lat_sec, r_lat_fullmin, r_lat_fulldeg, r_lat_neg;
        NSRange r_lon_deg, r_lon_min, r_lon_sec, r_lon_fullmin, r_lon_fulldeg, r_lon_neg;
        
        NSRegularExpression *re;
        NSTextCheckingResult *match = nil;

        //40.446195, -79.948862
        //40:26:46,-79:56:55
        //40°26′47″, -79°58′36″
        //40d 26′ 47″, -79d 58′ 36″
        //40:26:46.302 -79:56:55.903
        //40° 26.7717 -79° 56.93172
        re = [NSRegularExpression regularExpressionWithPattern:@"^(?:([0-9.-]+)(?:(?:°|d|:)(?: *(?:([0-9]+)(?:(?:′|'|:)(?: *([0-9.]+)(?:″|\")?)?)?|([0-9.]+)(?:′|')?))?)?|([0-9.-]+))[ ,]+(?:([0-9.-]+)(?:(?:°|d|:)(?: *(?:([0-9]+)(?:(?:′|'|:)(?: *([0-9.]+)(?:″|\")?)?)?|([0-9.]+)(?:′|')?))?)?|([0-9.-]+))$" options:NSRegularExpressionCaseInsensitive error:NULL];
        if ((match = [re firstMatchInString:str options:0 range:NSMakeRange(0, [str length])]))
        {
            r_lat_deg = [match rangeAtIndex: 1];
            r_lat_min = [match rangeAtIndex: 2];
            r_lat_sec = [match rangeAtIndex: 3];
            r_lat_fullmin = [match rangeAtIndex: 4];
            r_lat_fulldeg = [match rangeAtIndex: 5];
            r_lat_neg = NSMakeRange(NSNotFound, 0);

            r_lon_deg = [match rangeAtIndex: 6];
            r_lon_min = [match rangeAtIndex: 7];
            r_lon_sec = [match rangeAtIndex: 8];
            r_lon_fullmin = [match rangeAtIndex: 9];
            r_lon_fulldeg = [match rangeAtIndex: 10];
            r_lon_neg = NSMakeRange(NSNotFound, 0);

            goto done;
        }

        //40.446195N 79.948862W
        //40:26:46N,79:56:55W
        //40°26′47″N 79°58′36″W
        //40d 26′ 47″ N 79d 58′ 36″ W
        //40:26:46.302N 79:56:55.903W
        //40° 26.7717 N 79° 56.93172 W
        re = [NSRegularExpression regularExpressionWithPattern:@"^(?:([0-9.]+)(?:(?:°|d|:| )(?: *(?:([0-9]+)(?:(?:′|'|:| )(?: *([0-9.]+)(?:″|\")?)?)?|([0-9.]+)(?:′|')?))?)?|([0-9.]+)) *(N|S)[ ,]*(?:([0-9.]+)(?:(?:°|d|:| )(?: *(?:([0-9]+)(?:(?:′|'|:| )(?: *([0-9.]+)(?:″|\")?)?)?|([0-9.]+)(?:′|')?))?)?|([0-9.]+)) *(W|E)$" options:NSRegularExpressionCaseInsensitive error:NULL];
        if ((match = [re firstMatchInString:str options:0 range:NSMakeRange(0, [str length])]))
        {
            r_lat_deg = [match rangeAtIndex: 1];
            r_lat_min = [match rangeAtIndex: 2];
            r_lat_sec = [match rangeAtIndex: 3];
            r_lat_fullmin = [match rangeAtIndex: 4];
            r_lat_fulldeg = [match rangeAtIndex: 5];
            r_lat_neg = [match rangeAtIndex: 6];

            r_lon_deg = [match rangeAtIndex: 7];
            r_lon_min = [match rangeAtIndex: 8];
            r_lon_sec = [match rangeAtIndex: 9];
            r_lon_fullmin = [match rangeAtIndex: 10];
            r_lon_fulldeg = [match rangeAtIndex: 11];
            r_lon_neg = [match rangeAtIndex: 12];

            goto done;
        }

        //N40.446195 W79.948862
        //N40:26:46,W79:56:55
        //N40°26′47″ W79°58′36″
        //N40d 26′ 47″ W79d 58′ 36″
        //N40:26:46.302 W79:56:55.903
        //N40° 26.7717 W79° 56.93172
        re = [NSRegularExpression regularExpressionWithPattern:@"^(N|S) *(?:([0-9.]+)(?:(?:°|d|:| )(?: *(?:([0-9]+)(?:(?:′|'|:| )(?: *([0-9.]+)(?:″|\")?)?)?|([0-9.]+)(?:′|')?))?)?|([0-9.]+))[ ,]+(W|E) *(?:([0-9.]+)(?:(?:°|d|:| )(?: *(?:([0-9]+)(?:(?:′|'|:| )(?: *([0-9.]+)(?:″|\")?)?)?|([0-9.]+)(?:′|')?))?)?|([0-9.]+))$" options:NSRegularExpressionCaseInsensitive error:NULL];
        if ((match = [re firstMatchInString:str options:0 range:NSMakeRange(0, [str length])]))
        {
            r_lat_deg = [match rangeAtIndex: 2];
            r_lat_min = [match rangeAtIndex: 3];
            r_lat_sec = [match rangeAtIndex: 4];
            r_lat_fullmin = [match rangeAtIndex: 5];
            r_lat_fulldeg = [match rangeAtIndex: 6];
            r_lat_neg = [match rangeAtIndex: 1];

            r_lon_deg = [match rangeAtIndex: 8];
            r_lon_min = [match rangeAtIndex: 9];
            r_lon_sec = [match rangeAtIndex: 10];
            r_lon_fullmin = [match rangeAtIndex: 11];
            r_lon_fulldeg = [match rangeAtIndex: 12];
            r_lon_neg = [match rangeAtIndex: 7];

            goto done;
        }

        done:;
        if (match)
        {
            double lat_deg, lat_min, lat_sec;
            double lon_deg, lon_min, lon_sec;

            if (r_lat_deg.location != NSNotFound)
            {
                lat_deg = [[str substringWithRange:r_lat_deg] doubleValue];

                if (r_lat_min.location != NSNotFound)
                {
                    lat_min = [[str substringWithRange:r_lat_min] doubleValue];

                    if (r_lat_sec.location != NSNotFound)
                        lat_sec = [[str substringWithRange:r_lat_sec] doubleValue];
                    else
                        lat_sec = 0;
                }
                else if (r_lat_fullmin.location != NSNotFound)
                {
                    lat_min = [[str substringWithRange:r_lat_fullmin] doubleValue];
                    lat_sec = 0;
                }
                else
                    lat_min = lat_sec = 0;
            }
            else
            {
                lat_deg = [[str substringWithRange:r_lat_fulldeg] doubleValue];
                lat_min = lat_sec = 0;
            }

            if (r_lon_deg.location != NSNotFound)
            {
                lon_deg = [[str substringWithRange:r_lon_deg] doubleValue];

                if (r_lon_min.location != NSNotFound)
                {
                    lon_min = [[str substringWithRange:r_lon_min] doubleValue];

                    if (r_lon_sec.location != NSNotFound)
                        lon_sec = [[str substringWithRange:r_lon_sec] doubleValue];
                    else
                        lon_sec = 0;
                }
                else if (r_lon_fullmin.location != NSNotFound)
                {
                    lon_min = [[str substringWithRange:r_lon_fullmin] doubleValue];
                    lon_sec = 0;
                }
                else
                    lon_min = lon_sec = 0;
            }
            else
            {
                lon_deg = [[str substringWithRange:r_lon_fulldeg] doubleValue];
                lon_min = lon_sec = 0;
            }

            double lat = lat_deg + lat_min / 60.0 + lat_sec / 3600.0;
            double lon = lon_deg + lon_min / 60.0 + lon_sec / 3600.0;

            if (r_lat_neg.location != NSNotFound)
            {
                if ([[[str substringWithRange:r_lat_neg] uppercaseString] isEqualToString: @"S"])
                        lat = -lat;
                if ([[[str substringWithRange:r_lon_neg] uppercaseString] isEqualToString: @"W"])
                        lon = -lon;
            }

            [self goToLon: lon lat: lat w: 0];
            return YES;
        }
    }

    //Google Maps URL
    {
        //http://maps.google.ru/?ll=55.741028,37.669373&spn=0.545792,1.260681&t=k&vpsrc=6&z=10
        //http://maps.google.com/maps?ll=55.75,37.616667&spn=0.1,0.1&t=m&lci=org.wikipedia.en&q=55.75,37.616667
        //http://maps.google.co.jp/maps?ll=55.75,37.616667&spn=0.1,0.1&t=m&lci=org.wikipedia.en&q=55.75,37.616667
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^(?:https?://)?maps\\.google\\." options:NSRegularExpressionCaseInsensitive error:NULL];
        NSTextCheckingResult *match = [re firstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
        if (match)
        {
            NSRegularExpression *re2 = [NSRegularExpression regularExpressionWithPattern:@"(?:^|[^\\w])ll=([0-9.-]+),([0-9.-]+)" options:NSRegularExpressionCaseInsensitive error:NULL];
            NSTextCheckingResult *match2 = [re2 firstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
            
            if (match2)
            {
                double lat = [[str substringWithRange:[match2 rangeAtIndex:1]] doubleValue];
                double lon = [[str substringWithRange:[match2 rangeAtIndex:2]] doubleValue];
                double z = [[str valueForURLParameter:@"z"] doubleValue];
                           
                if (![world.name isEqualToString:@"Earth"])
                    if (![[NSApp delegate] switchWorldByName: @"Earth"])
                        return NO;

                if (z)
                    [self goToLon: lon lat: lat w: (double)w_px / pow(2, z-1)*256.0/360.0];
                else
                    [self goToLon: lon lat: lat w: 0];
            }
            return YES;
        }
    }
    
    //Google Moon & Mars
    {
        //http://www.google.com/moon/#lat=-5.090944&lon=-15.732421&zoom=6&map=elevation&apollo=
        //http://www.google.co.jp/moon/#lat=-5.090944&lon=-15.732421&zoom=6&map=elevation&apollo=
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^(?:https?://)?(?:www\\.)?google\\.(?:[a-z]{2,3}|co\\.[a-z]{2,3})/(moon|mars)/(.+)$" options:NSRegularExpressionCaseInsensitive error:NULL];
        NSTextCheckingResult *match = [re firstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
        if (match)
        {
            NSString *wname = [str substringWithRange:[match rangeAtIndex:1]];
            NSString *q = [str substringWithRange:[match rangeAtIndex:2]];
            
            
            double lat = [[q valueForURLParameter:@"lat"] doubleValue];
            double lon = [[q valueForURLParameter:@"lon"] doubleValue];
            double z = [[q valueForURLParameter:@"zoom"] doubleValue];
            
            if (![[world.name lowercaseString] isEqualToString:wname])
                if (![[NSApp delegate] switchWorldByName: wname])
                    return NO;
            
            if (z)
                [self goToLon: lon lat: lat w: (double)w_px / pow(2, z-1)*256.0/360.0];
            else
                [self goToLon: lon lat: lat w: 0];
            return YES;
        }
    }

    //Bing Maps URL
    {
        //http://it.bing.com/maps/?v=2&cp=59.46256272144687~61.06497130632078&lvl=5&dir=0&sty=r&form=LMLTCC
        //http://www.bing.com/maps/default.aspx?v=2&cp=40.15872999999999~-79.07250299999998&sty=a&lvl=17
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"^(?:https?://)?[a-z]{2,3}\\.bing\\.com/maps/(.+)$" options:NSRegularExpressionCaseInsensitive error:NULL];
        NSTextCheckingResult *match = [re firstMatchInString:str options:0 range:NSMakeRange(0, [str length])];
        if (match)
        {
            NSString *q = [str substringWithRange:[match rangeAtIndex:1]];
            NSRegularExpression *re2 = [NSRegularExpression regularExpressionWithPattern:@"(?:^|[^\\w])cp=([0-9.-]+)~([0-9.-]+)" options:NSRegularExpressionCaseInsensitive error:NULL];
            NSTextCheckingResult *match2 = [re2 firstMatchInString:q options:0 range:NSMakeRange(0, [q length])];
            
            if (match2)
            {
                double lat = [[q substringWithRange:[match2 rangeAtIndex:1]] doubleValue];
                double lon = [[q substringWithRange:[match2 rangeAtIndex:2]] doubleValue];
                double z = [[q valueForURLParameter:@"lvl"] doubleValue];
            

                if (![world.name isEqualToString:@"Earth"])
                    if (![[NSApp delegate] switchWorldByName: @"Earth"])
                        return NO;

                if (z)
                    [self goToLon: lon lat: lat w: (double)w_px / pow(2, z-1)*256.0/360.0];
                else
                    [self goToLon: lon lat: lat w: 0];
                return YES;
            }
        }
    }

    //Openstreetmap, opencyclemap, yahoo maps and others
    {
        NSString *lat_str = [str valueForURLParameter:@"lat"];
        NSString *lon_str = [str valueForURLParameter:@"lon"];

        if (lat_str && lon_str)
        {
            double lat = [lat_str doubleValue];
            double lon = [lon_str doubleValue];
            double z = [[str valueForURLParameter:@"zoom"] doubleValue];

            if (![world.name isEqualToString:@"Earth"])
                if (![[NSApp delegate] switchWorldByName: @"Earth"])
                    return NO;

            if (z)
                [self goToLon: lon lat: lat w: (double)w_px / pow(2, z-1)*256.0/360.0];
            else
                [self goToLon: lon lat: lat w: 0];
            return YES;
        }
    }
    
    return NO;
}

-(void) unregister3DMouse
{
    if(InstallConnexionHandlers != NULL)
	{
		if (fConnexionClientID)
            UnregisterConnexionClient(fConnexionClientID);
		CleanupConnexionHandlers();
	}
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end
