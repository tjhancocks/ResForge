#import "ElementWFLG.h"

#define SIZE_ON_DISK (2)

@implementation ElementWFLG
@synthesize value;

- (void)readDataFrom:(TemplateStream *)stream
{
    UInt16 tmp = 0;
    [stream readAmount:SIZE_ON_DISK toBuffer:&tmp];
    value = CFSwapInt16BigToHost(tmp);
}

- (UInt32)sizeOnDisk:(UInt32)currentSize
{
    return SIZE_ON_DISK;
}

- (void)writeDataTo:(TemplateStream *)stream
{
    UInt16 tmp = CFSwapInt16HostToBig(value);
    [stream writeAmount:SIZE_ON_DISK fromBuffer:&tmp];
}

@end
