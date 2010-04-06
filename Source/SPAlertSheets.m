//
//  $Id$
//
//  SPAlertSheets.m
//  sequel-pro
//
//  Created by Rowan Beentje on January 20, 2010
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

#import "SPMainThreadTrampoline.h"

/**
 * Provide a very simple alias of NSBeginAlertSheet with one difference:
 * printf-type format strings are no longer supported within the "msg"
 * message text argument, preventing access of random stack areas for
 * error text which contains inadvertant printf formatting.
 */
void SPBeginAlertSheet(
	NSString *title,
	NSString *defaultButton,
	NSString *alternateButton,
	NSString *otherButton,
	NSWindow *docWindow,
		  id modalDelegate,
		 SEL didEndSelector,
		 SEL didDismissSelector,
		void *contextInfo,
	NSString *msg
) {
	NSBeginAlertSheet(
		title,
		defaultButton,
		alternateButton,
		otherButton,
		docWindow,
		modalDelegate,
		didEndSelector,
		didDismissSelector,
		contextInfo,
		[msg stringByReplacingOccurrencesOfString:@"%" withString:@"%%"]
	);
	
	[[docWindow onMainThread] makeKeyWindow];
}
