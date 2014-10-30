#import "LayersPanelController.h"
#import "Globals.h"
#import "LayerSet.h"
#import "MyCheckboxCell.h"
#import "Geocoder.h"
#import "Font.h"

static int countOn(LayerSet *ls)
{
    Class mlc = [MapLayer class];
    Class lsc = [LayerSet class];
    
    int cnt = 0;
    for (Layer *l in ls->layers)
    {
        if (l->on)
        {
            if ([l isKindOfClass:mlc])
                cnt++;
            else if ([l isKindOfClass:lsc])
                cnt += countOn((LayerSet*)l);
        }
    }
    
    return cnt;
}

/*@interface WeakPtr : NSObject {
    id _obj;
}
@property(nonatomic,assign) id obj;
@end

@implementation WeakPtr
@synthesize obj=_obj;
@end*/

@interface LayersPanelController ()
@end

@implementation LayersPanelController

-(void) awakeFromNib
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeContainerHeightOnly) name:NSOutlineViewItemDidExpandNotification object:layersView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resizeContainerHeightOnly) name:NSOutlineViewItemDidCollapseNotification object:layersView];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearList) name:@"WorldWillChange" object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(worldChanged) name:@"WorldDidChange" object:NSApp];
    
    [self worldChanged];
}

-(void) resizeContainer
{
    float ind = [layersView indentationPerLevel];
    NSFont *f = [[[layersView tableColumnWithIdentifier:@"on"] dataCell] font];
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:f, NSFontAttributeName, nil];
    
    float k = 0;
    for (int i = 0; i < [layersView numberOfRows]; i++)
    {
        Layer *item = [layersView itemAtRow:i];

        int level = [layersView levelForItem:item];
        NSSize textSize = [item->name sizeWithAttributes:attrs];

        float w = textSize.width + level*ind;
        if (k < w)
            k = w;
    }
    k += 10 + [[layersView tableColumnWithIdentifier:@"cnt"] width];
    
    float h = [layersView numberOfRows]*19.0 + [world->rootLayer->layers count]*7.0;
    
    [ourPopover setContentSize:NSMakeSize(MAX(k+16,250), MIN(h, 600))];    
    
    //[layersView setSelectionHighlightStyle:<#(NSTableViewSelectionHighlightStyle)#> ???
    //[layersView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    //[[layersView dataWithPDFInsideRect:layersView.bounds] writeToFile:@"/Users/vit/a.pdf" atomically:NO];
}

-(void) resizeContainerHeightOnly
{
    float h = [layersView numberOfRows]*19.0 + [world->rootLayer->layers count]*7.0;
    [ourPopover setContentSize:NSMakeSize(ourPopover.contentSize.width, MIN(h, 600))];
}

-(void) clearList
{
    layersView.dataSource = nil;
}

-(void) worldChanged
{
    layersView.dataSource = self;
	//[layersView reloadData];

    //Expand groups
    if (world)
    {        
        for (Layer *l in world->rootLayer->layers)
            [layersView expandItem:l];
    }    
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item
{
	if (!world || !world->rootLayer)
		return nil;
	
	if (!item)
		return [world->rootLayer->layers objectAtIndex: index];
	
	return [((LayerSet*)item)->layers objectAtIndex: index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (!world || !world->rootLayer)
		return NO;
	
	return [item isKindOfClass: [LayerSet class]];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	if (!world || !world->rootLayer)
		return NO;
	
	return [item isKindOfClass: [LayerSet class]] && ((LayerSet*)item)->isGroup;
}

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (!world || !world->rootLayer)
		return 0;
	
	if (!item)
		return [world->rootLayer->layers count];
	
	return [((LayerSet*)item)->layers count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (!world || !world->rootLayer)
		return nil;
    		
	if ([[tableColumn identifier] isEqualToString: @"on"])
		return [NSNumber numberWithBool: ((Layer*)item)->on];	

	if (((Layer*)item)->on && [[tableColumn identifier] isEqualToString: @"cnt"] && [item isKindOfClass:[LayerSet class]])
    {
        int cnt = countOn(item);
        if (cnt)
            return [[NSNumber numberWithInt:cnt] stringValue];
    }
    
	return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ([[tableColumn identifier] isEqualToString: @"on"])
	{
        Layer *lyr = (Layer*)item;
        
        if (lyr->on == [object boolValue])
            return;
        
        if ([lyr->parent isKindOfClass:[LayerSet class]] && ((LayerSet*)lyr->parent)->exclusive)
        {
            for (Layer *l in ((LayerSet*)lyr->parent)->layers)
            {
                if (l->on)
                {
                    l->on = NO;
                    [l closeCache];
                    [world->schema setObject: [NSNumber numberWithBool:NO] forKey: [NSString stringWithFormat: @"On-%@", l->lid]];
                }
            }
        }
        
        lyr->on = [object boolValue];
        if (!lyr->on)
            [lyr closeCache];
        [world buildSortedLayerList];
        
        [world->schema setObject: object forKey: [NSString stringWithFormat: @"On-%@", ((Layer*)item)->lid]];
        [[NSUserDefaults standardUserDefaults] setObject: world->schema forKey: [@"Schema-" stringByAppendingString:world.name]];
        
        for (; !((LayerSet*)lyr->parent)->isGroup; lyr = lyr->parent);
        [layersView reloadItem:lyr reloadChildren:YES];
	}
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if (!world || !world->rootLayer)
		return;
    
    if ([item isKindOfClass:[LayerSet class]] && ((LayerSet*)item)->isGroup)
    {
        NSMutableParagraphStyle *ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [ps setAlignment:NSCenterTextAlignment];

        NSDictionary *txtDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                 ps, NSParagraphStyleAttributeName,
                                 nil];
        [ps release];

        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:[((Layer*)item)->name uppercaseString] attributes:txtDict];
        [cell setAttributedStringValue:attrStr];
        [attrStr release];
        
        return;
    }

    if ([[tableColumn identifier] isEqualToString: @"on"])
    {
        [cell setTitle:((Layer*)item)->name];
        return;
    }
    
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item
{
    return !([item isKindOfClass:[LayerSet class]] && (((LayerSet*)item)->isGroup || ((LayerSet*)item)->solid));
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return !([item isKindOfClass:[LayerSet class]] && ((LayerSet*)item)->isGroup);
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if (!tableColumn && [item isKindOfClass:[LayerSet class]] && ((LayerSet*)item)->isGroup)
    {
        NSTextFieldCell *iGroupRowCell = [[NSTextFieldCell alloc] init];
        [iGroupRowCell setEditable:NO];
        [iGroupRowCell setLineBreakMode:NSLineBreakByTruncatingTail];
        
        [iGroupRowCell setFont:[NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]]];
        [iGroupRowCell setTextColor:[NSColor darkGrayColor]];
                
        return [iGroupRowCell autorelease];
    }
    
    if ([[tableColumn identifier] isEqualToString:@"on"] && [((Layer*)item)->parent isKindOfClass:[LayerSet class]] && ((LayerSet*)((Layer*)item)->parent)->exclusive)
    {
        MyCheckboxCell *cell = [[MyCheckboxCell alloc] init];
        [cell setButtonType:NSRadioButton];
        [cell setControlSize:NSSmallControlSize];
        [cell setFont: [[tableColumn dataCell] font]];
        
        return [cell autorelease];
    }
    
    return nil;
}           

@end
