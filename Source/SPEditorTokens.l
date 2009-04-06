%{

/*
 * SPEditorTokens.l - created by Jakob on 3/15/09 for Sequel Pro
 *
 * This is the lex file used for syntax coloring.
 * To add new keywords, just add a line where the other
 * keywords are and replace spaces with {s}
 *
 * If you're new to lex and interested what the code below does, I found
 * "The Lex And Yacc Page" at http://dinosaur.compilertools.net/ to be
 * very helpful. Keep in mind that Xcode actually uses flex, the GNU
 * version of lex. There's a very thorough Texinfo manual for flex
 * available. (type 'info flex' in the Terminal)
 */
 
#import "SPEditorTokens.h"
int utf8strlen(const char *s);
int yyuoffset, yyuleng;

#define YY_NO_UNPUT

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlen(yytext); }
%}
%option noyywrap
%option case-insensitive
s		[ \t\n]+
word	[a-z_0-9À-ﾟ]
nonword	[^a-z_0-9À-ﾟ#\n\t]
%x comment
%%
\"([^"\\]|\\(.|\n))*\"?			{ return SPT_DOUBLE_QUOTED_TEXT;   }      /* double quoted strings          */
'([^'\\]|\\(.|\n))*'?			{ return SPT_SINGLE_QUOTED_TEXT;   }      /* single quoted strings          */
`[^`]*`?						{ return SPT_BACKTICK_QUOTED_TEXT; }      /* identifier quoting             */

"/*"							{ BEGIN(comment); return SPT_COMMENT; }   /* beginning of a c style comment */
<comment>[^*]* 				    { return SPT_COMMENT; }                   /* anything except * in a c cmnt  */
<comment>"*"+                   { return SPT_COMMENT; }                   /* a range of *                   */
<comment>"*"+"/" 				{ BEGIN(INITIAL); return SPT_COMMENT; }   /* a range of * with trailing /   
                                                                             Thanks to John Dickinson for publishing 
                                                                             this method of parsing C comments on
                                                                             http://www.stillhq.com/pdfdb/000561/data.pdf
                                                                                                            */
                                                                                                            
#[^\n]*\n?				        |									      /* # Comments                     */
--[ \t][^\n]*\n?				{ return SPT_COMMENT;  }		          /* -- Comments                    */

{s}								{ return SPT_WHITESPACE;    }		      /* ignore spaces                  */
ADD                         	|
ACCESSIBLE                      |
ADD                             |
ALL                             |
ALTER                           |
ANALYZE                         |
AND                             |
AS                              |
ASC                             |
ASENSITIVE                      |
BEFORE                          |
BETWEEN                         |
BIGINT                          |
BINARY                          |
BLOB                            |
BOTH                            |
BY                              |
CALL                            |
CASCADE                         |
CASE                            |
CHANGE                          |
CHAR                            |
CHARACTER                       |
CHECK                           |
COLLATE                         |
COLUMN                          |
CONDITION                       |
CONSTRAINT                      |
CONTINUE                        |
CONVERT                         |
CREATE                          |
CROSS                           |
CURRENT_DATE                    |
CURRENT_TIME                    |
CURRENT_TIMESTAMP               |
CURRENT_USER                    |
CURSOR                          |
DATABASE                        |
DATABASES                       |
DAY_HOUR                        |
DAY_MICROSECOND                 |
DAY_MINUTE                      |
DAY_SECOND                      |
DEC                             |
DECIMAL                         |
DECLARE                         |
DEFAULT                         |
DELAYED                         |
DELETE                          |
DESC                            |
DESCRIBE                        |
DETERMINISTIC                   |
DISTINCT                        |
DISTINCTROW                     |
DIV                             |
DOUBLE                          |
DROP                            |
DUAL                            |
EACH                            |
ELSE                            |
ELSEIF                          |
ENCLOSED                        |
ESCAPED                         |
EXISTS                          |
EXIT                            |
EXPLAIN                         |
FALSE                           |
FETCH                           |
FLOAT                           |
FLOAT4                          |
FLOAT8                          |
FOR                             |
FORCE                           |
FOREIGN                         |
FROM                            |
FULLTEXT                        |
GRANT                           |
GROUP                           |
HAVING                          |
HIGH_PRIORITY                   |
HOUR_MICROSECOND                |
HOUR_MINUTE                     |
HOUR_SECOND                     |
IF                              |
IGNORE                          |
IN                              |
INDEX                           |
INFILE                          |
INNER                           |
INOUT                           |
INSENSITIVE                     |
INSERT                          |
INT                             |
INT1                            |
INT2                            |
INT3                            |
INT4                            |
INT8                            |
INTEGER                         |
INTERVAL                        |
INTO                            |
IS                              |
ITERATE                         |
JOIN                            |
KEY                             |
KEYS                            |
KILL                            |
LEADING                         |
LEAVE                           |
LEFT                            |
LIKE                            |
LIMIT                           |
LINEAR                          |
LINES                           |
LOAD                            |
LOCALTIME                       |
LOCALTIMESTAMP                  |
LOCK                            |
LONG                            |
LONGBLOB                        |
LONGTEXT                        |
LOOP                            |
LOW_PRIORITY                    |
MASTER_SSL_VERIFY_SERVER_CERT   |
MATCH                           |
MEDIUMBLOB                      |
MEDIUMINT                       |
MEDIUMTEXT                      |
MIDDLEINT                       |
MINUTE_MICROSECOND              |
MINUTE_SECOND                   |
MOD                             |
MODIFIES                        |
NATURAL                         |
NOT                             |
NO_WRITE_TO_BINLOG              |
NULL                            |
NUMERIC                         |
ON                              |
OPTIMIZE                        |
OPTION                          |
OPTIONALLY                      |
OR                              |
ORDER                           |
OUT                             |
OUTER                           |
OUTFILE                         |
PRECISION                       |
PRIMARY                         |
PROCEDURE                       |
PURGE                           |
RANGE                           |
READ                            |
READS                           |
READ_WRITE                      |
REAL                            |
REFERENCES                      |
REGEXP                          |
RELEASE                         |
RENAME                          |
REPEAT                          |
REPLACE                         |
REQUIRE                         |
RESTRICT                        |
RETURN                          |
REVOKE                          |
RIGHT                           |
RLIKE                           |
SCHEMA                          |
SCHEMAS                         |
SECOND_MICROSECOND              |
SELECT                          |
SENSITIVE                       |
SEPARATOR                       |
SET                             |
SHOW                            |
SMALLINT                        |
SPATIAL                         |
SPECIFIC                        |
SQL                             |
SQLEXCEPTION                    |
SQLSTATE                        |
SQLWARNING                      |
SQL_BIG_RESULT                  |
SQL_CALC_FOUND_ROWS             |
SQL_SMALL_RESULT                |
SSL                             |
STARTING                        |
STRAIGHT_JOIN                   |
TABLE                           |
TERMINATED                      |
THEN                            |
TINYBLOB                        |
TINYINT                         |
TINYTEXT                        |
TO                              |
TRAILING                        |
TRIGGER                         |
TRUE                            |
UNDO                            |
UNION                           |
UNIQUE                          |
UNLOCK                          |
UNSIGNED                        |
UPDATE                          |
USAGE                           |
USE                             |
USING                           |
UTC_DATE                        |
UTC_TIME                        |
UTC_TIMESTAMP                   |
VALUES                          |
VARBINARY                       |
VARCHAR                         |
VARCHARACTER                    |
VARYING                         |
WHEN                            |
WHERE                           |
WHILE                           |
WITH                            |
WRITE                           |
XOR                             |
YEAR_MONTH                      |
ZEROFILL            			{ return SPT_RESERVED_WORD;        }   /* all the mysql reserved words  */
{word}+							{ return SPT_WORD;                 }   /* return any word               */
{nonword}						{ return SPT_OTHER;                }   /* return anything else          */
                    			
<<EOF>>   						{
                                    BEGIN(INITIAL);   /* make sure we return to initial state when finished! */
            						yy_delete_buffer(YY_CURRENT_BUFFER);
            						return 0;
          						}
%%

int utf8strlen(const char *s)
/*
 This simple function calculates the string length of an UTF-8 string
 It's fast enough and easy to comprehend
 
 Adapted from Kragen Javier Sitaker's my_strlen_utf8_c function as
 found on http://canonical.org/~kragen/strlen-utf8.html
 */
{
    int j=0;
	while (*s)
    {
		if ((*s & 0xC0) != 0x80) j++;
		s++;
	}
	return (j);
}