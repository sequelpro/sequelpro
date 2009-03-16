%{
#import "tokens.h"
int utf8strlen(const char *s);

#define YY_NO_UNPUT

int yyuoffset, yyuleng;
  
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlen(yytext); }
%}
%option noyywrap
%option case-insensitive
s		[ \t\n]+
word	[a-z_0-9]
nonword	[^a-z_0-9#]
%x comment
%%
\"([^"\\]|\\(.|\n))*\"?				{ return SPT_DOUBLE_QUOTED_TEXT;   } /* double quoted strings */
'([^'\\]|\\(.|\n))*'?				{ return SPT_SINGLE_QUOTED_TEXT;   } /* single quoted strings */
`[^`]*`?						{ return SPT_BACKTICK_QUOTED_TEXT; } /* identifier quoting    */
"/*"							{ BEGIN(comment); return SPT_COMMENT; }
<comment>[^*]* 				    { return SPT_COMMENT; }
<comment>"*"+                   { return SPT_COMMENT; }
<comment>"*"+"/" 				{ BEGIN(INITIAL); return SPT_COMMENT; }
							 
#[^\n]*\n?				        |									 
--[ \t][^\n]*\n?						{ return SPT_COMMENT;  }		     /* -- Comments           */
{s}								{ return SPT_OTHER;    } 								 /* ignore spaces         */
ADD                         	|
ALL                         	|
ALTER{s}TABLE               	|
ALTER{s}VIEW                	|
ALTER{s}SCHEMA              	|
ALTER{s}SCHEMA              	|
ALTER{s}FUNCTION            	|
ALTER{s}COLUMN              	|
ALTER{s}DATABASE            	|
ALTER{s}PROCEDURE           	|
ANALYZE                     	|
AND                         	|
ASC                         	|
ASENSITIVE                  	|
BEFORE                      	|
BETWEEN                     	|
BIGINT                      	|
BINARY                      	|
BLOB                        	|
BOTH                        	|
CALL                        	|
CASCADE                     	|
CASE                        	|
CHANGE                      	|
CHAR                        	|
CHARACTER                   	|
CHECK                       	|
COLLATE                     	|
COLUMN                      	|
COLUMNS                     	|
CONDITION                   	|
CONNECTION                  	|
CONSTRAINT                  	|
CONTINUE                    	|
CONVERT                     	|
CREATE{s}VIEW               	|
CREATE{s}INDEX              	|
CREATE{s}FUNCTION           	|
CREATE{s}DATABASE           	|
CREATE{s}PROCEDURE          	|
CREATE{s}SCHEMA             	|
CREATE{s}TRIGGER            	|
CREATE{s}TABLE              	|
CREATE{s}USER               	|
CROSS                       	|
CURRENT_DATE                	|
CURRENT_TIME                	|
CURRENT_TIMESTAMP           	|
CURRENT_USER                	|
CURSOR                      	|
DATABASE                    	|
DATABASES                   	|
DAY_HOUR                    	|
DAY_MICROSECOND             	|
DAY_MINUTE                  	|
DAY_SECOND                  	|
DEC                         	|
DECIMAL                     	|
DECLARE                     	|
DEFAULT                     	|
DELAYED                     	|
DELETE                      	|
DESC                        	|
DESCRIBE                    	|
DETERMINISTIC               	|
DISTINCT                    	|
DISTINCTROW                 	|
DIV                         	|
DOUBLE                      	|
DROP{s}TABLE                	|
DROP{s}TRIGGER              	|
DROP{s}VIEW                 	|
DROP{s}SCHEMA               	|
DROP{s}USER                 	|
DROP{s}PROCEDURE            	|
DROP{s}FUNCTION             	|
DROP{s}FOREIGN{s}KEY        	|
DROP{s}INDEX                	|
DROP{s}PREPARE              	|
DROP{s}PRIMARY{s}KEY        	|
DROP{s}DATABASE             	|
DUAL                        	|
EACH                        	|
ELSE                        	|
ELSEIF                      	|
ENCLOSED                    	|
ESCAPED                     	|
EXISTS                      	|
EXIT                        	|
EXPLAIN                     	|
FALSE                       	|
FETCH                       	|
FIELDS                      	|
FLOAT                       	|
FOR                         	|
FORCE                       	|
FOREIGN{s}KEY               	|
FOUND                       	|
FROM                        	|
FULLTEXT                    	|
GOTO                        	|
GRANT                       	|
GROUP                       	|
HAVING                      	|
HIGH_PRIORITY               	|
HOUR_MICROSECOND            	|
HOUR_MINUTE                 	|
HOUR_SECOND                 	|
IGNORE                      	|
INDEX                       	|
INFILE                      	|
INNER                       	|
INOUT                       	|
INSENSITIVE                 	|
INSERT                      	|
INT                         	|
INTEGER                     	|
INTERVAL                    	|
INTO                        	|
ITERATE                     	|
JOIN                        	|
KEY                         	|
KEYS                        	|
KILL                        	|
LEADING                     	|
LEAVE                       	|
LEFT                        	|
LIKE                        	|
LIMIT                       	|
LINES                       	|
LOAD                        	|
LOCALTIME                   	|
LOCALTIMESTAMP              	|
LOCK                        	|
LONG                        	|
LONGBLOB                    	|
LONGTEXT                    	|
LOOP                        	|
LOW_PRIORITY                	|
MATCH                       	|
MEDIUMBLOB                  	|
MEDIUMINT                   	|
MEDIUMTEXT                  	|
MIDDLEINT                   	|
MINUTE_MICROSECOND          	|
MINUTE_SECOND               	|
MOD                         	|
NATURAL                     	|
NOT                         	|
NO_WRITE_TO_BINLOG          	|
NULL                        	|
NUMERIC                     	|
ON                          	|
OPTIMIZE                    	|
OPTION                      	|
OPTIONALLY                  	|
ORDER                       	|
OUT                         	|
OUTER                       	|
OUTFILE                     	|
PRECISION                   	|
PRIMARY                     	|
PRIVILEGES                  	|
PROCEDURE                   	|
PURGE                       	|
READ                        	|
REAL                        	|
REFERENCES                  	|
REGEXP                      	|
RENAME                      	|
REPEAT                      	|
REPLACE                     	|
REQUIRE                     	|
RESTRICT                    	|
RETURN                      	|
REVOKE                      	|
RIGHT                       	|
RLIKE                       	|
SECOND_MICROSECOND          	|
SELECT                      	|
SENSITIVE                   	|
SEPARATOR                   	|
SET                         	|
SHOW{s}PROCEDURE{s}STATUS   	|
SHOW{s}PROCESSLIST          	|
SHOW{s}SCHEMAS              	|
SHOW{s}SLAVE{s}HOSTS        	|
SHOW{s}PRIVILEGES           	|
SHOW{s}OPEN{s}TABLES        	|
SHOW{s}MASTER{s}STATUS      	|
SHOW{s}SLAVE{s}STATUS       	|
SHOW{s}PLUGIN               	|
SHOW{s}STORAGE{s}ENGINES    	|
SHOW{s}VARIABLES            	|
SHOW{s}WARNINGS             	|
SHOW{s}TRIGGERS             	|
SHOW{s}TABLES               	|
SHOW{s}MASTER{s}LOGS        	|
SHOW{s}TABLE{s}STATUS       	|
SHOW{s}TABLE{s}TYPES        	|
SHOW{s}STATUS               	|
SHOW{s}INNODB{s}STATUS      	|
SHOW{s}CREATE{s}DATABASE    	|
SHOW{s}CREATE{s}FUNCTION    	|
SHOW{s}CREATE{s}PROCEDURE   	|
SHOW{s}CREATE{s}SCHEMA      	|
SHOW{s}COLUMNS              	|
SHOW{s}COLLATION            	|
SHOW{s}BINARY{s}LOGS        	|
SHOW{s}BINLOG{s}EVENTS      	|
SHOW{s}CHARACTER{s}SET      	|
SHOW{s}CREATE{s}TABLE       	|
SHOW{s}CREATE{s}VIEW        	|
SHOW{s}FUNCTION{s}STATUS    	|
SHOW{s}GRANTS               	|
SHOW{s}INDEX                	|
SHOW{s}FIELDS               	|
SHOW{s}ERRORS               	|
SHOW{s}DATABASES            	|
SHOW{s}ENGINE               	|
SHOW{s}ENGINES              	|
SHOW{s}KEYS                 	|
SMALLINT                    	|
SONAME                      	|
SPATIAL                     	|
SPECIFIC                    	|
SQL                         	|
SQLEXCEPTION                	|
SQLSTATE                    	|
SQLWARNING                  	|
SQL_BIG_RESULT              	|
SQL_CALC_FOUND_ROWS         	|
SQL_SMALL_RESULT            	|
SSL                         	|
STARTING                    	|
STRAIGHT_JOIN               	|
TABLE                       	|
TABLES                      	|
TERMINATED                  	|
THEN                        	|
TINYBLOB                    	|
TINYINT                     	|
TINYTEXT                    	|
TRAILING                    	|
TRIGGER                     	|
TRUE                        	|
UNDO                        	|
UNION                       	|
UNIQUE                      	|
UNLOCK                      	|
UNSIGNED                    	|
UPDATE                      	|
USAGE                       	|
USE                         	|
USING                       	|
UTC_DATE                    	|
UTC_TIME                    	|
UTC_TIMESTAMP               	|
VALUES                      	|
VARBINARY                   	|
VARCHAR                     	|
VARCHARACTER                	|
VARYING                     	|
WHEN                        	|
WHERE                       	|
WHILE                       	|
WITH                        	|
WRITE                       	|
XOR                         	|
YEAR_MONTH                  	|
ZEROFILL            			{ return SPT_RESERVED_WORD;        } /* all the mysql reserved words  */
{word}+							{ return SPT_OTHER;                } /* return any word  */
{nonword}						{ return SPT_OTHER;                } /* return anything else  */
                    			
<<EOF>>   						{
                                    BEGIN(INITIAL);
            						yy_delete_buffer(YY_CURRENT_BUFFER);
            						return 0;
          						}
%%

int utf8strlen(const char *s)
/*
This simple function calculates the length of an UTF8 string in characters (not bytes)
It's not especially fast, but it's easy to comprehend
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