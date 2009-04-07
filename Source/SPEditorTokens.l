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
nonword	[^a-z_0-9À-ﾟ©#\n\t]
keyword	(R(IGHT|E(GEXP|STRICT|NAME|TURN|P(EAT|LACE)|VOKE|QUIRE|FERENCES|LEASE|A(D(S|_WRITE)?|L))|LIKE|ANGE)|GR(OUP{s}BY|ANT)|XOR|M(I(NUTE_(MICROSECOND|SECOND)|DDLEINT)|OD(IFIES)?|EDIUM(BLOB|TEXT|INT)|A(STER_SSL_VERIFY_SERVER_CERT|TCH))|B(Y|I(GINT|NARY)|OTH|E(TWEEN|FORE)|LOB)|S(MALLINT|SL|HOW|CHEMA(S)?|T(RAIGHT_JOIN|ARTING)|P(ECIFIC|ATIAL)|E(NSITIVE|COND_MICROSECOND|T|PARATOR|LECT)|QL(STATE|_(BIG_RESULT|SMALL_RESULT|CALC_FOUND_ROWS)|EXCEPTION|WARNING)?)|H(IGH_PRIORITY|OUR_(MI(NUTE|CROSECOND)|SECOND)|AVING)|YEAR_MONTH|N(O(_WRITE_TO_BINLOG|T)|U(MERIC|LL)|ATURAL)|C(R(OSS|EATE)|H(ECK|A(R(ACTER)?|NGE))|O(N(STRAINT|TINUE|DITION|VERT)|L(UMN|LATE))|UR(RENT_(TIME(STAMP)?|DATE|USER)|SOR)|A(S(CADE|E)|LL))|T(R(IGGER|UE|AILING)|HEN|INY(BLOB|TEXT|INT)|O|ERMINATED|ABLE)|I(GNORE|S|N(SE(RT|NSITIVE)|NER|T(1|2|8|3|O|4|E(RVAL|GER))?|OUT|DEX|FILE)?|TERATE|F)|ZEROFILL|O(R(DER{s}BY)?|N|UT(ER|FILE)?|PTI(MIZE|ON(ALLY)?))|D(ROP|I(STINCT(ROW)?|V)|OUBLE|UAL|E(SC(RIBE)?|C(IMAL|LARE)?|TERMINISTIC|FAULT|L(ETE|AYED))|A(Y_(MI(NUTE|CROSECOND)|SECOND|HOUR)|TABASE(S)?))|U(S(ING|E|AGE)|N(SIGNED|I(ON|QUE)|DO|LOCK)|TC_(TIME(STAMP)?|DATE)|PDATE)|JOIN|P(R(IMARY|OCEDURE|ECISION)|URGE)|E(X(I(STS|T)|PLAIN)|SCAPED|NCLOSED|LSE(IF)?|ACH)|VA(R(BINARY|YING|CHAR(ACTER)?)|LUES)|K(ILL|EY(S)?)|F(ROM|OR(CE|EIGN)?|ULLTEXT|ETCH|LOAT(8|4)?|ALSE)|W(RITE|H(ILE|E(RE|N))|ITH)|L(I(MIT|NE(S|AR)|KE)|O(NG(BLOB|TEXT)?|C(K|ALTIME(STAMP)?)|OP|W_PRIORITY|AD)|E(FT|A(DING|VE)))|A(S(C|ENSITIVE)?|N(D|ALYZE)|CCESSIBLE|DD|L(TER|L)))

/* un-optimized keywords:
ADD
ACCESSIBLE
ADD
ALL
ALTER
ANALYZE
AND
AS
ASC
ASENSITIVE
BEFORE
BETWEEN
BIGINT
BINARY
BLOB
BOTH
BY
CALL
CASCADE
CASE
CHANGE
CHAR
CHARACTER
CHECK
COLLATE
COLUMN
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
DISTINCT
DISTINCTROW
DIV
DOUBLE
DROP
DUAL
EACH
ELSE
ELSEIF
ENCLOSED
ESCAPED
EXISTS
EXIT
EXPLAIN
FALSE
FETCH
FLOAT
FLOAT4
FLOAT8
FOR
FORCE
FOREIGN
FROM
FULLTEXT
GRANT
GROUP{s}BY
HAVING
HIGH_PRIORITY
HOUR_MICROSECOND
HOUR_MINUTE
HOUR_SECOND
IF
IGNORE
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
INTO
IS
ITERATE
JOIN
KEY
KEYS
KILL
LEADING
LEAVE
LEFT
LIKE
LIMIT
LINEAR
LINES
LOAD
LOCALTIME
LOCALTIMESTAMP
LOCK
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
NATURAL
NOT
NO_WRITE_TO_BINLOG
NULL
NUMERIC
ON
OPTIMIZE
OPTION
OPTIONALLY
OR
ORDER{s}BY
OUT
OUTER
OUTFILE
PRECISION
PRIMARY
PROCEDURE
PURGE
RANGE
READ
READS
READ_WRITE
REAL
REFERENCES
REGEXP
RELEASE
RENAME
REPEAT
REPLACE
REQUIRE
RESTRICT
RETURN
REVOKE
RIGHT
RLIKE
SCHEMA
SCHEMAS
SECOND_MICROSECOND
SELECT
SENSITIVE
SEPARATOR
SET
SHOW
SMALLINT
SPATIAL
SPECIFIC
SQL
SQLEXCEPTION
SQLSTATE
SQLWARNING
SQL_BIG_RESULT
SQL_CALC_FOUND_ROWS
SQL_SMALL_RESULT
SSL
STARTING
STRAIGHT_JOIN
TABLE
TERMINATED
THEN
TINYBLOB
TINYINT
TINYTEXT
TO
TRAILING
TRIGGER
TRUE
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
WITH
WRITE
XOR
YEAR_MONTH
ZEROFILL
*/

%x comment
%x equation
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

{numeric}/{ops}				{ BEGIN(equation); return SPT_NUMERIC; }	/* numeric before operator        */
<equation>{ops}				{ BEGIN(INITIAL); return SPT_OTHER; }		/* set operator after a numeric   */
{numeric}/{alpha}			{ return SPT_WORD; }						/* catch numeric followed by char */

{s}+						{ return SPT_WHITESPACE; }					/* ignore spaces                  */

{keyword}					{ return SPT_RESERVED_WORD; }				/* all the mysql reserved words   */

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
