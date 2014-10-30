#import "InfoPanelController.h"
#import "Globals.h"
#import "UserObjectsLayer.h"

@implementation InfoPanelController

InfoPanelController *infoPanelController;
extern UserObjectsLayer *userObjectsLayer;


- (void)awakeFromNib
{
	infoPanelController = self;
	[editObjectPanel setMovableByWindowBackground: YES];
	/*
	[panel setBackgroundColor: [NSColor colorWithCalibratedWhite:0.95 alpha: 1]];
	[panel setMovableByWindowBackground:YES];	
	[panel setOpaque: NO];
	[panel setAlphaValue: 0.90];	
	[[panel standardWindowButton:NSWindowMiniaturizeButton] setHidden:YES];
	[[panel standardWindowButton:NSWindowZoomButton] setHidden:YES];
	[panel setShowsResizeIndicator: TRUE];
*/
[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cc:) name:@"aaa1" object:nil];
}

- (NSView *)inspectorView
{
	if (!view){
        [NSBundle loadNibNamed:@"InfoPanel" owner:self];
		//	[self refresh];
	}
	return view;
}

- (void)cc: (id) note;
{
	[latField setDoubleValue: mapView->cy];
	[lonField setDoubleValue: mapView->cx];	
//	[infoField setStringValue: info];
}
/*
- (BOOL)windowShouldClose:(id)sender
{
    timer = [[NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(fade:) userInfo:nil repeats:YES] retain];
    return NO;
}

- (void)fade:(NSTimer *)theTimer
{
    if ([panel alphaValue] > 0.0)
        [panel setAlphaValue:[panel alphaValue] - 0.2];
    else
	{
        [timer invalidate];
        [timer release];
        timer = nil;
        
        [panel close];
        [panel setAlphaValue:1.0];
    }
}
*/

-(IBAction) editpressed: (id)sender
{
	if (mapView->curobj) // TODO: do we need this?
		return;
	int row = [objList selectedRow];
	if (row == -1)
		return;
	
	mapView->curobj = [objList itemAtRow: row];	
	mapView->editMode = !mapView->editMode;
	[editObjectPanel makeKeyAndOrderFront: self];
}

-(IBAction) newpressed: (id)sender
{
	POBJECT *obj = [[POBJECT alloc] init];
	userObjectsLayer->objects[userObjectsLayer->ocnt++] = obj;
	mapView->curobj = obj;	
	obj->outlined = YES;
	obj->fr = obj->fg = obj->fb = obj->fa = obj->lr = obj->lg = obj->lb = obj->la = 1;
	obj->lineWidth = 1;
	mapView->editMode = TRUE;
	
	[objList reloadData];
	[objList selectRowIndexes: [NSIndexSet indexSetWithIndex: [objList rowForItem: obj]] byExtendingSelection: FALSE];
	[self editObject: obj];
}

- (void) editObject: (POBJECT *)obj
{
	[editObjectOutlined setState: obj->outlined];
	[editObjectFilled setState: obj->filled];
	[editObjectClosed setState: obj->closed];
	[editObjectPanel makeKeyAndOrderFront: self];
	
	[editObjectClosed setEnabled: !obj->filled];
	[editObjectOutlined setEnabled: obj->filled];
	
	[editObjectFillColor setEnabled: obj->filled];
	[editObjectLineColor setEnabled: obj->outlined];	
	
	[editObjectFillColor setColor: [NSColor colorWithCalibratedRed: obj->fr green: obj->fg blue: obj->fb alpha: obj->fa]];
	[editObjectLineColor setColor: [NSColor colorWithCalibratedRed: obj->lr green: obj->lg blue: obj->lb alpha: obj->la]];
	
	[editObjectLineWidth setEnabled: obj->outlined];	
	[editObjectLineWidthStepper setEnabled: obj->outlined];	
	
	[editObjectLineWidth setFloatValue: obj->lineWidth];
	[editObjectLineWidthStepper setFloatValue: obj->lineWidth];	
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if (!userObjectsLayer)
		return nil;
	
	if (!item)
		return userObjectsLayer->objects[index];
	
	return nil;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (!userObjectsLayer)
		return nil;
	
	return NO;//[item isKindOfClass: [LayerSet class]];
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (!userObjectsLayer)
		return 0;
	NSLog(@"-");
	
	if (!item)
		return userObjectsLayer->ocnt;
	
	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (!userObjectsLayer)
		return nil;
	
	if ([[tableColumn identifier] isEqualToString: @"name"])
		return ((POBJECT*)item)->title;
	
	if ([[tableColumn identifier] isEqualToString: @"on"])
		return [NSNumber numberWithInt: 1];	
	
	return nil;
}
/*
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString: @"on"])
		[((LayerSet*)item) setOn: [object boolValue]];
}
*/

- (void)windowWillClose:(NSNotification *)aNotification
{
	mapView->editMode = FALSE;
	mapView->curobj = nil;
	[editObjectLineColor deactivate];
	[editObjectFillColor deactivate];	
}

-(void) editObjectClosedChanged: (id)sender
{
	mapView->curobj->closed = [sender state];
}

-(void) editObjectFilledChanged: (id)sender
{
	if ([sender state] && mapView->curobj->pcnt < 3)
	{
		[editObjectFilled setState: 0];
		return;
	}
	mapView->curobj->filled = [sender state];
	[editObjectFillColor setEnabled: mapView->curobj->filled];
	
	if (mapView->curobj->filled)
	{
		editObjectPrevClosed = [editObjectClosed state];
		[editObjectClosed setState: TRUE];
		[editObjectClosed setEnabled: FALSE];
		[editObjectOutlined setEnabled: TRUE];
	}
	else
	{
		[editObjectClosed setState: editObjectPrevClosed];
		[editObjectClosed setEnabled: TRUE];
		[editObjectOutlined setState: TRUE];
		[editObjectOutlined setEnabled: FALSE];
		[editObjectLineColor setEnabled: TRUE];
		[editObjectLineWidth setEnabled: TRUE];
		[editObjectLineWidthStepper setEnabled: TRUE];		
		mapView->curobj->outlined = TRUE;
	}
}

-(void) editObjectOutlinedChanged: (id)sender
{
	mapView->curobj->outlined = [sender state];
	
	[editObjectLineColor setEnabled: mapView->curobj->outlined];
	[editObjectLineWidth setEnabled: mapView->curobj->outlined];
	[editObjectLineWidthStepper setEnabled: mapView->curobj->outlined];
}

-(void) editObjectFillColorChanged: (id)sender
{
	[[[sender color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace] getRed: &mapView->curobj->fr green: &mapView->curobj->fg blue: &mapView->curobj->fb alpha: &mapView->curobj->fa];
}

-(void) editObjectLineColorChanged: (id)sender
{
	[[[sender color] colorUsingColorSpaceName: NSCalibratedRGBColorSpace] getRed: &mapView->curobj->lr green: &mapView->curobj->lg blue: &mapView->curobj->lb alpha: &mapView->curobj->la];
}

-(IBAction) editObjectLineWidthChanged: (id)sender
{
	mapView->curobj->lineWidth = [sender floatValue];
}

-(IBAction) editObjectLineWidthStepperChanged: (id)sender
{
	[editObjectLineWidth setFloatValue: [editObjectLineWidthStepper floatValue]];
	mapView->curobj->lineWidth = [sender floatValue];
}

@end
