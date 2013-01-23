#import "JATConstructFuzzTest.h"


bool JATConstructFuzzTest(NSString **outTemplate, NSDictionary **outParameters)
{
	NSCParameterAssert(outTemplate != NULL && outParameters != NULL);
	
	*outTemplate = @"{foo}";
	*outParameters = @{@"foo": @"value"};
	return true;
}
