//
//  $Id$
//
//  SPBundleHTMLOutputController.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on November 22, 2010
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
#import <WebKit/WebKit.h>

@interface SPBundleHTMLOutputController : NSWindowController {

	IBOutlet WebView *webView;

	NSString       *docTitle;
	NSString       *initHTMLSourceString;
	NSString       *windowUUID;
	NSString       *docUUID;
	WebPreferences *webPreferences;

}

@property(readwrite,retain) NSString *docTitle;
@property(readwrite,retain) NSString *initHTMLSourceString;
@property(readwrite,retain) NSString *windowUUID;
@property(readwrite,retain) NSString *docUUID;

- (IBAction)printDocument:(id)sender;

- (void)displayHTMLContent:(NSString *)content withOptions:(NSDictionary *)displayOptions;
- (void)displayURLString:(NSString *)url withOptions:(NSDictionary *)displayOptions;

- (void)showSourceCode;
- (void)saveDocument;

@end
