//
//  XmlXslPmTileProvider.h
//  Planito
//
//  Created by Vitaliy Pronkin on 1.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RemoteTileProvider.h"

@interface XMLPlacemarksTileProvider : RemoteTileProvider {
    NSString *xsl;
}

@end
