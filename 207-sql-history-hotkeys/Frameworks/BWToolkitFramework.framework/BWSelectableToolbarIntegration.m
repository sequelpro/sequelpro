//
//  BWSelectableToolbarIntegration.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "BWSelectableToolbar.h"
#import "BWSelectableToolbarInspector.h"
#import "BWSelectableToolbarHelper.h"

@interface NSToolbar (BWSTIntPrivate)
- (void)ibDocument:(id)fp8 willStartSimulatorWithContext:(id)fp12;
@end

@interface BWSelectableToolbar (BWSTIntPrivate)
- (id)parentOfObject:(id)anObj;
- (void)setDocumentToolbar:(BWSelectableToolbar *)obj;
@end

@interface IBDocument (BWSTIntPrivate)
+ (id)currentIBFrameworkVersion;
@end

@implementation BWSelectableToolbar ( BWSelectableToolbarIntegration )

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];
    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:@"isPreferencesToolbar",nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
    [classes addObject:[BWSelectableToolbarInspector class]];
}

// Display a modal warning just before the simulator is launched - this incompatibility will hopefully be fixed in a future version of this plugin
- (void)ibDocument:(id)fp8 willStartSimulatorWithContext:(id)fp12
{	
	[super ibDocument:fp8 willStartSimulatorWithContext:fp12];
	
	// Simulating seems to work fine in IB 3.1.1 (672) so we won't show the alert if the user is running that version
	if ([[IBDocument currentIBFrameworkVersion] intValue] != 672)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:@"Toolbar not compatible with simulator" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"The selectable toolbar is not yet compatible with the IB simulator. Quit the simulator and revert to the last saved document. Sorry for the inconvenience."];
		[alert runModal];
	}
}

- (void)ibDidAddToDesignableDocument:(IBDocument *)document
{
	[super ibDidAddToDesignableDocument:document];
	
	[self setDocumentToolbar:self];
	
	helper = [[BWSelectableToolbarHelper alloc] init];
	[document addObject:helper toParent:[self parentOfObject:self]];
}

- (void)addObject:(id)object toParent:(id)parent
{
	IBDocument *document = [IBDocument documentForObject:parent];
	
	[document addObject:object toParent:parent];
}

- (void)moveObject:(id)object toParent:(id)parent
{
	IBDocument *document = [IBDocument documentForObject:object];
	
	[document moveObject:object toParent:parent];
}

- (void)removeObject:(id)object
{
	IBDocument *document = [IBDocument documentForObject:object];
	
	[document removeObject:object];
}

- (NSArray *)objectsforDocumentObject:(id)anObj
{
	IBDocument *document = [IBDocument documentForObject:anObj];
	
	return [[document objects] retain];
}

- (id)parentOfObject:(id)anObj
{
	IBDocument *document = [IBDocument documentForObject:anObj];
	
	return [[document parentOfObject:anObj] retain];
}

- (NSArray *)childrenOfObject:(id)object
{
	IBDocument *document = [IBDocument documentForObject:object];
	
	return [document childrenOfObject:object];
}

@end
