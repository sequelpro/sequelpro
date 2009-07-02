//
//  BWSelectableToolbarHelper.m
//  BWToolkit
//
//  Created by Brandon Walkin (www.brandonwalkin.com)
//  All code is provided under the New BSD license.
//

#import "BWSelectableToolbarHelper.h"

@implementation BWSelectableToolbarHelper

@synthesize contentViewsByIdentifier;
@synthesize windowSizesByIdentifier;
@synthesize selectedIdentifier;
@synthesize oldWindowTitle;
@synthesize initialIBWindowSize;
@synthesize isPreferencesToolbar;

- (id)init
{
	if(self = [super init])
	{
		if (contentViewsByIdentifier == nil)
			contentViewsByIdentifier = [[NSMutableDictionary alloc] init];
		
		if (windowSizesByIdentifier == nil)
			windowSizesByIdentifier = [[NSMutableDictionary alloc] init];
		
		if (selectedIdentifier == nil)
			selectedIdentifier = [[NSString alloc] init];
		
		if (oldWindowTitle == nil)
			oldWindowTitle = [[NSString alloc] init];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder;
{
    if ((self = [super init]) != nil)
	{
		[self setContentViewsByIdentifier:[decoder decodeObjectForKey:@"BWSTHContentViewsByIdentifier"]];
		
		NSData *data = [decoder decodeObjectForKey:@"BWSTHWindowSizesByIdentifier"];
		[self setWindowSizesByIdentifier:[NSUnarchiver unarchiveObjectWithData:data]];
		
		[self setSelectedIdentifier:[decoder decodeObjectForKey:@"BWSTHSelectedIdentifier"]];
		
		[self setOldWindowTitle:[decoder decodeObjectForKey:@"BWSTHOldWindowTitle"]];
		
		[self setInitialIBWindowSize:[decoder decodeSizeForKey:@"BWSTHInitialIBWindowSize"]];
		
		[self setIsPreferencesToolbar:[decoder decodeBoolForKey:@"BWSTHIsPreferencesToolbar"]];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder*)coder
{
	[coder encodeObject:[self contentViewsByIdentifier] forKey:@"BWSTHContentViewsByIdentifier"];
	
	NSData *data = [NSArchiver archivedDataWithRootObject:[self windowSizesByIdentifier]];
	[coder encodeObject:data forKey:@"BWSTHWindowSizesByIdentifier"];
	
	[coder encodeObject:[self selectedIdentifier] forKey:@"BWSTHSelectedIdentifier"];
	
	[coder encodeObject:[self oldWindowTitle] forKey:@"BWSTHOldWindowTitle"];
	
	[coder encodeSize:[self initialIBWindowSize] forKey:@"BWSTHInitialIBWindowSize"];
	
	[coder encodeBool:[self isPreferencesToolbar] forKey:@"BWSTHIsPreferencesToolbar"];
}

- (void)dealloc
{
	[contentViewsByIdentifier release];
	[windowSizesByIdentifier release];
	[selectedIdentifier release];
	[oldWindowTitle release];
	[super dealloc];
}

@end
