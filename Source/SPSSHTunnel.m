//
//  SPSSHTunnel.m
//  sequel-pro
//
//  Created by Rowan Beentje on April 26, 2009.  Inspired by code by
//  Yann Bizuel for SSH Tunnel Manager 2.
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

#import "SPSSHTunnel.h"
#import <netinet/in.h>


@implementation SPSSHTunnel

/*
 * Initialise with the supplied connection details.  Host, login and port should all be provided.
 * The password can either be set later via setPassword:, which stores the password locally and is
 * therefore not recommended, or via setPasswordKeychainName:, which will use the keychain on-demand
 * and is therefore preferred.
 */
- (id) initToHost:(NSString *) theHost port:(int) thePort login:(NSString *) theLogin tunnellingToPort:(int) targetPort onHost:(NSString *) targetHost
{
	if (!theHost || !thePort || !theLogin || !targetPort || !targetHost) return nil;

	self = [super init];

	// Store the connection settings as appropriate
	sshHost = [[NSString alloc] initWithString:theHost];
	sshLogin = [[NSString alloc] initWithString:theLogin];
	sshPort = thePort;
	if ([theHost isEqualToString:targetHost]) {
		remoteHost = [[NSString alloc] initWithString:@"127.0.0.1"];
	} else {
		remoteHost = [[NSString alloc] initWithString:targetHost];
	}
	remotePort = targetPort;
	delegate = nil;
	stateChangeSelector = nil;
	lastError = nil;

	// Set up a connection for use by the tunnel process
	tunnelConnectionName = [NSString stringWithFormat:@"SequelPro-%f", [[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] hash]];
	tunnelConnection = [[NSConnection defaultConnection] retain];
	[tunnelConnection runInNewThread];
	[tunnelConnection removeRunLoop:[NSRunLoop currentRunLoop]];
	[tunnelConnection setRootObject:self];
	if ([tunnelConnection registerName:tunnelConnectionName] == NO) {
		return nil;
	}

	parentWindow = nil;
	password = nil;
	keychainName = nil;
	keychainAccount = nil;
	passwordInKeychain = NO;
	task = nil;
	localPort = 0;
	connectionState = SPSSH_STATE_IDLE;

	return self;
}

/*
 * Sets the connection callback selector; a function to be called whenever the tunnel state changes.
 * The callback function will be called and passed this SSH Tunnel object..
 */
- (BOOL) setConnectionStateChangeSelector:(SEL)theStateChangeSelector delegate:(id)theDelegate
{
	delegate = theDelegate;
	stateChangeSelector = theStateChangeSelector;

	return true;
}

/*
 * Set the parent window of the connection for use with dialogs.
 */
- (void)setParentWindow:(NSWindow *)theWindow
{
	parentWindow = theWindow;
	if (![NSBundle loadNibNamed:@"SSHQuestionDialog" owner:self]) {
		NSLog(@"SSH query dialog could not be loaded; SSH tunnels will not function correctly.");
		parentWindow = nil;
	}
}

/*
 * Sets the password to be stored (and returned to the tunnel authenticator) locally.
 * Providing a keychain name is much more secure.
 */
- (BOOL) setPassword:(NSString *)thePassword
{
	if (passwordInKeychain) return NO;
	password = [[NSString alloc] initWithString:thePassword];
	tunnelConnectionVerifyHash = [NSString stringWithFormat:@"%f", [[NSString stringWithFormat:@"%f%i", [[NSDate date] timeIntervalSince1970]] hash]];
	
	return YES;
}

/*
 * Sets the keychain name to use to retrieve the password.  This is the recommended and
 * secure way of supplying a password to the SSH tunnel.
 */
- (BOOL) setPasswordKeychainName:(NSString *)theName account:(NSString *)theAccount
{
	if (password) [password release], password = nil;

	passwordInKeychain = YES;
	keychainName = [[NSString alloc] initWithString:theName];
	keychainAccount = [[NSString alloc] initWithString:theAccount];

	return YES;
}

/*
 * Get the state of the connection.
 */
- (int) state
{
	return connectionState;
}

/*
 * Returns the last error string, if any.
 */
- (NSString *) lastError
{
	return [NSString stringWithString:lastError];
}

/*
 * Initiate the SSH tunnel connection, launching the task in a background thread.
 */
- (void) connect
{
	localPort = 0;
	if (connectionState != SPSSH_STATE_IDLE || (!passwordInKeychain && !password)) return;
	[NSThread detachNewThreadSelector:@selector(launchTask:) toTarget: self withObject: nil ];
}

/*
 * Launch the NSTask which wraps the SSH process, and use it to initiate the
 * tunnel to the remote server.
 * Sets up and tears down as appropriate for usage in a background thread.
 */
- (void) launchTask:(id) dummy
{
	if (connectionState != SPSSH_STATE_IDLE || task) return;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *taskArguments;
	NSMutableDictionary *taskEnvironment;
	NSString *authenticationAppPath;

	connectionState = SPSSH_STATE_CONNECTING;
	if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];

	// Enforce a parent window being present for dialogs
	if (!parentWindow) {
		connectionState = SPSSH_STATE_IDLE;
		if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
		if (lastError) [lastError release];
		lastError = [[NSString alloc] initWithString:@"SSH Tunnel started without a parent window.  A parent window must be present."];
		[pool release];
		return;
	}

	int connectionTimeout = [[[NSUserDefaults standardUserDefaults] objectForKey:@"ConnectionTimeout"] intValue];
	if (!connectionTimeout) connectionTimeout = 10;
	BOOL useKeepAlive = [[[NSUserDefaults standardUserDefaults] objectForKey:@"UseKeepAlive"] doubleValue];
	double keepAliveInterval = [[[NSUserDefaults standardUserDefaults] objectForKey:@"KeepAliveInterval"] doubleValue];
	if (!keepAliveInterval) keepAliveInterval = 0;

	// If no local port has yet been chosen, choose one
	if (!localPort) {
		int tempSocket;
		struct sockaddr_in tempSocketAddress;
		int addressLength = sizeof(tempSocketAddress);
		if((tempSocket = socket(AF_INET, SOCK_STREAM, 0)) > 0) {
			memset(&tempSocketAddress, 0, sizeof(tempSocketAddress));
			tempSocketAddress.sin_family = AF_INET;
			tempSocketAddress.sin_addr.s_addr = htonl(INADDR_ANY);
			tempSocketAddress.sin_port = 0;
			if (bind(tempSocket, (struct sockaddr *)&tempSocketAddress, addressLength) >= 0) {
				if (getsockname(tempSocket, (struct sockaddr *)&tempSocketAddress, (uint32_t *)&addressLength) >= 0) {
					localPort = ntohs(tempSocketAddress.sin_port);
				}
			}
			close(tempSocket);
		}
		
		// Abort if no local free port could be allocated
		if (!localPort) {
			connectionState = SPSSH_STATE_IDLE;
			if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
			if (lastError) [lastError release];
			lastError = [[NSString alloc] initWithString:NSLocalizedString(@"No local port could be allocated for the SSH Tunnel.", @"SSH tunnel could not be created because no local port could be allocated")];
			[pool release];
			return;
		}
	}

	// Set up the NSTask
	task = [[NSTask alloc] init];
	[task setLaunchPath: @"/usr/bin/ssh"];

	// Set up the arguments for the task
	taskArguments = [ NSMutableArray array ];
	[taskArguments addObject:@"-N"]; // Tunnel only
	[taskArguments addObject:@"-v"]; // Verbose mode for messages
//	[taskArguments addObject:@"-C"]; // TODO: compression?
	[taskArguments addObject:@"-o ExitOnForwardFailure=yes"];
	[taskArguments addObject:[NSString stringWithFormat:@"-o ConnectTimeout=%i", connectionTimeout]];
	[taskArguments addObject:@"-o PubkeyAuthentication=yes"];
	[taskArguments addObject:@"-o NumberOfPasswordPrompts=1"];
	if (useKeepAlive && keepAliveInterval) {
		[taskArguments addObject:@"-o TCPKeepAlive=no"];		
		[taskArguments addObject:[NSString stringWithFormat:@"-o ServerAliveInterval=%i", (int)ceil(keepAliveInterval)]];		
		[taskArguments addObject:@"-o ServerAliveCountMax=1"];		
	}
	[taskArguments addObject:[NSString stringWithFormat:@"-p %i", sshPort]];
	[taskArguments addObject:[NSString stringWithFormat:@"%@@%@", sshLogin, sshHost]];
	[taskArguments addObject:[NSString stringWithFormat:@"-L %i/%@/%i", localPort, remoteHost, remotePort]];
	[task setArguments:taskArguments];

	// Set up the environment for the task
	authenticationAppPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"TunnelPassphraseRequester"];
	taskEnvironment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
	[taskEnvironment removeObjectForKey: @"SSH_AGENT_PID"];
	[taskEnvironment removeObjectForKey: @"SSH_AUTH_SOCK"];
	[taskEnvironment setObject:authenticationAppPath forKey:@"SSH_ASKPASS"];
	[taskEnvironment setObject:@":0" forKey:@"DISPLAY"];
	[taskEnvironment setObject:tunnelConnectionName forKey:@"SP_CONNECTION_NAME"];
	if (passwordInKeychain) {
		[taskEnvironment setObject:[[NSNumber numberWithInt:SPSSH_PASSWORD_USES_KEYCHAIN] stringValue] forKey:@"SP_PASSWORD_METHOD"];
		[taskEnvironment setObject:keychainName forKey:@"SP_KEYCHAIN_ITEM_NAME"];
		[taskEnvironment setObject:keychainAccount forKey:@"SP_KEYCHAIN_ITEM_ACCOUNT"];
	} else {
		[taskEnvironment setObject:[[NSNumber numberWithInt:SPSSH_PASSWORD_ASKS_UI] stringValue] forKey:@"SP_PASSWORD_METHOD"];
		[taskEnvironment setObject:tunnelConnectionVerifyHash forKey:@"SP_CONNECTION_VERIFY_HASH"];
	}
	[task setEnvironment:taskEnvironment];

	// Set up the standard error pipe
	standardError = [[NSPipe alloc] init];
    [task setStandardError:standardError];
    [[ NSNotificationCenter defaultCenter] addObserver:self 
											  selector:@selector(standardErrorHandler:) 
												  name:@"NSFileHandleDataAvailableNotification"
												object:[standardError fileHandleForReading]];
	[[standardError fileHandleForReading] waitForDataInBackgroundAndNotify];

	// Launch and run the tunnel
	[task launch];

	// TODO: The below code doesn't actually appear to work.  We will probably have to switch to system()/exec() for grouped children...
	// Apply the process group to the child task to ensure it quits with the parent process.
	// Note that if run from within Xcode, Xcode is the parent process!
/*	pid_t group = setsid();
	if (group == -1) group = getpgrp();
	if(setpgid([task processIdentifier], group) == -1) {
		connectionState = SPSSH_STATE_IDLE;
		[task terminate];
		if (lastError) [lastError release];
		lastError = [[NSString alloc] initWithFormat:NSLocalizedString(@"The SSH Tunnel could not safely be marked as belonging to Sequel Pro, and so has been shut down for security reasons.  Please try again.\n\n(Error %i)", @"SSH tunnel could not be security marked by Sequel Pro"), errno];
		if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
	}*/

	// Listen for output
	[task waitUntilExit];
	if (connectionState != SPSSH_STATE_IDLE) {
		connectionState = SPSSH_STATE_IDLE;
		lastError = [[NSString alloc] initWithString:NSLocalizedString(@"The SSH Tunnel has unexpectedly closed.", @"SSH tunnel unexpectedly closed")];
		if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
	}

	// On tunnel close, clean up
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:@"NSFileHandleDataAvailableNotification"
												  object:[standardError fileHandleForReading]];
	[task release], task = nil;
	[standardError release], standardError = nil;

	[pool release];
}

/*
 * Disconnects the tunnel
 */
- (void)disconnect
{
    if (connectionState == SPSSH_STATE_IDLE) return;
    [task terminate];
    connectionState = SPSSH_STATE_IDLE;
	if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
}
 
/*
 * Processes messages recieved from the SSH task
 */
- (void)standardErrorHandler:(NSNotification*)aNotification
{
	NSString *notificationText;
	NSEnumerator *enumerator;
	NSArray *messages;
	NSString *message;

	notificationText = [[NSString alloc] initWithData:[[aNotification object] availableData] encoding:NSASCIIStringEncoding];

	if ([notificationText length]) {
		messages = [notificationText componentsSeparatedByString:@"\n"];
		enumerator = [messages objectEnumerator];
		while (message = [enumerator nextObject]) {

			if ([message rangeOfString:@"Entering interactive session."].location != NSNotFound) {
				connectionState = SPSSH_STATE_CONNECTED;
				if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
			}

			if ([message rangeOfString:@"Connection established"].location != NSNotFound) {
				connectionState = SPSSH_STATE_WAITING_FOR_AUTH;
				if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
			}

			if ([message rangeOfString:@"closed by remote host." ].location != NSNotFound) {
				connectionState = SPSSH_STATE_IDLE;
				[task terminate];
				if (lastError) [lastError release];
				lastError = [[NSString alloc] initWithString:NSLocalizedString(@"The SSH Tunnel was closed 'by the remote host'.  This may indicate a networking issue or a network timeout.", @"SSH tunnel was closed by remote host message")];
				if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
			}
			if ([message rangeOfString:@"Permission denied (" ].location != NSNotFound) {
				connectionState = SPSSH_STATE_IDLE;
				[task terminate];
				if (lastError) [lastError release];
				lastError = [[NSString alloc] initWithString:NSLocalizedString(@"The SSH Tunnel could not authenticate with the remote host.  Please check your password and ensure you still have access.", @"SSH tunnel authentication failed message")];
				if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
			}
			if ([message rangeOfString:@"Operation timed out" ].location != NSNotFound) {
				connectionState = SPSSH_STATE_IDLE;
				[task terminate];
				if (lastError) [lastError release];
				lastError = [[NSString alloc] initWithFormat:NSLocalizedString(@"The SSH Tunnel was unable to connect to host %@, or the request timed out.\n\nBe sure that the address is correct and that you have the necessary privileges, or try increasing the connection timeout (currently %i seconds).", @"SSH tunnel failed or timed out message"), sshHost, [[[NSUserDefaults standardUserDefaults] objectForKey:@"ConnectionTimeoutValue"] intValue]];
				if (delegate) [delegate performSelectorOnMainThread:stateChangeSelector withObject:self waitUntilDone:NO];
			}
		}
	}

	if (connectionState != SPSSH_STATE_IDLE) {
		[[standardError fileHandleForReading] waitForDataInBackgroundAndNotify];
	}

	[notificationText release];
}

/*
 * Returns the local port assigned for use by the tunnel
 */
- (int) localPort
{
	return localPort;
}

/*
 * Method to request the password for the current connection, as used by TunnelPassphraseRequester;
 * called with a verification hash to check against the stored hash, to provide basic security.  Note
 * that this is easily bypassed, but if bypassed the password can already easily be retrieved in the same way.
 */
- (NSString *)getPasswordWithVerificationHash:(NSString *)theHash
{
	if (passwordInKeychain) return nil;
	if (![theHash isEqualToString:tunnelConnectionVerifyHash]) return nil;
	return password;
}

/*
 * Method to allow an SSH tunnel to request the response to a question, returning the response as
 * a boolean.  This is used by the SSH_ASKPASS environment setting to deal with situations like
 * host key mismatches.
 */
- (BOOL) getResponseForQuestion:(NSString *)theQuestion
{

	// Ask how to proceed
	[sshQuestionText setStringValue:theQuestion];
	[NSApp beginSheet:sshQuestionDialog modalForWindow:parentWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
	int sshQueryResponseCode = [NSApp runModalForWindow:sshQuestionDialog];
	[NSApp endSheet:sshQuestionDialog];
	[sshQuestionDialog orderOut:nil];

	switch (sshQueryResponseCode) {

		// Yes
		case 1:
			return YES;

		// No
		default:
			return NO;
	}
}

/*
 * Ends an existing modal session
 */
- (IBAction) closeSheet:(id)sender
{
	[NSApp stopModalWithCode:[sender tag]];
}

@end
