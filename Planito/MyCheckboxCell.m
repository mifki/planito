//
//  MyCheckboxCell.m
//  Planito
//
//  Created by Vitaliy Pronkin on 9.8.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "MyCheckboxCell.h"

@implementation MyCheckboxCell

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView
{
    NSPoint event_location = [event locationInWindow];
    NSPoint local_point = [controlView convertPoint:event_location fromView:nil];
    
    if (local_point.x > 20+cellFrame.origin.x)
        return 0;
    
	return [super hitTestForEvent: event inRect:cellFrame ofView:controlView];
}

@end
