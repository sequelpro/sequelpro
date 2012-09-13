//
//  SPMySQLHTTPTunnelResponseData.h
//  SPMySQLFramework
//
//  Created by Ramon Fritsch on 8/22/12.
//
//

#import <Foundation/Foundation.h>

@interface SPMySQLHTTPTunnelResponseData : NSObject {
	NSData *data;
	NSUInteger position;
}

@property (readonly) NSUInteger position;

- (id)initWithData:(NSData *)theData;

- (void)seekToPos:(NSUInteger)thePosition;

- (unsigned char)readChar;
- (UInt32)readLong;
- (char *)readBlock;
- (char *)readBlockGettingLength:(unsigned long *)length;
- (void)skipBlock;

- (NSString *)readBlockAsString;


@end
