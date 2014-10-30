/* InfoPanelController */

#import <Cocoa/Cocoa.h>

@interface InfoPanelController
{
	IBOutlet NSTextField *latField;
	IBOutlet NSTextField *lonField;	
	IBOutlet NSTextField *infoField;	
	IBOutlet NSView *view;		
	IBOutlet NSOutlineView *objList;
	
	IBOutlet NSPanel *editObjectPanel;
	IBOutlet NSTextField *editObjectTitle;
	IBOutlet NSColorWell *editObjectLineColor;
	IBOutlet NSColorWell *editObjectFillColor;
	IBOutlet NSButton *editObjectClosed, *editObjectFilled, *editObjectOutlined;
	IBOutlet NSTextField *editObjectLineWidth;
	IBOutlet NSStepper *editObjectLineWidthStepper;
	
	bool editObjectPrevClosed;
}

-(IBAction) editpressed: (id)sender;
-(IBAction) newpressed: (id)sender;

-(IBAction) editObjectClosedChanged: (id)sender;
-(IBAction) editObjectFilledChanged: (id)sender;
-(IBAction) editObjectOutlinedChanged: (id)sender;
-(IBAction) editObjectFillColorChanged: (id)sender;
-(IBAction) editObjectLineColorChanged: (id)sender;
-(IBAction) editObjectLineWidthChanged: (id)sender;
-(IBAction) editObjectLineWidthStepperChanged: (id)sender;

@end
