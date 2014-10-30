//
//  PreferencesPanelController.m
//  Planito
//
//  Created by Vitaliy Pronkin on 23.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import "PreferencesPanelController.h"

@implementation PreferencesPanelController

- (id)init
{
    if (self = [super init]) {
        [NSBundle loadNibNamed: @"PreferencesPanel" owner:self];
    }
    
    return self;
}

-(void) showInWindow: (NSWindow*)window
{
    if ([window attachedSheet])
        return;
    [self retain];
    
    //[panel orderFront:nil];
    [NSApp beginSheet: panel modalForWindow: window modalDelegate: nil didEndSelector: nil contextInfo: nil];
}

-(void) done: (id)sender
{
    [NSApp endSheet: panel];
    [panel close];
    
    [self release];
}

@end
