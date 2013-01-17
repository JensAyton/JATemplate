#import <SenTestingKit/SenTestingKit.h>


@interface JATemplateTests: SenTestCase
@end


// Interception of warning messages.
NSArray *JATGetWarnings(void);
void JATResetWarnings(void);
