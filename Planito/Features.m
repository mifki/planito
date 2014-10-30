//
//  Features.m
//  Planito
//
//  Created by Vitaliy Pronkin on 17.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "Features.h"

@implementation Features

-(void) dealloc
{
    if (placemarks)
    {
        for (int k = 0; k < pmcnt; k++)
        {
            [placemarks[k].title release];
            [placemarks[k].label release];
            [placemarks[k].descr release];
            [placemarks[k].url release];
        }
        free(placemarks);
    }
    
    if (polylines)
    {
        for (int k = 0; k < plcnt; k++)
        {
            [polylines[k].title release];
            [polylines[k].descr release];
            [polylines[k].url release];
            free(polylines[k].ptcoords);
        }
        free(polylines);
    }
    
    [super dealloc];
}

@end
