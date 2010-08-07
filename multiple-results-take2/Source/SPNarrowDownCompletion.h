//
//  $Id: SPNarrowDownCompletion.h 744 2009-05-22 20:00:00Z bibiko $
//
//  SPNarrowDownCompletion.h
//  sequel-pro
//
//  Created by Hans-J. Bibiko on May 14, 2009.
//
//  This class is based on TextMate's TMDIncrementalPopUp implementation
//  (Dialog plugin) written by Joachim Mårtensson, Allan Odgaard, and H.-J. Bibiko.
//   see license: http://svn.textmate.org/trunk/LICENSE
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

#import <Cocoa/Cocoa.h>

@interface SPNarrowDownCompletion : NSWindow 
{
	NSArray* suggestions;
	NSMutableString* mutablePrefix;
	NSString* staticPrefix;
	NSString* currentDb;
	NSArray* filtered;
	NSTableView* theTableView;
	NSPoint caretPos;
	BOOL isAbove;
	BOOL closeMe;
	BOOL caseSensitive;
	BOOL dictMode;
	BOOL triggerMode;
	BOOL dbStructureMode;
	BOOL fuzzyMode;
	BOOL noFilterString;
	BOOL cursorMovedLeft;
	BOOL commaInsertionMode;
	BOOL autoCompletionMode;
	BOOL oneColumnMode;
	BOOL isQueryingDatabaseStructure;
	BOOL commonPrefixWasInsertedByAutoComplete;
	NSMutableString *originalFilterString;
	NSInteger backtickMode;
	NSFont *tableFont;
	NSRange theCharRange;
	NSRange theParseRange;
	NSString *theDbName;

	NSTimer *stateTimer;
	NSArray *syncArrowImages;
	NSInteger currentSyncImage;

	NSUInteger timeCounter;

	id theView;
	
	NSInteger maxWindowWidth;
	NSInteger spaceCounter;
	
	NSMutableCharacterSet* textualInputCharacters;

	NSUserDefaults *prefs;

}

- (id)initWithItems:(NSArray*)someSuggestions alreadyTyped:(NSString*)aUserString staticPrefix:(NSString*)aStaticPrefix 
	additionalWordCharacters:(NSString*)someAdditionalWordCharacters caseSensitive:(BOOL)isCaseSensitive 
	charRange:(NSRange)initRange parseRange:(NSRange)parseRange inView:(id)aView 
	dictMode:(BOOL)mode dbMode:(BOOL)theDbMode tabTriggerMode:(BOOL)tabTriggerMode fuzzySearch:(BOOL)fuzzySearch 
	backtickMode:(NSInteger)theBackTickMode withDbName:(NSString*)dbName withTableName:(NSString*)tableName 
	selectedDb:(NSString*)selectedDb caretMovedLeft:(BOOL)caretMovedLeft autoComplete:(BOOL)autoComplete oneColumn:(BOOL)oneColumn
	isQueryingDBStructure:(BOOL)isQueryingDBStructure;
- (void)setCaretPos:(NSPoint)aPos;
- (void)insert_text:(NSString* )aString;
- (void)insertCommonPrefix;
- (void)adjustWorkingRangeByDelta:(NSInteger)delta;

- (void)updateSyncArrowStatus;
- (void)reInvokeCompletion;


@end
