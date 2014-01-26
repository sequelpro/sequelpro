//
//  SPFavoritesImportProtocol.h
//  sequel-pro
//
//  Created by Stuart Connolly (stuconnolly.com) on August 1, 2011.
//  Copyright (c) 2011 Stuart Connolly. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//
//  More info at <https://github.com/sequelpro/sequelpro>

/**
 * @protocol SPFavoritesImportProtocol SPFavoritesImportProtocol.h
 *
 * @author Stuart Connolly http://stuconnolly.com/ 
 *
 * Favorites importer delegate protocol.
 */
@protocol SPFavoritesImportProtocol

/**
 * Invoked when the favorites import process successfully imports the favorites data.
 *
 * @param data The imported data as a dictionary.
 */
- (void)favoritesImportData:(NSArray *)data;

/**
 * Invoked when the favorites import proccess completes.
 *
 * @param error An error instance. Anything other than nil indicates an error occurred.
 */
- (void)favoritesImportCompletedWithError:(NSError *)error;

@end
