//
//  CMTextView.m
//  CocoaMySQL
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
//  More info at <http://cocoamysql.sourceforge.net/>
//  Or mail to <lorenz@textor.ch>

#import "CMTextView.h"

@implementation CMTextView

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index
{

	NSString *partialString = [[self string] substringWithRange:charRange];
	unsigned int partialLength = [partialString length];
	unsigned int options = NSCaseInsensitiveSearch | NSAnchoredSearch;
	unsigned int i;
	NSRange partialRange = NSMakeRange(0, partialLength);
	NSMutableArray *compl = [[NSMutableArray alloc] initWithCapacity:32];
	NSArray *keywords = [self keywords];

	// Get the document
//	id tableDocument = [[[self window] windowController] document];
	id tableDocument = [[self window] delegate];

//NSLog(@"doc: %@", [[[self window] windowController] document]);

	// Get an array of table names for the current database
	id tableNames = [[tableDocument valueForKeyPath:@"tablesListInstance"] valueForKey:@"tables"];

	// Add matching table names to compl
	for (i = 0; i < [tableNames count]; i ++)
	{
		if ([[tableNames objectAtIndex:i] length] > partialLength)
		{
			NSRange range = [[tableNames objectAtIndex:i] rangeOfString:partialString
																options:options
																  range:partialRange];
			if (range.location != NSNotFound)
			{
				[compl addObject:[tableNames objectAtIndex:i]];
			}
		}
		
	}

	// Add matching keywords to compl
	for (i = 0; i < [keywords count]; i ++)
	{
		if ([[keywords objectAtIndex:i] length] > partialLength)
		{
			NSRange range = [[keywords objectAtIndex:i] rangeOfString:partialString
															  options:options
																range:partialRange];
			if (range.location != NSNotFound)
			{
				[compl addObject:[keywords objectAtIndex:i]];
			}
		}
	}

	return [compl autorelease];
}



-(NSArray *)keywords {
	return [NSArray arrayWithObjects:
	@"ADD",
	@"ALL",
	@"ALTER",
	@"ANALYZE",
	@"AND",
	@"ASC",
	@"ASENSITIVE",
	@"BEFORE",
	@"BETWEEN",
	@"BIGINT",
	@"BINARY",
	@"BLOB",
	@"BOTH",
	@"CALL",
	@"CASCADE",
	@"CASE",
	@"CHANGE",
	@"CHAR",
	@"CHARACTER",
	@"CHECK",
	@"COLLATE",
	@"COLUMN",
	@"COLUMNS",
	@"CONDITION",
	@"CONNECTION",
	@"CONSTRAINT",
	@"CONTINUE",
	@"CONVERT",
	@"CREATE",
	@"CROSS",
	@"CURRENT_DATE",
	@"CURRENT_TIME",
	@"CURRENT_TIMESTAMP",
	@"CURRENT_USER",
	@"CURSOR",
	@"DATABASE",
	@"DATABASES",
	@"DAY_HOUR",
	@"DAY_MICROSECOND",
	@"DAY_MINUTE",
	@"DAY_SECOND",
	@"DEC",
	@"DECIMAL",
	@"DECLARE",
	@"DEFAULT",
	@"DELAYED",
	@"DELETE",
	@"DESC",
	@"DESCRIBE",
	@"DETERMINISTIC",
	@"DISTINCT",
	@"DISTINCTROW",
	@"DIV",
	@"DOUBLE",
	@"DROP",
	@"DUAL",
	@"EACH",
	@"ELSE",
	@"ELSEIF",
	@"ENCLOSED",
	@"ESCAPED",
	@"EXISTS",
	@"EXIT",
	@"EXPLAIN",
	@"FALSE",
	@"FETCH",
	@"FIELDS",
	@"FLOAT",
	@"FOR",
	@"FORCE",
	@"FOREIGN",
	@"FOUND",
	@"FROM",
	@"FULLTEXT",
	@"GOTO",
	@"GRANT",
	@"GROUP",
	@"HAVING",
	@"HIGH_PRIORITY",
	@"HOUR_MICROSECOND",
	@"HOUR_MINUTE",
	@"HOUR_SECOND",
	@"IGNORE",
	@"INDEX",
	@"INFILE",
	@"INNER",
	@"INOUT",
	@"INSENSITIVE",
	@"INSERT",
	@"INT",
	@"INTEGER",
	@"INTERVAL",
	@"INTO",
	@"ITERATE",
	@"JOIN",
	@"KEY",
	@"KEYS",
	@"KILL",
	@"LEADING",
	@"LEAVE",
	@"LEFT",
	@"LIKE",
	@"LIMIT",
	@"LINES",
	@"LOAD",
	@"LOCALTIME",
	@"LOCALTIMESTAMP",
	@"LOCK",
	@"LONG",
	@"LONGBLOB",
	@"LONGTEXT",
	@"LOOP",
	@"LOW_PRIORITY",
	@"MATCH",
	@"MEDIUMBLOB",
	@"MEDIUMINT",
	@"MEDIUMTEXT",
	@"MIDDLEINT",
	@"MINUTE_MICROSECOND",
	@"MINUTE_SECOND",
	@"MOD",
	@"NATURAL",
	@"NOT",
	@"NO_WRITE_TO_BINLOG",
	@"NULL",
	@"NUMERIC",
	@"ON",
	@"OPTIMIZE",
	@"OPTION",
	@"OPTIONALLY",
	@"ORDER",
	@"OUT",
	@"OUTER",
	@"OUTFILE",
	@"PRECISION",
	@"PRIMARY",
	@"PRIVILEGES",
	@"PROCEDURE",
	@"PURGE",
	@"READ",
	@"REAL",
	@"REFERENCES",
	@"REGEXP",
	@"RENAME",
	@"REPEAT",
	@"REPLACE",
	@"REQUIRE",
	@"RESTRICT",
	@"RETURN",
	@"REVOKE",
	@"RIGHT",
	@"RLIKE",
	@"SECOND_MICROSECOND",
	@"SELECT",
	@"SENSITIVE",
	@"SEPARATOR",
	@"SET",
	@"SHOW",
	@"SMALLINT",
	@"SONAME",
	@"SPATIAL",
	@"SPECIFIC",
	@"SQL",
	@"SQLEXCEPTION",
	@"SQLSTATE",
	@"SQLWARNING",
	@"SQL_BIG_RESULT",
	@"SQL_CALC_FOUND_ROWS",
	@"SQL_SMALL_RESULT",
	@"SSL",
	@"STARTING",
	@"STRAIGHT_JOIN",
	@"TABLE",
	@"TABLES",
	@"TERMINATED",
	@"THEN",
	@"TINYBLOB",
	@"TINYINT",
	@"TINYTEXT",
	@"TRAILING",
	@"TRIGGER",
	@"TRUE",
	@"UNDO",
	@"UNION",
	@"UNIQUE",
	@"UNLOCK",
	@"UNSIGNED",
	@"UPDATE",
	@"USAGE",
	@"USE",
	@"USING",
	@"UTC_DATE",
	@"UTC_TIME",
	@"UTC_TIMESTAMP",
	@"VALUES",
	@"VARBINARY",
	@"VARCHAR",
	@"VARCHARACTER",
	@"VARYING",
	@"WHEN",
	@"WHERE",
	@"WHILE",
	@"WITH",
	@"WRITE",
	@"XOR",
	@"YEAR_MONTH",
	@"ZEROFILL",
	nil];
}

@end
