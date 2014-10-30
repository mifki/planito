//
//  FontManager.h
//  Planito
//
//  Created by Vitaliy Pronkin on 4/27/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#define FONTMAN_BUFFER_SIZE_STEP 1024

@class Font;

@interface FontManager : NSObject {
@public
	Font *font;
	unsigned int charcnt, maxcharcnt;
	
	double *tcoords, *vcoords;
	float *colors;
}

-(void) render;

-(void) enlargeBuffers;

@end
