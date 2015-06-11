//
//  SPSSHTunnel.h
//  sequel-pro
//
//  Created by Rowan Beentje on April 26, 2009.
//  Copyright (c) 2009 Rowan Beentje. All rights reserved.
//  
//  Inspired by code by Yann Bizuel for SSH Tunnel Manager 2.
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

#import <SPMySQL/SPMySQL.h>

@interface SPSSHTunnel : NSObject <SPMySQLConnectionProxy>
{
	id delegate;

	NSWindow *parentWindow;
	NSTask *task;
	NSPipe *standardError;
	NSConnection *tunnelConnection;
	NSString *lastError;
	id lastErrorLock;
	NSString *tunnelConnectionName;
	NSString *tunnelConnectionVerifyHash;
	NSString *sshHost;
	NSString *sshLogin;
	NSString *remoteHost;
	NSString *password;
	NSString *keychainName;
	NSString *keychainAccount;
	NSString *requestedPassphrase;
	NSString *identityFilePath;
	NSMutableArray *debugMessages;
	NSLock *debugMessagesLock;
	NSInteger sshPort;
	NSInteger remotePort;
	NSUInteger localPort;
	NSUInteger localPortFallback;
	SPMySQLConnectionProxyState connectionState;
    
    NSLock *answerAvailableLock;
    NSString *currentKeyName;
	
	SEL stateChangeSelector;

	BOOL useHostFallback;
	BOOL connectionMuxingEnabled;
	BOOL requestedResponse;
	BOOL passwordInKeychain;
	BOOL passwordPromptCancelled;
	BOOL taskExitedUnexpectedly;
	
	IBOutlet NSWindow *sshQuestionDialog;
	IBOutlet NSTextField *sshQuestionText;
	IBOutlet NSButton *sshPasswordKeychainCheckbox;
	IBOutlet NSWindow *sshPasswordDialog;
	IBOutlet NSTextField *sshPasswordText;
	IBOutlet NSSecureTextField *sshPasswordField;
}

@property (readonly) BOOL passwordPromptCancelled;
@property (readonly) BOOL taskExitedUnexpectedly;

- (id)initToHost:(NSString *)theHost port:(NSInteger)thePort login:(NSString *)theLogin tunnellingToPort:(NSInteger)targetPort onHost:(NSString *)targetHost;
- (BOOL)setConnectionStateChangeSelector:(SEL)theStateChangeSelector delegate:(id)theDelegate;
- (void)setParentWindow:(NSWindow *)theWindow;
- (BOOL)setPasswordKeychainName:(NSString *)theName account:(NSString *)theAccount;
- (BOOL)setPassword:(NSString *)thePassword;
- (BOOL)setKeyFilePath:(NSString *)thePath;
- (SPMySQLConnectionProxyState)state;
- (NSString *)lastError;
- (NSString *)debugMessages;
- (NSUInteger)localPort;
- (NSUInteger)localPortFallback;
- (void)connect;
- (void)launchTask:(id)dummy;
- (void)disconnect;
- (void)standardErrorHandler:(NSNotification*)aNotification;
- (NSString *)getPasswordWithVerificationHash:(NSString *)theHash;
- (BOOL)getResponseForQuestion:(NSString *)theQuestion;
- (void)workerGetResponseForQuestion:(NSString *)theQuestion;
- (NSString *)getPasswordForQuery:(NSString *)theQuery verificationHash:(NSString *)theHash;
- (void)workerGetPasswordForQuery:(NSString *)theQuery;
- (IBAction)closeSSHQuestionSheet:(id)sender;
- (IBAction)closeSSHPasswordSheet:(id)sender;

@end
