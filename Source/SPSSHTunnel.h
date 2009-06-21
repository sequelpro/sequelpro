#import <Cocoa/Cocoa.h>

enum spsshtunnel_states
{
	SPSSH_STATE_IDLE = 0,
	SPSSH_STATE_CONNECTING = 1,
	SPSSH_STATE_WAITING_FOR_AUTH = 2,
	SPSSH_STATE_CONNECTED = 3,
	SPSSH_STATE_FORWARDING_FAILED = 4
};

enum spsshtunnel_password_modes
{
	SPSSH_PASSWORD_USES_KEYCHAIN = 0,
	SPSSH_PASSWORD_ASKS_UI = 1
};


@interface SPSSHTunnel : NSObject
{
	IBOutlet NSWindow *sshQuestionDialog;
	IBOutlet NSTextField *sshQuestionText;
	IBOutlet NSButton *sshPasswordKeychainCheckbox;
	IBOutlet NSWindow *sshPasswordDialog;
	IBOutlet NSTextField *sshPasswordText;
	IBOutlet NSSecureTextField *sshPasswordField;

	NSWindow *parentWindow;
	NSTask *task;
	NSPipe *standardError;
	id delegate;
	SEL stateChangeSelector;
	NSConnection *tunnelConnection;
	NSString *lastError;
	NSString *tunnelConnectionName;
	NSString *tunnelConnectionVerifyHash;
	NSString *sshHost;
	NSString *sshLogin;
	NSString *remoteHost;
	NSString *password;
	NSString *keychainName;
	NSString *keychainAccount;
	NSString *requestedPassphrase;
	NSMutableArray *debugMessages;
	BOOL useHostFallback;
	BOOL requestedResponse;
	BOOL passwordInKeychain;
	int sshPort;
	int remotePort;
	int localPort;
	int localPortFallback;
	int connectionState;
}

- (id) initToHost:(NSString *) theHost port:(int) thePort login:(NSString *) theLogin tunnellingToPort:(int) targetPort onHost:(NSString *) targetHost;
- (BOOL) setConnectionStateChangeSelector:(SEL)theStateChangeSelector delegate:(id)theDelegate;
- (void) setParentWindow:(NSWindow *)theWindow;
- (BOOL) setPasswordKeychainName:(NSString *)theName account:(NSString *)theAccount;
- (BOOL) setPassword:(NSString *)thePassword;
- (int) state;
- (NSString *) lastError;
- (NSString *) debugMessages;
- (int) localPort;
- (int) localPortFallback;
- (void) connect;
- (void) launchTask:(id) dummy;
- (void) disconnect;
- (void) standardErrorHandler:(NSNotification*)aNotification;
- (NSString *) getPasswordWithVerificationHash:(NSString *)theHash;
- (BOOL) getResponseForQuestion:(NSString *)theQuestion;
- (void) workerGetResponseForQuestion:(NSString *)theQuestion;
- (NSString *) getPasswordForQuery:(NSString *)theQuery verificationHash:(NSString *)theHash;
- (void) workerGetPasswordForQuery:(NSString *)theQuery;
- (IBAction) closeSheet:(id)sender;

@end
