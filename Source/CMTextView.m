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
//  Or mail to <lorenz@textor.ch>

#import "CMTextView.h"

@implementation CMTextView

- (NSArray *)completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(int *)index
{

	NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@" \t\r\n,()\"'`-!"];
	NSArray *textViewWords = [[self string] componentsSeparatedByCharactersInSet:separators];
	NSString *partialString = [[self string] substringWithRange:charRange];
	unsigned int partialLength = [partialString length];
	id tableNames = [[[[self window] delegate] valueForKeyPath:@"tablesListInstance"] valueForKey:@"tables"];
	//unsigned int options = NSCaseInsensitiveSearch | NSAnchoredSearch;
	//NSRange partialRange = NSMakeRange(0, partialLength);
	NSMutableArray *compl = [[NSMutableArray alloc] initWithCapacity:32];
	NSArray *possibleCompletions = [[tableNames arrayByAddingObjectsFromArray:[self keywords]]
									arrayByAddingObjectsFromArray:textViewWords];
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@ AND length > %d", partialString, partialLength];
	NSArray *matchingCompletions = [[possibleCompletions filteredArrayUsingPredicate:predicate] sortedArrayUsingSelector:@selector(compare:)];
	unsigned i, insindex;
	
	insindex = 0;
	for (i = 0; i < [matchingCompletions count]; i ++)
	{
		if ([partialString isEqualToString:[[matchingCompletions objectAtIndex:i] substringToIndex:partialLength]])
		{
			// Matches case --> Insert at beginning of completion list
			[compl insertObject:[matchingCompletions objectAtIndex:i] atIndex:insindex++];
		}
		else
		{
			// Not matching case --> Insert at end of completion list
			[compl addObject:[matchingCompletions objectAtIndex:i]];	
		}
	}
	
	return [compl autorelease];
}



-(NSArray *)keywords {
	return [NSArray arrayWithObjects:
	@"ADD",
	@"ALL",
	@"ALTER TABLE",
	@"ALTER VIEW",
	@"ALTER SCHEMA",
	@"ALTER SCHEMA",
	@"ALTER FUNCTION",
	@"ALTER COLUMN",
	@"ALTER DATABASE",
	@"ALTER PROCEDURE",
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
	@"CREATE VIEW",
	@"CREATE INDEX",
	@"CREATE FUNCTION",
	@"CREATE DATABASE",
	@"CREATE PROCEDURE",
	@"CREATE SCHEMA",
	@"CREATE TRIGGER",
	@"CREATE TABLE",
	@"CREATE USER",
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
	@"DROP TABLE",
	@"DROP TRIGGER",
	@"DROP VIEW",
	@"DROP SCHEMA",
	@"DROP USER",
	@"DROP PROCEDURE",
	@"DROP FUNCTION",
	@"DROP FOREIGN KEY",
	@"DROP INDEX",
	@"DROP PREPARE",
	@"DROP PRIMARY KEY",
	@"DROP DATABASE",
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
	@"FOREIGN KEY",
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
	@"SHOW PROCEDURE STATUS",
	@"SHOW PROCESSLIST",
	@"SHOW SCHEMAS",
	@"SHOW SLAVE HOSTS",
	@"SHOW PRIVILEGES",
	@"SHOW OPEN TABLES",
	@"SHOW MASTER STATUS",
	@"SHOW SLAVE STATUS",
	@"SHOW PLUGIN",
	@"SHOW STORAGE ENGINES",
	@"SHOW VARIABLES",
	@"SHOW WARNINGS",
	@"SHOW TRIGGERS",
	@"SHOW TABLES",
	@"SHOW MASTER LOGS",
	@"SHOW TABLE STATUS",
	@"SHOW TABLE TYPES",
	@"SHOW STATUS",
	@"SHOW INNODB STATUS",
	@"SHOW CREATE DATABASE",
	@"SHOW CREATE FUNCTION",
	@"SHOW CREATE PROCEDURE",
	@"SHOW CREATE SCHEMA",
	@"SHOW COLUMNS",
	@"SHOW COLLATION",
	@"SHOW BINARY LOGS",
	@"SHOW BINLOG EVENTS",
	@"SHOW CHARACTER SET",
	@"SHOW CREATE TABLE",
	@"SHOW CREATE VIEW",
	@"SHOW FUNCTION STATUS",
	@"SHOW GRANTS",
	@"SHOW INDEX",
	@"SHOW FIELDS",
	@"SHOW ERRORS",
	@"SHOW DATABASES",
	@"SHOW ENGINE",
	@"SHOW ENGINES",
	@"SHOW KEYS",
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
