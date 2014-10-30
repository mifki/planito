//
//  FontManager.m
//  Planito
//
//  Created by Vitaliy Pronkin on 4/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#include <OpenGL/CGLMacro.h> 
#import <OpenGL/GL.h>
#import "FontManager.h"
#import "Font.h"
#import "Globals.h"

extern CGLContextObj CGL_MACRO_CONTEXT;

@implementation FontManager

-(FontManager*) init
{
    if (self=[super init])
    {
        font = [[Font alloc] initWithConfigs: [NSArray arrayWithObjects: @"cjk", @"main", nil]];
    }
	
	return self;
}

-(void) enlargeBuffers
{
    maxcharcnt += FONTMAN_BUFFER_SIZE_STEP;
    
    tcoords = (double*)realloc(tcoords, maxcharcnt*sizeof(double)*4*2);  //2 components for each vertex
    vcoords = (double*)realloc(vcoords, maxcharcnt*sizeof(double)*4*2);  //2 components for each vertex
    colors = (float*)realloc(colors, maxcharcnt*sizeof(float)*4*4); //4 components for each vertex
}

-(void) render
{
    if (!charcnt)
        return;

    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_COLOR_ARRAY);
	glTexCoordPointer(2, GL_DOUBLE, 0, tcoords);
	glVertexPointer(2, GL_DOUBLE, 0, vcoords);
	glColorPointer(4, GL_FLOAT, 0, colors);
    
    for (int i = 0; i < font->pagecnt; i++)
    {
        if (font->indcnt[i])
        {
            if (!font->tex[i])
                [font createTextureForPage: i];
            glBindTexture(GL_TEXTURE_2D, font->tex[i]);    
            glDrawElements(GL_QUADS, font->indcnt[i], GL_UNSIGNED_INT, font->indices[i]);
            font->indcnt[i] = 0;
        }
    }
    
    charcnt = 0;
}

@end
