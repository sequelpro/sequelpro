//
//  SSHTunnel.m
//  SSH Tunnel Manager 2
//
//  Created by Yann Bizeul on Wed Nov 19 2003.
//  Copyright (c) 2003 __MyCompanyName__. All rights reserved.
//

#import "SSHTunnel.h"
#include <unistd.h>

// start diff lorenz textor
/*
#define T_START NSLocalizedString(@"T_START",@"")
#define T_STOP NSLocalizedString(@"T_STOP",@"")
#define S_IDLE NSLocalizedString(@"S_IDLE",@"")
#define S_CONNECTING NSLocalizedString(@"S_CONNECTING",@"")
#define S_CONNECTED NSLocalizedString(@"S_CONNECTED",@"")
#define S_AUTH NSLocalizedString(@"S_AUTH",@"")
#define S_PORT NSLocalizedString(@"S_PORT",@"")
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

#pragma mark -
#pragma mark Initialization
-(id)init
{
	return [ self initWithName:@"New Tunnel"];
}
-(id)initWithName:(NSString*)aName
{
	NSDictionary *dictionary = [ NSDictionary dictionaryWithObjectsAndKeys:
	[ NSNumber numberWithBool: NO ],@"compression",
	[ NSNumber numberWithBool: YES ],@"connAuth",
	@"", @"connHost",
	aName, @"connName",
	@"", @"connPort",
	[ NSNumber numberWithBool: NO ],@"connRemote",
	@"", @"connUser",
	@"3des", @"encryption",
	[ NSNumber numberWithBool: NO ],@"socks4",
	[ NSNumber numberWithInt: 1080 ], @"socks4p",
	[ NSArray array ], @"tunnelsLocal",
	[ NSArray array ], @"tunnelsRemote",
	[ NSNumber numberWithBool: NO ],@"v1", nil
	];
	return [ self initWithDictionary: dictionary ];
}
-(id)initWithDictionary:(NSDictionary*)aDictionary
{
	NSEnumerator *e;
	NSString *key;

	self = [ super init ];
	e = [[ aDictionary allKeys ] objectEnumerator ];
	while (key = [ e nextObject ])
	{
	[ self setValue: [ aDictionary objectForKey: key ] forKey: key ];
	}
	code = 0;
	if ([[ self valueForKey: @"autoConnect" ] boolValue ])
	[ self startTunnel ];
	return self;
}
+(id)tunnelWithName:(NSString*)aName
{
	return [[ SSHTunnel alloc ] initWithName: aName ];
}
+(SSHTunnel*)tunnelFromDictionary:(NSDictionary*)aDictionary
{
	return [[ SSHTunnel alloc ] initWithDictionary: aDictionary ];
}
+(NSArray*)tunnelsFromArray:(NSArray*)anArray
{
	NSMutableArray *newArray;
	SSHTunnel *currentTunnel;
	NSEnumerator *e;
	NSDictionary *currentTunnelDictionary;
	
	newArray = [ NSMutableArray array ];
	e = [ anArray objectEnumerator ];
	while (currentTunnelDictionary = [ e nextObject ])
	{
	currentTunnel = [ SSHTunnel tunnelFromDictionary: currentTunnelDictionary ];
	[ newArray addObject: currentTunnel ];
	}
	return [[ newArray copy ] autorelease ];
}

#pragma mark -
#pragma mark Adding and removing port redir.
-(void)addLocalTunnel:(NSDictionary*)aDictionary;
{
	NSMutableArray *tempTunnelsLocal = [ NSMutableArray arrayWithArray: tunnelsLocal ];
	[ tempTunnelsLocal addObject: aDictionary ];
	[ tunnelsLocal release ];
	tunnelsLocal = [ tempTunnelsLocal copy ];
}
- (void)removeLocal:(int)index
{
	NSMutableArray *tempLocalTunnels = [ tunnelsLocal mutableCopy ];
	[ tempLocalTunnels removeObjectAtIndex: index ];
	[ tunnelsLocal release ];
	tunnelsLocal = [ tempLocalTunnels copy ];
	[ tempLocalTunnels release ];
}
-(void)addRemoteTunnel:(NSDictionary*)aDictionary;
{
	NSMutableArray *tempTunnelsRemote = [ NSMutableArray arrayWithArray: tunnelsRemote ];
	[ tempTunnelsRemote addObject: aDictionary ];
	[ tunnelsRemote release ];
	tunnelsRemote = [ tempTunnelsRemote copy ];
}
- (void)removeRemote:(int)index
{
	NSMutableArray *tempRemoteTunnels = [ tunnelsRemote mutableCopy ];
	[ tempRemoteTunnels removeObjectAtIndex: index ];
	[ tunnelsRemote release ];
	tunnelsRemote = [ tempRemoteTunnels copy ];
	[ tempRemoteTunnels release ];
}
- (void)setLocalValue:(NSString*)aValue ofTunnel:(int)index forKey:(NSString*)key
{
	NSMutableArray *tempLocalTunnel;
	NSMutableDictionary *tempCurrentTunnel;
	
	tempLocalTunnel = [tunnelsLocal mutableCopy];
	tempCurrentTunnel = [[ tempLocalTunnel objectAtIndex: index ] mutableCopy ];
	
	[ tempCurrentTunnel setObject: aValue forKey: key ];
	[ tempLocalTunnel replaceObjectAtIndex:index withObject:[tempCurrentTunnel copy ]];
	[ tempCurrentTunnel release ];
	[ tunnelsLocal release ];
	tunnelsLocal = [ tempLocalTunnel copy ];
}
- (void)setRemoteValue:(NSString*)aValue ofTunnel:(int)index forKey:(NSString*)key
{
	NSMutableArray *tempRemoteTunnel;
	NSMutableDictionary *tempCurrentTunnel;
	
	tempRemoteTunnel = [tunnelsRemote mutableCopy];
	tempCurrentTunnel = [[ tempRemoteTunnel objectAtIndex: index ] mutableCopy ];
	
	[ tempCurrentTunnel setObject: aValue forKey: key ];
	[ tempRemoteTunnel replaceObjectAtIndex:index withObject:[tempCurrentTunnel copy ]];
	[ tempCurrentTunnel release ];
	[ tunnelsRemote release ];
	tunnelsRemote = [ tempRemoteTunnel copy ];
}

#pragma mark -
#pragma mark Execution related
- (void)startTunnel
{	
//	NSDictionary *t;
//	NSEnumerator *e;
//	BOOL asRoot = NO;
	
	if ([ self isRunning ])
	return;
	
	shouldStop = NO;
	/*
	[ arguments addObject: @"-N" ];
	[ arguments addObject: @"-v" ];
	[ arguments addObject: @"-p" ];
	if ([ connPort length ])
	[ arguments addObject: connPort];
	else
	[ arguments addObject: @"22" ];
	
	if (connRemote)
	[ arguments addObject: @"-g" ];
	if (compression)
	[ arguments addObject: @"-C" ];
	if (v1)
	[ arguments addObject: @"-1" ];
	
	[ arguments addObject: @"-c"];
	if (encryption)
	[ arguments addObject: encryption];
	else
	[ arguments addObject: @"3des"];
	
	if (socks4 && socks4p != nil)
	{
	[ arguments addObject: @"-D" ];
	[ arguments addObject: [ socks4p stringValue ]];
	}
	[ arguments addObject: [ NSString stringWithFormat: @"%@@%@",
	connUser, connHost ]
	];
	
	NSString *hostPort;
	e = [ tunnelsLocal objectEnumerator ];
	while (t = [ e nextObject ])
	{
	[ arguments addObject: @"-L" ];
	if ([[ t objectForKey:@"hostport"] isEqualTo: @"" ])
		hostPort = [ t objectForKey:@"port" ];
	else
		hostPort = [ t objectForKey:@"hostport" ];
	[ arguments addObject: [NSString stringWithFormat:@"%@/%@/%@",
		[ t objectForKey:@"port"],
		[ t objectForKey:@"host"],
		hostPort
		] ];
	if ([[ t objectForKey:@"port"] intValue] < 1024)
		asRoot=YES;
	}
	
	e = [ tunnelsRemote objectEnumerator ];
	while (t = [ e nextObject ])
	{
	[ arguments addObject: @"-R" ];
	if ([[ t objectForKey:@"hostport"] isEqualTo: @"" ])
		hostPort = [ t objectForKey:@"port" ];
	else
		hostPort = [ t objectForKey:@"hostport" ];
	[ arguments addObject: [NSString stringWithFormat:@"%@/%@/%@",
		[ t objectForKey:@"port"],
		[ t objectForKey:@"host"],
		hostPort
		]];
	}
	args = [ NSMutableDictionary dictionary ];
	[ args setObject: arguments forKey:@"arguments" ];
	[ args setObject: [ NSNumber numberWithBool: connAuth ] forKey: @"handleAuth" ];
	[ args setObject: connName forKey:@"tunnelName" ];
	[ args setObject: [ NSNumber numberWithBool: asRoot ] forKey: @"asRoot" ];
	
	
	 [ NSThread detachNewThreadSelector:@selector(launchTunnel:)
				   toTarget: self
				 withObject: args ];
	 */
	[ NSThread detachNewThreadSelector:@selector(launchTunnel:)
				  toTarget: self
				withObject: nil ];
//	[ arguments release ];
	
}
- (void)stopTunnel
{
	if (! [ self isRunning ])
	return;
	shouldStop=YES;
	[ self setValue: nil forKey: @"status" ];
	[ task terminate ];
	code = 0;
	[[ NSNotificationCenter defaultCenter]  postNotificationName:@"STMStatusChanged" object:self ];
}

- (void)toggleTunnel
{
	if ([ self isRunning ])
	[ self stopTunnel ];
	else
	[ self startTunnel ];
}

- (void)launchTunnel:(id)foo;
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if (task)
	[ task release ];
	task = [[ NSTask alloc ] init ];
	NSMutableDictionary *environment = [ NSMutableDictionary dictionaryWithDictionary: [[ NSProcessInfo processInfo ] environment ]];
	NSString *pathToAuthentifier = [[ NSBundle mainBundle ] pathForResource: @"askForPass" ofType: @"sh" ];
	if (socks4)
	[ task setLaunchPath: [[ NSBundle mainBundle ] pathForResource: @"ssh" ofType: @"" ]];
	else
	[ task setLaunchPath: @"/usr/bin/ssh" ];
	[ task setArguments: [ self arguments ]];
	if (connAuth)
	{
		[ environment removeObjectForKey: @"SSH_AGENT_PID" ];
		[ environment removeObjectForKey: @"SSH_AUTH_SOCK" ];
		[ environment setObject: pathToAuthentifier forKey: @"SSH_ASKPASS" ];
		[ environment setObject:@":0" forKey:@"DISPLAY" ];
	}
	[ environment setObject: connName forKey: @"TUNNEL_NAME" ];
	[ task setEnvironment: environment ];

	stdErrPipe = [[ NSPipe alloc ] init ];
	[ task setStandardError: stdErrPipe ];
	
	[[ NSNotificationCenter defaultCenter] addObserver:self 
						  selector:@selector(stdErr:) 
						  name: @"NSFileHandleDataAvailableNotification"
						object:[ stdErrPipe fileHandleForReading]];
	
	[[ stdErrPipe fileHandleForReading] waitForDataInBackgroundAndNotify ];

	NSLog(T_START,connName);
	[ self setValue: S_CONNECTING forKey: @"status" ];
	code = 1;
	[ task launch ];
	[[ NSNotificationCenter defaultCenter]  postNotificationName:@"STMStatusChanged" object:self ];
	[ task waitUntilExit ];
	sleep(1);
	code = 0;
	[ self setValue: S_IDLE forKey: @"status" ];
	NSLog(T_STOP,connName);
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
	//NSLog(log);
	NSArray *lines = [ log componentsSeparatedByString:@"\n" ];
	NSEnumerator *e = [ lines objectEnumerator ];
	NSString *line;
	while (line = [ e nextObject ])
	{
		if ([ line rangeOfString:@"Entering interactive session." ].location != NSNotFound)
		{
		code = 2;   
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

- (BOOL)isRunning
{
	if ([ task isRunning ])
	return YES;
	return NO;
}

#pragma mark -
#pragma mark Getting tunnel informations
- (NSString *)status
{
	if (status)
	return status;
	return S_IDLE;
}
- (NSArray*)arguments
{
	NSMutableArray *arguments;
	NSEnumerator *e;
	NSDictionary *t;
	BOOL asRoot;
	
	arguments = [ NSMutableArray array ];
	[ arguments addObject: @"-N" ];
	[ arguments addObject: @"-v" ];
	[ arguments addObject: @"-p" ];
	if ([ connPort length ])
	[ arguments addObject: connPort];
	else
	[ arguments addObject: @"22" ];
	
	if (connRemote)
	[ arguments addObject: @"-g" ];
	if (compression)
	[ arguments addObject: @"-C" ];
	if (v1)
	[ arguments addObject: @"-1" ];
	
	[ arguments addObject: @"-c"];
	if (encryption)
	[ arguments addObject: encryption];
	else
	[ arguments addObject: @"3des"];
	
	if (socks4 && socks4p != nil)
	{
	[ arguments addObject: @"-D" ];
	[ arguments addObject: [ socks4p stringValue ]];
	}
	[ arguments addObject: [ NSString stringWithFormat: @"%@@%@",
	connUser, connHost ]
	];
	
	NSString *hostPort;
	e = [ tunnelsLocal objectEnumerator ];
	while (t = [ e nextObject ])
	{
	[ arguments addObject: @"-L" ];
	if ([[ t objectForKey:@"hostport"] isEqualTo: @"" ])
		hostPort = [ t objectForKey:@"port" ];
	else
		hostPort = [ t objectForKey:@"hostport" ];
	[ arguments addObject: [NSString stringWithFormat:@"%@/%@/%@",
		[ t objectForKey:@"port"],
		[ t objectForKey:@"host"],
		hostPort
		] ];
	if ([[ t objectForKey:@"port"] intValue] < 1024)
		asRoot=YES;
	}
	
	e = [ tunnelsRemote objectEnumerator ];
	while (t = [ e nextObject ])
	{
	[ arguments addObject: @"-R" ];
	if ([[ t objectForKey:@"hostport"] isEqualTo: @"" ])
		hostPort = [ t objectForKey:@"port" ];
	else
		hostPort = [ t objectForKey:@"hostport" ];
	[ arguments addObject: [NSString stringWithFormat:@"%@/%@/%@",
		[ t objectForKey:@"port"],
		[ t objectForKey:@"host"],
		hostPort
		]];
	}
	
	return [[ arguments copy ] autorelease ];
}

- (NSDictionary*)dictionary
{
	return [ NSDictionary dictionaryWithObjectsAndKeys:
	[ NSNumber numberWithBool: compression ],@"compression",
	[ NSNumber numberWithBool: connAuth ],@"connAuth",
	[ NSNumber numberWithBool: autoConnect ],@"autoConnect",
	connHost, @"connHost",
	connName, @"connName",
	connPort, @"connPort",
	[ NSNumber numberWithBool: connRemote ],@"connRemote",
	connUser, @"connUser",
	encryption, @"encryption",
	[ NSNumber numberWithBool: socks4 ],@"socks4",
	socks4p, @"socks4p",
	tunnelsLocal, @"tunnelsLocal",
	tunnelsRemote, @"tunnelsRemote",
	[ NSNumber numberWithBool: v1 ],@"v1", nil
	];
}


#pragma mark -
#pragma mark Key/Value coding
- (NSImage*)icon
{
	switch (code)
	{
	case 0:
		return [ NSImage imageNamed: @"offState" ];
		break;
	case 1:
		return [ NSImage imageNamed: @"middleState" ];
		break;
	case 2:
		return [ NSImage imageNamed: @"onState" ];
		break;
	}
	return [ NSImage imageNamed: @"offState" ];
}
- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	NSLog(@"key %@ undefined",key);
}
- (id)valueForUndefinedKey:(NSString *)key
{
	return nil;
}

#pragma mark -
#pragma mark Misc.
-(void)dealloc
{
	[ self stopTunnel ];
	[ tunnelsLocal release ];
	[ tunnelsRemote release ];
	
	[ task release ];
	[ stdErrPipe release ];
	[ connName release ];
	[ status release ];
	[ connPort release ];
	[ encryption release ];
	[ socks4p release ];
	[ connUser release ];
	[ connHost release ];
	
	// start diff lorenz textor
	[super dealloc];
	// end diff lorenz textor
}
@end
