//
//  QuadTile.h
//  Planito
//
//  Created by Vitaliy Pronkin on 2/2/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <OpenGL/GL.h>
#import "Tile.h"

@class QuadTileLayer;

@interface QuadTile : Tile {
    GLdouble vs[8];
    GLdouble vs_merc[8*10];
    
@public
	double cx, cy;

	double degx;
	
	QuadTileLayer *layer;
	QuadTile **childs;
    QuadTile *_childs[4];
	
	GLuint tex;
    short texind;

    unsigned char *imgdata;

    BOOL uflag;
    double udist;
}

-(QuadTile*) initWithLayer: (QuadTileLayer*) _layer level: (int) _level i: (int) _i j: (int) _j;

@end
