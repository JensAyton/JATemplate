//
//  JATemplate.h
//  JATemplate
//
//  Created by Jens Ayton on 2013-01-07.
//  Copyright (c) 2013 Jens Ayton. All rights reserved.
//

#import <Foundation/Foundation.h>
/*
	The notional interface for the expansion system is as follows. The actual
	implementations are mostly macros as defined below.
	
	NSString *JATExpand(NSString *template, ...)
		Look up <template> in the bundle's Localizable.strings, if possible,
		otherwise use it as-is. Replace all substitution expressions in the
		template string with corresponding named variable. For example,
		NSString *foo = @"banana"; JATExpand(@"test: {foo}", foo); returns
		@"test: banana" (unless of course the template is localized).
		
		Parameters must be variables of object type, not expressions, except
		that the boxing syntax for numbers and C strings is supported: for
		example, int bar = 5; JATExpand(@"A number: {bar}", @(bar)); works.
		Nils are replaced with NSNull (which is printed as "(null)").
		
		Parameters may be modified using modifiers, which are specified using
		a vertical bar. Operators may optionally have a parameter, seperated
		by a colon. Several operators may be chained. Examples:
			{foo|uppercase}
			{bar|num:$#,##0.00}
			{baz|num:spellout|capitalize}
		More information about operators is found further down the header.
		
		Template syntax is quite strict. In particular, there is no optional
		whitespace.
	
	NSString *JATExpandLiteral(NSString *template, ...)
		Like JATExpand(), but without the Localizable.strings lookup.
	
	NSString *JATExpandLiteral(NSString *template, NSString *table, ...)
		Like JATExpand(), but allows you to specify a strings file other than
		Localizable.strings. The table name should be specified without the
		.strings extension. Compare NSLocalizedStringFromTable().
	
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
		are looked up in <parameters> instead of using variables. Attempts to
		localize using Localizable.strings.
	
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
	
	
	void JATLog(NSString *message, ...)
		Combines JATExpandLiteral() with NSLog() in the obvious way.
	
	void JATLogLocalized(NSString *message, ...)
		Combines JATExpand() with NSLog() in the obvious way.
	
	
	The following operators are built in. They can be suppressed by defining
	JATEMPLATE_SUPPRESS_DEFAULT_OPERATORS.
	
		num:
		Format numbers. The argument may be an NSNumberFormatter format string,
		or one of the following constants for locale-sensitive formatting:
		- decimal or dec
		  Decimal formatting using NSNumberFormatterDecimalStyle.
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
		
		plural:
		Takes one to three arguments separated by semicolons. If one argument
		is provided, the argument is returned if the value is plural and the
		empty string is returned otherwise. If there are two arguments, the
		first is used for singular and the second for plural. If there are
		three arguments, the first is singular, the second is dual (i.e., used
		for exactly two items) and the third is plural.
		Example: "I have {gooseCount} {gooseCount|plural:goose;geese}.".
		
		not
		Coerces the value to a boolean and returns its negation.
		
		if:
		Takes one or two arguments separated by semicolons. If the value, as a
		boolean, is true, returns the first argument. Otherwise returns the
		second argument (or the empty string if none).
		Example: "The flag is {flag|if:set;not set}."
		
		ifuse:
		Like if:, but treats its arguments as parameter keys:
		Example: "If the flag is true, \"{flag|ifuse:trueString:falseString}
		is {trueString}, otherwise it's {falseString}."
		
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
*/

typedef __strong id JATParameterArray[];


#define JATExpand(TEMPLATE, ...) \
	JATLocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, nil, nil, \
	@#__VA_ARGS__, (JATParameterArray){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JATExpandLiteral(TEMPLATE, ...) \
	JATExpandTemplateUsingMacroKeysAndValues(TEMPLATE, \
	@#__VA_ARGS__, (JATParameterArray){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JATExpandFromTable(TEMPLATE, TABLE, ...) \
	JATLocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, nil, TABLE, \
	@#__VA_ARGS__, (JATParameterArray){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JATExpandFromTableInBundle(TEMPLATE, TABLE, BUNDLE, ...) \
	JATLocalizeAndExpandTemplateUsingMacroKeysAndValues(TEMPLATE, BUNDLE, TABLE, \
	@#__VA_ARGS__, (JATParameterArray){ __VA_ARGS__ }, JATEMPLATE_ARGUMENT_COUNT(__VA_ARGS__))

#define JATExpandWithParameters(TEMPLATE, PARAMETERS) \
	JATExpandFromTableInBundleWithParameters(TEMPLATE, nil, nil, PARAMETERS)

NSString *JATExpandLiteralWithParameters(NSString *templateString, NSDictionary *parameters);

#define JATExpandFromTableWithParameters(TEMPLATE, TABLE, PARAMETERS) \
	JATExpandFromTableInBundleWithParameters(TEMPLATE, TABLE, nil, PARAMETERS)

NSString *JATExpandFromTableInBundleWithParameters(NSString *templateString, NSString *localizationTable, NSBundle *bundle, NSDictionary *parameters);

#define JATLog(TEMPLATE, ...)  NSLog(@"%@", JATExpandLiteral(TEMPLATE, __VA_ARGS__))

#define JATLogLocalized(TEMPLATE, ...)  NSLog(@"%@", JATExpand(TEMPLATE, __VA_ARGS__))


@interface NSObject (JATTemplateOperators)

/*	-jatemplatePerformOperator:argument:variables: implements formatting
	operators in template substitutions. The default implementation builds and
	calls a selector based on the operator name according to the following pattern:
		- (id) jatemplatePerform_{operator}_withArgument:(NSString *)argument variables:(NSDictionary *)variables;
	
	Argument is the string following a colon in the operator expression, or nil
	if there is no colon. Variables is a dictionary of all the variables passed
	to JATExpand*().
	
	For example, a substitution of the form {foo|num:spellout} is turned into
	a call to -jatemplatePerform_num_withArgument:@"spellout" variables:variables.
	
	The recommended pattern is to implement operators as categories on NSObject
	and coerce the object to the required class. For some custom operators, it
	may be reasonable to implement them on a specific class instead.
	
	Operators signal failure by returning nil.
	
	If no operator implementation is found, the default implementation of
	-jatemplatePerformOperator:withArgument: returns nil.
*/
- (id) jatemplatePerformOperator:(NSString *)op withArgument:(NSString *)argument variables:(NSDictionary *)variables;


/*	- (NSNumber *) jatemplateCoerceToString
	
	Convert reciever to an NSString. May return nil on failure. Used by default
	template operators that expect a string, and should be used for custom
	template operators in the same way. Also used to convert the result of a
	series of operators, or a variable with no operators applied, to a string
	for insertion in the template.
	
	The default implementation calls -description. Overridden for NSNull to
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


/*
	JATExpandTemplateUsingMacroKeysAndValues()
	JATLocalizeAndExpandTemplateUsingMacroKeysAndValues()
	
	Implementation details, do not call directly.
*/
NSString *JATExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSString *names, JATParameterArray objects, NSUInteger count);

NSString *JATLocalizeAndExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSBundle *bundle, NSString *localizationTable, NSString *names, JATParameterArray objects, NSUInteger count);


/*
	Macros to assist with sanity checking.
	
	JATEMPLATE_ARGUMENT_COUNT returns the number of elements in a __VA_ARGS__
	list. Trivially modified from code by Laurent Deniau and
	"arpad.goret...@gmail.com" (full name not available). Source:
	https://groups.google.com/forum/?fromgroups=#!topic/comp.std.c/d-6Mj5Lko_s
	
	This version relies on the GCC/Clang ##__VA_ARGS__ extension to handle
	zero-length lists. It supports up to 62 arguments.
*/

#define JATEMPLATE_ARGUMENT_COUNT(...) \
		JATEMPLATE_ARGUMENT_COUNT_INNER(_0, ##__VA_ARGS__, JATEMPLATE_ARGUMENT_COUNT_63_VALUES())
#define JATEMPLATE_ARGUMENT_COUNT_INNER(...) \
		JATEMPLATE_ARGUMENT_COUNT_EXTRACT_64TH_ARG(__VA_ARGS__)
#define JATEMPLATE_ARGUMENT_COUNT_EXTRACT_64TH_ARG( \
		 _1, _2, _3, _4, _5, _6, _7, _8, _9,_10, \
		_11,_12,_13,_14,_15,_16,_17,_18,_19,_20, \
		_21,_22,_23,_24,_25,_26,_27,_28,_29,_30, \
		_31,_32,_33,_34,_35,_36,_37,_38,_39,_40, \
		_41,_42,_43,_44,_45,_46,_47,_48,_49,_50, \
		_51,_52,_53,_54,_55,_56,_57,_58,_59,_60, \
		_61,_62,_63,N,...) N
#define JATEMPLATE_ARGUMENT_COUNT_63_VALUES() \
		62,61,60, \
		59,58,57,56,55,54,53,52,51,50, \
		49,48,47,46,45,44,43,42,41,40, \
		39,38,37,36,35,34,33,32,31,30, \
		29,28,27,26,25,24,23,22,21,20, \
		19,18,17,16,15,14,13,12,11,10, \
		9,8,7,6,5,4,3,2,1,0
