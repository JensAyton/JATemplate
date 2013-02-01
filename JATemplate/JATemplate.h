/*

JATemplate.h

Vanilla Edition: this version minimizes the use of preprocessor tricks at the
cost of efficiency, type-safety and expressiveness. If you’re not scared of
macros, consider the Hairy Edition instead.


JATemplate is a string expansion system designed for convenience of use and
safety. In particular, it is intended to replace printf-style formatting
(-[NSString stringWithFormat:], NSLog() etc.), and to be immune to format
string attacks.

*** WARNING: while it is intended to avoid designed-in vulnerabilities, this
is prototype-level code that hasn't been extensively tested. Don’t use it with
arbitrary format strings fresh of the interwebs. ***

Internationalization is achieved through implicit calls of NSLocalizedString()
(by default) and locale-sensitive formatting operations.

Immunity from format string attacks is achieved by specifying the substitution
parameters out-of-band at compile time (which is handled automatically by
macros). An unknown variable in a template will be ignored, rather than reading
arbitrary parts of the stack as with printf-style formatting. There is no
equivalent to the dangerous %n specifier (which, to be fair, isn’t supported by
Foundation either).

Examples of use:
	NSString *item = @"apples";
	NSUInteger quantity = 12563;
	NSString *ex1 = JATExpand(@"We have {quantity} {items}.", items, @(quantity));
	// Produces “We have 12,463 apples.”, assuming an English locale.
	
	float timeElapsed = 1.3;
	float estimatedTotalTime = 2.7;
	float timeRatio = timeElapsed / estimatedTotalTime;
	NSString *ex2 = JATExpand(@"Progress: {timeRatio|round|num:percent}", timeRatio);
	// Produces “Progress: 48%” using the num: formatting operator.
	
	NSString *foo = @"bunny";
	NSString *ex3 = JATExpand(@"{foo}");
	// Produces “{foo}”, because foo wasn’t passed as a parameter.


Copyright © 2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software“), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 
*/

#import <Foundation/Foundation.h>


#pragma mark Interface documentation – Read me first

/*
	The notional interface for the expansion system is as follows. The actual
	implementations are mostly macros as defined below.
	
	NSString *JATExpand(NSString *template, ...)
		Look up <template> in the bundle's Localizable.strings, if possible,
		otherwise use it as-is. Replace all substitution expressions in the
		template string with corresponding named variable. For example,
		NSString *foo = @"banana"; JATExpand(@"test: {foo}", foo); returns
		@"test: banana" (unless of course the template is localized).
		
		Parameters may be referenced by name if they are plain variables or
		variables boxed using @() syntax. All parameters can also be referenced
		by index using the form {0}, {1} etc.
		
		In the Vanilla Edition, all parameters must be objects.
		
		Parameters may be modified using operators, which are specified using
		a vertical bar. Operators may optionally have a parameter, seperated
		by a colon. Several operators may be chained. Examples:
			{foo|uppercase}
			{bar|num:$#,##0.00}
			{2|num:spellout|capitalize}
		More information about operators is found further down the header.
		
		Template syntax is quite strict. In particular, there is no optional
		whitespace.
	
	NSString *JATExpandLiteral(NSString *template, ...)
		Like JATExpand(), but without the Localizable.strings lookup.
	
	NSString *JATExpandFromTable(NSString *template, NSString *table, ...)
		Like JATExpand(), but allows you to specify a strings file other than
		Localizable.strings. The table name should be specified without the
		.strings extension. Compare NSLocalizedStringFromTable().
	
	JATExpandFromTableInBundle(NSString *template, NSString *table, NSBundle *bundle, ...)
		Like JATExpandFromTable(), but additionally allows you to specify a
		bundle other than the main bundle. Compare
		NSLocalizedStringFromTableInBundle().
	
	
	NSString *JATExpandWithParameters(NSString *template, NSDictionary *parameters)
		Allows the template system to be used the old-fashioned way: values
		are looked up in <parameters> instead of using variables. Positional
		parameters are looked up using NSNumber keys (for example,
		JATExpandWithParameters(@"(@0)", @{ @(0): @"value" }) works).
		Attempts to localize template using Localizable.strings.
	
	NSString *JATExpandLiteralWithParameters(NSString *template, NSDictionary *parameters)
		Like JATExpandWithParameters(), but without the Localizable.strings lookup.
	
	NSString *JATExpandFromTableWithParameters(NSString *template, NSString *table, NSDictionary *parameters)
		Like JATExpandWithParameters(), but allows you to specify a strings file
		other than Localizable.strings. The table name should be specified
		without the .strings extension. Compare JATExpandFromTable().
	
	NSString *JATExpandFromTableInBundleWithParameters(NSString *template, NSString *table, NSBundle *bundle, NSDictionary *parameters)
		Like JATExpandFromTableWithParameters(), but additionally allows you to
		specify a bundle other than the main bundle. Compare
		JATExpandFromTableInBundle().
	
	
	void JATAppend(NSMutableString *string, NSString *template, ...)
		Equivalent to [string appendString:JATExpand(template, ...)].
	
	void JATAppendLiteral(NSMutableString *string, NSString *template, ...)
		Equivalent to [string appendString:JATExpandLiteral(template, ...)].
	
	void JATAppendFromTable(NSMutableString *string, NSString *template, NSString *table, ...)
		Equivalent to [string appendString:JATExpandFromTable(template, table, ...)].
	
	void JATAppendFromTableInBundle(NSMutableString *string, NSString *template, NSString *table, NSBundle *bundle, ...)
		Equivalent to [string appendString:JATExpandFromTableInBundle(template, table, bundle, ...)].
	
	
	void JATLog(NSString *template, ...)
		Equivalent to NSLog(@"%@", JATExpandLiteral(template, ...)).
	
	void JATLogLocalized(NSString *template, ...)
		Equivalent to NSLog(@"%@", JATExpand(template, ...)).
	
	
	JATAssert(condition, template, ...)
		Equivalent to NSAssert1(condition, @"%@", JATExpandLiteral(template, ...)).
	
	JATCAssert(condition, template, ...)
		Equivalent to NSCAssert1(condition, @"%@", JATExpandLiteral(template, ...)).
	
	
	The following operators are defined in JATemplateDefaultOperators. If you
	don’t want them, JATemplate.m will work without the operators.
	
		num:
		Format numbers. The argument may be an NSNumberFormatter format string,
		or one of the following constants for locale-sensitive formatting:
		- decimal or dec
		  Decimal formatting using NSNumberFormatterDecimalStyle. This is
		  generally redundant since the default string coersion of numbers
		  also uses NSNumberFormatterDecimalStyle, but included for
		  completeness.
		- noloc
		  The number's non-locale-sensitive description.
		- currency or cur
		  Currency formatting using NSNumberFormatterCurrencyStyle.
		- percent or pct
		  Percentage formatting using NSNumberFormatterPercentStyle.
		- scientific or sci
		  Scientific formatting using NSNumberFormatterScientificStyle.
		- spellout
		  Textual formatting using NSNumberFormatterSpellOutStyle.
		- filebytes, file or bytes
		  Byte count formatting using NSByteCountFormatterCountStyleFile.
		- memorybytes or memory
		  Byte count formatting using NSByteCountFormatterCountStyleMemory.
		- decimalbytes
		  Byte count formatting using NSByteCountFormatterCountStyleDecimal.
		- binarybytes
		  Byte count formatting using NSByteCountFormatterCountStyleBinary.
		
		round
		Coerces value to a number and rounds it to an integer, rounding half-way
		cases away from zero (“school rounding”).
		
		plur:
		A powerful pluralization operator with support for many languages. It
		takes three to seven arguments separated by semicolons. The first is a
		number specifying a pluralization rule, and the others are different
		word forms determined by the rule. The rules are the same as used by
		Mozilla’s PluralForm system, documented here (except that rule 0 is
		not supported or needed):
		https://developer.mozilla.org/en-US/docs/Localization_and_Plurals
		For example, the template "{count} minute{count|plural:s}" might be
		translated to Polish as "{count} {count|plur:9;minuta;minuty;minut}".
		
		The selected string is also expanded as a template, so it’s possible
		to do things like "{plur:1;{singularString};{pluralString}}". This is
		generally a bad idea, because handling all the different language rules
		this way is likely to be impossible, but it’s there if you need it.
		(This also works with plural: and pluraz:.)
		
		plural:
		A simplified plural operator for languages that use the same numeric
		inflection structure as English. If one argument is given, the empty
		string is used for a singular value and the argument is used for plural.
		If two areguments separated by a semicolon are given, the first is
		singular and the second is plural.
		Example: "I have {gooseCount} {gooseCount|plural:goose;geese}.".
		
		pluraz:
		Like plural:, except that a count of zero is treated as singular.
		Example: "J’ai {gooseCount} {gooseCount|pluraz:oie;oies}.", or
		equivalently "J’ai {gooseCount} oie{gooseCount|pluraz:s}.".
		
		not
		Coerces the value to a boolean and returns its negation.
		
		if:
		Takes one or two arguments separated by semicolons. If the value, as a
		boolean, is true, selects the first argument. Otherwise selects the
		second argument (or the empty string if none). The selected argument is
		then expanded as a template.
		Example: "The flag is {flag|if:set;not set}."
		
		select:
		Takes any number of arguments separated by semicolons. The value is
		coerced to a number and truncated. The corresponding argument is selected
		(and expanded). Arguments are numbered from zero; if the value is out
		of range, the last item is used.
		Example: "Today is {weekDay|select:Mon;Tues;Wednes;Thurs;Fri;Satur;Sun}day."
		
		uppercase
		Locale-sensitive conversion to uppercase using uppercaseStringWithLocale:.
		
		lowercase
		Locale-sensitive conversion to lowercase using lowercaseStringWithLocale:.
		
		capitalize
		Locale-sensitive conversion to lowercase using capitalizedStringWithLocale:.
		
		uppercase_noloc
		Locale-insensitive canonical conversion to uppercase using uppercaseString.
		
		lowercase_noloc
		Locale-insensitive canonical conversion to lowercase using lowercaseString.
		
		capitalize_noloc
		Locale-insensitive canonical conversion to lowercase using capitalizedString.
		
		trim
		Remove leading and trailing whitespace and newlines.
		
		length
		String length. (If the object is not a string, it will be coerced to a
		string and its length will be used.)
		
		fold:
		Locale-sensitive removal of lesser character distinctions using
		stringByFoldingWithOptions:locale:. The argument is a comma-separated
		list of options. The currently supported options are "case", "width"
		and "diacritics".
		
		pointer
		Produces a string representing the address of a value object, equivalent
		to %p in printf-style formatting. NSNull becomes 0x0, since there is
		no way to distinguish a parameter value of NSNull from nil internally.
		
		basedesc
		Produces the class name and address of an object enclosed in angle
		brackets, equivalent to the default implementation of -description.
		
		debugdesc
		Calls -debugDescription on the value if implemented, otherwise
		-description. (Try it on some Foundation collections.)
*/


#pragma mark Formatting operator support

@interface NSObject (JATOperatorSupport)

/*	-jatemplatePerformOperator:argument:variables: implements formatting
	operators in template substitutions. The default implementation builds and
	calls a selector based on the operator name according to the following pattern:
		- (id) jatemplatePerform_{operator}_withArgument:(NSString *)argument variables:(NSDictionary *)variables;
	
	Argument is the string following a colon in the operator expression, or nil
	if there is no colon. Variables is a dictionary of all the variables passed
	to JATExpand*().
	
	For example, a substitution of the form {foo|num:spellout} is turned into
	a call to -jatemplatePerform_num_withArgument:variables: with @"spellout"
	as the first argument.
	
	The recommended pattern is to implement operators as categories on NSObject
	and coerce the object to the required class. For some custom operators, it
	may be reasonable to implement them on a specific class instead.
	
	Operators signal failure by returning nil. Nil values are represented with
	NSNull, which becomes @"(null)" when coerced to a string.
	
	If no operator implementation is found, the default implementation of
	-jatemplatePerformOperator:withArgument: returns nil.
*/
- (id) jatemplatePerformOperator:(NSString *)op withArgument:(NSString *)argument variables:(NSDictionary *)variables;

@end


/*	NSArray *JATSplitArgumentString(NSString *string, unichar separator)
	
	Split a string into components separated by <separator>, but ignore
	<separator>s inside of braces. (No other balanced punctuation pairs are
	supported.)
	
	For consistency, operators should use ';' as the separator unless there is
	a pressing reason not to.
	
	If an unbalanced } is found, a warning will be logged.
*/
NSArray *JATSplitArgumentString(NSString *string, unichar separator);


#pragma mark - JATCoercible protocol

@protocol JATCoercible <NSObject>

/*	- (NSNumber *) jatemplateCoerceToString
	
	Convert reciever to an NSString. May return nil on failure. Used by default
	template operators that expect a string, and should be used for custom
	template operators in the same way. Also used to convert the result of a
	series of operators, or a variable with no operators applied, to a string
	for insertion in the template.
	
	The default implementation calls -description. Overridden for NSNumber to
	use locale-sensitive NSNumberFormatterDecimalStyle, and for NSNull to
	return @"(null)".
*/
- (NSString *) jatemplateCoerceToString;


/*	- (NSNumber *) jatemplateCoerceToNumber
	
	Convert reciever to an NSNumber. May return nil on failure. Used by default
	template operators that expect a number, and should be used for custom
	template operators in the same way.
	
	The default implementation attempts to call -doubleValue, -floatValue,
	-integerValue or -intValue, in that order. If they fail, it returns nil.
	Overriden for NSNumber to return self.
*/
- (NSNumber *) jatemplateCoerceToNumber;


/*	- (NSNumber *) jatemplateCoerceToBoolean
	
	Convert reciever to an boolean NSNumber. May return nil on failure. Used
	by default template operators that expect a boolean, and should be used for
	custom template operators in the same way.
	
	The default implementation attempts to call boolValue. If this is not
	implemented, it returns nil. Overridden for NSNull to return false.
*/
- (NSNumber *) jatemplateCoerceToBoolean;

@end


@interface NSObject (JATCoercible) <JATCoercible>
@end


#pragma mark - Implementation details

/*
	JAT_DoExpandTemplateUsingMacroKeysAndValues()
	JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues()
	
	Implementation details, do not call directly.
*/
FOUNDATION_EXTERN NSString *JAT_DoExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSString *names, NSArray *objects);

FOUNDATION_EXTERN NSString *JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSBundle *bundle, NSString *localizationTable, NSString *names, NSArray *objects);


#define JATExpand(TEMPLATE, ...) \
	JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, nil, nil, \
	@#__VA_ARGS__, @[ __VA_ARGS__ ])

#define JATExpandLiteral(TEMPLATE, ...) \
	JAT_DoExpandTemplateUsingMacroKeysAndValues(TEMPLATE, \
	@#__VA_ARGS__, @[ __VA_ARGS__ ])

#define JATExpandFromTable(TEMPLATE, TABLE, ...) \
	JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, nil, TABLE, \
	@#__VA_ARGS__, @[ __VA_ARGS__ ])

#define JATExpandFromTableInBundle(TEMPLATE, TABLE, BUNDLE, ...) \
	JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, BUNDLE, TABLE, \
	@#__VA_ARGS__, @[ __VA_ARGS__ ])

#define JATExpandWithParameters(TEMPLATE, PARAMETERS) \
	JATExpandFromTableInBundleWithParameters(TEMPLATE, nil, nil, PARAMETERS)

FOUNDATION_EXTERN NSString *JATExpandLiteralWithParameters(NSString *templateString, NSDictionary *parameters);

#define JATExpandFromTableWithParameters(TEMPLATE, TABLE, PARAMETERS) \
	JATExpandFromTableInBundleWithParameters(TEMPLATE, TABLE, nil, PARAMETERS)

FOUNDATION_EXTERN NSString *JATExpandFromTableInBundleWithParameters(NSString *templateString, NSString *localizationTable, NSBundle *bundle, NSDictionary *parameters);


#define JATAppend(MSTRING, TEMPLATE, ...) \
	[MSTRING appendString:JATExpand(TEMPLATE, __VA_ARGS__)]

#define JATAppendLiteral(MSTRING, TEMPLATE, ...) \
	[MSTRING appendString:JATExpandLiteral(TEMPLATE, __VA_ARGS__)]

#define JATAppendFromTable(MSTRING, TEMPLATE, TABLE, ...) \
	[MSTRING appendString:JATExpandFromTable(TEMPLATE, TABLE, __VA_ARGS__)]

#define JATAppendFromTableInBundle(MSTRING, TEMPLATE, TABLE, BUNDLE, ...) \
	[MSTRING appendString:JATExpandFromTableInBundle(TEMPLATE, TABLE, BUNDLE, __VA_ARGS__)]


#define JATLog(TEMPLATE, ...)  NSLog(@"%@", JATExpandLiteral(TEMPLATE, __VA_ARGS__))
#define JATLogLocalized(TEMPLATE, ...)  NSLog(@"%@", JATExpand(TEMPLATE, __VA_ARGS__))


#define JATAssert(CONDITION, TEMPLATE, ...)  NSAssert1(CONDITION, @"%@", JATExpandLiteral(TEMPLATE, __VA_ARGS__))
#define JATCAssert(CONDITION, TEMPLATE, ...)  NSCAssert1(CONDITION, @"%@", JATExpandLiteral(TEMPLATE, __VA_ARGS__))
