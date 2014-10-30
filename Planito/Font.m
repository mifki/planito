//
//  Font.m
//  Planito
//
//  Created by Vitaliy Pronkin on 4/27/07.
//  Copyright 2007 mifki. All rights reserved.
//

#include <OpenGL/CGLMacro.h> 
#import "Font.h"
#import "Globals.h"
#import "ImageLoader.h"

extern CGLContextObj CGL_MACRO_CONTEXT;

@interface Font ()
-(void) createTextureForPage: (int)_page;
@end

double measureString (Font *font, unichar *str, int len, double scale)
{
	unsigned int i;
	
	double width = 0;
	
	for (i = 0; i < len; i++)
    {
        unichar c = str[i];
        
        if (c >= GLYPH_CNT || !font->w[c])
            c = 63; //replace unsupported chars with '?'

		width += font->xa[c]*scale + 1;
    }

	return width;
}

void renderString (Font *font, unichar *str, int len, double x_pos, double y_pos, int y_align, float r, float g, float b, float a, double scale)
{
    if (fontManager->charcnt + len > fontManager->maxcharcnt)
        [fontManager enlargeBuffers];
    
    for (int i = 0; i < font->pagecnt; i++)
    {
        if (font->indcnt[i] + len > font->maxindcnt[i])
        {
            font->maxindcnt[i] += FONTMAN_BUFFER_SIZE_STEP;
            font->indices[i] = (GLuint*)realloc(font->indices[i], font->maxindcnt[i]*sizeof(GLuint)*4);
        }
    }

    switch (y_align)
    {
        case A_TOP:
            break;
        case A_CENTER:
            y_pos += font->lineOffset*scale;
            break;
        case A_BOTTOM:
            y_pos += font->lineHeight*scale;
            break;
    }
    
	for (int i = 0; i < len; i++)
    {
        unichar c = str[i];
        
        if (c == 32) //don't draw whitespace :)
        {
            x_pos += font->xa[c]*scale + 1;
            continue;
        }
        
        if (c >= GLYPH_CNT || !font->w[c])
            c = 63; //replace unsupported chars with '?'
        
        int page = font->page[c];
        double xo = font->xo[c]*scale;
        double yo = font->yo[c]*scale;
        double w = font->w[c]*scale;
        double h = font->h[c]*scale;
        
        double tx = font->tx[c];
        double ty = font->ty[c];
        double tw = font->tw[c];
        double th = font->th[c];
        
		int k = fontManager->charcnt << 3;
		fontManager->tcoords[k++] = tx;
		fontManager->tcoords[k++] = ty + th;
        
		fontManager->tcoords[k++] = tx;
		fontManager->tcoords[k++] = ty;
        
		fontManager->tcoords[k++] = tx + tw;
		fontManager->tcoords[k++] = ty;
        
		fontManager->tcoords[k++] = tx + tw;
		fontManager->tcoords[k] = ty + th;
		
		k = fontManager->charcnt << 3;
		
		fontManager->vcoords[k++] = x_pos + xo;
		fontManager->vcoords[k++] = y_pos - h - yo;
        
		fontManager->vcoords[k++] = x_pos + xo;
		fontManager->vcoords[k++] = y_pos - yo;
        
		fontManager->vcoords[k++] = x_pos + xo + w;
		fontManager->vcoords[k++] = y_pos - yo;
        
		fontManager->vcoords[k++] = x_pos + xo + w;
		fontManager->vcoords[k] = y_pos - yo - h;
		
		x_pos += font->xa[c]*scale + 1;
		
		k = fontManager->charcnt << 4;
		fontManager->colors[k++] = r;
		fontManager->colors[k++] = g;
		fontManager->colors[k++] = b;
		fontManager->colors[k++] = a;
		
		fontManager->colors[k++] = r;
		fontManager->colors[k++] = g;
		fontManager->colors[k++] = b;
		fontManager->colors[k++] = a;
		
		fontManager->colors[k++] = r;
		fontManager->colors[k++] = g;
		fontManager->colors[k++] = b;
		fontManager->colors[k++] = a;
		
		fontManager->colors[k++] = r;
		fontManager->colors[k++] = g;
		fontManager->colors[k++] = b;
		fontManager->colors[k] = a;
        
        font->indices[page][font->indcnt[page]++] = fontManager->charcnt*4;
        font->indices[page][font->indcnt[page]++] = fontManager->charcnt*4+1;
        font->indices[page][font->indcnt[page]++] = fontManager->charcnt*4+2;
        font->indices[page][font->indcnt[page]++] = fontManager->charcnt*4+3;
        
        fontManager->charcnt++;
	}
}

@implementation Font

-(Font*) initWithConfigs: (NSArray*)configs
{
    if (self=[super init])
    {
        for (NSString *cfg in configs)
        {
            NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData: [NSData dataWithContentsOfFile: [[NSBundle mainBundle] pathForResource: cfg ofType: @"fnt"]] options: 0 error: nil];
            if (doc)
            {
                NSXMLElement *xcommon = [[[doc rootElement] elementsForName:@"common"] lastObject];
                lineHeight = [[[xcommon attributeForName:@"lineHeight"] stringValue] doubleValue];
                base = [[[xcommon attributeForName:@"base"] stringValue] doubleValue];
                
                NSArray *xpages = [doc nodesForXPath: @"//pages/page" error: nil];
                for (int i = 0; i < [xpages count]; i++)
                {
                    pagefns[pagecnt+i] = [[[[xpages objectAtIndex:i] attributeForName:@"file"] stringValue] retain];
                }
                
                NSArray *chars = [doc nodesForXPath: @"//chars/char" error: nil];
                for (int i = 0; i < [chars count]; i++)
                {
                    NSXMLElement *el = [chars objectAtIndex: i];
                    int c = [[[el attributeForName: @"id"] stringValue] intValue];
                    
                    page[c] = pagecnt + [[[el attributeForName: @"page"] stringValue] intValue];
                    
                    x[c] = [[[el attributeForName: @"x"] stringValue] intValue];
                    y[c] = [[[el attributeForName: @"y"] stringValue] intValue];
                    w[c] = [[[el attributeForName: @"width"] stringValue] intValue];
                    h[c] = [[[el attributeForName: @"height"] stringValue] intValue];
                    xo[c] = [[[el attributeForName: @"xoffset"] stringValue] intValue];
                    yo[c] = [[[el attributeForName: @"yoffset"] stringValue] intValue];
                    xa[c] = [[[el attributeForName: @"xadvance"] stringValue] intValue];
                    tx[c] = x[c] / 1024.0;
                    ty[c] = y[c] / 1024.0;	
                    tw[c] = w[c] / 1024.0;	
                    th[c] = h[c] / 1024.0;	
                }
                
                pagecnt += [xpages count];
                
                [doc release];
            }
        }
        
        lineOffset = floor(lineHeight - base/2);
    }
	
	return self;
}

-(void) createTextureForPage: (int)_page
{
    ImageLoader *il = [[ImageLoader alloc] initWithFile:[[NSBundle mainBundle] pathForImageResource:pagefns[_page]]];
    [il load];
    pageimgs[_page] = il->imgdata;
    [il release];
        
	glGenTextures(1, &tex[_page]);
	glBindTexture(GL_TEXTURE_2D,tex[_page]);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_CACHED_APPLE);
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 1024);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1024, 1024, 0, GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, pageimgs[_page]);
	
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
	//glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE);
	//glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
}

@end
