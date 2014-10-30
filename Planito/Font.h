//
//  Font.h
//  Planito
//
//  Created by Vitaliy Pronkin on 4/27/07.
//  Copyright 2007 mifki. All rights reserved.
//

#import <OpenGL/GL.h>

#define GLYPH_CNT 65536

@interface Font : NSObject {
@public
	GLuint tex[32];
    unsigned char *pageimgs[32];
    NSString *pagefns[32];
    int pagecnt;
    
    double lineHeight, base, lineOffset;
    
    int page[GLYPH_CNT];
    double x[GLYPH_CNT], y[GLYPH_CNT], w[GLYPH_CNT], h[GLYPH_CNT];
    double tx[GLYPH_CNT], ty[GLYPH_CNT], tw[GLYPH_CNT], th[GLYPH_CNT];
    double xo[GLYPH_CNT], yo[GLYPH_CNT], xa[GLYPH_CNT];
    
    GLuint *indices[32];
    int indcnt[32], maxindcnt[32];
}

@end

#define A_CENTER 0
#define A_TOP 1
#define A_BOTTOM 2

//inline
double measureString (Font *font, unichar *str, int len, double scale);
//inline
void renderString (Font *font, unichar *str, int len, double x_pos, double y_pos, int y_align, float r, float g, float b, float a, double scale);
    