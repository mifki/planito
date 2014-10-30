/* LayersPanelController */

#import <Cocoa/Cocoa.h>

@interface LayersPanelController : NSViewController
{
    IBOutlet NSPopover *ourPopover;
	
    IBOutlet NSOutlineView *layersView;
}

-(void) resizeContainer;

@end
