/*	We need to run the casting tests in both Objective-C and Objective-C++
	because the casting is implemented slightly differently.
*/

// TODO: can we use C++11 initializer syntax instead of C99 compound literals?
#pragma clang diagnostic ignored "-Wc99-extensions"


#define JATemplateCastTests JATemplateCastTestsCpp
#import "JATemplateCastTests.m"
