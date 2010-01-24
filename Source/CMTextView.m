//
//  $Id$
//
//  CMTextView.m
//  sequel-pro
//
//  Created by Carsten Blüm.
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#import "CMTextView.h"
#import "CustomQuery.h"
#import "TableDocument.h"
#import "SPStringAdditions.h"
#import "SPArrayAdditions.h"
#import "SPTextViewAdditions.h"
#import "SPNarrowDownCompletion.h"
#import "SPConstants.h"
#import "SPQueryController.h"

#pragma mark -
#pragma mark lex init

/*
 * Include all the extern variables and prototypes required for flex (used for syntax highlighting)
 */
#import "SPEditorTokens.h"
extern NSInteger yylex();
extern NSInteger yyuoffset, yyuleng;
typedef struct yy_buffer_state *YY_BUFFER_STATE;
void yy_switch_to_buffer(YY_BUFFER_STATE);
YY_BUFFER_STATE yy_scan_string (const char *);

#pragma mark -
#pragma mark attribute definition 

#define kAPlinked      @"Linked" // attribute for a via auto-pair inserted char
#define kAPval         @"linked"
#define kLEXToken      @"Quoted" // set via lex to indicate a quoted string
#define kLEXTokenValue @"isMarked"
#define kSQLkeyword    @"SQLkw"  // attribute for found SQL keywords
#define kQuote         @"Quote"
#define kQuoteValue    @"isQuoted"
#define kValue         @"dummy"
#define kBTQuote       @"BTQuote"
#define kBTQuoteValue  @"isBTQuoted"

#pragma mark -
#pragma mark constant definitions

#define SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG 1000
#define SP_CQ_COPY_AS_RTF_MENU_ITEM_TAG          1001
#define SP_CQ_SELECT_CURRENT_QUERY_MENU_ITEM_TAG 1002

#define SP_SYNTAX_HILITE_BIAS 2000

#define MYSQL_DOC_SEARCH_URL @"http://dev.mysql.com/doc/refman/%@/en/%@.html"

#pragma mark -

@implementation CMTextView

- (void) awakeFromNib
{
	// Set self as delegate for the textView's textStorage to enable syntax highlighting,
	[[self textStorage] setDelegate:self];

	// Set defaults for general usage
	autoindentEnabled = YES;
	autopairEnabled = YES;
	autoindentIgnoresEnter = NO;
	autouppercaseKeywordsEnabled = YES;
	autohelpEnabled = NO;
	delBackwardsWasPressed = NO;
	startListeningToBoundChanges = NO;
	snippetControlCounter = -1;

	lineNumberView = [[NoodleLineNumberView alloc] initWithScrollView:scrollView];
	[scrollView setVerticalRulerView:lineNumberView];
	[scrollView setHasHorizontalRuler:NO];
	[scrollView setHasVerticalRuler:YES];
	[scrollView setRulersVisible:YES];

	// Re-define 64 tab stops for a better editing
	NSFont *tvFont = [self font];
	float firstColumnInch = 0.5, otherColumnInch = 0.5, pntPerInch = 72.0;
	NSInteger i;
	NSTextTab *aTab;
	NSMutableArray *myArrayOfTabs;
	NSMutableParagraphStyle *paragraphStyle;
	myArrayOfTabs = [NSMutableArray arrayWithCapacity:64];
	aTab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:firstColumnInch*pntPerInch];
	[myArrayOfTabs addObject:aTab];
	[aTab release];
	for(i=1; i<64; i++) {
		aTab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:(firstColumnInch*pntPerInch) + ((float)i * otherColumnInch * pntPerInch)];
		[myArrayOfTabs addObject:aTab];
		[aTab release];
	}
	paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[paragraphStyle setTabStops:myArrayOfTabs];
	// Soft wrapped lines are indented slightly
	[paragraphStyle setHeadIndent:4.0];

	NSMutableDictionary *textAttributes = [[[NSMutableDictionary alloc] initWithCapacity:1] autorelease];
	[textAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

	NSRange range = NSMakeRange(0, [[self textStorage] length]);
	if ([self shouldChangeTextInRange:range replacementString:nil]) {
		[[self textStorage] setAttributes:textAttributes range: range];
		[self didChangeText];
	}
	[self setTypingAttributes:textAttributes];
	[self setDefaultParagraphStyle:paragraphStyle];
	[paragraphStyle release];
	[self setFont:tvFont];
	
	// disabled to get the current text range in textView safer
	[[self layoutManager] setBackgroundLayoutEnabled:NO];

	// add NSViewBoundsDidChangeNotification to scrollView
	[[scrollView contentView] setPostsBoundsChangedNotifications:YES];
	NSNotificationCenter *aNotificationCenter = [NSNotificationCenter defaultCenter];
	[aNotificationCenter addObserver:self selector:@selector(boundsDidChangeNotification:) name:@"NSViewBoundsDidChangeNotification" object:[scrollView contentView]];

	prefs = [[NSUserDefaults standardUserDefaults] retain];

}

- (void) setConnection:(MCPConnection *)theConnection withVersion:(NSInteger)majorVersion
{
	mySQLConnection = theConnection;
	mySQLmajorVersion = majorVersion;
}

/*
 * Sort function (mainly used to sort the words in the textView)
 */
NSInteger alphabeticSort(id string1, id string2, void *reverse)
{
	return [string1 localizedCaseInsensitiveCompare:string2];
}

/*
 * Return an array of NSDictionary containing the sorted strings representing
 * the set of unique words, SQL keywords, user-defined funcs/procs, tables etc.
 * NSDic key "display" := the displayed and to be inserted word
 * NSDic key "image" := an image to be shown left from "display" (optional)
 *
 * [NSDictionary dictionaryWithObjectsAndKeys:@"foo", @"display", @"`foo`", @"match", @"func-small", @"image", nil]
 */
- (NSArray *)suggestionsForSQLCompletionWith:(NSString *)currentWord dictMode:(BOOL)isDictMode browseMode:(BOOL)dbBrowseMode withTableName:(NSString*)aTableName withDbName:(NSString*)aDbName
{

	NSMutableArray *possibleCompletions = [[NSMutableArray alloc] initWithCapacity:32];

	// If caret is not inside backticks add keywords and all words coming from the view.
	if(!dbBrowseMode)
	{
		// Only parse for words if text size is less than 60kB
		if([[self string] length] && [[self string] length]<60000)
		{
			NSMutableArray *uniqueArray = [NSMutableArray array];
			[uniqueArray addObjectsFromArray:[NSSet setWithArray:[[self string] componentsMatchedByRegex:@"\\w+"]]];

			// Remove current word from list
			[uniqueArray removeObject:currentWord];

			NSInteger reverseSort = NO;
			NSArray *sortedArray = [[[uniqueArray mutableCopy] autorelease] sortedArrayUsingFunction:alphabeticSort context:&reverseSort];
			for(id w in sortedArray)
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:w, @"display", @"dummy-small", @"image", nil]];

		}

		if(!isDictMode) {
			// Add predefined keywords
			for(id s in [self keywords])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:s, @"display", @"dummy-small", @"image", nil]];

			// Add predefined functions
			for(id s in [self functions])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:s, @"display", @"func-small", @"image", nil]];
		}

	}

	if(!isDictMode && [mySQLConnection isConnected])
	{
		// Add structural db/table/field data to completions list or fallback to gathering TablesList data
		NSDictionary *dbs = [NSDictionary dictionaryWithDictionary:[mySQLConnection getDbStructure]];
		if(dbs != nil && [dbs count]) {
			NSMutableArray *allDbs = [[NSMutableArray array] autorelease];
			[allDbs addObjectsFromArray:[dbs allKeys]];

			// Add database names having no tables since they don't appear in the information_schema
			if ([[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allDatabaseNames"] != nil)
				for(id db in [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allDatabaseNames"])
					if(![allDbs containsObject:db])
						[allDbs addObject:db];

			NSSortDescriptor *desc = [[NSSortDescriptor alloc] initWithKey:nil ascending:YES selector:@selector(localizedCompare:)];
			NSMutableArray *sortedDbs = [[NSMutableArray array] autorelease];
			[sortedDbs addObjectsFromArray:[allDbs sortedArrayUsingDescriptors:[NSArray arrayWithObject:desc]]];

			NSString *currentDb = nil;
			NSString *currentTable = nil;

			if ([[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"selectedDatabase"] != nil)
				currentDb = [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKeyPath:@"selectedDatabase"];
			if ([[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"tableName"] != nil)
				currentTable = [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKeyPath:@"tableName"];

			// Put current selected db at the top
			if(aTableName == nil && aDbName == nil && [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKeyPath:@"selectedDatabase"]) {
				currentDb = [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKeyPath:@"selectedDatabase"];
				[sortedDbs removeObject:currentDb];
				[sortedDbs insertObject:currentDb atIndex:0];
			}

			// Put information_schema and/or mysql db at the end if not selected
			if(currentDb && ![currentDb isEqualToString:@"mysql"] && [sortedDbs containsObject:@"mysql"]) {
				[sortedDbs removeObject:@"mysql"];
				[sortedDbs addObject:@"mysql"];
			}
			if(currentDb && ![currentDb isEqualToString:@"information_schema"] && [sortedDbs containsObject:@"information_schema"]) {
				[sortedDbs removeObject:@"information_schema"];
				[sortedDbs addObject:@"information_schema"];
			}

			BOOL aTableNameExists = NO;
			if(!aDbName) {
				// Try to suggest only items which are uniquely valid for the parsed string

				NSInteger uniqueSchemaKind = [mySQLConnection getUniqueDbIndentifierFor:[aTableName lowercaseString]];

				// If no db name but table name check if table name is a valid name in the current selected db
			 	if(aTableName && [aTableName length] && [dbs objectForKey:currentDb] && [[dbs objectForKey:currentDb] objectForKey:aTableName] && uniqueSchemaKind == 2) {
					aTableNameExists = YES;
					aDbName = [NSString stringWithString:currentDb];
				}

				// If no db name but table name check if table name is a valid db name
				if(!aTableNameExists && aTableName && [aTableName length] && uniqueSchemaKind == 1) {
					aDbName = [NSString stringWithString:aTableName];
					aTableNameExists = NO;
				}

			} else if (aDbName && [aDbName length]) {
				if(aTableName && [aTableName length] && [dbs objectForKey:aDbName] && [[dbs objectForKey:aDbName] objectForKey:aTableName]) {
					aTableNameExists = YES;
				}
			}

			// If aDbName exist show only those table
			if(aDbName && [aDbName length] && [allDbs containsObject:aDbName]) {
				[sortedDbs removeAllObjects];
				[sortedDbs addObject:aDbName];
			}

			for(id db in sortedDbs) {
				NSArray *allTables = [[dbs objectForKey:db] allKeys];
				NSMutableArray *sortedTables = [NSMutableArray array];
				if(aTableNameExists) {
					[sortedTables addObject:aTableName];
				} else {
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:db, @"display", @"database-small", @"image", db, @"isRef", nil]];
					[sortedTables addObjectsFromArray:[allTables sortedArrayUsingDescriptors:[NSArray arrayWithObject:desc]]];
					if([sortedTables count] > 1 && [sortedTables containsObject:currentTable]) {
						[sortedTables removeObject:currentTable];
						[sortedTables insertObject:currentTable atIndex:0];
					}
				}
				for(id table in sortedTables) {
					NSDictionary * theTable = [[dbs objectForKey:db] objectForKey:table];
					NSArray *allFields = [theTable allKeys];
					NSInteger structtype = [[theTable objectForKey:@"  struct_type  "] intValue];
					BOOL breakFlag = NO;
					if(!aTableNameExists)
						switch(structtype) {
							case 0:
							[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:table, @"display", @"table-small-square", @"image", db, @"path", [NSString stringWithFormat:@"%@.%@",db,table], @"isRef", nil]];
							break;
							case 1:
							[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:table, @"display", @"table-view-small-square", @"image", db, @"path", [NSString stringWithFormat:@"%@.%@",db,table], @"isRef", nil]];
							break;
							case 2:
							[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:table, @"display", @"proc-small", @"image", db, @"path", [NSString stringWithFormat:@"%@.%@",db,table], @"isRef", nil]];
							breakFlag = YES;
							break;
							case 3:
							[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:table, @"display", @"func-small", @"image", db, @"path", [NSString stringWithFormat:@"%@.%@",db,table], @"isRef", nil]];
							breakFlag = YES;
							break;
						}
					if(!breakFlag) {
						NSArray *sortedFields = [allFields sortedArrayUsingDescriptors:[NSArray arrayWithObject:desc]];
						for(id field in sortedFields) {
							if(![field hasPrefix:@"  "]) {
								NSString *typ = [theTable objectForKey:field];
								// Check if type definition contains a , if so replace the bracket content by … and add 
								// the bracket content as "list" key to prevend the token field to split them by ,
								if(typ && [typ rangeOfString:@","].length) {
									NSString *t = [typ stringByReplacingOccurrencesOfRegex:@"\\(.*?\\)" withString:@"(…)"];
									NSString *lst = [typ stringByMatching:@"\\(([^\\)]*?)\\)" capture:1L];
									[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										field, @"display", 
										@"field-small-square", @"image", 
										[NSString stringWithFormat:@"%@⇠%@",table,db], @"path", 
										t, @"type", 
										lst, @"list", 
										[NSString stringWithFormat:@"%@.%@.%@",db,table,field], @"isRef", 
										nil]];
								} else {
									[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:
										field, @"display", 
										@"field-small-square", @"image", 
										[NSString stringWithFormat:@"%@⇠%@",table,db], @"path", 
										typ, @"type", 
										[NSString stringWithFormat:@"%@.%@.%@",db,table,field], @"isRef", 
										nil]];
								}
							}
						}
					}
				}
			}
			if(desc) [desc release];
		} else {
			// Fallback for MySQL < 5 and if the data gathering is in progress
			if(mySQLmajorVersion > 4)
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:NSLocalizedString(@"fetching table data…", @"fetching table data for completion in progress message"), @"path", @"", @"noCompletion", nil]];

			// Add all database names to completions list
			for (id obj in [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allDatabaseNames"])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"database-small", @"image", @"", @"isRef", nil]];

			// Add all system database names to completions list
			for (id obj in [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allSystemDatabaseNames"])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"database-small", @"image", @"", @"isRef", nil]];

			// Add table names to completions list
			for (id obj in [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allTableNames"])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"table-small-square", @"image", @"", @"isRef", nil]];

			// Add view names to completions list
			for (id obj in [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allViewNames"])
				[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"table-view-small-square", @"image", @"", @"isRef", nil]];

			// Add field names to completions list for currently selected table
			if ([[[self window] delegate] table] != nil)
				for (id obj in [[[[self window] delegate] valueForKeyPath:@"tableDataInstance"] valueForKey:@"columnNames"])
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"field-small-square", @"image", @"", @"isRef", nil]];

			// Add proc/func only for MySQL version 5 or higher
			if(mySQLmajorVersion > 4) {
				// Add all procedures to completions list for currently selected table
				for (id obj in [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allProcedureNames"])
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"proc-small", @"image", @"", @"isRef", nil]];

				// Add all function to completions list for currently selected table
				for (id obj in [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allFunctionNames"])
					[possibleCompletions addObject:[NSDictionary dictionaryWithObjectsAndKeys:obj, @"display", @"func-small", @"image", @"", @"isRef", nil]];
			}
		}
	}

	// Make suggestions unique
	NSMutableArray *compl = [[NSMutableArray alloc] initWithCapacity:32];
	for(id suggestion in possibleCompletions)
		if(![compl containsObject:suggestion])
			[compl addObject:suggestion];
	
	[possibleCompletions release];

	return [compl autorelease];

}

- (void) doCompletionByUsingSpellChecker:(BOOL)isDictMode fuzzyMode:(BOOL)fuzzySearch
{

	// No completion for a selection (yet?) and if caret positiopn == 0
	if([self selectedRange].length > 0 || ![self selectedRange].location) return;

	[self breakUndoCoalescing];

	NSInteger caretPos = [self selectedRange].location;
	BOOL caretMovedLeft = NO;

	// Check if caret is located after a ` - if so move caret inside
	if([[self string] characterAtIndex:caretPos-1] == '`') {
		if([[self string] length] > caretPos && [[self string] characterAtIndex:caretPos] == '`') {
			;
		} else {
			caretPos--;
			caretMovedLeft = YES;
			[self setSelectedRange:NSMakeRange(caretPos, 0)];
		}
	}

	NSString* filter;
	NSString* dbName        = nil;
	NSString* tableName     = nil;
	NSRange completionRange = [self getRangeForCurrentWord];
	NSRange parseRange      = completionRange;
	NSString* currentWord   = [[self string] substringWithRange:completionRange];
	NSString* prefix        = @"";
	NSString *currentDb     = nil;

	NSString* allow; // additional chars which not close the popup
	if(isDictMode)
		allow= @"_";
	else
		allow= @"_. ";


	BOOL dbBrowseMode = NO;
	NSInteger backtickMode = 0; // 0 none, 1 rigth only, 2 left only, 3 both
	BOOL caseInsensitive = YES;

	// Remove that attribute to suppress auto-uppercasing of certain keyword combinations
	if(![self selectedRange].length && [self selectedRange].location)
		[[self textStorage] removeAttribute:kSQLkeyword range:completionRange];


	if(!isDictMode) {

		// Parse for leading db.table.field infos

		if([[[self window] delegate] isKindOfClass:[TableDocument class]] && [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKeyPath:@"selectedDatabase"])
			currentDb = [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKeyPath:@"selectedDatabase"];
		else
			currentDb = @"";
		
		BOOL caretIsInsideBackticks = NO;

		// Is the caret inside backticks
		// Do not using attribute:atIndex: since it could return wrong results due to editing.
		// This approach counts the number of ` up to the beginning of the current line from caret position
		NSRange lineHeadRange = [[self string] lineRangeForRange:NSMakeRange(caretPos, 0)];
		NSString *lineHead = [[self string] substringWithRange:NSMakeRange(lineHeadRange.location, caretPos - lineHeadRange.location)];
		for(NSInteger i=0; i<[lineHead length]; i++)
			if([lineHead characterAtIndex:i]=='`') caretIsInsideBackticks = !caretIsInsideBackticks;
			
		NSCharacterSet *whiteSpaceCharSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
		NSInteger start = caretPos;
		NSInteger backticksCounter = (caretIsInsideBackticks) ? 1 : 0;
		NSInteger pointCounter     = 0;
		NSInteger firstPoint       = 0;
		NSInteger secondPoint      = 0;
		BOOL rightBacktick         = NO;
		BOOL leftBacktick          = NO;
		BOOL doParsing             = YES;

		unichar currentCharacter;

		while(start > 0 && doParsing) {
			currentCharacter = [[self string] characterAtIndex:--start];
			if(!(backticksCounter%2) && [whiteSpaceCharSet characterIsMember:currentCharacter]) {
				start++;
				break;
			}
			if(currentCharacter == '.' && !(backticksCounter%2)) {
				pointCounter++;
				switch(pointCounter) {
					case 1:
					firstPoint = start;
					break;
					case 2:
					secondPoint = start;
					break;
					default:
					doParsing = NO;
					start++;
				}
			}
			if(doParsing && currentCharacter == '`') {
				backticksCounter++;
				if(!(backticksCounter%2) && start > 0) {
					currentCharacter = [[self string] characterAtIndex:start-1];
					if(currentCharacter != '`' && currentCharacter != '.') break;
					if(currentCharacter == '`') { // ignore `` 
						backticksCounter++;
						start--;
					}
				}
			}
		}

		dbBrowseMode = (pointCounter || backticksCounter);
		
		if(dbBrowseMode) {
			parseRange = NSMakeRange(start, caretPos-start);
			NSString *parsedString = [[self string] substringWithRange:parseRange];

			// Check if parsed string is wrapped by ``
			if([parsedString hasPrefix:@"`"]) {
				backtickMode+=1;
				leftBacktick = YES;
			}
			if([[self string] length] > parseRange.location+parseRange.length) {
				if([[self string] characterAtIndex:parseRange.location+parseRange.length] == '`') {
					backtickMode+=2;
					parseRange.length++; // adjust parse string for right `
					rightBacktick = YES;
				}
			}

			// Normalize point positions
			firstPoint-=start;
			secondPoint-=start;

			if(secondPoint>0) {
				dbName = [[[parsedString substringWithRange:NSMakeRange(0, secondPoint)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
				tableName = [[[parsedString substringWithRange:NSMakeRange(secondPoint+1,firstPoint-secondPoint-1)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
				filter = [[[parsedString substringWithRange:NSMakeRange(firstPoint+1,[parsedString length]-firstPoint-1)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
			} else if(firstPoint>0) {
				tableName = [[[parsedString substringWithRange:NSMakeRange(0, firstPoint)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
				filter = [[[parsedString substringWithRange:NSMakeRange(firstPoint+1,[parsedString length]-firstPoint-1)] stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
			} else {
				filter = [[parsedString stringByReplacingOccurrencesOfString:@"``" withString:@"`"] stringByReplacingOccurrencesOfRegex:@"^`|`$" withString:@""];
			}

			// Adjust completion range
			if(firstPoint>0) {
				completionRange = NSMakeRange(firstPoint+1+start,[parsedString length]-firstPoint-1);
			} 
			else if([filter length] && leftBacktick) {
				completionRange = NSMakeRange(completionRange.location-1,completionRange.length+1);
			}
			if(rightBacktick)
				completionRange.length++;

			// Check leading . since .tableName == <currentDB>.tableName etc.
			if([filter hasPrefix:@".`"]) {
				filter = [filter substringFromIndex:2];
				completionRange = NSMakeRange(completionRange.location-1,completionRange.length+1);
			} else if([filter hasPrefix:@"."]) {
				filter = [filter substringFromIndex:1];
			} else if([tableName hasPrefix:@".`"]) {
				tableName = [tableName substringFromIndex:2];
			}

			if(fuzzySearch) {
				filter = [[NSString stringWithString:[[self string] substringWithRange:parseRange]] stringByReplacingOccurrencesOfString:@"`" withString:@""];
				completionRange = parseRange;
			}

		} else {
			filter = [NSString stringWithString:currentWord];
		}
	} else {
		filter = [NSString stringWithString:currentWord];
	}

	SPNarrowDownCompletion* completionPopUp = [[SPNarrowDownCompletion alloc] initWithItems:[self suggestionsForSQLCompletionWith:currentWord dictMode:isDictMode browseMode:dbBrowseMode withTableName:tableName withDbName:dbName] 
					alreadyTyped:filter 
					staticPrefix:prefix 
					additionalWordCharacters:allow 
					caseSensitive:!caseInsensitive
					charRange:completionRange
					parseRange:parseRange
					inView:self
					dictMode:isDictMode
					dbMode:dbBrowseMode
					fuzzySearch:fuzzySearch
					backtickMode:backtickMode
					withDbName:dbName
					withTableName:tableName
					selectedDb:currentDb
					caretMovedLeft:caretMovedLeft];
	
	//Get the NSPoint of the first character of the current word
	NSRange glyphRange = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(completionRange.location,1) actualCharacterRange:NULL];
	NSRect boundingRect = [[self layoutManager] boundingRectForGlyphRange:glyphRange inTextContainer:[self textContainer]];
	boundingRect = [self convertRect: boundingRect toView: NULL];
	NSPoint pos = [[self window] convertBaseToScreen: NSMakePoint(boundingRect.origin.x + boundingRect.size.width,boundingRect.origin.y + boundingRect.size.height)];

	// TODO: check if needed
	// if(filter)
	// 	pos.x -= [filter sizeWithAttributes:[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName]].width;
	
	// Adjust list location to be under the current word or insertion point
	pos.y -= [[self font] pointSize]*1.25;
	
	[completionPopUp setCaretPos:pos];
	[completionPopUp orderFront:self];
	[completionPopUp insertCommonPrefix];

}


/*
 * Returns the associated line number for a character position inside of the CMTextView
 */
- (NSUInteger) getLineNumberForCharacterIndex:(NSUInteger)anIndex
{
	return [lineNumberView lineNumberForCharacterIndex:anIndex inText:[self string]]+1;
}


/*
 * Search for the current selection or current word in the MySQL Help 
 */
- (IBAction) showMySQLHelpForCurrentWord:(id)sender
{	
	[[[[self window] delegate] valueForKeyPath:@"customQueryInstance"] showHelpForCurrentWord:self];
}

/*
 * Checks if the char after the current caret position/selection matches a supplied attribute
 */
- (BOOL) isNextCharMarkedBy:(id)attribute withValue:(id)aValue
{
	NSUInteger caretPosition = [self selectedRange].location;

	// Perform bounds checking
	if (caretPosition >= [[self string] length]) return NO;
	
	// Perform the check
	if ([[[self textStorage] attribute:attribute atIndex:caretPosition effectiveRange:nil] isEqualToString:aValue])
		return YES;

	return NO;
}

/*
 * Checks if the caret adjoins to an alphanumeric char  |word or word| or wo|rd
 * Exception for word| and char is a “(” to allow e.g. auto-pairing () for functions
 */
- (BOOL) isCaretAdjacentToAlphanumCharWithInsertionOf:(unichar)aChar
{
	NSUInteger caretPosition = [self selectedRange].location;
	NSCharacterSet *alphanum = [NSCharacterSet alphanumericCharacterSet];
	BOOL leftIsAlphanum = NO;
	BOOL rightIsAlphanum = NO;
	BOOL charIsOpenBracket = (aChar == '(');
	
	// Check previous/next character for being alphanum
	// @try block for bounds checking
	@try
	{
		leftIsAlphanum = [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition-1]] && !charIsOpenBracket;
	} @catch(id ae) { }
	@try {
		rightIsAlphanum= [alphanum characterIsMember:[[self string] characterAtIndex:caretPosition]];
		
	} @catch(id ae) { }

	return (leftIsAlphanum ^ rightIsAlphanum || leftIsAlphanum && rightIsAlphanum);
}

/*
 * Checks if the caret is wrapped by auto-paired characters.
 * e.g. [| := caret]: "|" 
 */
- (BOOL) areAdjacentCharsLinked
{
	NSUInteger caretPosition = [self selectedRange].location;
	unichar leftChar, matchingChar;

	// Perform bounds checking
	if ([self selectedRange].length) return NO;
	if (caretPosition < 1) return NO;
	if (caretPosition >= [[self string] length]) return NO;

	// Check the character to the left of the cursor and set the pairing character if appropriate
	leftChar = [[self string] characterAtIndex:caretPosition - 1];
	if (leftChar == '(')
		matchingChar = ')';
	else if (leftChar == '"' || leftChar == '`' || leftChar == '\'')
		matchingChar = leftChar;
	else
		return NO;

	// Check that the pairing character exists after the caret, and is tagged with the link attribute
	if (matchingChar == [[self string] characterAtIndex:caretPosition]
		&& [[[self textStorage] attribute:kAPlinked atIndex:caretPosition effectiveRange:nil] isEqualToString:kAPval]) {
		return YES;
	}

	return NO;
}

/*
 * If the textview has a selection, wrap it with the supplied prefix and suffix strings;
 * return whether or not any wrap was performed.
 */
- (BOOL) wrapSelectionWithPrefix:(NSString *)prefix suffix:(NSString *)suffix
{

	// Only proceed if a selection is active
	if ([self selectedRange].length == 0)
		return NO;

	// Replace the current selection with the selected string wrapped in prefix and suffix
	[self insertText:
		[NSString stringWithFormat:@"%@%@%@", 
			prefix,
			[[self string] substringWithRange:[self selectedRange]],
			suffix
		]
	];
	return YES;
}

/*
 * Copy selected text chunk as RTF to preserve syntax highlighting
 */
- (void) copyAsRTF
{

	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	NSTextStorage *textStorage = [self textStorage];
	NSData *rtf = [textStorage RTFFromRange:[self selectedRange]
		documentAttributes:nil];
	
	if (rtf)
	{
		[pb declareTypes:[NSArray arrayWithObject:NSRTFPboardType] owner:self];
		[pb setData:rtf forType:NSRTFPboardType];
	}
}

- (void) selectCurrentQuery
{
	[[[[self window] delegate] valueForKeyPath:@"customQueryInstance"] selectCurrentQuery];
}

/*
 * Selects the line lineNumber relatively to a selection (if given) and scrolls to it
 */
- (void) selectLineNumber:(NSUInteger)lineNumber ignoreLeadingNewLines:(BOOL)ignLeadingNewLines
{
	NSRange selRange;
	NSArray *lineRanges;
	if([self selectedRange].length)
		lineRanges = [[[self string] substringWithRange:[self selectedRange]] lineRangesForRange:NSMakeRange(0, [self selectedRange].length)];
	else
		lineRanges = [[self string] lineRangesForRange:NSMakeRange(0, [[self string] length])];

	if(ignLeadingNewLines) // ignore leading empty lines
	{
		NSInteger arrayCount = [lineRanges count];
		NSInteger i;
		for (i = 0; i < arrayCount; i++) {
			if(NSRangeFromString([lineRanges objectAtIndex:i]).length > 0)
				break;
			lineNumber++;
		}
	}
	
	// Safety-check the line number
	if (lineNumber > [lineRanges count]) lineNumber = [lineRanges count];

	// Grab the range to select
	selRange = NSRangeFromString([lineRanges objectAtIndex:lineNumber-1]);

	// adjust selRange if a selection was given
	if([self selectedRange].length)
		selRange.location += [self selectedRange].location;
	[self setSelectedRange:selRange];
	[self scrollRangeToVisible:selRange];
}

/*
 * Used for autoHelp update if the user changed the caret position by using the mouse.
 */
- (void) mouseDown:(NSEvent *)theEvent
{
	
	// Cancel autoHelp timer
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp])
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(autoHelp) 
									object:nil];

	[super mouseDown:theEvent];

	// Start autoHelp timer
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp])
		[self performSelector:@selector(autoHelp) withObject:nil afterDelay:[[prefs valueForKey:SPCustomQueryAutoHelpDelay] doubleValue]];
	
}

- (void)selectCurrentSnippet
{
	if(snippetControlCounter > -1)
		[self setSelectedRange:NSMakeRange(snippetControlArray[currentSnippetIndex][0], snippetControlArray[currentSnippetIndex][1])];
}

- (void)insertFavoriteAsSnippet:(NSString*)theSnippet atRange:(NSRange)targetRange
{

	if(theSnippet == nil || ![theSnippet length]) return;

	NSMutableString *snip = [[NSMutableString string] autorelease];
	// NSString *re = @"(?<!\\\\)\\$\\{([^\\{\\}]*)\\}";
	[snip setString:theSnippet];

	snippetControlCounter = -1;
	// while([snip isMatchedByRegex:re]) {
	// 	snippetControlCounter++;
	// 	NSRange hintRange = [snip rangeOfRegex:re capture:1L];
	// 	NSRange snipRange = [snip rangeOfRegex:re capture:0L];
	// 	[snip replaceCharactersInRange:snipRange withString:[snip substringWithRange:hintRange]];
	// 	snippetControlArray[snippetControlCounter][0] = snipRange.location + targetRange.location;
	// 	snippetControlArray[snippetControlCounter][1] = snipRange.length-3;
	// }
	// 
	// if(snippetControlCounter > -1) {
	// 	// Store the end for eventually tab out
	// 	snippetControlCounter++;
	// 	snippetControlArray[snippetControlCounter][0] = targetRange.location + [snip length];
	// 	snippetControlArray[snippetControlCounter][1] = 0;
	// }

	[self breakUndoCoalescing];
	[self setSelectedRange:targetRange];
	snippetWasJustInserted = YES;
	[self insertText:snip];

	currentSnippetIndex = 0;
	if(snippetControlCounter > -1)
		[self selectCurrentSnippet];

	snippetWasJustInserted = NO;
}

- (BOOL)checkForCaretInsideSnippet
{

	if(snippetControlCounter < 0 || currentSnippetIndex == snippetControlCounter) {
		snippetControlCounter = -1;
		return NO;
	}

	BOOL isCaretInsideASnippet = NO;
	NSInteger caretPos = [self selectedRange].location;
	NSInteger i;

	for(i=0; i<snippetControlCounter; i++) {
		if(caretPos >= snippetControlArray[i][0]
			&& caretPos <= snippetControlArray[i][0] + snippetControlArray[i][1]) {

			isCaretInsideASnippet = YES;
			break;
		}
	}
	// if(!isCaretInsideASnippet)
	// 	snippetControlCounter = -1;
	return isCaretInsideASnippet;
}
/*
 * Handle some keyDown events in order to provide autopairing functionality (if enabled).
 */
- (void) keyDown:(NSEvent *)theEvent
{

	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp]) {// restart autoHelp timer
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(autoHelp) 
									object:nil];
		[self performSelector:@selector(autoHelp) withObject:nil 
			afterDelay:[[prefs valueForKey:SPCustomQueryAutoHelpDelay] doubleValue]];
	}

	long allFlags = (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask);
	
	// Check if user pressed ⌥ to allow composing of accented characters.
	// e.g. for US keyboard "⌥u a" to insert ä
	// or for non-US keyboards to allow to enter dead keys
	// e.g. for German keyboard ` is a dead key, press space to enter `
	if (([theEvent modifierFlags] & allFlags) == NSAlternateKeyMask || [[theEvent characters] length] == 0)
	{
		[super keyDown: theEvent];
		return;
	}

	NSString *characters = [theEvent characters];
	NSString *charactersIgnMod = [theEvent charactersIgnoringModifiers];
	unichar insertedCharacter = [characters characterAtIndex:0];
	long curFlags = ([theEvent modifierFlags] & allFlags);

	if ([theEvent keyCode] == 53 && [self isEditable]){ // ESC key for internal completion
		if(curFlags==(NSControlKeyMask))
			[self doCompletionByUsingSpellChecker:NO fuzzyMode:YES];
		else
			[self doCompletionByUsingSpellChecker:NO fuzzyMode:NO];
		return;
	}
	if (insertedCharacter == NSF5FunctionKey){ // F5 for completion based on spell checker
		[self doCompletionByUsingSpellChecker:YES fuzzyMode:NO];
		return;
	}

	// Check for {SHIFT}TAB to insert favorites via TAB-trigger if CMTextView belongs to CustomQuery
	if ([theEvent keyCode] == 48 && [self isEditable] && [[self delegate] isKindOfClass:[CustomQuery class]]){
		NSRange targetRange = [self getRangeForCurrentWord];
		NSString *tabTrigger = [[self string] substringWithRange:targetRange];

		// Is TAB trigger active change selection according to {SHIFT}TAB
		if(snippetControlCounter > -1 && [self checkForCaretInsideSnippet]){
			if(curFlags==(NSShiftKeyMask)) {
				currentSnippetIndex--;
				if(currentSnippetIndex < 0) {
					snippetControlCounter = -1;
				} else {
					[self selectCurrentSnippet];
					return;
				}
			} else {
				currentSnippetIndex++;
				if(currentSnippetIndex > snippetControlCounter) {
					snippetControlCounter = -1;
				} else if(currentSnippetIndex == snippetControlCounter) {
					[self selectCurrentSnippet];
					snippetControlCounter = -1;
					return;
				} else {
					[self selectCurrentSnippet];
					return;
				}
			}
		}
		// Check if tab-trigger is defined; if so insert it
		if(snippetControlCounter < 0 && [[[self window] delegate] fileURL]) {
			NSArray *snippets = [[SPQueryController sharedQueryController] queryFavoritesForFileURL:[[[self window] delegate] fileURL] andTabTrigger:tabTrigger includeGlobals:YES];
			if([snippets count] > 0 && [(NSString*)[(NSDictionary*)[snippets objectAtIndex:0] objectForKey:@"query"] length]) {
				[self insertFavoriteAsSnippet:[(NSDictionary*)[snippets objectAtIndex:0] objectForKey:@"query"] atRange:targetRange];
				return;
			}
		}
	}

	// Note: switch(insertedCharacter) {} does not work instead use charactersIgnoringModifiers
	if([charactersIgnMod isEqualToString:@"c"]) // ^C copy as RTF
		if(curFlags==(NSControlKeyMask))
		{
			[self copyAsRTF];
			return;
		}
	if([charactersIgnMod isEqualToString:@"h"]) // ^H show MySQL Help
		if(curFlags==(NSControlKeyMask))
		{
			[self showMySQLHelpForCurrentWord:self];
			return;
		}
	if([charactersIgnMod isEqualToString:@"y"]) // ^Y select current query
		if(curFlags==(NSControlKeyMask))
		{
			[self selectCurrentQuery];
			return;
		}
	if(curFlags & NSCommandKeyMask) {
		if([charactersIgnMod isEqualToString:@"+"]) // increase text size by 1; ⌘+ and numpad +
		{
			[self makeTextSizeLarger];
			return;
		}
		if([charactersIgnMod isEqualToString:@"-"]) // decrease text size by 1; ⌘- and numpad -
		{
			[self makeTextSizeSmaller];
			return;
		}
	}

	// Only process for character autopairing if autopairing is enabled and a single character is being added.
	if ([prefs boolForKey:SPCustomQueryAutoPairCharacters] && characters && [characters length] == 1) {

		delBackwardsWasPressed = NO;

		NSString *matchingCharacter = nil;
		BOOL processAutopair = NO, skipTypedLinkedCharacter = NO;
		NSRange currentRange;

		// When a quote character is being inserted into a string quoted with other
		// quote characters, or if it's the same character but is escaped, don't
		// automatically match it.
		if(
			// Only for " ` or ' quote characters
			(insertedCharacter == '\'' || insertedCharacter == '"' || insertedCharacter == '`')

			// And if the next char marked as linked auto-pair
			&& [self isNextCharMarkedBy:kAPlinked withValue:kAPval]

			// And we are inside a quoted string
			&& [self isNextCharMarkedBy:kLEXToken withValue:kLEXTokenValue]

			// And there is no selection, just the text caret
			&& ![self selectedRange].length

			&& (
				// And the user is inserting an escaped string
				[[self string] characterAtIndex:[self selectedRange].location-1] == '\\'
				
				// Or the user is inserting a character not matching the characters used to quote this string
				|| [[self string] characterAtIndex:[self selectedRange].location] != insertedCharacter
			)
		)
		{
			[super keyDown: theEvent];
			return;
		}

		// If the caret is inside a text string, without any selection, and not adjoined to an alphanumeric char
		// (exception for '(' ) skip autopairing.
		// There is one exception to this - if the caret is before a linked pair character,
		// processing continues in order to check whether the next character should be jumped
		// over; e.g. [| := caret]: "foo|" and press " => only caret will be moved "foo"|
		if( ([self isCaretAdjacentToAlphanumCharWithInsertionOf:insertedCharacter] && ![self isNextCharMarkedBy:kAPlinked withValue:kAPval] && ![self selectedRange].length) 
			|| (![self isNextCharMarkedBy:kAPlinked withValue:kAPval] && [self isNextCharMarkedBy:kLEXToken withValue:kLEXTokenValue] && ![self selectedRange].length)) {
			[super keyDown:theEvent];
			return;
		}

		// Check whether the submitted character should trigger autopair processing.
		switch (insertedCharacter)
		{
			case '(':
				matchingCharacter = @")";
				processAutopair = YES;
				break;
			case '"':
				matchingCharacter = @"\"";
				processAutopair = YES;
				skipTypedLinkedCharacter = YES;
				break;
			case '`':
				matchingCharacter = @"`";
				processAutopair = YES;
				skipTypedLinkedCharacter = YES;
				break;
			case '\'':
				matchingCharacter = @"'";
				processAutopair = YES;
				skipTypedLinkedCharacter = YES;
				break;
			case ')':
				skipTypedLinkedCharacter = YES;
				break;
		}

		// Check to see whether the next character should be compared to the typed character;
		// if it matches the typed character, and is marked with the is-linked-pair attribute,
		// select the next character and replace it with the typed character.  This allows
		// a normally quoted string to be typed in full, with the autopair appearing as a hint and
		// then being automatically replaced when the user types it.
		if (skipTypedLinkedCharacter) {
			currentRange = [self selectedRange];
			if (currentRange.location != NSNotFound && currentRange.length == 0) {
				if ([self isNextCharMarkedBy:kAPlinked withValue:kAPval]) {
					if ([[[self textStorage] string] characterAtIndex:currentRange.location] == insertedCharacter) {
						currentRange.length = 1;
						[self setSelectedRange:currentRange];
						processAutopair = NO;
					}
				}
			}
		}

		// If an appropriate character has been typed, and a matching character has been set,
		// some form of autopairing is required.
		if (processAutopair && matchingCharacter) {

			// Check to see whether several characters are selected, and if so, wrap them with
			// the auto-paired characters.  This returns false if the selection has zero length.
			if ([self wrapSelectionWithPrefix:characters suffix:matchingCharacter])
				return;
			
			// Otherwise, start by inserting the original character - the first half of the autopair.
			[super keyDown:theEvent];
			
			// Then process the second half of the autopair - the matching character.
			currentRange = [self selectedRange];
			if (currentRange.location != NSNotFound) {
				NSTextStorage *textStorage = [self textStorage];

				// Register the auto-pairing for undo
				[self shouldChangeTextInRange:currentRange replacementString:matchingCharacter];

				// Insert the matching character and give it the is-linked-pair-character attribute
				[self replaceCharactersInRange:currentRange withString:matchingCharacter];
				currentRange.length = 1;
				[textStorage addAttribute:kAPlinked value:kAPval range:currentRange];

				// Restore the original selection.
				currentRange.length=0;
				[self setSelectedRange:currentRange];
			}
			return;
		}
	}
	
	// break down the undo grouping level for better undo behavior
	[self breakUndoCoalescing];
	// The default action is to perform the normal key-down action.
	[super keyDown:theEvent];

}


- (void) deleteBackward:(id)sender
{

	// If the caret is currently inside a marked auto-pair, delete the characters on both sides
	// of the caret.
	NSRange currentRange = [self selectedRange];
	if (currentRange.length == 0 && currentRange.location > 0 && [self areAdjacentCharsLinked])
		[self setSelectedRange:NSMakeRange(currentRange.location - 1,2)];

	// Avoid auto-uppercasing if resulting word would be a SQL keyword;
	// e.g. type inta| and deleteBackward:
	delBackwardsWasPressed = YES;	

	[super deleteBackward:sender];

}

/*
 * Handle special commands - see NSResponder.h for a sample list.
 * This subclass currently handles insertNewline: in order to preserve indentation
 * when adding newlines.
 */
- (void) doCommandBySelector:(SEL)aSelector
{

	// Handle newlines, adding any indentation found on the current line to the new line - ignoring the enter key if appropriate
    if (aSelector == @selector(insertNewline:)
		&& [prefs boolForKey:SPCustomQueryAutoIndent]
		&& (!autoindentIgnoresEnter || [[NSApp currentEvent] keyCode] != 0x4C))
	{
		NSString *textViewString = [[self textStorage] string];
		NSString *currentLine, *indentString = nil;
		NSScanner *whitespaceScanner;
		NSRange currentLineRange;
		NSInteger lineCursorLocation;

		// Extract the current line based on the text caret or selection start position
		currentLineRange = [textViewString lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];
		currentLine = [[NSString alloc] initWithString:[textViewString substringWithRange:currentLineRange]];
		lineCursorLocation = [self selectedRange].location - currentLineRange.location;

		// Scan all indentation characters on the line into a string
		whitespaceScanner = [[NSScanner alloc] initWithString:currentLine];
		[whitespaceScanner setCharactersToBeSkipped:nil];
		[whitespaceScanner scanCharactersFromSet:[NSCharacterSet whitespaceCharacterSet] intoString:&indentString];
		[whitespaceScanner release];
		[currentLine release];

		// Always add the newline, whether or not we want to indent the next line
		[self insertNewline:self];

		// Replicate the indentation on the previous line if one was found.
		if (indentString) {
			if (lineCursorLocation < [indentString length]) {
				[self insertText:[indentString substringWithRange:NSMakeRange(0, lineCursorLocation)]];
			} else {
				[self insertText:indentString];
			}
		}

		// Return to avoid the original implementation, preventing double linebreaks
		return;
	}
	[super doCommandBySelector:aSelector];
}


/*
 * Shifts the selection, if any, rightwards by indenting any selected lines with one tab.
 * If the caret is within a line, the selection is not changed after the index; if the selection
 * has length, all lines crossed by the length are indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionRight
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;
	NSArray *lineRanges;
	NSString *tabString = @"\t";
	NSInteger i, indentedLinesLength = 0;

	if ([self selectedRange].location == NSNotFound) return NO;

	// Indent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {
		NSRange currentLineRange;

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 0) replacementString:tabString];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 0) withString:tabString];

		return YES;
	}

	// Otherwise, the selection has a length - get an array of current line ranges for the specified selection
	lineRanges = [textViewString lineRangesForRange:[self selectedRange]];

	// Loop through the ranges, storing a count of the overall length.
	for (i = 0; i < [lineRanges count]; i++) {
		currentLineRange = NSRangeFromString([lineRanges objectAtIndex:i]);
		indentedLinesLength += currentLineRange.length + 1;

		// Register the indent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location+i, 0) replacementString:tabString];

		// Insert the new tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location+i, 0) withString:tabString];
	}

	// Select the entirety of the new range
	[self setSelectedRange:NSMakeRange(NSRangeFromString([lineRanges objectAtIndex:0]).location, indentedLinesLength)];

	return YES;
}


/*
 * Shifts the selection, if any, leftwards by un-indenting any selected lines by one tab if possible.
 * If the caret is within a line, the selection is not changed after the undent; if the selection has
 * length, all lines crossed by the length are un-indented and fully selected.
 * Returns whether or not an indentation was performed.
 */
- (BOOL) shiftSelectionLeft
{
	NSString *textViewString = [[self textStorage] string];
	NSRange currentLineRange;
	NSArray *lineRanges;
	NSInteger i, unindentedLines = 0, unindentedLinesLength = 0;

	if ([self selectedRange].location == NSNotFound) return NO;

	// Undent the currently selected line if the caret is within a single line
	if ([self selectedRange].length == 0) {
		NSRange currentLineRange;

		// Extract the current line range based on the text caret
		currentLineRange = [textViewString lineRangeForRange:[self selectedRange]];

		// Ensure that the line has length and that the first character is a tab
		if (currentLineRange.length < 1
			|| [textViewString characterAtIndex:currentLineRange.location] != '\t')
			return NO;

		// Register the undent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location, 1) replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location, 1) withString:@""];

		return YES;
	}

	// Otherwise, the selection has a length - get an array of current line ranges for the specified selection
	lineRanges = [textViewString lineRangesForRange:[self selectedRange]];

	// Loop through the ranges, storing a count of the total lines changed and the new length.
	for (i = 0; i < [lineRanges count]; i++) {
		currentLineRange = NSRangeFromString([lineRanges objectAtIndex:i]);
		unindentedLinesLength += currentLineRange.length;
		
		// Ensure that the line has length and that the first character is a tab
		if (currentLineRange.length < 1
			|| [textViewString characterAtIndex:currentLineRange.location-unindentedLines] != '\t')
			continue;

		// Register the undent for undo
		[self shouldChangeTextInRange:NSMakeRange(currentLineRange.location-unindentedLines, 1) replacementString:@""];

		// Remove the tab
		[self replaceCharactersInRange:NSMakeRange(currentLineRange.location-unindentedLines, 1) withString:@""];
		
		// As a line has been unindented, modify counts and lengths
		unindentedLines++;
		unindentedLinesLength--;
	}

	// If a change was made, select the entirety of the new range and return success
	if (unindentedLines) {
		[self setSelectedRange:NSMakeRange(NSRangeFromString([lineRanges objectAtIndex:0]).location, unindentedLinesLength)];
		return YES;
	}

	return NO;
}

/*
 * Handle autocompletion, returning a list of suggested completions for the supplied character range.
 */
// - (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index
// {
// 
// 	if (!charRange.length) return nil;
// 	
// 	// Refresh quote attributes
// 	[[self textStorage] removeAttribute:kQuote range:NSMakeRange(0,[[self string] length])];
// 	[self insertText:@""];
// 	
// 	
// 	// Check if the caret is inside quotes "" or ''; if so 
// 	// return the normal word suggestion due to the spelling's settings
// 	if([[[self textStorage] attribute:kQuote atIndex:charRange.location effectiveRange:nil] isEqualToString:kQuoteValue] )
// 		return [[NSSpellChecker sharedSpellChecker] completionsForPartialWordRange:NSMakeRange(0,charRange.length) inString:[[self string] substringWithRange:charRange] language:nil inSpellDocumentWithTag:0];
// 
// 
// 	NSMutableArray *compl = [[NSMutableArray alloc] initWithCapacity:32];
// 	NSMutableArray *possibleCompletions = [[NSMutableArray alloc] initWithCapacity:32];
// 
// 	NSString *partialString    = [[self string] substringWithRange:charRange];
// 	NSUInteger partialLength = [partialString length];
// 
// 	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@ AND length > %lu", partialString, (unsigned long)partialLength];
// 	NSArray *matchingCompletions;
// 
// 	NSUInteger i, insindex;
// 	insindex = 0;
// 
// 
// 	if([mySQLConnection isConnected])
// 	{
// 
// 		// Add all database names to completions list
// 		[possibleCompletions addObjectsFromArray:[[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allDatabaseNames"]];
// 
// 		// Add table names to completions list
// 		[possibleCompletions addObjectsFromArray:[[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allTableAndViewNames"]];
// 
// 		// Add field names to completions list for currently selected table
// 		if ([[[self window] delegate] table] != nil)
// 			[possibleCompletions addObjectsFromArray:[[[[self window] delegate] valueForKeyPath:@"tableDataInstance"] valueForKey:@"columnNames"]];
// 
// 		// Add proc/func only for MySQL version 5 or higher
// 		if(mySQLmajorVersion > 4) {
// 			[possibleCompletions addObjectsFromArray:[[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allProcedureNames"]];
// 			[possibleCompletions addObjectsFromArray:[[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"allFunctionNames"]];
// 		}
// 
// 	}
// 	// If caret is not inside backticks add keywords and all words coming from the view.
// 	if(![[[self textStorage] attribute:kBTQuote atIndex:charRange.location effectiveRange:nil] isEqualToString:kBTQuoteValue] )
// 	{
// 		// Only parse for words if text size is less than 6MB
// 		if([[self string] length]<6000000)
// 		{
// 			NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n,()[]{}\"'`-!;=+|?:~@"];
// 			NSMutableArray *uniqueArray = [NSMutableArray array];
// 			[uniqueArray addObjectsFromArray:[[NSSet setWithArray:[[self string] componentsSeparatedByCharactersInSet:separators]] allObjects]];
// 			[possibleCompletions addObjectsFromArray:uniqueArray];
// 		}
// 
// 		[possibleCompletions addObjectsFromArray:[self keywords]];
// 		[possibleCompletions addObjectsFromArray:[self functions]];
// 	}
// 	
// 	// Check for possible completions
// 	matchingCompletions = [[possibleCompletions filteredArrayUsingPredicate:predicate] sortedArrayUsingSelector:@selector(compare:)];
// 
// 	for (i = 0; i < [matchingCompletions count]; i++)
// 	{
// 		NSString* obj = NSArrayObjectAtIndex(matchingCompletions, i);
// 		if(![compl containsObject:obj])
// 			if ([partialString isEqualToString:[obj substringToIndex:partialLength]])
// 				// Matches case --> Insert at beginning of completion list
// 				[compl insertObject:obj atIndex:insindex++];
// 			else
// 				// Not matching case --> Insert at end of completion list
// 				[compl addObject:obj];
// 	}
// 
// 	[possibleCompletions release];
// 
// 	return [compl autorelease];
// }


/*
 * List of keywords for autocompletion. If you add a keyword here,
 * it should also be added to the flex file SPEditorTokens.l
 */
-(NSArray *)keywords
{
	return [NSArray arrayWithObjects:
	@"ACCESSIBLE",
	@"ACTION",
	@"ADD",
	@"AFTER",
	@"AGAINST",
	@"AGGREGATE",
	@"ALGORITHM",
	@"ALL",
	@"ALTER",
	@"ALTER COLUMN",
	@"ALTER DATABASE",
	@"ALTER EVENT",
	@"ALTER FUNCTION",
	@"ALTER LOGFILE GROUP",
	@"ALTER PROCEDURE",
	@"ALTER SCHEMA",
	@"ALTER SERVER",
	@"ALTER TABLE",
	@"ALTER TABLESPACE",
	@"ALTER VIEW",
	@"ANALYZE",
	@"ANALYZE TABLE",
	@"AND",
	@"ANY",
	@"AS",
	@"ASC",
	@"ASCII",
	@"ASENSITIVE",
	@"AT",
	@"AUTHORS",
	@"AUTOEXTEND_SIZE",
	@"AUTO_INCREMENT",
	@"AVG",
	@"AVG_ROW_LENGTH",
	@"BACKUP",
	@"BACKUP TABLE",
	@"BEFORE",
	@"BEGIN",
	@"BETWEEN",
	@"BIGINT",
	@"BINARY",
	@"BINLOG",
	@"BIT",
	@"BLOB",
	@"BOOL",
	@"BOOLEAN",
	@"BOTH",
	@"BTREE",
	@"BY",
	@"BYTE",
	@"CACHE",
	@"CACHE INDEX",
	@"CALL",
	@"CASCADE",
	@"CASCADED",
	@"CASE",
	@"CHAIN",
	@"CHANGE",
	@"CHANGED",
	@"CHAR",
	@"CHARACTER",
	@"CHARACTER SET",
	@"CHARSET",
	@"CHECK",
	@"CHECK TABLE",
	@"CHECKSUM",
	@"CHECKSUM TABLE",
	@"CIPHER",
	@"CLIENT",
	@"CLOSE",
	@"COALESCE",
	@"CODE",
	@"COLLATE",
	@"COLLATION",
	@"COLUMN",
	@"COLUMNS",
	@"COLUMN_FORMAT"
	@"COMMENT",
	@"COMMIT",
	@"COMMITTED",
	@"COMPACT",
	@"COMPLETION",
	@"COMPRESSED",
	@"CONCURRENT",
	@"CONDITION",
	@"CONNECTION",
	@"CONSISTENT",
	@"CONSTRAINT",
	@"CONTAINS",
	@"CONTINUE",
	@"CONTRIBUTORS",
	@"CONVERT",
	@"CREATE",
	@"CREATE DATABASE",
	@"CREATE EVENT",
	@"CREATE FUNCTION",
	@"CREATE INDEX",
	@"CREATE LOGFILE GROUP",
	@"CREATE PROCEDURE",
	@"CREATE SCHEMA",
	@"CREATE TABLE",
	@"CREATE TABLESPACE",
	@"CREATE TRIGGER",
	@"CREATE USER",
	@"CREATE VIEW",
	@"CROSS",
	@"CUBE",
	@"CURRENT_DATE",
	@"CURRENT_TIME",
	@"CURRENT_TIMESTAMP",
	@"CURRENT_USER",
	@"CURSOR",
	@"DATA",
	@"DATABASE",
	@"DATABASES",
	@"DATAFILE",
	@"DATE",
	@"DATETIME",
	@"DAY",
	@"DAY_HOUR",
	@"DAY_MICROSECOND",
	@"DAY_MINUTE",
	@"DAY_SECOND",
	@"DEALLOCATE",
	@"DEALLOCATE PREPARE",
	@"DEC",
	@"DECIMAL",
	@"DECLARE",
	@"DEFAULT",
	@"DEFINER",
	@"DELAYED",
	@"DELAY_KEY_WRITE",
	@"DELETE",
	@"DELIMITER ",
	@"DELIMITER ;\n",
	@"DELIMITER ;;\n",
	@"DESC",
	@"DESCRIBE",
	@"DES_KEY_FILE",
	@"DETERMINISTIC",
	@"DIRECTORY",
	@"DISABLE",
	@"DISCARD",
	@"DISK",
	@"DISTINCT",
	@"DISTINCTROW",
	@"DIV",
	@"DO",
	@"DOUBLE",
	@"DROP",
	@"DROP DATABASE",
	@"DROP EVENT",
	@"DROP FOREIGN KEY",
	@"DROP FUNCTION",
	@"DROP INDEX",
	@"DROP LOGFILE GROUP",
	@"DROP PREPARE",
	@"DROP PRIMARY KEY",
	@"DROP PREPARE",
	@"DROP PROCEDURE",
	@"DROP SCHEMA",
	@"DROP SERVER",
	@"DROP TABLE",
	@"DROP TABLESPACE",
	@"DROP TRIGGER",
	@"DROP USER",
	@"DROP VIEW",
	@"DUAL",
	@"DUMPFILE",
	@"DUPLICATE",
	@"DYNAMIC",
	@"EACH",
	@"ELSE",
	@"ELSEIF",
	@"ENABLE",
	@"ENCLOSED",
	@"END",
	@"ENDS",
	@"ENGINE",
	@"ENGINES",
	@"ENUM",
	@"ERRORS",
	@"ESCAPE",
	@"ESCAPED",
	@"EVENT",
	@"EVENTS",
	@"EVERY",
	@"EXECUTE",
	@"EXISTS",
	@"EXIT",
	@"EXPANSION",
	@"EXPLAIN",
	@"EXTENDED",
	@"EXTENT_SIZE",
	@"FALSE",
	@"FAST",
	@"FETCH",
	@"FIELDS",
	@"FIELDS TERMINATED BY",
	@"FILE",
	@"FIRST",
	@"FIXED",
	@"FLOAT",
	@"FLOAT4",
	@"FLOAT8",
	@"FLUSH",
	@"FOR",
	@"FOR UPDATE",
	@"FORCE",
	@"FOREIGN",
	@"FOREIGN KEY",
	@"FOUND",
	@"FRAC_SECOND",
	@"FROM",
	@"FULL",
	@"FULLTEXT",
	@"FUNCTION",
	@"GEOMETRY",
	@"GEOMETRYCOLLECTION",
	@"GET_FORMAT",
	@"GLOBAL",
	@"GRANT",
	@"GRANTS",
	@"GROUP",
	@"GROUP BY",
	@"HANDLER",
	@"HASH",
	@"HAVING",
	@"HELP",
	@"HIGH_PRIORITY",
	@"HOSTS",
	@"HOUR",
	@"HOUR_MICROSECOND",
	@"HOUR_MINUTE",
	@"HOUR_SECOND",
	@"IDENTIFIED",
	@"IF",
	@"IGNORE",
	@"IMPORT",
	@"IN",
	@"INDEX",
	@"INDEXES",
	@"INFILE",
	@"INITIAL_SIZE",
	@"INNER",
	@"INNOBASE",
	@"INNODB",
	@"INOUT",
	@"INSENSITIVE",
	@"INSERT",
	@"INSERT_METHOD",
	@"INSTALL",
	@"INSTALL PLUGIN",
	@"INT",
	@"INT1",
	@"INT2",
	@"INT3",
	@"INT4",
	@"INT8",
	@"INTEGER",
	@"INTERVAL",
	@"INTO",
	@"INTO DUMPFILE",
	@"INTO OUTFILE",
	@"INTO TABLE",
	@"INVOKER",
	@"IO_THREAD",
	@"IS",
	@"ISOLATION",
	@"ISSUER",
	@"ITERATE",
	@"JOIN",
	@"KEY",
	@"KEYS",
	@"KEY_BLOCK_SIZE",
	@"KILL",
	@"LANGUAGE",
	@"LAST",
	@"LEADING",
	@"LEAVE",
	@"LEAVES",
	@"LEFT",
	@"LESS",
	@"LEVEL",
	@"LIKE",
	@"LIMIT",
	@"LINEAR",
	@"LINES",
	@"LINES TERMINATED BY",
	@"LINESTRING",
	@"LIST",
	@"LOAD DATA",
	@"LOAD INDEX INTO CACHE",
	@"LOAD XML",
	@"LOCAL",
	@"LOCALTIME",
	@"LOCALTIMESTAMP",
	@"LOCK",
	@"LOCK IN SHARE MODE",
	@"LOCK TABLES",
	@"LOCKS",
	@"LOGFILE",
	@"LOGS",
	@"LONG",
	@"LONGBLOB",
	@"LONGTEXT",
	@"LOOP",
	@"LOW_PRIORITY",
	@"MASTER",
	@"MASTER_CONNECT_RETRY",
	@"MASTER_HOST",
	@"MASTER_LOG_FILE",
	@"MASTER_LOG_POS",
	@"MASTER_PASSWORD",
	@"MASTER_PORT",
	@"MASTER_SERVER_ID",
	@"MASTER_SSL",
	@"MASTER_SSL_CA",
	@"MASTER_SSL_CAPATH",
	@"MASTER_SSL_CERT",
	@"MASTER_SSL_CIPHER",
	@"MASTER_SSL_KEY",
	@"MASTER_USER",
	@"MATCH",
	@"MAXVALUE",
	@"MAX_CONNECTIONS_PER_HOUR",
	@"MAX_QUERIES_PER_HOUR",
	@"MAX_ROWS",
	@"MAX_SIZE",
	@"MAX_UPDATES_PER_HOUR",
	@"MAX_USER_CONNECTIONS",
	@"MEDIUM",
	@"MEDIUMBLOB",
	@"MEDIUMINT",
	@"MEDIUMTEXT",
	@"MEMORY",
	@"MERGE",
	@"MICROSECOND",
	@"MIDDLEINT",
	@"MIGRATE",
	@"MINUTE",
	@"MINUTE_MICROSECOND",
	@"MINUTE_SECOND",
	@"MIN_ROWS",
	@"MOD",
	@"MODE",
	@"MODIFIES",
	@"MODIFY",
	@"MONTH",
	@"MULTILINESTRING",
	@"MULTIPOINT",
	@"MULTIPOLYGON",
	@"MUTEX",
	@"NAME",
	@"NAMES",
	@"NATIONAL",
	@"NATURAL",
	@"NCHAR",
	@"NDB",
	@"NDBCLUSTER",
	@"NEW",
	@"NEXT",
	@"NO",
	@"NODEGROUP",
	@"NONE",
	@"NOT",
	@"NO_WAIT",
	@"NO_WRITE_TO_BINLOG",
	@"NULL",
	@"NUMERIC",
	@"NVARCHAR",
	@"OFFSET",
	@"OLD_PASSWORD",
	@"ON",
	@"ONE",
	@"ONE_SHOT",
	@"OPEN",
	@"OPTIMIZE",
	@"OPTIMIZE TABLE",
	@"OPTION",
	@"OPTIONALLY",
	@"OPTIONALLY ENCLOSED BY",
	@"OPTIONS",
	@"OR",
	@"ORDER",
	@"ORDER BY",
	@"OUT",
	@"OUTER",
	@"OUTFILE",
	@"PACK_KEYS",
	@"PARSER",
	@"PARTIAL",
	@"PARTITION",
	@"PARTITIONING",
	@"PARTITIONS",
	@"PASSWORD",
	@"PHASE",
	@"PLUGIN",
	@"PLUGINS",
	@"POINT",
	@"POLYGON",
	@"PRECISION",
	@"PREPARE",
	@"PRESERVE",
	@"PREV",
	@"PRIMARY",
	@"PRIMARY KEY",
	@"PRIVILEGES",
	@"PROCEDURE",
	@"PROCEDURE ANALYSE",
	@"PROCESS",
	@"PROCESSLIST",
	@"PURGE",
	@"QUARTER",
	@"QUERY",
	@"QUICK",
	@"RANGE",
	@"READ",
	@"READS",
	@"READ_ONLY",
	@"READ_WRITE",
	@"REAL",
	@"REBUILD",
	@"RECOVER",
	@"REDOFILE",
	@"REDO_BUFFER_SIZE",
	@"REDUNDANT",
	@"REFERENCES",
	@"REGEXP",
	@"RELAY_LOG_FILE",
	@"RELAY_LOG_POS",
	@"RELAY_THREAD",
	@"RELEASE",
	@"RELOAD",
	@"REMOVE",
	@"RENAME",
	@"RENAME DATABASE",
	@"RENAME TABLE",
	@"REORGANIZE",
	@"REPAIR",
	@"REPAIR TABLE",
	@"REPEAT",
	@"REPEATABLE",
	@"REPLACE",
	@"REPLICATION",
	@"REQUIRE",
	@"RESET",
	@"RESET MASTER",
	@"RESTORE",
	@"RESTORE TABLE",
	@"RESTRICT",
	@"RESUME",
	@"RETURN",
	@"RETURNS",
	@"REVOKE",
	@"RIGHT",
	@"RLIKE",
	@"ROLLBACK",
	@"ROLLUP",
	@"ROUTINE",
	@"ROW",
	@"ROWS",
	@"ROWS IDENTIFIED BY"
	@"ROW_FORMAT",
	@"RTREE",
	@"SAVEPOINT",
	@"SCHEDULE",
	@"SCHEDULER",
	@"SCHEMA",
	@"SCHEMAS",
	@"SECOND",
	@"SECOND_MICROSECOND",
	@"SECURITY",
	@"SELECT",
	@"SELECT DISTINCT",
	@"SENSITIVE",
	@"SEPARATOR",
	@"SERIAL",
	@"SERIALIZABLE",
	@"SESSION",
	@"SET",
	@"SET GLOBAL",
	@"SET NAMES",
	@"SET PASSWORD",
	@"SHARE",
	@"SHOW",
	@"SHOW BINARY LOGS",
	@"SHOW BINLOG EVENTS",
	@"SHOW CHARACTER SET",
	@"SHOW COLLATION",
	@"SHOW COLUMNS",
	@"SHOW CONTRIBUTORS",
	@"SHOW CREATE DATABASE",
	@"SHOW CREATE EVENT",
	@"SHOW CREATE FUNCTION",
	@"SHOW CREATE PROCEDURE",
	@"SHOW CREATE SCHEMA",
	@"SHOW CREATE TABLE",
	@"SHOW CREATE TRIGGERS",
	@"SHOW CREATE VIEW",
	@"SHOW DATABASES",
	@"SHOW ENGINE",
	@"SHOW ENGINES",
	@"SHOW ERRORS",
	@"SHOW EVENTS",
	@"SHOW FIELDS",
	@"SHOW FULL PROCESSLIST",
	@"SHOW FUNCTION CODE",
	@"SHOW FUNCTION STATUS",
	@"SHOW GRANTS",
	@"SHOW INDEX",
	@"SHOW INNODB STATUS",
	@"SHOW KEYS",
	@"SHOW MASTER LOGS",
	@"SHOW MASTER STATUS",
	@"SHOW OPEN TABLES",
	@"SHOW PLUGINS",
	@"SHOW PRIVILEGES",
	@"SHOW PROCEDURE CODE",
	@"SHOW PROCEDURE STATUS",
	@"SHOW PROFILE",
	@"SHOW PROFILES",
	@"SHOW PROCESSLIST",
	@"SHOW SCHEDULER STATUS",
	@"SHOW SCHEMAS",
	@"SHOW SLAVE HOSTS",
	@"SHOW SLAVE STATUS",
	@"SHOW STATUS",
	@"SHOW STORAGE ENGINES",
	@"SHOW TABLE STATUS",
	@"SHOW TABLE TYPES",
	@"SHOW TABLES",
	@"SHOW TRIGGERS",
	@"SHOW VARIABLES",
	@"SHOW WARNINGS",
	@"SHUTDOWN",
	@"SIGNED",
	@"SIMPLE",
	@"SLAVE",
	@"SMALLINT",
	@"SNAPSHOT",
	@"SOME",
	@"SONAME",
	@"SOUNDS",
	@"SPATIAL",
	@"SPECIFIC",
	@"SQL_AUTO_IS_NULL",
	@"SQL_BIG_RESULT",
	@"SQL_BIG_SELECTS",
	@"SQL_BIG_TABLES",
	@"SQL_BUFFER_RESULT",
	@"SQL_CACHE",
	@"SQL_CALC_FOUND_ROWS",
	@"SQL_LOG_BIN",
	@"SQL_LOG_OFF",
	@"SQL_LOG_UPDATE",
	@"SQL_LOW_PRIORITY_UPDATES",
	@"SQL_MAX_JOIN_SIZE",
	@"SQL_NO_CACHE",
	@"SQL_QUOTE_SHOW_CREATE",
	@"SQL_SAFE_UPDATES",
	@"SQL_SELECT_LIMIT",
	@"SQL_SLAVE_SKIP_COUNTER",
	@"SQL_SMALL_RESULT",
	@"SQL_THREAD",
	@"SQL_TSI_DAY",
	@"SQL_TSI_FRAC_SECOND",
	@"SQL_TSI_HOUR",
	@"SQL_TSI_MINUTE",
	@"SQL_TSI_MONTH",
	@"SQL_TSI_QUARTER",
	@"SQL_TSI_SECOND",
	@"SQL_TSI_WEEK",
	@"SQL_TSI_YEAR",
	@"SQL_WARNINGS",
	@"SSL",
	@"START",
	@"START TRANSACTION",
	@"STARTING",
	@"STARTS",
	@"STATUS",
	@"STOP",
	@"STORAGE",
	@"STRAIGHT_JOIN",
	@"STRING",
	@"SUBJECT",
	@"SUBPARTITION",
	@"SUBPARTITIONS",
	@"SUPER",
	@"SUSPEND",
	@"TABLE",
	@"TABLES",
	@"TABLESPACE",
	@"TEMPORARY",
	@"TEMPTABLE",
	@"TERMINATED",
	@"TEXT",
	@"THAN",
	@"THEN",
	@"TIME",
	@"TIMESTAMP",
	@"TIMESTAMPADD",
	@"TIMESTAMPDIFF",
	@"TINYBLOB",
	@"TINYINT",
	@"TINYTEXT",
	@"TO",
	@"TRAILING",
	@"TRANSACTION",
	@"TRIGGER",
	@"TRIGGERS",
	@"TRUE",
	@"TRUNCATE",
	@"TYPE",
	@"TYPES",
	@"UNCOMMITTED",
	@"UNDEFINED",
	@"UNDO",
	@"UNDOFILE",
	@"UNDO_BUFFER_SIZE",
	@"UNICODE",
	@"UNINSTALL",
	@"UNINSTALL PLUGIN",
	@"UNION",
	@"UNIQUE",
	@"UNKNOWN",
	@"UNLOCK",
	@"UNLOCK TABLES",
	@"UNSIGNED",
	@"UNTIL",
	@"UPDATE",
	@"UPGRADE",
	@"USAGE",
	@"USE",
	@"USER",
	@"USER_RESOURCES",
	@"USE_FRM",
	@"USING",
	@"UTC_DATE",
	@"UTC_TIME",
	@"UTC_TIMESTAMP",
	@"VALUE",
	@"VALUES",
	@"VARBINARY",
	@"VARCHAR",
	@"VARCHARACTER",
	@"VARIABLES",
	@"VARYING",
	@"VIEW",
	@"WAIT",
	@"WARNINGS",
	@"WEEK",
	@"WHEN",
	@"WHERE",
	@"WHILE",
	@"WITH",
	@"WITH CONSISTENT SNAPSHOT",
	@"WORK",
	@"WRITE",
	@"X509",
	@"XA",
	@"XOR",
	@"YEAR",
	@"YEAR_MONTH",
	@"ZEROFILL",

	nil];
}

/*
 * List of fucntions for autocompletion. If you add a keyword here,
 * it should also be added to the flex file SPEditorTokens.l
 */
-(NSArray *)functions
{
	return [NSArray arrayWithObjects:
	@"ABS",
	@"ACOS",
	@"ADDDATE",
	@"ADDTIME",
	@"AES_DECRYPT",
	@"AES_ENCRYPT",
	@"AREA",
	@"ASBINARY",
	@"ASCII",
	@"ASIN",
	@"ASTEXT",
	@"ATAN",
	@"ATAN2",
	@"AVG",
	@"BDMPOLYFROMTEXT",
	@"BDMPOLYFROMWKB",
	@"BDPOLYFROMTEXT",
	@"BDPOLYFROMWKB",
	@"BENCHMARK",
	@"BIN",
	@"BIT_AND",
	@"BIT_COUNT",
	@"BIT_LENGTH",
	@"BIT_OR",
	@"BIT_XOR",
	@"BOUNDARY",
	@"BUFFER",
	@"CAST",
	@"CEIL",
	@"CEILING",
	@"CENTROID",
	@"CHAR",
	@"CHARACTER_LENGTH",
	@"CHARSET",
	@"CHAR_LENGTH",
	@"COALESCE",
	@"COERCIBILITY",
	@"COLLATION",
	@"COMPRESS",
	@"CONCAT",
	@"CONCAT_WS",
	@"CONNECTION_ID",
	@"CONTAINS",
	@"CONV",
	@"CONVERT",
	@"CONVERT_TZ",
	@"CONVEXHULL",
	@"COS",
	@"COT",
	@"COUNT",
	@"COUNT(*)",
	@"CRC32",
	@"CROSSES",
	@"CURDATE",
	@"CURRENT_DATE",
	@"CURRENT_TIME",
	@"CURRENT_TIMESTAMP",
	@"CURRENT_USER",
	@"CURTIME",
	@"DATABASE",
	@"DATE",
	@"DATEDIFF",
	@"DATE_ADD",
	@"DATE_DIFF",
	@"DATE_FORMAT",
	@"DATE_SUB",
	@"DAY",
	@"DAYNAME",
	@"DAYOFMONTH",
	@"DAYOFWEEK",
	@"DAYOFYEAR",
	@"DECODE",
	@"DEFAULT",
	@"DEGREES",
	@"DES_DECRYPT",
	@"DES_ENCRYPT",
	@"DIFFERENCE",
	@"DIMENSION",
	@"DISJOINT",
	@"DISTANCE",
	@"ELT",
	@"ENCODE",
	@"ENCRYPT",
	@"ENDPOINT",
	@"ENVELOPE",
	@"EQUALS",
	@"EXP",
	@"EXPORT_SET",
	@"EXTERIORRING",
	@"EXTRACT",
	@"EXTRACTVALUE",
	@"FIELD",
	@"FIND_IN_SET",
	@"FLOOR",
	@"FORMAT",
	@"FOUND_ROWS",
	@"FROM_DAYS",
	@"FROM_UNIXTIME",
	@"GEOMCOLLFROMTEXT",
	@"GEOMCOLLFROMWKB",
	@"GEOMETRYCOLLECTION",
	@"GEOMETRYCOLLECTIONFROMTEXT",
	@"GEOMETRYCOLLECTIONFROMWKB",
	@"GEOMETRYFROMTEXT",
	@"GEOMETRYFROMWKB",
	@"GEOMETRYN",
	@"GEOMETRYTYPE",
	@"GEOMFROMTEXT",
	@"GEOMFROMWKB",
	@"GET_FORMAT",
	@"GET_LOCK",
	@"GLENGTH",
	@"GREATEST",
	@"GROUP_CONCAT",
	@"GROUP_UNIQUE_USERS",
	@"HEX",
	@"HOUR",
	@"IF",
	@"IFNULL",
	@"INET_ATON",
	@"INET_NTOA",
	@"INSERT",
	@"INSERT_ID",
	@"INSTR",
	@"INTERIORRINGN",
	@"INTERSECTION",
	@"INTERSECTS",
	@"INTERVAL",
	@"ISCLOSED",
	@"ISEMPTY",
	@"ISNULL",
	@"ISRING",
	@"ISSIMPLE",
	@"IS_FREE_LOCK",
	@"IS_USED_LOCK",
	@"LAST_DAY",
	@"LAST_INSERT_ID",
	@"LCASE",
	@"LEAST",
	@"LEFT",
	@"LENGTH",
	@"LINEFROMTEXT",
	@"LINEFROMWKB",
	@"LINESTRING",
	@"LINESTRINGFROMTEXT",
	@"LINESTRINGFROMWKB",
	@"LN",
	@"LOAD_FILE",
	@"LOCALTIME",
	@"LOCALTIMESTAMP",
	@"LOCATE",
	@"LOG",
	@"LOG10",
	@"LOG2",
	@"LOWER",
	@"LPAD",
	@"LTRIM",
	@"MAKEDATE",
	@"MAKETIME",
	@"MAKE_SET",
	@"MASTER_POS_WAIT",
	@"MAX",
	@"MBRCONTAINS",
	@"MBRDISJOINT",
	@"MBREQUAL",
	@"MBRINTERSECTS",
	@"MBROVERLAPS",
	@"MBRTOUCHES",
	@"MBRWITHIN",
	@"MD5",
	@"MICROSECOND",
	@"MID",
	@"MIN",
	@"MINUTE",
	@"MLINEFROMTEXT",
	@"MLINEFROMWKB",
	@"MOD",
	@"MONTH",
	@"MONTHNAME",
	@"NOW",
	@"MPOINTFROMTEXT",
	@"MPOINTFROMWKB",
	@"MPOLYFROMTEXT",
	@"MPOLYFROMWKB",
	@"MULTILINESTRING",
	@"MULTILINESTRINGFROMTEXT",
	@"MULTILINESTRINGFROMWKB",
	@"MULTIPOINT",
	@"MULTIPOINTFROMTEXT",
	@"MULTIPOINTFROMWKB",
	@"MULTIPOLYGON",
	@"MULTIPOLYGONFROMTEXT",
	@"MULTIPOLYGONFROMWKB",
	@"NAME_CONST",
	@"NOW",
	@"NULLIF",
	@"NUMGEOMETRIES",
	@"NUMINTERIORRINGS",
	@"NUMPOINTS",
	@"OCT",
	@"OCTET_LENGTH",
	@"OLD_PASSWORD",
	@"ORD",
	@"OVERLAPS",
	@"PASSWORD",
	@"PERIOD_ADD",
	@"PERIOD_DIFF",
	@"PI",
	@"POINT",
	@"POINTFROMTEXT",
	@"POINTFROMWKB",
	@"POINTN",
	@"POINTONSURFACE",
	@"POLYFROMTEXT",
	@"POLYFROMWKB",
	@"POLYGON",
	@"POLYGONFROMTEXT",
	@"POLYGONFROMWKB",
	@"POSITION",
	@"POW",
	@"POWER",
	@"QUARTER",
	@"QUOTE",
	@"RADIANS",
	@"RAND",
	@"RELATED",
	@"RELEASE_LOCK",
	@"REPEAT",
	@"REPLACE",
	@"REVERSE",
	@"RIGHT",
	@"ROUND",
	@"ROW_COUNT",
	@"RPAD",
	@"RTRIM",
	@"SCHEMA",
	@"SECOND",
	@"SEC_TO_TIME",
	@"SESSION_USER",
	@"SHA",
	@"SHA1",
	@"SIGN",
	@"SIN",
	@"SLEEP",
	@"SOUNDEX",
	@"SPACE",
	@"SQRT",
	@"SRID",
	@"STARTPOINT",
	@"STD",
	@"STDDEV",
	@"STDDEV_POP",
	@"STDDEV_SAMP",
	@"STRCMP",
	@"STR_TO_DATE",
	@"SUBDATE",
	@"SUBSTR",
	@"SUBSTRING",
	@"SUBSTRING_INDEX",
	@"SUBTIME",
	@"SUM",
	@"SYMDIFFERENCE",
	@"SYSDATE",
	@"SYSTEM_USER",
	@"TAN",
	@"TIME",
	@"TIMEDIFF",
	@"TIMESTAMP",
	@"TIMESTAMPADD",
	@"TIMESTAMPDIFF",
	@"TIME_FORMAT",
	@"TIME_TO_SEC",
	@"TOUCHES",
	@"TO_DAYS",
	@"TRIM",
	@"TRUNCATE",
	@"UCASE",
	@"UNCOMPRESS",
	@"UNCOMPRESSED_LENGTH",
	@"UNHEX",
	@"UNIQUE_USERS",
	@"UNIX_TIMESTAMP",
	@"UPDATEXML",
	@"UPPER",
	@"USER",
	@"UTC_DATE",
	@"UTC_TIME",
	@"UTC_TIMESTAMP",
	@"UUID",
	@"VARIANCE",
	@"VAR_POP",
	@"VAR_SAMP",
	@"VERSION",
	@"WEEK",
	@"WEEKDAY",
	@"WEEKOFYEAR",
	@"WITHIN",
	@"YEAR",
	@"YEARWEEK",

	nil];
}


/*
 * Set whether this text view should apply the indentation on the current line to new lines.
 */
- (void)setAutoindent:(BOOL)enableAutoindent
{
	autoindentEnabled = enableAutoindent;
}

/*
 * Retrieve whether this text view applies indentation on the current line to new lines.
 */
- (BOOL)autoindent
{
	return autoindentEnabled;
}

/*
 * Set whether this text view should not autoindent when the Enter key is used, as opposed
 * to the return key.  Also catches function-return.
 */
- (void)setAutoindentIgnoresEnter:(BOOL)enableAutoindentIgnoresEnter
{
	autoindentIgnoresEnter = enableAutoindentIgnoresEnter;
}

/*
 * Retrieve whether this text view should not autoindent when the Enter key is used.
 */
- (BOOL)autoindentIgnoresEnter
{
	return autoindentIgnoresEnter;
}

/*
 * Set whether this text view should automatically create the matching closing char for ", ', ` and ( chars.
 */
- (void)setAutopair:(BOOL)enableAutopair
{
	autopairEnabled = enableAutopair;
}

/*
 * Retrieve whether this text view automatically creates the matching closing char for ", ', ` and ( chars.
 */
- (BOOL)autopair
{
	return autopairEnabled;
}

/*
 * Set whether MySQL Help should be automatically invoked while typing.
 */
- (void)setAutohelp:(BOOL)enableAutohelp
{
	autohelpEnabled = enableAutohelp;
}

/*
 * Retrieve whether MySQL Help should be automatically invoked while typing.
 */
- (BOOL)autohelp
{
	return autohelpEnabled;
}

/*
 * Set whether SQL keywords should be automatically uppercased.
 */
- (void)setAutouppercaseKeywords:(BOOL)enableAutouppercaseKeywords
{
	autouppercaseKeywordsEnabled = enableAutouppercaseKeywords;
}

/*
 * Retrieve whether SQL keywords should be automatically uppercased.
 */
- (BOOL)autouppercaseKeywords
{
	return autouppercaseKeywordsEnabled;
}


/*
 * If enabled it shows the MySQL Help for the current word (not inside quotes) or for the selection
 * after an adjustable delay if the textView is idle, i.e. no user interaction.
 */
- (void)autoHelp
{

	if(![prefs boolForKey:SPCustomQueryUpdateAutoHelp]) return;

	// If selection show Help for it
	if([self selectedRange].length)
	{
		[[[[self window] delegate] valueForKeyPath:@"customQueryInstance"] performSelector:@selector(showAutoHelpForCurrentWord:) withObject:self afterDelay:0.1];
		return;
	}
	// Otherwise show Help if caret is not inside quotes
	NSUInteger cursorPosition = [self selectedRange].location;
	if (cursorPosition >= [[self string] length]) cursorPosition--;
	if(cursorPosition > -1 && (![[self textStorage] attribute:kQuote atIndex:cursorPosition effectiveRange:nil]||[[self textStorage] attribute:kSQLkeyword atIndex:cursorPosition effectiveRange:nil]))
		[[[[self window] delegate] valueForKeyPath:@"customQueryInstance"] performSelector:@selector(showAutoHelpForCurrentWord:) withObject:self afterDelay:0.1];
	
}

/*
 * Syntax Highlighting.
 *  
 * (The main bottleneck is the [NSTextStorage addAttribute:value:range:] method - the parsing itself is really fast!)
 * Some sample code from Andrew Choi ( http://members.shaw.ca/akochoi-old/blog/2003/11-09/index.html#3 ) has been reused.
 */
- (void)doSyntaxHighlighting
{

	NSTextStorage *textStore = [self textStorage];
	NSString *selfstr        = [self string];
	NSUInteger strlength     = [selfstr length];

	NSRange textRange;
		
	// If text larger than SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING
	// do highlighting partly (max SP_SYNTAX_HILITE_BIAS*2).
	// The approach is to take the middle position of the current view port
	// and highlight only ±SP_SYNTAX_HILITE_BIAS of that middle position
	// considering of line starts resp. ends
	if(strlength > SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING)
	{

		// Cancel all doSyntaxHighlighting requests
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(doSyntaxHighlighting) 
									object:nil];

		// Get the text range currently displayed in the view port
		NSRect visibleRect = [[[self enclosingScrollView] contentView] documentVisibleRect];
		NSRange visibleRange = [[self layoutManager] glyphRangeForBoundingRectWithoutAdditionalLayout:visibleRect inTextContainer:[self textContainer]];
		if(!visibleRange.length) return;

		// Take roughly the middle position in the current view port
		NSInteger curPos = visibleRange.location+(NSInteger)(visibleRange.length/2);

		// get the last line to parse due to SP_SYNTAX_HILITE_BIAS
		NSInteger end = curPos + SP_SYNTAX_HILITE_BIAS;
		if (end > strlength ) {
			end = strlength;
		} else {
			while(end < strlength) {
				if([selfstr characterAtIndex:end]=='\n')
					break;
				end++;
			}
		}

		// get the first line to parse due to SP_SYNTAX_HILITE_BIAS	
		NSInteger start = end - (SP_SYNTAX_HILITE_BIAS*2);
		if (start > 0)
			while(start>-1) {
				if([selfstr characterAtIndex:start]=='\n')
					break;
				start--;
			}
		else
			start = 0;

		textRange = NSMakeRange(start, end-start);
		// only to be sure that nothing went wrongly
		textRange = NSIntersectionRange(textRange, NSMakeRange(0, [textStore length])); 
		if (!textRange.length)
			return;
	} else {
		// If text size is less SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING
		// process syntax highlighting for the entire text view buffer
		textRange = NSMakeRange(0,strlength);
	}
	
	NSColor *tokenColor;
	
	NSColor *commentColor   = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorCommentColor]] retain];
	NSColor *quoteColor     = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorQuoteColor]] retain];
	NSColor *keywordColor   = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorSQLKeywordColor]] retain];
	NSColor *backtickColor  = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorBacktickColor]] retain];
	NSColor *numericColor   = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorNumericColor]] retain];
	NSColor *variableColor  = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorVariableColor]] retain];
	NSColor *textColor      = [[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorTextColor]] retain];
		
	BOOL autouppercaseKeywords = [prefs boolForKey:SPCustomQueryAutoUppercaseKeywords];

	NSUInteger tokenEnd, token;
	NSRange tokenRange;

	// first remove the old colors and kQuote
	[textStore removeAttribute:NSForegroundColorAttributeName range:textRange];
	// mainly for suppressing auto-pairing in 
	[textStore removeAttribute:kLEXToken range:textRange];

	// initialise flex
	yyuoffset = textRange.location; yyuleng = 0;
	yy_switch_to_buffer(yy_scan_string(NSStringUTF8String([selfstr substringWithRange:textRange])));

	// NO if lexer doesn't find a token to suppress auto-uppercasing
	// and continue earlier.
	BOOL allowToCheckForUpperCase;
	
	// now loop through all the tokens
	while (token=yylex()){

		allowToCheckForUpperCase = YES;
		
		switch (token) {
			case SPT_SINGLE_QUOTED_TEXT:
			case SPT_DOUBLE_QUOTED_TEXT:
			    tokenColor = quoteColor;
			    break;
			case SPT_BACKTICK_QUOTED_TEXT:
			    tokenColor = backtickColor;
			    break;
			case SPT_RESERVED_WORD:
			    tokenColor = keywordColor;
			    break;
			case SPT_NUMERIC:
				tokenColor = numericColor;
				break;
			case SPT_COMMENT:
			    tokenColor = commentColor;
			    break;
			case SPT_VARIABLE:
			    tokenColor = variableColor;
			    break;
			case SPT_WHITESPACE:
			    continue;
			    break;
			default:
			    tokenColor = textColor;
				allowToCheckForUpperCase = NO;
		}

		tokenRange = NSMakeRange(yyuoffset, yyuleng);

		// make sure that tokenRange is valid (and therefore within textRange)
		// otherwise a bug in the lex code could cause the the TextView to crash
		// NOTE Disabled for testing purposes for speed it up
		tokenRange = NSIntersectionRange(tokenRange, textRange);
		if (!tokenRange.length) continue;

		// If the current token is marked as SQL keyword, uppercase it if required.
		tokenEnd = tokenRange.location+tokenRange.length-1;
		// Check the end of the token
		if (allowToCheckForUpperCase && autouppercaseKeywords && !delBackwardsWasPressed
			&& [[textStore attribute:kSQLkeyword atIndex:tokenEnd effectiveRange:nil] isEqualToString:kValue])
			// check if next char is not a kSQLkeyword or current kSQLkeyword is at the end; 
			// if so then upper case keyword if not already done
			// @try catch() for catching valid index esp. after deleteBackward:
			{

				NSString* curTokenString = [selfstr substringWithRange:tokenRange];
				NSString* upperCaseCurTokenString = [curTokenString uppercaseString];
				BOOL doIt = NO;
				@try
				{
					doIt = ![[textStore attribute:kSQLkeyword atIndex:tokenEnd+1 effectiveRange:nil] isEqualToString:kValue];
				} @catch(id ae) { doIt = NO; }

				if(doIt && ![upperCaseCurTokenString isEqualToString:curTokenString])
				{
					// Register it for undo works only partly for now, at least the uppercased keyword will be selected
					[self shouldChangeTextInRange:tokenRange replacementString:curTokenString];
					[self replaceCharactersInRange:tokenRange withString:upperCaseCurTokenString];
				}
			}

		NSMutableAttributedStringAddAttributeValueRange(textStore, NSForegroundColorAttributeName, tokenColor, tokenRange);

		if(!allowToCheckForUpperCase) continue;

		// Add an attribute to be used in the auto-pairing (keyDown:)
		// to disable auto-pairing if caret is inside of any token found by lex.
		// For discussion: maybe change it later (only for quotes not keywords?)
		if(token < 6)
			NSMutableAttributedStringAddAttributeValueRange(textStore, kLEXToken, kLEXTokenValue, tokenRange);

		// Mark each SQL keyword for auto-uppercasing and do it for the next textStorageDidProcessEditing: event.
		// Performing it one token later allows words which start as reserved keywords to be entered.
		if(token == SPT_RESERVED_WORD)
			NSMutableAttributedStringAddAttributeValueRange(textStore, kSQLkeyword, kValue, tokenRange);

		// Add an attribute to be used to distinguish quotes from keywords etc.
		// used e.g. in completion suggestions
		else if(token < 4)
			NSMutableAttributedStringAddAttributeValueRange(textStore, kQuote, kQuoteValue, tokenRange);

		//distinguish backtick quoted word for completion
		else if(token == SPT_BACKTICK_QUOTED_TEXT)
			NSMutableAttributedStringAddAttributeValueRange(textStore, kBTQuote, kBTQuoteValue, tokenRange);

	}
	
	[commentColor release];
	[quoteColor release];
	[keywordColor release];
	[backtickColor release];
	[numericColor release];
	[variableColor release];
	[textColor release];

}


#pragma mark -
#pragma mark context menu

/*
 * Add a menu item to context menu for looking up mysql documentation.
 */
- (NSMenu *)menuForEvent:(NSEvent *)event 
{	
	// Set title of the menu item
	if([self selectedRange].length)
		showMySQLHelpFor = NSLocalizedString(@"MySQL Help for Selection", @"MySQL Help for Selection");
	else
		showMySQLHelpFor = NSLocalizedString(@"MySQL Help for Word", @"MySQL Help for Word");
	
	// Add the menu items for
	// - MySQL Help for Word/Selection
	// - Copy as RTF
	// - Select Active Query
	// if it doesn't yet exist
	NSMenu *menu = [[self class] defaultMenu];
	
	if ([[[self class] defaultMenu] itemWithTag:SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG] == nil)
	{
		[menu insertItem:[NSMenuItem separatorItem] atIndex:3];
		NSMenuItem *showMySQLHelpForMenuItem = [[NSMenuItem alloc] initWithTitle:showMySQLHelpFor action:@selector(showMySQLHelpForCurrentWord:) keyEquivalent:@"h"];
		[showMySQLHelpForMenuItem setTag:SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG];
		[showMySQLHelpForMenuItem setKeyEquivalentModifierMask:NSControlKeyMask];
		[menu insertItem:showMySQLHelpForMenuItem atIndex:4];
		[showMySQLHelpForMenuItem release];
	} else {
		[[menu itemWithTag:SP_CQ_SEARCH_IN_MYSQL_HELP_MENU_ITEM_TAG] setTitle:showMySQLHelpFor];
	}
	if ([[[self class] defaultMenu] itemWithTag:SP_CQ_COPY_AS_RTF_MENU_ITEM_TAG] == nil)
	{
		NSMenuItem *copyAsRTFMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy as RTF", @"Copy as RTF") action:@selector(copyAsRTF) keyEquivalent:@"c"];
		[copyAsRTFMenuItem setTag:SP_CQ_COPY_AS_RTF_MENU_ITEM_TAG];
		[copyAsRTFMenuItem setKeyEquivalentModifierMask:NSControlKeyMask];
		[menu insertItem:copyAsRTFMenuItem atIndex:2];
		[copyAsRTFMenuItem release];
	}
	if ([[[self class] defaultMenu] itemWithTag:SP_CQ_SELECT_CURRENT_QUERY_MENU_ITEM_TAG] == nil)
	{
		NSMenuItem *selectCurrentQueryMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Select Active Query", @"Select Active Query") action:@selector(selectCurrentQuery) keyEquivalent:@"y"];
		[selectCurrentQueryMenuItem setTag:SP_CQ_SELECT_CURRENT_QUERY_MENU_ITEM_TAG];
		[selectCurrentQueryMenuItem setKeyEquivalentModifierMask:NSControlKeyMask];
		[menu insertItem:selectCurrentQueryMenuItem atIndex:4];
		[selectCurrentQueryMenuItem release];
	}
	// Hide "Select Active Query" if self is not editable
	[[menu itemAtIndex:4] setHidden:![self isEditable]];
	
	if([[[self window] delegate] valueForKeyPath:@"customQueryInstance"]) {
		[[menu itemAtIndex:5] setHidden:NO];
		[[menu itemAtIndex:6] setHidden:NO];
	} else {
		[[menu itemAtIndex:5] setHidden:YES];
		[[menu itemAtIndex:6] setHidden:YES];
	}
	
    return menu;
}

/*
 * Disable the search in the MySQL help function when getRangeForCurrentWord returns zero length. 
 */
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem 
{	
	// Enable or disable the search in the MySQL help menu item depending on whether there is a 
	// selection and whether it is a reasonable length.
	if ([menuItem action] == @selector(showMySQLHelpForCurrentWord:)) {
		NSUInteger stringSize = [self getRangeForCurrentWord].length;
		return (stringSize || stringSize > 64);
	}
	// Enable Copy as RTF if something is selected
	if ([menuItem action] == @selector(copyAsRTF)) {
		return ([self selectedRange].length>0);
	}
	// Validate Select Active Query
	if ([menuItem action] == @selector(selectCurrentQuery)) {
		return ([self isEditable] && [[self delegate] isKindOfClass:[CustomQuery class]]);
	}
	// Disable "Copy with Column Names" and "Copy as SQL INSERT"
	// in the main menu
	if ( [menuItem tag] == MENU_EDIT_COPY_WITH_COLUMN
		|| [menuItem tag] == MENU_EDIT_COPY_AS_SQL ) {
		return NO;
	}
	
	return YES;
}


#pragma mark -
#pragma mark delegates

/*
 * Update colors by setting them in the Preference pane.
 */
- (void)changeColor:(id)sender
{
	[self setInsertionPointColor:[NSUnarchiver unarchiveObjectWithData:[prefs dataForKey:SPCustomQueryEditorCaretColor]]];
	// Remember the old selected range
	NSRange oldRange = [self selectedRange];
	// Invoke syntax highlighting
	[self setSelectedRange:NSMakeRange(oldRange.location,0)];
	[self insertText:@""];
	// Reset old selected range
	[self setSelectedRange:oldRange];
}

/*
 * Scrollview delegate after the textView's view port was changed.
 * Manily used to update the syntax highlighting for a large text size.
 */
- (void) boundsDidChangeNotification:(NSNotification *)notification
{
	// Invoke syntax highlighting if text view port was changed for large text
	if(startListeningToBoundChanges && [[self string] length] > SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING)
	{
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
									selector:@selector(doSyntaxHighlighting) 
									object:nil];
		
		if(![[self textStorage] changeInLength])
			[self performSelector:@selector(doSyntaxHighlighting) withObject:nil afterDelay:0.4];
	}

}

/*
 *  Performs syntax highlighting after a text change.
 */
- (void)textStorageDidProcessEditing:(NSNotification *)notification
{

	NSTextStorage *textStore = [notification object];

	//make sure that the notification is from the correct textStorage object
	if (textStore!=[self textStorage]) return;

	NSInteger editedMask = [textStore editedMask];

	// Start autohelp only if the user really changed the text (not e.g. for setting a background color)
	if([prefs boolForKey:SPCustomQueryUpdateAutoHelp] && editedMask != 1) {
		[self performSelector:@selector(autoHelp) withObject:nil afterDelay:[[[prefs valueForKey:SPCustomQueryAutoHelpDelay] retain] doubleValue]];
	}

	if([[self string] length] > SP_TEXT_SIZE_TRIGGER_FOR_PARTLY_PARSING)
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
								selector:@selector(doSyntaxHighlighting) 
								object:nil];

	// Do syntax highlighting only if the user really changed the text
	if(editedMask != 1) {

		if(snippetControlCounter > -1 && !snippetWasJustInserted) {
			NSInteger editStartPosition = [textStore editedRange].location;
			NSInteger changeInLength = [textStore changeInLength];
			NSInteger i;
			BOOL isCaretInsideASnippet = NO;
			for(i=0; i<=snippetControlCounter; i++) {
				if(editStartPosition >= snippetControlArray[i][0]
					&& editStartPosition <= snippetControlArray[i][0] + snippetControlArray[i][1]) {

					if(i!=snippetControlCounter)
						isCaretInsideASnippet = YES;
					snippetControlArray[i][1] += changeInLength;
					if(snippetControlArray[i][1] < 0) {
						snippetControlCounter = -1;
						break;
					}
				// Adjust start position of snippets after caret position
				} else if(editStartPosition < snippetControlArray[i][0]) {
					snippetControlArray[i][0] += changeInLength;
					if(snippetControlArray[i][1] < 0) {
						snippetControlCounter = -1;
						break;
					}
				}
			}
			if(!isCaretInsideASnippet)
				snippetControlCounter = -1;

		}

		[self doSyntaxHighlighting];

	}

	startListeningToBoundChanges = YES;

}

/*
 * Show only setable modes in the font panel
 */
- (NSUInteger)validModesForFontPanel:(NSFontPanel *)fontPanel
{
   return (NSFontPanelFaceModeMask | NSFontPanelSizeModeMask);
}

#pragma mark -
#pragma mark drag&drop

///////////////////////////
// Dragging methods
///////////////////////////

/*
 * Insert the content of a dragged file path or if ⌘ is pressed
 * while dragging insert the file path
 */
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];

	if ( [[pboard types] containsObject:NSFilenamesPboardType] && [[pboard types] containsObject:@"CorePasteboardFlavorType 0x54455854"])
		return [super performDragOperation:sender];

	if ( [[pboard types] containsObject:NSFilenamesPboardType] ) {
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

		// Only one file path is allowed
		if([files count] > 1) {
			NSLog(@"%@", NSLocalizedString(@"Only one dragged item allowed.",@"Only one dragged item allowed."));
			return YES;
		}

		NSString *filepath = [[pboard propertyListForType:NSFilenamesPboardType] objectAtIndex:0];
		// if (([filenamesAttributes fileHFSTypeCode] == 'clpt' && [filenamesAttributes fileHFSCreatorCode] == 'MACS') || [[filename pathExtension] isEqualToString:@"textClipping"] == YES) {
		// 	
		// }


		// Set the new insertion point
		NSPoint draggingLocation = [sender draggingLocation];
		draggingLocation = [self convertPoint:draggingLocation fromView:nil];
		NSUInteger characterIndex = [self characterIndexOfPoint:draggingLocation];
		[self setSelectedRange:NSMakeRange(characterIndex,0)];

		// Check if user pressed  ⌘ while dragging for inserting only the file path
		if([sender draggingSourceOperationMask] == 4)
		{
			[self insertText:filepath];
			return YES;
		}

		// Check size and NSFileType
		NSDictionary *attr = [[NSFileManager defaultManager] fileAttributesAtPath:filepath traverseLink:YES];
		if(attr)
		{
			NSNumber *filesize = [attr objectForKey:NSFileSize];
			NSString *filetype = [attr objectForKey:NSFileType];
			if(filetype == NSFileTypeRegular && filesize)
			{
				// Ask for confirmation if file content is larger than 1MB
				if([filesize unsignedLongValue] > 1000000)
				{
					NSAlert *alert = [[NSAlert alloc] init];
					[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button")];
					[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"cancel button")];
					[alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Do you really want to proceed with %.1f MB of data?", @"message of panel asking for confirmation for inserting large text from dragging action"),
						 [filesize unsignedLongValue]/1048576.0]];
					[alert setHelpAnchor:filepath];
					[alert setMessageText:NSLocalizedString(@"Warning",@"warning")];
					[alert setAlertStyle:NSWarningAlertStyle];
					[alert beginSheetModalForWindow:[self window] 
						modalDelegate:self 
						didEndSelector:@selector(dragAlertSheetDidEnd:returnCode:contextInfo:) 
						contextInfo:nil];
					[alert release];
					
				} else
					[self insertFileContentOfFile:filepath];
			}
		}
		return YES;
	} 

	return [super performDragOperation:sender];
}

/*
 * Confirmation sheetDidEnd method
 */
- (void)dragAlertSheetDidEnd:(NSAlert *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{

	[[sheet window] orderOut:nil];
	if ( returnCode == NSAlertFirstButtonReturn )
		[self insertFileContentOfFile:[sheet helpAnchor]];

}
/*
 * Convert a NSPoint, usually the mouse location, to
 * a character index of the text view.
 */
- (NSUInteger)characterIndexOfPoint:(NSPoint)aPoint
{
	NSUInteger glyphIndex;
	NSLayoutManager *layoutManager = [self layoutManager];
	CGFloat fraction;
	NSRange range;

	range = [layoutManager glyphRangeForTextContainer:[self textContainer]];
	glyphIndex = [layoutManager glyphIndexForPoint:aPoint
		inTextContainer:[self textContainer]
		fractionOfDistanceThroughGlyph:&fraction];
	if( fraction > 0.5 ) glyphIndex++;

	if( glyphIndex == NSMaxRange(range) )
		return  [[self textStorage] length];
	else
		return [layoutManager characterIndexForGlyphAtIndex:glyphIndex];

}

/*
 * Insert content of a plain text file for a given path.
 * In addition it tries to figure out the file's text encoding heuristically.
 */
- (void)insertFileContentOfFile:(NSString *)aPath
{
	
	NSError *err = nil;
	NSStringEncoding enc;
	NSString *content = nil;

	// Make usage of the UNIX command "file" to get an info
	// about file type and encoding.
	NSTask *task=[[NSTask alloc] init];
	NSPipe *pipe=[[NSPipe alloc] init];
	NSFileHandle *handle;
	NSString *result;
	[task setLaunchPath:@"/usr/bin/file"];
	[task setArguments:[NSArray arrayWithObjects:aPath, @"-Ib", nil]];
	[task setStandardOutput:pipe];
	handle=[pipe fileHandleForReading];
	[task launch];
	result=[[NSString alloc] initWithData:[handle readDataToEndOfFile]
		encoding:NSASCIIStringEncoding];

	[pipe release];
	[task release];

	// UTF16/32 files are detected as application/octet-stream resp. audio/mpeg
	if( [result hasPrefix:@"text/plain"] 
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:@"sql"] 
		|| [[[aPath pathExtension] lowercaseString] isEqualToString:@"txt"]
		|| [result hasPrefix:@"audio/mpeg"] 
		|| [result hasPrefix:@"application/octet-stream"]
	)
	{
		// if UTF16/32 cocoa will try to find the correct encoding
		if([result hasPrefix:@"application/octet-stream"] || [result hasPrefix:@"audio/mpeg"] || [result rangeOfString:@"utf-16"].length)
			enc = 0;
		else if([result rangeOfString:@"utf-8"].length)
			enc = NSUTF8StringEncoding;
		else if([result rangeOfString:@"iso-8859-1"].length)
			enc = NSISOLatin1StringEncoding;
		else if([result rangeOfString:@"us-ascii"].length)
			enc = NSASCIIStringEncoding;
		else 
			enc = 0;

		if(enc == 0) // cocoa tries to detect the encoding
			content = [NSString stringWithContentsOfFile:aPath usedEncoding:&enc error:&err];
		else
			content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];

		if(content)
		{
			[self insertText:content];
			[result release];
			// [self insertText:@""]; // Invoke keyword uppercasing
			return;
		}
		// If UNIX "file" failed try cocoa's encoding detection
		content = [NSString stringWithContentsOfFile:aPath encoding:enc error:&err];
		if(content)
		{
			[self insertText:content];
			[result release];
			// [self insertText:@""]; // Invoke keyword uppercasing
			return;
		}
	}
	
	[result release];

	NSLog(@"%@ ‘%@’.", NSLocalizedString(@"Couldn't read the file content of", @"Couldn't read the file content of"), aPath);
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[lineNumberView release];
	[super dealloc];
}

@end