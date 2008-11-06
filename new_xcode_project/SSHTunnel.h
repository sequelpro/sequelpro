#import <Cocoa/Cocoa.h>

@interface SSHTunnel : NSObject
{
    int code;
    NSArray *tunnelsLocal;
    NSArray *tunnelsRemote;
    
    BOOL shouldStop;
    NSTask *task;
    BOOL connAuth;
    BOOL autoConnect;
    NSPipe *stdErrPipe;
    NSString *connName;
    NSString *status;
    NSString *connPort;
    BOOL connRemote;
    BOOL compression;
    BOOL v1;
    NSString * encryption;
    BOOL socks4;
    NSNumber *socks4p;
    NSString *connUser;
    NSString *connHost;
}
-(id)initWithName:(NSString*)aName;
-(id)initWithDictionary:(NSDictionary*)aDictionary;
+(id)tunnelWithName:(NSString*)aName;
+(NSArray*)tunnelsFromArray:(NSArray*)anArray;

-(void)addLocalTunnel:(NSDictionary*)aDictionary;
- (void)removeLocal:(int)index;
-(void)addRemoteTunnel:(NSDictionary*)aDictionary;
- (void)removeRemote:(int)index;
- (void)setLocalValue:(NSString*)aValue ofTunnel:(int)index forKey:(NSString*)key;
- (void)setRemoteValue:(NSString*)aValue ofTunnel:(int)index forKey:(NSString*)key;

#pragma mark -
#pragma mark Execution related
- (void)startTunnel;
- (void)stopTunnel;
- (void)toggleTunnel;
- (void)launchTunnel:(id)foo;
- (void)stdErr:(NSNotification*)aNotification;
- (BOOL)isRunning;

#pragma mark -
#pragma mark Getting tunnel informations
- (NSString*)status;
- (NSArray*)arguments;
- (NSDictionary*)dictionary;

#pragma mark -
#pragma mark Key/Value coding
- (NSImage*)icon;

@end
