/*******************************************************************************
    BDAlias.h
        Copyright (c) 2001-2002 bDistributed.com, Inc.
        Copyright (c) 2002-2009 BDAlias developers
        Some rights reserved: <http://opensource.org/licenses/mit-license.php>

    ***************************************************************************/

#import <Foundation/Foundation.h>
#import <CoreServices/CoreServices.h>

@interface BDAlias : NSObject
{
    AliasHandle _alias;
}

- (id)initWithAliasHandle:(AliasHandle)alias; // designated initializer
- (id)initWithData:(NSData *)data;
- (id)initWithPath:(NSString *)fullPath;
- (id)initWithPath:(NSString *)fullPath error:(NSError **)outError;
- (id)initWithPath:(NSString *)path relativeToPath:(NSString *)relPath;
- (id)initWithFSRef:(FSRef *)ref;
- (id)initWithFSRef:(FSRef *)ref error:(NSError **)outError;
- (id)initWithFSRef:(FSRef *)ref relativeToFSRef:(FSRef *)relRef;
- (id)initWithFSRef:(FSRef *)ref relativeToFSRef:(FSRef *)relRef error:(NSError **)outError;
- (id)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder*)coder;

- (void)dealloc;

- (AliasHandle)alias;
- (void)setAlias:(AliasHandle)newAlias;

- (NSData *)aliasData;
- (void)setAliasData:(NSData *)newAliasData;

- (NSString *)fullPath;
- (NSString *)fullPathRelativeToPath:(NSString *)relPath;

+ (BDAlias *)aliasWithAliasHandle:(AliasHandle)alias;
+ (BDAlias *)aliasWithData:(NSData *)data;
+ (BDAlias *)aliasWithPath:(NSString *)fullPath;
+ (BDAlias *)aliasWithPath:(NSString *)fullPath error:(NSError **)outError;
+ (BDAlias *)aliasWithPath:(NSString *)path relativeToPath:(NSString *)relPath;
+ (BDAlias *)aliasWithFSRef:(FSRef *)ref;
+ (BDAlias *)aliasWithFSRef:(FSRef *)ref relativeToFSRef:(FSRef *)relRef;

@end
