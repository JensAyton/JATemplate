#import "JATAppDelegate.h"
#import "JATemplate.h"


@implementation JATAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Test that it works with no parameters.
	JATLog(@"Trivial string");
	
	// Test substitution.
	id foo = @"sausage";
	int bar = 76;
	JATLog(@"foo: {foo}; bar: {bar}", foo, @(bar));
	
	// Test unknown parameter. Template system should log a warning before this line.
	JATLog(@"Unknown variable: {nonesuch}");
	
	// Test formatting operators. Also a redundant parameter, and reuse of a cached parameter list parse.
	JATLog(@"Fancy bar: {bar|num:spellout|capitalize}", foo, @(bar));
	
	// Test booleans.
	NSNumber *boolValue = @NO;
	NSString *trueString = @"yes";
	NSString *falseString = @"no";
	JATLog(@"Boolean: {boolValue|if:true;false}; inverted: {boolValue|not|ifuse:trueString;falseString}", boolValue, trueString, falseString);
	
	// Test byte size formatting.
	NSUInteger byteSize = 65536;
	JATLog(@"File bytes: {byteSize|num:filebytes}; memory bytes: {byteSize|num:memorybytes}", @(byteSize));
	
	// Test plural: operator.
	NSUInteger kittenCount = 1;
	NSUInteger gooseCount = 5;
	JATLog(@"I have {kittenCount|num:spellout} kitten{kittenCount|plural:s} and {gooseCount|num:spellout} {gooseCount|plural:goose;geese}. That’s {gooseCount|plural:one goose;a couple of geese;several geese}.", @(kittenCount), @(gooseCount));
	
	// Test fold: operator.
	NSString *blargh = @"BläÄ";
	JATLog(@"Fold operator: {blargh|fold:case,diacritics}", blargh);
	
	// Test brace escapes.
	JATLog(@"Braces: int main() {(} return 0; {)}");
	
	// Test localization.
	NSString *localizationFile = @"Localizable.strings";
	JATLogLocalized(@"This is a template in the source code, not from {localizationFile}.", localizationFile);
	
	// Test Boring Mode.
	NSString *boring = JATExpandWithParameters(@"boring_mode_test", @{ @"boring": @"SUPER EXCITING!" });
	NSLog(@"%@", boring);
	
	// Test debugdesc.
	NSArray *array = @[@"foo", @36, @YES];
	JATLog(@"Debug description: {array|debugdesc}", array);
	
	[NSApp terminate:nil];
}

@end
