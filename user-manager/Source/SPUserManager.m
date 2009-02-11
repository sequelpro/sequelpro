//
//  SPUserManager.m
//  sequel-pro
//
//  Created by Mark on 1/20/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "SPUserManager.h"
#import "CMMCPConnection.h"
#import "SPUserItem.h"
#import "CMMCPResult.h"
#import "ImageAndTextCell.h"

#define COLUMNIDNAME @"NameColumn"

@interface SPUserManager (PrivateMethods)
- (void)_initializeTree:(NSArray *)items;
- (void)_initializeUsers;
@end

@implementation SPUserManager

- (id)init {
	[self dealloc];
	@throw [NSException exceptionWithName:@"BadInitCall" reason:@"Can't call init here" userInfo:nil];
	return nil;
}

- (id)initWithConnection:(CMMCPConnection*) connection
{
	if (![super init]) {
		return nil;
	}
	
	[self setConnection:connection];
	if (!outlineView) {
		[NSBundle loadNibNamed:@"UserManagerView" owner:self];
	}
	return self;
}

- (void)awakeFromNib
{
	NSLog(@"Just loaded UserManagerView!");
	
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:COLUMNIDNAME];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];
	
	// Initializing could take a while so run in a separate thread
	[NSThread detachNewThreadSelector:@selector(_initializeUsers) toTarget:self withObject:nil];
	
	
}

 - (void)_initializeUsers
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *resultAsArray = [NSMutableArray array];
	NSMutableArray *usersResultArray = [NSMutableArray array];
	
	[[self connection] selectDB:@"mysql"];
	CMMCPResult *result = [[[self connection] queryString:@"select * from user order by user"] retain];
	int rows = [result numOfRows];
	if (rows > 0)
	{
		// Go to the beginning
		[result dataSeek:0];
	}
	[users release];
	users = nil;
	users = [[NSMutableArray alloc] init];
	for(int i = 0; i < rows; i++)
	{
		[resultAsArray addObject:[result fetchRowAsDictionary]];
	}
	[usersResultArray addObjectsFromArray:resultAsArray];

	[self performSelectorOnMainThread:@selector(_initializeTree:) withObject:usersResultArray waitUntilDone:TRUE];
	
	[result release];
	[pool release];
}

- (void)_initializeTree:(NSArray *)items
{
	NSLog(@"Initalize Tree");
	
	for(int i = 0; i < [items count]; i++)
	{
		NSString *username = [[items objectAtIndex:i] valueForKey:@"User"];

		if ([[users valueForKey:@"username"] containsObject:username])
		{
			int parentIndex = [[users valueForKey:@"username"] indexOfObject:username];
			SPUserItem *parent = [users objectAtIndex:parentIndex];
			SPUserItem *childItem = [[[SPUserItem alloc] init] autorelease];
			[childItem setUsername: [[items objectAtIndex:i] valueForKey:@"User"]];
			[childItem setHost:[[items objectAtIndex:i] valueForKey:@"Host"]];
			[childItem setItemTitle:[childItem host]];
			[childItem setLeaf:TRUE];
			[parent addChild:childItem];
		}
		else
		{
			SPUserItem *userItem = [[[SPUserItem alloc] init] autorelease];
			[userItem setUsername:username];
			[userItem setItemTitle:username];
			[userItem setLeaf:FALSE];
			
			SPUserItem *childItem = [[[SPUserItem alloc] init] autorelease];
			[childItem setUsername: username];
			[childItem setHost:[[items objectAtIndex:i] valueForKey:@"Host"]];
			[childItem setItemTitle:[childItem host]];
			[childItem setLeaf:TRUE];
			[userItem addChild:childItem];
			
			
			[treeController insertObject:userItem atArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:i]];			
		}
	}
}
- (void)setConnection:(CMMCPConnection *)connection
{
	[connection retain];
	[mySqlConnection release];
	mySqlConnection = connection;
}

- (CMMCPConnection* )connection
{
	return mySqlConnection;
}

- (void)show
{
	[window makeKeyAndOrderFront:nil];
}

- (void)dealloc
{
	[users release];
	users = nil;
	[mySqlConnection release];
	[super dealloc];
}

- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([cell isKindOfClass:[ImageAndTextCell class]])
	{
		if ([(SPUserItem *)item isLeaf])
		{
			[(ImageAndTextCell*)cell setImage:[NSImage imageNamed:@"network-16"]];
			
		} else {
			[(ImageAndTextCell*)cell setImage:[NSImage imageNamed:@"NSUser.png"]];
		}
	}
}
@end
