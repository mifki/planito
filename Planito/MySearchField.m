//
//  MySearchField.m
//  Planito
//
//  Created by Vitaliy Pronkin on 13.1.12.
//  Copyright (c) 2012 mifki. All rights reserved.
//

#import "MySearchField.h"

@implementation MySearchField

-(BOOL) becomeFirstResponder
{
    BOOL r = [super becomeFirstResponder];
    
    if (r)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DidReceiveFocus" object:self];
    
    return r;
}


@end
