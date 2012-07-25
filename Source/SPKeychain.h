//
//  $Id$
//
//  SPKeychain.h
//  sequel-pro
//
//  Created by Lorenz Textor (lorenz@textor.ch) on December 25, 2002.
//  Copyright (c) 2002-2003 Lorenz Textor. All rights reserved.
//  Copyright (c) 2012 Sequel Pro Team. All rights reserved.
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
//  More info at <http://code.google.com/p/sequel-pro/>

@interface SPKeychain : NSObject

- (void)addPassword:(NSString *)password forName:(NSString *)name account:(NSString *)account;
- (void)addPassword:(NSString *)password forName:(NSString *)name account:(NSString *)account withLabel:(NSString *)label;
- (NSString *)getPasswordForName:(NSString *)name account:(NSString *)account;
- (void)deletePasswordForName:(NSString *)name account:(NSString *)account;
- (BOOL)passwordExistsForName:(NSString *)name account:(NSString *)account;
- (void)updateItemWithName:(NSString *)name account:(NSString *)account toPassword:(NSString *)password;
- (void)updateItemWithName:(NSString *)name account:(NSString *)account toName:(NSString *)newName account:(NSString *)newAccount password:(NSString *)password;
- (NSString *)nameForFavoriteName:(NSString *)theName id:(NSString *)theID;
- (NSString *)accountForUser:(NSString *)theUser host:(NSString *)theHost database:(NSString *)theDatabase;
- (NSString *)nameForSSHForFavoriteName:(NSString *)theName id:(NSString *)theID;
- (NSString *)accountForSSHUser:(NSString *)theSSHUser sshHost:(NSString *)theSSHHost;

@end
