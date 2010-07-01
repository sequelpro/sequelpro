//
//  $Id$
//
//  SPEditorTokens.h
//  sequel-pro
//
//  Created by Jakob on 3/15/2009.
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

/** 
 *  This file defines all the tokens used for parsing the source code
 */

#define SPT_DOUBLE_QUOTED_TEXT   1
#define SPT_SINGLE_QUOTED_TEXT   2
#define SPT_COMMENT              3
#define SPT_BACKTICK_QUOTED_TEXT 4
#define SPT_RESERVED_WORD        5
#define SPT_WHITESPACE           6
#define SPT_NUMERIC              7
#define SPT_VARIABLE             8
#define SPT_WORD                 9
#define SPT_OTHER               10
