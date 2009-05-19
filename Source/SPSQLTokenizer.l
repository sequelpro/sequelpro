%{

//
//  $Id$
//
//  SPSQLTokenizer.l
//  sequel-pro
//
//  Created by Hans-J. Bibiko on May 14, 2009
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

#import "SPSQLTokenizer.h"
int utf8strlenfortoken(const char * _s);
int yyuoffset, yyuleng;

#define YY_NO_UNPUT

//keep track of the current utf-8 character (not byte) offset and token length
#define YY_USER_ACTION { yyuoffset += yyuleng; yyuleng = utf8strlenfortoken(yytext); }
%}
%option prefix="to"
%option noyywrap
%option case-insensitive

s			[ \t\n\r]
dkey		"delimiter"
scol		";"
dval		[!-ﾟ]
compstart	"begin"{s}
compend		{s}"end"
%x comment
%x delim
%x delimbody
%x comp
%x compbody

%%

\"([^"\\]|\\(.|[\n\r]))*\"?			{ return SP_SQL_TOKEN_IGNORE; }
'([^'\\]|\\(.|[\n\r]))*'?			{ return SP_SQL_TOKEN_IGNORE; }
`[^`]*`?							{ return SP_SQL_TOKEN_IGNORE; }

"/*"								{ BEGIN(comment); return SP_SQL_TOKEN_IGNORE; }
<comment>[^*]* 						{ return SP_SQL_TOKEN_IGNORE; }
<comment>"*"+						{ return SP_SQL_TOKEN_IGNORE; }
<comment>"*"+"/" 					{ BEGIN(INITIAL); return SP_SQL_TOKEN_IGNORE; }
#[^\n\r]*(\n|\r)?			|
--[ \t][^\n\r]*(\n|\r)?				{ return SP_SQL_TOKEN_IGNORE; }

{s}+								{ return SP_SQL_TOKEN_IGNORE; }

{s}*{dkey}{s}+						{ BEGIN(delim); return SP_SQL_TOKEN_IGNORE; }
<delim>{dval}+						{ BEGIN(delimbody); return SP_SQL_TOKEN_DELIM_VALUE; }
<delimbody>{s}+{dkey}{s}+{scol}{s}*	{ BEGIN(INITIAL); return SP_SQL_TOKEN_DELIM_END; }
{compstart}							{ BEGIN(comp); return SP_SQL_TOKEN_IGNORE; }
<comp>{dval}+						{ BEGIN(compbody); return SP_SQL_TOKEN_IGNORE; }
<compbody>{compend}{s}*{scol}		{ BEGIN(INITIAL); return SP_SQL_TOKEN_COMPOUND_END; }

{scol}{s}*							{ return SP_SQL_TOKEN_SEMICOLON; }
[.\r\n]+							{ return SP_SQL_TOKEN_IGNORE; }


<<EOF>>   						{
                                    BEGIN(INITIAL);   /* make sure we return to initial state when finished! */
            						yy_delete_buffer(YY_CURRENT_BUFFER);
            						return 0;
          						}
%%
#define ONEMASK ((size_t)(-1) / 0xFF)
// adapted from http://www.daemonology.net/blog/2008-06-05-faster-utf8-strlen.html
int utf8strlenfortoken(const char * _s)
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
