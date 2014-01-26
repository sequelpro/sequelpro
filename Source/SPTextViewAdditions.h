//
//  SPTextViewAdditions.h
//  sequel-pro
//
//  Created by Hans-Jörg Bibiko on April 05, 2009.
//  Copyright (c) 2009 Hans-Jörg Bibiko. All rights reserved.
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

@interface NSTextView (SPTextViewAdditions)

- (NSRange)getRangeForCurrentWord;

- (IBAction)selectCurrentWord:(id)sender;
- (IBAction)selectCurrentLine:(id)sender;
- (IBAction)selectEnclosingBrackets:(id)sender;
- (IBAction)doSelectionUpperCase:(id)sender;
- (IBAction)doSelectionLowerCase:(id)sender;
- (IBAction)doSelectionTitleCase:(id)sender;
- (IBAction)doDecomposedStringWithCanonicalMapping:(id)sender;
- (IBAction)doDecomposedStringWithCompatibilityMapping:(id)sender;
- (IBAction)doPrecomposedStringWithCanonicalMapping:(id)sender;
- (IBAction)doPrecomposedStringWithCompatibilityMapping:(id)sender;
- (IBAction)doTranspose:(id)sender;
- (IBAction)doRemoveDiacritics:(id)sender;
- (IBAction)insertNULLvalue:(id)sender;
- (IBAction)moveSelectionLineUp:(id)sender;
- (IBAction)moveSelectionLineDown:(id)sender;

#ifndef SP_CODA
- (IBAction)executeBundleItemForInputField:(id)sender;
#endif

- (void)makeTextSizeLarger;
- (void)makeTextSizeSmaller;
- (void)makeTextStandardSize;

@end
