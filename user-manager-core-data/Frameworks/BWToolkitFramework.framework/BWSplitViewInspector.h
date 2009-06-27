//
//  BWSplitViewInspector.h
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWSplitView.h"
#import "BWSplitViewInspectorAutosizingView.h"

@interface BWSplitViewInspector : IBInspector 
{
	IBOutlet NSTextField *maxField, *minField, *maxLabel, *minLabel;
	IBOutlet NSButton *dividerCheckbox;
	IBOutlet BWSplitViewInspectorAutosizingView *autosizingView;
	
	int subviewPopupSelection, collapsiblePopupSelection, minUnitPopupSelection, maxUnitPopupSelection;
	NSMutableArray *subviewPopupContent, *collapsiblePopupContent;
	
	BWSplitView *splitView;
	BOOL dividerCheckboxCollapsed;
}

@property int subviewPopupSelection, collapsiblePopupSelection, minUnitPopupSelection, maxUnitPopupSelection;
@property (copy) NSMutableArray *subviewPopupContent, *collapsiblePopupContent;
@property (retain) BWSplitView *splitView;
@property BOOL dividerCheckboxCollapsed;

@end
