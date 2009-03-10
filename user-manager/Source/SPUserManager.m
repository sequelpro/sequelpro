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
- (void)_initializeDatabaseList;
- (void)_initializeGlobalPrivilegesWithItem:(NSDictionary *)item intoChildItem:(SPUserItem *)childItem;
- (void)_initializeSchemaPrivilegesWithItems:(NSArray *)items;
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
	
	// Set up the sorting for the NSArrayControllers
	NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	[selectedPrivsController setSortDescriptors:[NSArray arrayWithObject:sd]];
	[availablePrivsController setSortDescriptors:[NSArray arrayWithObject:sd]];
	[sd release];
	
	[tabView selectTabViewItemAtIndex:0];
	
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:COLUMNIDNAME];
	ImageAndTextCell *imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	
	[imageAndTextCell setEditable:NO];
	[tableColumn setDataCell:imageAndTextCell];
	
	[self _initializeDatabaseList];
	availablePrivs = [[NSMutableArray alloc] init];
	selectedPrivs = [[NSMutableArray alloc] init];
	
	// Initializing could take a while so run in a separate thread
	[NSThread detachNewThreadSelector:@selector(_initializeUsers) toTarget:self withObject:nil];	
}

- (void)_initializeDatabaseList
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	MCPResult *result = [[self connection] listDBs];
	
	if ([result numOfRows])
	{
		[result dataSeek:0];
	}
	for (int i = 0; i < [result numOfRows]; i++)
	{
		[databaseList addObject:[result fetchRowAsDictionary]];
	}
	[pool release];
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
	[self _initializeSchemaPrivilegesWithItems:usersResultArray];
	[result release];
	[pool release];
}

- (void)_initializeTree:(NSArray *)items
{
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
			[childItem setPassword:[[items objectAtIndex:i] valueForKey:@"Password"]];
			[self _initializeGlobalPrivilegesWithItem:[items objectAtIndex:i] intoChildItem:childItem];
			[childItem setLeaf:TRUE];
			[parent addChild:childItem];
		}
		else
		{
			SPUserItem *userItem = [[[SPUserItem alloc] init] autorelease];
			[userItem setUsername:username];
			[userItem setPassword:[[items objectAtIndex:i] valueForKey:@"Password"]];
			[userItem setLeaf:FALSE];
			
			SPUserItem *childItem = [[[SPUserItem alloc] init] autorelease];
			[childItem setUsername: username];
			[childItem setPassword: [[items objectAtIndex:i] valueForKey:@"Password"]];
			[childItem setHost:[[items objectAtIndex:i] valueForKey:@"Host"]];
			[self _initializeGlobalPrivilegesWithItem:[items objectAtIndex:i] intoChildItem:childItem];
			[childItem setLeaf:TRUE];
			[userItem addChild:childItem];
			
			
			[treeController insertObject:userItem atArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:[users count]]];			
		}
	}
}

- (void)_initializeGlobalPrivilegesWithItem:(NSDictionary *)item intoChildItem:(SPUserItem *)childItem
{
	NSArray *itemKeys = [item allKeys];
	NSMutableDictionary *globalPrivs = [NSMutableDictionary dictionary];
	
	for (int index = 0; index < [itemKeys count]; index++)
	{
		NSString *key = [itemKeys objectAtIndex:index];
		if ([key hasSuffix:@"_priv"])
		{
			[globalPrivs setValue:[item valueForKey:key] forKey:key];
		}
	}
	[childItem setGlobalPrivileges:globalPrivs];
}

- (void)_initializeSchemaPrivilegesWithItems:(NSArray *)items
{
	NSDictionary *firstItem = [items objectAtIndex:0];
	NSArray *keys = [firstItem allKeys];
	for(int index = 0; index < [keys count]; index++)
	{
		NSString *key = [keys objectAtIndex:index];
		if ([key hasSuffix:@"_priv"])
		{
			NSString *newKey = [key substringToIndex:[key rangeOfString:@"_priv"].location];
			[availablePrivsController addObject:[NSDictionary dictionaryWithObject:newKey forKey:@"name"]];			
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
	NSLog(@"SPUserManager dealloc.");
	[dbList release];
	dbList = nil;
	[availablePrivs release];
	availablePrivs = nil;
	[selectedPrivs release];
	selectedPrivs = nil;
	[allPrivs release];
	allPrivs = nil;
	[users release];
	users = nil;
	[mySqlConnection release];
	[super dealloc];
}

// OutlineView Delegate Methods
- (void)outlineView:(NSOutlineView *)olv willDisplayCell:(NSCell*)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([cell isKindOfClass:[ImageAndTextCell class]])
	{
		if ([(SPUserItem *)[item  representedObject] host] != nil)
		{
			[(ImageAndTextCell*)cell setImage:[NSImage imageNamed:@"network-16"]];
			
		} else {
			[(ImageAndTextCell*)cell setImage:[NSImage imageNamed:@"NSUser.png"]];
		}
	}
}

// TableView Delegate Methods


// General Action Methods
- (IBAction)doCancel:(id)sender
{
	[window close];
}

- (IBAction)doApply:(id)sender
{
	
}

// Schema Privileges Actions
- (IBAction)addToSelected:(id)sender
{
	[selectedPrivsController addObjects:[availablePrivsController selectedObjects]];
	[availablePrivsController removeObjects:[availablePrivsController selectedObjects]];
}

- (IBAction)addToAvailable:(id)sender
{
	[availablePrivsController addObjects:[selectedPrivsController selectedObjects]];
	[selectedPrivsController removeObjects:[selectedPrivsController selectedObjects]];
}
@end
