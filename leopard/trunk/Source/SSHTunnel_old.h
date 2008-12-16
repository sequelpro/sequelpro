/*

SSHTunnel.h

Original code by tynsoe.org, Copyright 2002
Modified by Lorenz Textor for use with Sequel Pro

*/

#import <Cocoa/Cocoa.h>

@interface SSHTunnel : NSObject
{
	BOOL shouldStop;
	NSTask *task;
	NSPipe *stdErrPipe;
	NSString *status;

	NSDictionary *tunnelArguments;
}

// initialization
- (id)init;

// Getting tunnels informations
- (BOOL)isRunning;
- (NSString *)status;

// starting & stopping the tunnel
- (void)startTunnel;
- (void)startTunnelWithArguments:(NSDictionary *)args;
- (void)stopTunnel;
- (void)launchTunnel:(NSArray*)arguments;
- (void)stdErr:(NSNotification*)aNotification;
- (id)authenticate:(NSScriptCommand *)command;
- (id)handleQuitScriptCommand:(NSScriptCommand *)command;

// deallocation
- (void) dealloc;

@end
