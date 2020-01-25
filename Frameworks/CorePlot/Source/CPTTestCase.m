#import "CPTTestCase.h"

@implementation CPTTestCase

-(nullable id)archiveRoundTrip:(nonnull id)object
{
    return [self archiveRoundTrip:object toClass:[object class]];
}

-(nullable id)archiveRoundTrip:(nonnull id)object toClass:(nonnull Class)archiveClass
{
    const BOOL secure = ![archiveClass isSubclassOfClass:[NSNumberFormatter class]];

    NSMutableData *archiveData = [[NSMutableData alloc] init];

    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:archiveData];

    archiver.requiresSecureCoding = secure;

    [archiver encodeObject:object forKey:@"test"];
    [archiver finishEncoding];

    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:archiveData];
    unarchiver.requiresSecureCoding = secure;

    return [unarchiver decodeObjectOfClass:archiveClass forKey:@"test"];
}

@end
