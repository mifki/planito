//
//  PreferencesPanelController.h
//  Planito
//
//  Created by Vitaliy Pronkin on 23.9.11.
//  Copyright 2011 mifki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PreferencesPanelController : NSObject {
    IBOutlet NSPanel *panel;
}

-(IBAction) done: (id)sender;

-(void) showInWindow: (NSWindow*)window;

@end
