/*

SSHTunnel.m

Original code by tynsoe.org, Copyright 2002
Modified by Lorenz Textor for use with Sequel Pro

*/

#import "SSHTunnel.h"
#include <unistd.h>

// start diff lorenz textor
/*
#define T_START @"START: %@"
#define T_STOP @"STOP: %@"
#define S_IDLE @"Idle"
#define S_CONNECTING @"Connecting..."
#define S_CONNECTED @"Connected"
#define S_AUTH @"Authenticated"
#define S_PORT "Port %@ forwarded"
*/
#define T_START @"START: %@"
#define T_STOP @"STOP: %@"
#define S_IDLE @"Idle"
#define S_CONNECTING @"Connecting..."
#define S_CONNECTED @"Connected"
#define S_AUTH @"Authenticated"
#define S_PORT "Port %@ forwarded"
// end diff lorenz textor

@implementation SSHTunnel

// initialization
- (id)init
{
    self = [super init];
	
    // Make this class the root one for AppleEvent calls
//    [[ NSScriptExecutionContext sharedScriptExecutionContext] setTopLevelObject: self ];

	return self;
}

// Getting tunnels informations
- (BOOL)isRunning
/* returns YES if tunnel is running */
{
    return [ task isRunning ];
}

- (NSString*)status
{
    if (status)
		return status;
    return S_IDLE;
}

// starting & stopping the tunnel
- (void)startTunnel
/* starts tunnel with saved arguments */
{
	[self startTunnelWithArguments:tunnelArguments];
}

- (void)startTunnelWithArguments:(NSDictionary *)args
/* starts the tunnel */
{
	NSMutableArray *arguments = [[ NSMutableArray alloc] init ];

	if (tunnelArguments )
		[tunnelArguments release];
	tunnelArguments = [args retain];

	// stop tunnel if already running
	if ( [self isRunning] )
//		[self stopTunnel];
		return;

    shouldStop = NO;

// get arguments
	[ arguments addObject: @"-N" ];
	[ arguments addObject: @"-v" ];

//	[ arguments addObject: @"-p" ];
//	[ arguments addObject: @"-p" ];
//	[ arguments addObject: @"22" ];

//	[ arguments addObject: @"-c"];
//	[ arguments addObject: @"3des"];

	[ arguments addObject: [ NSString stringWithFormat: @"%@@%@", [args objectForKey:@"connUser"], [args objectForKey:@"connHost"] ]];

	[ arguments addObject: @"-L" ];
	[ arguments addObject: [NSString stringWithFormat:@"%@/%@/%@", [args objectForKey:@"localPort"], [args objectForKey:@"host"], [args objectForKey:@"remotePort"]] ];

    [ NSThread detachNewThreadSelector:@selector(launchTunnel:)
			      toTarget: self
			    withObject: arguments ];

	[ arguments release ];
}

- (void)stopTunnel
/* stops the tunnel */
{
    if (! [ self isRunning ])
		return;
    shouldStop=YES;
    [ self setValue: nil forKey: @"status" ];
    [ task terminate ];
    [[ NSNotificationCenter defaultCenter]  postNotificationName:@"STMStatusChanged" object:self ];
}

- (void)launchTunnel:(NSArray*)arguments
/* launches the tunnel in a separate thread */
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (task)
		[ task release ];
    task = [[ NSTask alloc ] init ];
    NSMutableDictionary *environment = [ NSMutableDictionary dictionaryWithDictionary: [[ NSProcessInfo processInfo ] environment ]];
    NSString *pathToAuthentifier = [[ NSBundle mainBundle ] pathForResource: @"askForPass" ofType: @"sh" ];
    
    [ task setLaunchPath: @"/usr/bin/ssh" ];
    [ task setArguments: arguments ];

// really necessary???
	[ environment removeObjectForKey: @"SSH_AGENT_PID" ];
	[ environment removeObjectForKey: @"SSH_AUTH_SOCK" ];
	[ environment setObject: pathToAuthentifier forKey: @"SSH_ASKPASS" ];
	[ environment setObject:@":0" forKey:@"DISPLAY" ];
    
    [ environment setObject: @"Sequel Pro Tunnel" forKey: @"TUNNEL_NAME" ];
    [ task setEnvironment: environment ];
	
    stdErrPipe = [[ NSPipe alloc ] init ];
    [ task setStandardError: stdErrPipe ];
    
    [[ NSNotificationCenter defaultCenter] addObserver:self 
					      selector:@selector(stdErr:) 
						  name: @"NSFileHandleDataAvailableNotification"
						object:[ stdErrPipe fileHandleForReading]];
    
    [[ stdErrPipe fileHandleForReading] waitForDataInBackgroundAndNotify ];

    NSLog(T_START,@"Sequel Pro Tunnel");
    [ self setValue: S_CONNECTING forKey: @"status" ];
    [ task launch ];
    [[ NSNotificationCenter defaultCenter]  postNotificationName:@"STMStatusChanged" object:self ];
    [ task waitUntilExit ];
    sleep(1);
    [ self setValue: S_IDLE forKey: @"status" ];
    NSLog(T_STOP,@"Sequel Pro Tunnel");
    [[ NSNotificationCenter defaultCenter] removeObserver:self 
						     name: @"NSFileHandleDataAvailableNotification"
						   object:[ stdErrPipe fileHandleForReading]];    
    [ task release ];
    task = nil;
    [ stdErrPipe release ];
    stdErrPipe = nil;
    [[ NSNotificationCenter defaultCenter]  postNotificationName:@"STMStatusChanged" object:self ];
    if (! shouldStop)
		[ self startTunnel ];
    [ pool release ];
}

- (void)stdErr:(NSNotification*)aNotification
{
    NSData *data = [[ aNotification object ] availableData ];
    NSString *log = [[ NSString alloc ] initWithData: data encoding: NSASCIIStringEncoding ];
    BOOL wait = YES;
    if ([ log length ])
    {
		NSLog(log);
		NSArray *lines = [ log componentsSeparatedByString:@"\n" ];
		NSEnumerator *e = [ lines objectEnumerator ];
		NSString *line;
		while (line = [ e nextObject ])
		{
			if ([ line rangeOfString:@"Entering interactive session." ].location != NSNotFound)
			{
				[ self setValue: S_CONNECTED  forKey: @"status"];
			}
			if ([ line rangeOfString:@"Authentication succeeded" ].location != NSNotFound)
				[ self setValue: S_AUTH forKey: @"status"];
			if ([ line rangeOfString:@"Connections to local port" ].location != NSNotFound)
			{
				NSScanner *s;
				NSString *port;
				s = [ NSScanner scannerWithString:log];
				[ s scanUpToString: @"Connections to local port " intoString: nil ];
				[ s scanString: @"Connections to local port " intoString: nil ];
				[ s scanUpToString: @"forwarded" intoString:&port];
				[ self setValue: [ NSString stringWithFormat: @"Port %@ forwarded", port ] forKey: @"status"];
			}
			if ([ line rangeOfString:@"closed by remote host." ].location != NSNotFound)
			{
				[ task terminate];
				[ self setValue: @"Connection closed" forKey: @"status"];
				wait = NO;
			}
			[[ NSNotificationCenter defaultCenter]  postNotificationName:@"STMStatusChanged" object:self ];
		}
		if (wait)
			[[ stdErrPipe fileHandleForReading ] waitForDataInBackgroundAndNotify ];
    }
    [ log release] ;
}

// deallocation
- (void) dealloc
{
	[self stopTunnel];
	
	[task release];
    [stdErrPipe release];
    [status release];
	[tunnelArguments release];

    [super dealloc];
}

@end
