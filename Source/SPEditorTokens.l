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
int utf8strlen(const char * _s);
int yyuoffset, yyuleng;

#define YY_NO_UNPUT

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlen(yytext); }
%}
%option noyywrap
%option case-insensitive

s		[ \t\n]+
alpha	[a-z_\.À-ﾟ]
numeric	([+-]?(([0-9]+\.[0-9]+)|([0-9]*\.[0-9]+)|([0-9]+))(e[+-]?[0-9]+)?)
ops		"+"|"-"|"*"|"/"
word	[a-z_\.0-9À-ﾟ@]
variable	@{1,2}[a-z_\.0-9À-ﾟ$]+
nonword	[^a-z_0-9À-ﾟ#\n\t]
keyworda	(G(R(OUP{s}BY|ANT)|LOBAL)|B(Y|TREE|I(GINT|NARY)|OTH|E(TWEEN|FORE)|LOB|ACKUP{s}TABLE)|H(IGH_PRIORITY|OUR_(MI(NUTE|CROSECOND)|SECOND)|A(SH|NDLER|VING))|C(R(OSS|EATE)|H(ECK(SUM{s}TABLE)?|A(R(ACTER)?|NGE))|O(MMENT|N(STRAINT|CURRENT|TINUE|DITION|VERT)|L(UMN|LATE)|ALESCE{s}PARTITION)|UR(RENT_(TIME(STAMP)?|DATE|USER)|SOR)|LOSE|A(S(CADE|E)|CHE{s}INDEX|LL))|I(GNORE|MPORT{s}TABLESPACE|S|N(SE(RT|NSITIVE)|NER|T(1|2|8|3|O({s}(DUMP|OUT)FILE)?|4|E(RVAL|GER))?|OUT|DEX|FILE)?|TERATE|F)|D(ROP|I(S(CARD{s}TABLESPACE|TINCT(ROW)?|ABLE{s}KEYS)|V)|O(UBLE)?|UAL|E(SC(RIBE)?|C(IMAL|LARE)?|TERMINISTIC|FAULT|L(ETE|AYED))|A(Y_(MI(NUTE|CROSECOND)|SECOND|HOUR)|TABASE(S)?))|JOIN|E(X(I(STS|T)|PLAIN|ECUTE)|SCAPED{s}BY|N(CLOSED{s}BY|ABLE{s}KEYS)|LSE(IF)?|ACH)|K(ILL({s}(CONNECTION|QUERY))?|EY(S|_BLOCK_SIZE)?)|F(ROM|IRST|OR(CE|EIGN)?|ULLTEXT|ETCH|L(OAT(8|4)?|USH)|ALSE)|A(S(C|ENSITIVE)?|N(D|ALYZE)|CCESSIBLE|DD|UTO_INCREMENT|FTER|L(TER|L)))
keywordl	(R(TREE|IGHT|E(GEXP|MOVE{s}PARTITIONING|BUILD{s}PARTITION|S(T(RICT|ORE{s}TABLE)|ET)|NAME|TURN|ORGANIZE{s}PARTITION|P(EAT|LACE|AIR)|VOKE|QUIRE|FERENCES|LEASE|A(D(S|_WRITE)?|L))|LIKE|ANGE)|XOR|M(I(NUTE_(MICROSECOND|SECOND)|DDLEINT)|OD(IF(Y|IES))?|EDIUM(BLOB|TEXT|INT)|A(STER_SSL_VERIFY_SERVER_CERT|TCH))|S(MALLINT|SL|HOW({s}(E(NGINE(S)?|RRORS)|M(ASTER|UTEX)|BINLOG|GRANTS|INNODB|P(RIVILEGES|ROFILE(S)?|ROCEDURE{s}CODE)|SLAVE{s}(HOSTS|STATUS)|TRIGGERS|VARIABLES|WARNINGS))?|CHEMA(S)?|T(RAIGHT_JOIN|A(RTING{s}BY|TUS))|P(ECIFIC|ATIAL)|E(SSION|NSITIVE|COND_MICROSECOND|T({s}(PASSWORD|NAMES|ONE_SHOT))?|PARATOR|LECT)|QL(STATE|_(B(IG_RESULT|UFFER_RESULT)|SMALL_RESULT|NO_CACHE|CA(CHE|LC_FOUND_ROWS))|EXCEPTION|WARNING)?)|YEAR_MONTH|N(O(_WRITE_TO_BINLOG|T)|U(MERIC|LL)|EXT|ATURAL)|T(R(IGGER|U(NCATE|E)|AILING)|HEN|INY(BLOB|TEXT|INT)|O|ERMINATED{s}BY|ABLE)|ZEROFILL|O(R(DER{s}BY)?|N({s}(DUPLICATE{s}KEY{s}UPDATE)?|LINE)|UT(ER|FILE)?|P(TI(MIZE|ON(ALLY)?)|EN)|FF(SET|LINE))|U(S(ING|E|AGE)|N(SIGNED|I(ON|QUE)|DO|LOCK)|TC_(TIME(STAMP)?|DATE)|PDATE)|P(R(IMARY|OCEDURE|E(CISION|PARE|V))|URGE|ARTITION)|VA(R(BINARY|YING|CHAR(ACTER)?)|LUES)|QUICK|W(RITE|H(ILE|E(RE|N))|ITH({s}PARSER)?)|L(I(MIT|NE(S|AR)|KE)|O(GS|NG(BLOB|TEXT)?|C(K|AL(TIME(STAMP)?)?)|OP|W_PRIORITY|AD{s}(DATA|INDEX{s}INTO{s}CACHE))|E(FT|A(DING|VE))|AST))


%x comment
%x equation
%x varequation
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
                                                                                                            
#[^\n]*\n?			        |											/* # Comments                     */
--[ \t][^\n]*\n?			{ return SPT_COMMENT; }						/* -- Comments                    */

{variable}/{ops}			{ BEGIN(varequation); return SPT_VARIABLE; }/* SQL variables before operator*/
<varequation>{ops}			{ BEGIN(INITIAL); return SPT_OTHER; }
{variable}					{ return SPT_VARIABLE; }					/* SQL variables */

{numeric}/{ops}				{ BEGIN(equation); return SPT_NUMERIC; }	/* numeric before operator        */
<equation>{ops}				{ BEGIN(INITIAL); return SPT_OTHER; }		/* set operator after a numeric   */
{numeric}/{alpha}			{ return SPT_WORD; }						/* catch numeric followed by char */

{s}+						{ return SPT_WHITESPACE; }					/* ignore spaces                  */

{keyworda}					{ return SPT_RESERVED_WORD; }				/* all the mysql reserved words   */
{keywordl}					{ return SPT_RESERVED_WORD; }				/* all the mysql reserved words   */


{numeric}					{ return SPT_NUMERIC; }						/* single numeric value           */

{word}+						{ return SPT_WORD; }						/* return any word                */

{nonword}					{ return SPT_OTHER; }						/* return anything else           */


                    			
<<EOF>>   						{
                                    BEGIN(INITIAL);   /* make sure we return to initial state when finished! */
            						yy_delete_buffer(YY_CURRENT_BUFFER);
            						return 0;
          						}
%%

#define ONEMASK ((size_t)(-1) / 0xFF)
// adapted from http://www.daemonology.net/blog/2008-06-05-faster-utf8-strlen.html
int utf8strlen(const char * _s)
{
	const char * s;
	size_t count = 0;
	size_t u;
	unsigned char b;

	/* Handle any initial misaligned bytes. */
	for (s = _s; (uintptr_t)(s) & (sizeof(size_t) - 1); s++) {
		b = *s;

		/* Exit if we hit a zero byte. */
		if (b == '\0')
			goto done;

		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}

	/* Handle complete blocks. */
	for (; ; s += sizeof(size_t)) {
		/* Prefetch 256 bytes ahead. */
		__builtin_prefetch(&s[256], 0, 0);

		/* Grab 4 or 8 bytes of UTF-8 data. */
		u = *(size_t *)(s);

		/* Exit the loop if there are any zero bytes. */
		if ((u - ONEMASK) & (~u) & (ONEMASK * 0x80))
			break;

		/* Count bytes which are NOT the first byte of a character. */
		u = ((u & (ONEMASK * 0x80)) >> 7) & ((~u) >> 6);
		count += (u * ONEMASK) >> ((sizeof(size_t) - 1) * 8);
	}

	/* Take care of any left-over bytes. */
	for (; ; s++) {
		b = *s;

		/* Exit if we hit a zero byte. */
		if (b == '\0')
			break;

		/* Is this byte NOT the first byte of a character? */
		count += (b >> 7) & ((~b) >> 6);
	}

done:
	return ((s - _s) - count);
}

/* un-optimized keywords:
ACCESSIBLE
ADD
AFTER
ALL
ALTER
ANALYZE
AND
AS
ASC
ASENSITIVE
AUTO_INCREMENT
BACKUP{s}TABLE
BEFORE
BETWEEN
BIGINT
BINARY
BLOB
BOTH
BTREE
BY
CACHE{s}INDEX
CALL
CASCADE
CASE
CHANGE
CHAR
CHARACTER
CHECK
CHECKSUM{s}TABLE
CLOSE
COALESCE{s}PARTITION
COLLATE
COLUMN
COMMENT
CONCURRENT
CONDITION
CONSTRAINT
CONTINUE
CONVERT
CREATE
CROSS
CURRENT_DATE
CURRENT_TIME
CURRENT_TIMESTAMP
CURRENT_USER
CURSOR
DATABASE
DATABASES
DAY_HOUR
DAY_MICROSECOND
DAY_MINUTE
DAY_SECOND
DEC
DECIMAL
DECLARE
DEFAULT
DELAYED
DELETE
DESC
DESCRIBE
DETERMINISTIC
DISABLE{s}KEYS
DISCARD{s}TABLESPACE
DISTINCT
DISTINCTROW
DIV
DO
DOUBLE
DROP
DUAL
EACH
ELSE
ELSEIF
ENABLE{s}KEYS
ENCLOSED{s}BY
ESCAPED{s}BY
EXECUTE
EXISTS
EXIT
EXPLAIN
FALSE
FETCH
FIRST
FLOAT
FLOAT4
FLOAT8
FLUSH
FOR
FORCE
FOREIGN
FROM
FULLTEXT
GLOBAL
GRANT
GROUP{s}BY
HANDLER
HASH
HAVING
HIGH_PRIORITY
HOUR_MICROSECOND
HOUR_MINUTE
HOUR_SECOND
IF
IGNORE
IMPORT{s}TABLESPACE
IN
INDEX
INFILE
INNER
INOUT
INSENSITIVE
INSERT
INT
INT1
INT2
INT3
INT4
INT8
INTEGER
INTERVAL
INTO({s}(DUMP|OUT)FILE)?
IS
ITERATE
JOIN
KEY
KEYS
KEY_BLOCK_SIZE
KILL({s}(CONNECTION|QUERY))?
LAST
LEADING
LEAVE
LEFT
LIKE
LIMIT
LINEAR
LINES
LOAD{s}(DATA|INDEX{s}INTO{s}CACHE)
LOCAL
LOCALTIME
LOCALTIMESTAMP
LOCK
LOGS
LONG
LONGBLOB
LONGTEXT
LOOP
LOW_PRIORITY
MASTER_SSL_VERIFY_SERVER_CERT
MATCH
MEDIUMBLOB
MEDIUMINT
MEDIUMTEXT
MIDDLEINT
MINUTE_MICROSECOND
MINUTE_SECOND
MOD
MODIFIES
MODIFY
NATURAL
NEXT
NOT
NO_WRITE_TO_BINLOG
NULL
NUMERIC
OFFLINE
OFFSET
ONLINE
ON{s}(DUPLICATE{s}KEY{s}UPDATE)?
OPEN
OPTIMIZE
OPTION
OPTIONALLY
OR
ORDER{s}BY
OUT
OUTER
OUTFILE
PARTITION
PRECISION
PREPARE
PREV
PRIMARY
PROCEDURE
PURGE
QUICK
RANGE
READ
READS
READ_WRITE
REAL
REBUILD{s}PARTITION
REFERENCES
REGEXP
RELEASE
REMOVE{s}PARTITIONING
RENAME
REORGANIZE{s}PARTITION
REPAIR
REPEAT
REPLACE
REQUIRE
RESET
RESTORE{s}TABLE
RESTRICT
RETURN
REVOKE
RIGHT
RLIKE
RTREE
SCHEMA
SCHEMAS
SECOND_MICROSECOND
SELECT
SENSITIVE
SEPARATOR
SESSION
SET({s}(PASSWORD|NAMES|ONE_SHOT))?
SHOW({s}(E(NGINE(S)?|RRORS)|M(ASTER|UTEX)|BINLOG|GRANTS|INNODB|P(RIVILEGES|ROFILE(S)?|ROCEDURE{s}CODE)|SLAVE{s}(HOSTS|STATUS)|TRIGGERS|VARIABLES|WARNINGS))?
SMALLINT
SPATIAL
SPECIFIC
SQL
SQLEXCEPTION
SQLSTATE
SQLWARNING
SQL_BIG_RESULT
SQL_BUFFER_RESULT
SQL_CACHE
SQL_CALC_FOUND_ROWS
SQL_NO_CACHE
SQL_SMALL_RESULT
SSL
STARTING{s}BY
STATUS
STRAIGHT_JOIN
TABLE
TERMINATED{s}BY
THEN
TINYBLOB
TINYINT
TINYTEXT
TO
TRAILING
TRIGGER
TRUE
TRUNCATE
UNDO
UNION
UNIQUE
UNLOCK
UNSIGNED
UPDATE
USAGE
USE
USING
UTC_DATE
UTC_TIME
UTC_TIMESTAMP
VALUES
VARBINARY
VARCHAR
VARCHARACTER
VARYING
WHEN
WHERE
WHILE
WITH({s}PARSER)?
WRITE
XOR
YEAR_MONTH
ZEROFILL
*/
