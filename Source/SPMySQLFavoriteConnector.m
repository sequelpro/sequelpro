//
//  SPMySQLFavoriteConnector.m
//  Sequel Plus
//

#import "SPMySQLFavoriteConnector.h"
#import "SPSSHTunnel.h"
#import "SPKeychain.h"
#import "SPConstants.h"
#import "SPFavoritesController.h"
#import "SPFavoriteNode.h"
#import "SPTreeNode.h"
#import <SPMySQL/SPMySQL.h>

NSString * const SPMySQLConnectorErrorDomain = @"SPMySQLConnectorErrorDomain";

static NSError *SPConnectorError(SPMySQLConnectorErrorCode code, NSString *message)
{
	if (![message length]) {
		message = (code == SPMySQLConnectorErrorCancelled) ? NSLocalizedString(@"The connection was cancelled.", @"MySQL connector: cancelled")
														   : NSLocalizedString(@"The connection failed.", @"MySQL connector: failed");
	}
	return [NSError errorWithDomain:SPMySQLConnectorErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@interface SPMySQLFavoriteConnector ()
{
	NSDictionary *favorite;
	NSString *password;
	NSWindow *parentWindow;
	SPSSHTunnel *tunnel;
	SPMySQLConnection *connection;
	void (^completion)(SPMySQLConnection *, NSError *);
	BOOL started;
	BOOL finished;
	BOOL mysqlStarted;
}
@end

@implementation SPMySQLFavoriteConnector

@synthesize favorite;
@synthesize password;
@synthesize tunnel;

- (instancetype)initWithFavorite:(NSDictionary *)theFavorite password:(NSString *)thePassword parentWindow:(NSWindow *)theParentWindow
{
	if ((self = [super init])) {
		favorite = [theFavorite copy];
		password = [(thePassword ?: [[self class] keychainPasswordForFavorite:theFavorite]) copy];
		parentWindow = [theParentWindow retain];
	}
	return self;
}

- (void)dealloc
{
	[self _closeTunnel];
	[self _closeConnection];
	[favorite release];
	[password release];
	[parentWindow release];
	[completion release];
	[super dealloc];
}

#pragma mark - Favorites

+ (NSArray<NSDictionary *> *)mysqlFavorites
{
	NSMutableArray *favorites = [NSMutableArray array];
	SPTreeNode *root = [[SPFavoritesController sharedFavoritesController] favoritesTree];
	for (SPTreeNode *node in [root allChildLeafs]) {
		id represented = [node representedObject];
		if (![represented respondsToSelector:@selector(nodeFavorite)]) continue;
		NSDictionary *dictionary = [represented nodeFavorite];
		if ([dictionary isKindOfClass:[NSDictionary class]] && [dictionary objectForKey:SPFavoriteIDKey]) [favorites addObject:dictionary];
	}
	return favorites;
}

+ (NSString *)descriptionForFavorite:(NSDictionary *)theFavorite
{
	NSString *user = [theFavorite objectForKey:SPFavoriteUserKey] ?: @"";
	NSInteger type = [[theFavorite objectForKey:SPFavoriteTypeKey] integerValue];
	if (type == SPSocketConnection) {
		NSString *socket = [theFavorite objectForKey:SPFavoriteSocketKey];
		return [NSString stringWithFormat:@"%@@%@", user, [socket length] ? socket : NSLocalizedString(@"local socket", @"MySQL transfer: a socket favorite's target line")];
	}
	NSString *port = [[theFavorite objectForKey:SPFavoritePortKey] description];
	NSString *line = [NSString stringWithFormat:@"%@@%@:%@", user, [theFavorite objectForKey:SPFavoriteHostKey] ?: @"", [port length] ? port : @"3306"];
	if (type == SPSSHTunnelConnection) {
		line = [NSString stringWithFormat:NSLocalizedString(@"%@ via SSH %@@%@", @"MySQL transfer: target line through an SSH tunnel"), line, [theFavorite objectForKey:SPFavoriteSSHUserKey] ?: @"", [theFavorite objectForKey:SPFavoriteSSHHostKey] ?: @""];
	}
	return line;
}

+ (NSString *)keychainPasswordForFavorite:(NSDictionary *)theFavorite
{
	id favoriteID = [theFavorite objectForKey:SPFavoriteIDKey];
	if (!favoriteID) return nil;
	SPKeychain *keychain = [[[SPKeychain alloc] init] autorelease];
	BOOL socket = [[theFavorite objectForKey:SPFavoriteTypeKey] integerValue] == SPSocketConnection;
	NSString *name = [keychain nameForFavoriteName:[theFavorite objectForKey:SPFavoriteNameKey] id:[favoriteID description]];
	NSString *account = [keychain accountForUser:[theFavorite objectForKey:SPFavoriteUserKey] host:(socket ? @"localhost" : [theFavorite objectForKey:SPFavoriteHostKey]) database:[theFavorite objectForKey:SPFavoriteDatabaseKey]];
	NSString *found = [keychain getPasswordForName:name account:account];
	return [found length] ? found : nil;
}

#pragma mark - Connecting

- (void)connectWithCompletion:(void (^)(SPMySQLConnection *, NSError *))theCompletion
{
	NSAssert([NSThread isMainThread], @"SPMySQLFavoriteConnector is for the main thread");
	if (started) {
		void (^copied)(SPMySQLConnection *, NSError *) = [[theCompletion copy] autorelease];
		dispatch_async(dispatch_get_main_queue(), ^{ if (copied) copied(nil, SPConnectorError(SPMySQLConnectorErrorFailed, nil)); });
		return;
	}
	started = YES;
	completion = [theCompletion copy];

	NSInteger type = [[favorite objectForKey:SPFavoriteTypeKey] integerValue];
	if (type == SPSSHTunnelConnection) [self _startTunnel];
	else [self _startMySQLThroughTunnel:NO];
}

- (void)_startTunnel
{
	NSString *sshHost = [favorite objectForKey:SPFavoriteSSHHostKey], *host = [favorite objectForKey:SPFavoriteHostKey];
	if (![sshHost length]) {
		[self _finishLaterWithError:SPConnectorError(SPMySQLConnectorErrorSSHTunnelFailed, NSLocalizedString(@"The favorite has no SSH host.", @"MySQL connector: no SSH host"))];
		return;
	}
	NSInteger port = [[[favorite objectForKey:SPFavoritePortKey] description] integerValue] ?: 3306;
	NSInteger sshPort = [[[favorite objectForKey:SPFavoriteSSHPortKey] description] integerValue];
	tunnel = [[SPSSHTunnel alloc] initToHost:sshHost port:sshPort login:[favorite objectForKey:SPFavoriteSSHUserKey] tunnellingToPort:port onHost:([host length] ? host : @"127.0.0.1")];
	if (!tunnel) {
		[self _finishLaterWithError:SPConnectorError(SPMySQLConnectorErrorSSHTunnelFailed, NSLocalizedString(@"The SSH tunnel could not be created.", @"MySQL connector: tunnel not created"))];
		return;
	}
	if (parentWindow) [tunnel setParentWindow:parentWindow];
	SPKeychain *keychain = [[[SPKeychain alloc] init] autorelease];
	NSString *sshName = [keychain nameForSSHForFavoriteName:[favorite objectForKey:SPFavoriteNameKey] id:[[favorite objectForKey:SPFavoriteIDKey] description]];
	NSString *sshAccount = [keychain accountForSSHUser:[favorite objectForKey:SPFavoriteSSHUserKey] sshHost:sshHost];
	if ([keychain passwordExistsForName:sshName account:sshAccount]) [tunnel setPasswordKeychainName:sshName account:sshAccount];
	if ([[favorite objectForKey:SPFavoriteSSHKeyLocationEnabledKey] boolValue] && [[favorite objectForKey:SPFavoriteSSHKeyLocationKey] length]) {
		[tunnel setKeyFilePath:[favorite objectForKey:SPFavoriteSSHKeyLocationKey]];
	}
	[tunnel setConnectionStateChangeSelector:@selector(_tunnelStateChanged:) delegate:self];
	[tunnel connect];
}

- (void)_tunnelStateChanged:(SPSSHTunnel *)theTunnel
{
	if (finished || theTunnel != tunnel) return;
	if ([theTunnel passwordPromptCancelled]) {
		[self _finishWithConnection:nil error:SPConnectorError(SPMySQLConnectorErrorCancelled, nil)];
		return;
	}
	SPMySQLConnectionProxyState state = [theTunnel state];
	if (state == SPMySQLProxyIdle) {
		[self _finishWithConnection:nil error:SPConnectorError(SPMySQLConnectorErrorSSHTunnelFailed, [theTunnel lastError])];
	}
	else if (state == SPMySQLProxyConnected && !mysqlStarted) {
		[self _startMySQLThroughTunnel:YES];
	}
}

- (void)_startMySQLThroughTunnel:(BOOL)throughTunnel
{
	mysqlStarted = YES;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	SPMySQLConnection *theConnection = [[[SPMySQLConnection alloc] init] autorelease];
	[theConnection setUsername:[favorite objectForKey:SPFavoriteUserKey]];
	NSInteger type = [[favorite objectForKey:SPFavoriteTypeKey] integerValue];
	if (type == SPSocketConnection) {
		[theConnection setUseSocket:YES];
		NSString *socket = [favorite objectForKey:SPFavoriteSocketKey];
		if ([socket length]) [theConnection setSocketPath:socket];
	}
	else if (throughTunnel) {
		[theConnection setUseSocket:NO];
		[theConnection setHost:@"127.0.0.1"];
		[theConnection setPort:[tunnel localPort]];
		[theConnection setProxy:tunnel];
	}
	else {
		[theConnection setUseSocket:NO];
		[theConnection setHost:[favorite objectForKey:SPFavoriteHostKey]];
		NSString *port = [[favorite objectForKey:SPFavoritePortKey] description];
		if ([port length]) [theConnection setPort:(NSUInteger)[port integerValue]];
	}
	if (password) [theConnection setPassword:password];
	if ([[favorite objectForKey:SPFavoriteUseSSLKey] boolValue]) {
		[theConnection setUseSSL:YES];
		if ([[favorite objectForKey:SPFavoriteSSLKeyFileLocationEnabledKey] boolValue]) [theConnection setSslKeyFilePath:[favorite objectForKey:SPFavoriteSSLKeyFileLocationKey]];
		if ([[favorite objectForKey:SPFavoriteSSLCertificateFileLocationEnabledKey] boolValue]) [theConnection setSslCertificatePath:[favorite objectForKey:SPFavoriteSSLCertificateFileLocationKey]];
		if ([[favorite objectForKey:SPFavoriteSSLCACertFileLocationEnabledKey] boolValue]) [theConnection setSslCACertificatePath:[favorite objectForKey:SPFavoriteSSLCACertFileLocationKey]];
		NSString *ciphers = [prefs stringForKey:SPSSLCipherListKey];
		if (ciphers) {
			// "foo:bar:--:baz": the ciphers after the marker are disabled
			NSRange marker = [ciphers rangeOfString:@":--"];
			if (marker.location == NSNotFound && [ciphers hasPrefix:@"--"]) marker = NSMakeRange(0, 2);
			if (marker.location != NSNotFound) ciphers = [ciphers substringToIndex:marker.location];
			[theConnection setSslCipherList:ciphers];
		}
	}
	if ([favorite objectForKey:SPFavoriteUseCompressionKey] && ![[favorite objectForKey:SPFavoriteUseCompressionKey] boolValue]) [theConnection removeClientFlags:SPMySQLClientFlagCompression];
	NSInteger timeout = [[prefs objectForKey:SPConnectionTimeoutValue] integerValue];
	[theConnection setTimeout:(NSUInteger)(timeout > 0 ? timeout : 10)];
	[theConnection setUseKeepAlive:[[prefs objectForKey:SPUseKeepAlive] boolValue]];
	[theConnection setKeepAliveInterval:[[prefs objectForKey:SPKeepAliveInterval] floatValue]];
	connection = [theConnection retain];

	// -connect blocks (name lookup, handshake): off the main thread
	SPSSHTunnel *theTunnel = [[tunnel retain] autorelease];
	[self retain];
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		BOOL connected = [theConnection connect];
		// The tunnel's first port refused: its fallback port
		if (!connected && theTunnel && [theTunnel state] == SPMySQLProxyForwardingFailed && [theTunnel localPortFallback]) {
			[theConnection setPort:[theTunnel localPortFallback]];
			connected = [theConnection connect];
		}
		NSUInteger errorID = connected ? 0 : [theConnection lastErrorID];
		NSString *message = connected ? nil : [[[theConnection lastErrorMessage] copy] autorelease];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (theConnection == self->connection) [self _mysqlConnected:connected errorID:errorID message:message];
			[self release];
		});
		[pool drain];
	});
}

- (void)_mysqlConnected:(BOOL)connected errorID:(NSUInteger)errorID message:(NSString *)message
{
	if (finished) return;
	if (connected) {
		[self _finishWithConnection:connection error:nil];
		return;
	}
	if (tunnel && [tunnel state] == SPMySQLProxyForwardingFailed && [[tunnel lastError] length]) {
		[self _finishWithConnection:nil error:SPConnectorError(SPMySQLConnectorErrorSSHTunnelFailed, [tunnel lastError])];
		return;
	}
	// Access denied
	SPMySQLConnectorErrorCode code = (errorID == 1045) ? SPMySQLConnectorErrorPasswordRequired : SPMySQLConnectorErrorFailed;
	[self _finishWithConnection:nil error:SPConnectorError(code, message)];
}

- (void)_finishLaterWithError:(NSError *)error
{
	[self retain];
	dispatch_async(dispatch_get_main_queue(), ^{
		[self _finishWithConnection:nil error:error];
		[self release];
	});
}

- (void)_finishWithConnection:(SPMySQLConnection *)theConnection error:(NSError *)error
{
	if (finished) return;
	finished = YES;
	[[self retain] autorelease];
	if (error) {
		[self _closeTunnel];
		[self _closeConnection];
	}
	else if (tunnel) {
		// The window was only for the tunnel's sheets while connecting
		[tunnel setParentWindow:nil];
	}
	[parentWindow release];
	parentWindow = nil;
	void (^theCompletion)(SPMySQLConnection *, NSError *) = completion;
	completion = nil;
	if (theCompletion) theCompletion(error ? nil : theConnection, error);
	[theCompletion release];
}

#pragma mark - Closing

- (void)_closeTunnel
{
	if (!tunnel) return;
	SPSSHTunnel *theTunnel = tunnel;
	tunnel = nil;
	[theTunnel setConnectionStateChangeSelector:NULL delegate:nil];
	[theTunnel disconnect];
	// -disconnect does nothing until ssh has been launched (moments after -connect, on its thread): once more later
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[theTunnel disconnect];
		[theTunnel release];
	});
}

- (void)_closeConnection
{
	if (!connection) return;
	SPMySQLConnection *theConnection = connection;
	connection = nil;
	// Off the main thread: a connect still running finishes first, then the disconnect
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
		[theConnection disconnect];
		[theConnection release];
	});
}

- (void)cancel
{
	if (started && !finished) {
		[self _finishWithConnection:nil error:SPConnectorError(SPMySQLConnectorErrorCancelled, nil)];
		return;
	}
	[self disconnect];
}

- (void)disconnect
{
	finished = YES;
	[self _closeTunnel];
	[self _closeConnection];
}

@end
