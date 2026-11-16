//
//  SPMySQLFavoriteConnector.h
//  Sequel Plus
//
//  Opens a MySQL connection for a saved favorite, away from the connection screen (the Transfer sheet's target).
//

#import <Cocoa/Cocoa.h>

@class SPMySQLConnection;
@class SPSSHTunnel;

extern NSString * const SPMySQLConnectorErrorDomain __attribute__((visibility("default")));

typedef NS_ENUM(NSInteger, SPMySQLConnectorErrorCode) {
	SPMySQLConnectorErrorFailed = 1,
	/// The server refused the user and password (MySQL error 1045): the caller may ask for a password
	SPMySQLConnectorErrorPasswordRequired = 2,
	SPMySQLConnectorErrorSSHTunnelFailed = 3,
	SPMySQLConnectorErrorCancelled = 4
};

/**
 * Connects a favorite (its dictionary, as SPFavoriteNode holds it): TCP/IP, socket, or through an SSH tunnel, with
 * its SSL and compression settings and the app's timeout and keep-alive preferences. The password is the one given,
 * or the favorite's keychain item. The connection has no delegate (it never asks the app for anything).
 *
 * Use from the main thread. The connector owns the session: keep it while the connection is in use; releasing it
 * (or -disconnect) closes the connection and its tunnel.
 */
__attribute__((visibility("default")))
@interface SPMySQLFavoriteConnector : NSObject

/// password nil: the favorite's keychain password, if any. parentWindow: for the SSH tunnel's password and
/// host-key sheets (without one an SSH favorite fails at once).
- (instancetype)initWithFavorite:(NSDictionary *)favorite password:(NSString *)password parentWindow:(NSWindow *)parentWindow;

/// Completion called once, on the main thread, never from within this call: a connected connection, or an error in
/// SPMySQLConnectorErrorDomain.
- (void)connectWithCompletion:(void (^)(SPMySQLConnection *connection, NSError *error))completion;

/// Stops an attempt (completes with Cancelled) or closes the connection.
- (void)cancel;
- (void)disconnect;

@property (readonly) NSDictionary *favorite;
@property (readonly, copy) NSString *password;
@property (readonly) SPSSHTunnel *tunnel;

/// The MySQL favorites (dictionaries), in the favorites list's order (PostgreSQL ones left out).
+ (NSArray<NSDictionary *> *)mysqlFavorites;

/// "user@host:port", "user@socket path", or "user@host:port via SSH sshUser@sshHost".
+ (NSString *)descriptionForFavorite:(NSDictionary *)favorite;

/// The favorite's MySQL password from the keychain, or nil.
+ (NSString *)keychainPasswordForFavorite:(NSDictionary *)favorite;

@end
