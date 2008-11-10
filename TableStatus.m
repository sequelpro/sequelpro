#import "TableStatus.h"

@implementation TableStatus

- (void)awakeFromNib
{
	// TODO: implement awake code.
}

- (void)setConnection:(CMMCPConnection *)theConnection
{
	mySQLConnection = theConnection;
	[mySQLConnection retain];
}

- (NSString*)getSQLColumnValue:(NSString *)withName usingFields:(NSDictionary*)fields withLabel:(NSString*)label
{
	NSString* value = [fields objectForKey:withName];
	if([value isKindOfClass:[NSNull class]])
	{
	value = @"--";
	}
	
	NSString* labelVal = [NSString stringWithFormat:@"%@: %@",label,value];
	
	return labelVal;
}

- (void)loadTable:(NSString *)aTable
{
	// Store the table name away for future use...
	selectedTable = aTable;
	
	// Notify any listeners that a query is about to begin...
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryWillBePerformed" object:self];
	
	// no table selected
	if([aTable isEqualToString:@""] || !aTable) {
		[tableName setStringValue:@"Name: --"];
		[tableType setStringValue:@"Type: --"];
		[tableCreatedAt setStringValue:@"Created At: --"];
		[tableUpdatedAt setStringValue:@"Updated At: --"];
		
		// Assign the row values...
		[rowsNumber setStringValue:@"Number Of: --"];
		[rowsFormat setStringValue:@"Format: --"];	
		[rowsAvgLength setStringValue:@"Avg. Length: --"];
		[rowsAutoIncrement setStringValue:@"Auto Increment: --"];
		
		// Assign the size values...
		[sizeData setStringValue:@"Data: --"]; 
		[sizeMaxData setStringValue:@"Max Data: --"];	
		[sizeIndex setStringValue:@"Index: --"]; 
		[sizeFree setStringValue:@"Free: --"];
		
		// Finally, set the value of the comments box
		[commentsBox setStringValue:@"--"];
		
		// Tell everyone we've finished with our query...
		[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];
		return;
	}
	
	// Run the query to retrieve the status of the selected table.  We'll then use this information to populate
	// the associated view's controls.	
	tableStatusResult = [mySQLConnection queryString:[NSString stringWithFormat:@"SHOW TABLE STATUS LIKE '%@'", selectedTable]];
	
	statusFields = [tableStatusResult fetchRowAsDictionary];
	
	// Assign the table values...
	[tableName setStringValue:[NSString stringWithFormat:@"Name: %@",selectedTable]];
	if ( [statusFields objectForKey:@"Type"] ) {
		[tableType setStringValue:[self getSQLColumnValue:@"Type" usingFields:statusFields withLabel:@"Type"]];
	} else {
		// mysql > 4.1
		[tableType setStringValue:[self getSQLColumnValue:@"Engine" usingFields:statusFields withLabel:@"Type"]];
	}
	[tableCreatedAt setStringValue:[self getSQLColumnValue:@"Create_time" usingFields:statusFields withLabel:@"Created At"]];
	[tableUpdatedAt setStringValue:[self getSQLColumnValue:@"Update_time" usingFields:statusFields withLabel:@"Updated At"]];
	
	// Assign the row values...
	[rowsNumber setStringValue:[self getSQLColumnValue:@"Rows" usingFields:statusFields withLabel:@"Number Of"]];
	[rowsFormat setStringValue:[self getSQLColumnValue:@"Row_format" usingFields:statusFields withLabel:@"Format"]];	
	[rowsAvgLength setStringValue:[self getSQLColumnValue:@"Avg_row_length" usingFields:statusFields withLabel:@"Avg. Length"]];
	[rowsAutoIncrement setStringValue:[self getSQLColumnValue:@"Auto_increment" usingFields:statusFields withLabel:@"Auto Increment"]];

	// Assign the size values...
	[sizeData setStringValue:[self getSQLColumnValue:@"Data_length" usingFields:statusFields withLabel:@"Data"]]; 
	[sizeMaxData setStringValue:[self getSQLColumnValue:@"Max_data_length" usingFields:statusFields withLabel:@"Max Data"]];	
	[sizeIndex setStringValue:[self getSQLColumnValue:@"Index_length" usingFields:statusFields withLabel:@"Index"]]; 
	[sizeFree setStringValue:[self getSQLColumnValue:@"Data_free" usingFields:statusFields withLabel:@"Free"]];	 
	
	// Finally, assign the comments...
	[commentsBox setStringValue:[statusFields objectForKey:@"Comment"]];
	
	// Tell everyone we've finished with our query...
	[[NSNotificationCenter defaultCenter] postNotificationName:@"SMySQLQueryHasBeenPerformed" object:self];	
	
	return;
}

- (IBAction)reloadTable:(id)sender
{
	[self loadTable:selectedTable];
}

- (id)init
{
	self = [super init];
	
	return self;
}
@end
