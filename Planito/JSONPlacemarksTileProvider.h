//
//  JSONPlacemarksTileProvider.h
//  Planito
//
//  Created by Vitaliy Pronkin on 13.12.11.
//  Copyright (c) 2011 mifki. All rights reserved.
//

#import "RemoteTileProvider.h"

@interface JSONPlacemarksTileProvider : RemoteTileProvider {
    NSString *xsl;
}
@end