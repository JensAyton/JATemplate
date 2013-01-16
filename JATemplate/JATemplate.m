/*

JATemplate.m

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

#import "JATemplate.h"


/*
	Cache limit.
	
	By default, an NSCache is used in ParseNames (per thread) to cache the
	mapping of <names> parameters to parsed name arrays. Set
	JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT to 0 at command line to disable
	the cache.
*/
#ifndef JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT
#define JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT	64
#endif

/*
	Enable or disable syntax warnings.
*/

#ifndef JATEMPLATE_SYNTAX_WARNINGS
#ifdef NDEBUG
#define JATEMPLATE_SYNTAX_WARNINGS 0
#else
#define JATEMPLATE_SYNTAX_WARNINGS 1
#endif
#endif

#if JATEMPLATE_SYNTAX_WARNINGS
static void Warn(const unichar characters[], NSUInteger length, NSString *format, ...)  NS_FORMAT_FUNCTION(3, 4);
#else
#define Warn(...) do {} while (0)
#endif


static NSString * const kJATemplateParseCacheThreadDictionaryKey = @"se.ayton.jens JATemplate parse cache";

enum
{
	kStackStringLimit		= 1024	// Largest string length we'll allocate on the stack.
};


static NSDictionary *JATBuildParameterDictionary(NSString *names, JATParameterArray objects, NSUInteger expectedCount);
static NSString *JATExpandInternal(const unichar *stringBuffer, NSUInteger length, NSDictionary *parameters);

static bool IsIdentifierStartChar(unichar value);
static bool IsIdentifierChar(unichar value);
#ifndef NS_BLOCK_ASSERTIONS
static bool IsValidIdentifier(NSString *candidate);
#endif
static bool ScanIdentifier(const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger *outEnd);


#pragma mark - Public

/*
	JAT_DoExpandTemplateUsingMacroKeysAndValues(template, names, paddedObjectArray, expectedCount)
	
		- template is the string to expand - for example, @"foo = {foo}, bar = {bar}".
		- names is the preprocessor stringification of the parameter list -
		  for example, "foo, @(bar)". Note that the preprocessor will remove
		  comments for us.
		- objects is an array of the parameter values.
		- expectedCount is the number of parameters. This can be inferred from
		  <names>, but we use a value calculated using the preprocessor for
		  sanity checking.
*/
NSString *JAT_DoExpandTemplateUsingMacroKeysAndValues(NSString *template, NSString *names, JATParameterArray objects, NSUInteger expectedCount)
{
	NSCParameterAssert(template != nil);
	NSCParameterAssert(names != nil);
	NSCParameterAssert(objects != NULL);
	
	/*	Non-optimization: it's tempting to short-circuit here if there are no
		parameters, but that breaks if there are {(} escapes.
	*/
	
	// Build dictionary of parametes and hand off to Boring Mode.
	NSDictionary *parameters = JATBuildParameterDictionary(names, objects, expectedCount);
	if (parameters == nil)  return template;
	
	return JATExpandLiteralWithParameters(template, parameters);
}


/*
	JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(...)
	
	Equivalent to using one of the NSLocalizedString macro family before calling
	JAT_DoExpandTemplateUsingMacroKeysAndValues().
*/
NSString *JAT_DoLocalizeAndExpandTemplateUsingMacroKeysAndValues(NSString *template, NSBundle *bundle, NSString *localizationTable, NSString *names, JATParameterArray objects, NSUInteger count)
{
	// Perform the equivalent of NSLocalizedString*().
	if (bundle == nil)  bundle = [NSBundle mainBundle];
	template = [bundle localizedStringForKey:template value:@"" table:localizationTable];
	
	return JAT_DoExpandTemplateUsingMacroKeysAndValues(template, names, objects, count);
}


NSString *JATExpandLiteralWithParameters(NSString *template, NSDictionary *parameters)
{
	/*
		Extract template string into a buffer on the stack or, if it's big,
		a malloced buffer.
	*/
	NSUInteger length = template.length;
	NSUInteger bufferSize = length;
	bool useHeapAllocation = length > kStackStringLimit;
	if (useHeapAllocation)  bufferSize = 1;
	unichar *stringBuffer = NULL;
	unichar stackBuffer[bufferSize];
	if (useHeapAllocation)
	{
		stringBuffer = malloc(sizeof *stringBuffer * bufferSize);
		if (stringBuffer == NULL)  return nil;
	}
	else
	{
		stringBuffer = stackBuffer;
	}
	
	@try
	{
		[template getCharacters:stringBuffer];
		
		// Do the work.
		return JATExpandInternal(stringBuffer, length, parameters);
	}
	@finally
	{
		if (useHeapAllocation)  free(stringBuffer);
	}
}


NSString *JATExpandFromTableInBundleWithParameters(NSString *template, NSString *localizationTable, NSBundle *bundle, NSDictionary *parameters)
{
	// Perform the equivalent of NSLocalizedString*().
	if (bundle == nil)  bundle = [NSBundle mainBundle];
	template = [bundle localizedStringForKey:template value:@"" table:localizationTable];
	
	return JATExpandLiteralWithParameters(template, parameters);
}


#pragma mark - Name string parsing

static NSArray *JATemplateParseNames(NSString *nameString, NSUInteger expectedCount);
static NSArray *JATemplateParseNamesUncached(NSString *nameString, NSUInteger expectedCount);
static NSString *JATemplateParseOneName(NSString *name);


static NSDictionary *JATBuildParameterDictionary(NSString *names, JATParameterArray objects, NSUInteger expectedCount)
{
	// Parse <names> into an array of identifiers. This also strips boxing @() syntax.
	NSArray *parameterNames = JATemplateParseNames(names, expectedCount);
	if (parameterNames == nil)  return nil;
	
	// Stick parameter values in an array, replacing nils with [NSNull null].
	NSNull *null = nil;
	__unsafe_unretained id shadowArray[expectedCount];
	for (NSUInteger i = 0; i < expectedCount; i++)
	{
		id value = objects[i];
		if (value != nil)
		{
			shadowArray[i] = value;
		}
		else
		{
			if (null == nil)  null = [NSNull null];
			shadowArray[i] = null;
		}
	}
	NSArray *parameterValues = [NSArray arrayWithObjects:shadowArray count:expectedCount];
	
	// Build dictionary of parameters.
	return [NSDictionary dictionaryWithObjects:parameterValues forKeys:parameterNames];
}


/*
	JATemplateParseNames(nameString, expectedCount)
	
	Convert a string produced by stringifying __VA_ARGS__ in one of the wrapper
	macros to an array of <expectedCount> identifiers.
	
	The string will be a comma-separated list of expressions with comments
	stripped, but with whitespace otherwise intact.
	
	If an item is wrapped in @(), this is removed, allowing boxing expressions
	to be used directly. For example, JATExpand(@"{foo}{bar}", foo, @(bar))
	produces @"foo, @( bar )", which is mapped to @[@"foo", @"bar"].
	
	It is asserted that the string contains the correct number of items and
	that each expression is in fact a single identifier. Assertion is considered
	sufficient since these strings come directly from source code, not data
	files, so disabling assertions does not result in an equivalent to format
	string attack vulnerabilities, only increased exposure to bugs in the
	template system and client code.
	
	JATemplateParseNames() is not optimized. It should be significantly more
	efficient to take the name string as a const char[] and do a singe-pass
	scan, extracting NSStrings directly from identifier ranges. However, for
	most practical uses cases where JATemplateParseNames() is a significant
	cost, raising the cache limit is probably a better bet.
*/
static NSArray *JATemplateParseNames(NSString *nameString, NSUInteger expectedCount)
{
	NSCParameterAssert(nameString != nil);
	
	NSArray *result;
#if JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT > 0
	NSMutableDictionary *threadDictionary = NSThread.currentThread.threadDictionary;
	NSCache *cache = threadDictionary[kJATemplateParseCacheThreadDictionaryKey];
	result = [cache objectForKey:nameString];
	if (result != nil)
	{
		return result;
	}
#endif
	
	result = JATemplateParseNamesUncached(nameString, expectedCount);
	
#if JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT > 0
	if (cache == nil)
	{
		cache = [NSCache new];
		cache.name = kJATemplateParseCacheThreadDictionaryKey;
		cache.countLimit = JATEMPLATE_NAME_PARSE_CACHE_COUNT_LIMIT;
		threadDictionary[kJATemplateParseCacheThreadDictionaryKey] = cache;
	}
	[cache setObject:result forKey:nameString];
#endif
	
	return result;
}


static NSArray *JATemplateParseNamesUncached(NSString *nameString, NSUInteger expectedCount)
{
	if (expectedCount == 0)
	{
		NSCParameterAssert(nameString.length == 0);
		return @[];
	}
	
	NSArray *components = [nameString componentsSeparatedByString:@","];
	NSCAssert(components.count == expectedCount, @"Expected %lu variable names in template expansion, got %lu. The problem name string is: \"%@\".", expectedCount, components.count, nameString);
	
	NSString *cleanedNames[expectedCount];
	
	// Trim out whitespace. NOTE: the preprocessor handles comments for us.
	NSUInteger idx = 0;
	for (NSString *name in components)
	{
		cleanedNames[idx++] = JATemplateParseOneName(name);
	}
	
#ifndef NS_BLOCK_ASSERTIONS
	// Verify that the parsed names are identifiers.
	for (idx = 0; idx < expectedCount; idx++)
	{
		NSCAssert(IsValidIdentifier(cleanedNames[idx]), @"Template variable list doesn't look like a list of identifiers - got \"%@\" from \"%@\".", cleanedNames[idx], nameString);
	}
#endif
	
	return [NSArray arrayWithObjects:cleanedNames count:expectedCount];
}


static NSString *JATemplateParseOneName(NSString *name)
{
	NSCharacterSet *whiteSpace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
	
	name = [name stringByTrimmingCharactersInSet:whiteSpace];
	
	/*	Handle boxing expressions: "@(foo)" -> "foo".
		Syntax note: @ (foo) is invalid, so we can treat @( as one token.
		However, we need to strip out whitespace inside the parentheses.
	*/
	if (name.length > 3 && [name characterAtIndex:0] == '@')
	{
		NSUInteger length = name.length;
		NSCAssert([name characterAtIndex:1] == '(' && [name characterAtIndex:length - 1] == ')', @"Identified a boxed variable but didn't find expected parentheses when parsing variable name \"%@\".", name);
		
		name = [name substringWithRange:(NSRange){2, length - 3}];
		name = [name stringByTrimmingCharactersInSet:whiteSpace];
	}
	
	return name;
}


#pragma mark - Template parsing
static NSString *JATExpandOneSub(const unichar characters[], NSUInteger length, NSUInteger idx, NSUInteger *replaceLength, NSDictionary *parameters);
static NSString *JATExpandOneSimpleSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters);
static NSString *JATExpandOneFancyPantsSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters);

static void JATemplateAppendCharacters(NSMutableString *buffer, const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger end);


/*
	JATExpandInternal(characters, length, parameters)
	
	Parse a template string and substitute the parameters. In other words, do
	the actual work after the faffing about parsing names and so forth.
*/
static NSString *JATExpandInternal(const unichar characters[], NSUInteger length, NSDictionary *parameters)
{
	NSCParameterAssert(characters != NULL);
	
	// Nothing to expand in an empty string, and the length-1 thing below would be trouble.
	if (length == 0)  return @"";
	
	NSMutableString *result = [NSMutableString string];
	
	/*	Beginning of current range of non-special characters. When we encounter
		a substitution, we'll be copying from here forward.
	*/
	NSUInteger copyRangeStart = 0;
	
	/*	The iteration limit is length - 1 because every valid substitution is at
		least 3 characters long. This way, characters[idx + 1] is always valid.
	*/
	for (NSUInteger idx = 0; idx < length - 1; idx++)
	{
		NSString *replacement = nil;
		NSUInteger replaceLength = 0;
		unichar thisChar = characters[idx];
		
		if (thisChar == '{')
		{
			replacement = JATExpandOneSub(characters, length, idx, &replaceLength, parameters);
		}
		// Other types of replacement can easily be chained here.
		
		if (replacement != nil)
		{
			NSCAssert(replaceLength != 0, @"Internal error in JATemplate: substitution length is zero, which will lead to an infinite loop.");
			
			// Write the pending literal segment to result.
			JATemplateAppendCharacters(result, characters, length, copyRangeStart, idx);
			[result appendString:replacement];
			
			// Skip over replaced part and start a new literal segment.
			idx += replaceLength - 1;
			copyRangeStart = idx + 1;
		}
	}
	
	// Append any trailing literal segment.
	JATemplateAppendCharacters(result, characters, length, copyRangeStart, length);
	
	return result;
}


static NSString *JATExpandOneSub(const unichar characters[], NSUInteger length, NSUInteger idx, NSUInteger *replaceLength, NSDictionary *parameters)
{
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(idx < length - 1);
	NSCParameterAssert(replaceLength != NULL);
	NSCParameterAssert(characters[idx] == '{');
	
	// Find the balancing close brace.
	NSUInteger end, balanceCount = 1;
	bool isIdentifier = IsIdentifierStartChar(characters[idx + 1]);
	
	for (end = idx + 1; end < length && balanceCount > 0; end++)
	{
		if (characters[end] == '}')  balanceCount--;
		else
		{
			isIdentifier = isIdentifier && IsIdentifierChar(characters[end]);
			if (characters[end] == '}')  balanceCount++;
		}
	}
	
	// Fail if no balancing bracket. (Not asserted since input is format string.)
	if (balanceCount != 0)
	{
		Warn(characters, length, @"Unbalanced braces in template string.");
		return nil;
	}
	
	*replaceLength = end - idx;
	NSUInteger keyStart = idx + 1, keyLength = *replaceLength - 2;
	if (keyLength == 0)
	{
		Warn(characters, length, @"Empty substitution expression in template string. To silence this message, use {(}{)} instead of {}.");
		return nil;
	}
	
	if (isIdentifier)
	{
		return JATExpandOneSimpleSub(characters, length, keyStart, keyLength, parameters);
	}
	else
	{
		return JATExpandOneFancyPantsSub(characters, length, keyStart, keyLength, parameters);
	}
}


/*
	JATExpandOneSimpleSub()
	
	Handles cases where the substitution token is a simple identifier.
*/
static NSString *JATExpandOneSimpleSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters)
{
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(keyStart < length);
	NSCParameterAssert(keyStart + keyLength < length);
	
	NSString *key = [NSString stringWithCharacters:characters + keyStart length:keyLength];
	id value = parameters[key];
	if (value == nil)
	{
		Warn(characters, length, @"Template substitution uses unknown key \"%@\".", key);
	}
	return [value jatemplateCoerceToString];
}


/*
	JATExpandOneFancyPantsSub()
	
	Handles cases where the substitution token is something other than a simple
	identifier. Length is guaranteed not to be zero.
*/
static NSString *JATExpandOneFancyPantsSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters)
{
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(keyStart < length);
	NSCParameterAssert(length > 0);
	NSCParameterAssert(keyStart + keyLength < length);
	
	unichar first = characters[keyStart];
	if (keyLength == 1)
	{
		/*	Escape code {(} allows literal {s in templates. {)} is unnecessary
			but provides aesthetic harmony. ({{} is not possible because the
			parser requires braces to be balanced.)
		*/
		if (first == '(')  return @"{";
		if (first == ')')  return @"}";
	}
	
	bool isIdentifier = ScanIdentifier(characters, length, keyStart, &keyLength);
	if (!isIdentifier)
	{
		// No other forms starting with non-identifiers are defined.
		Warn(characters, length, @"Unkown template substitution syntax {%@}.", [NSString stringWithCharacters:characters + keyStart length:keyLength]);
		return nil;
	}
	
	// extract the identifier.
	NSString *identifier = [NSString stringWithCharacters:characters + keyStart length:keyLength];
	
	// At this point, we expect one or more bars, each followed by an operator expression.
	NSUInteger cursor = keyStart + keyLength;
	if (characters[cursor] != '|')
	{
		Warn(characters, length, @"Unexpected character '%@' in template substitution {%@}.", [NSString stringWithCharacters:characters + cursor length:1], [NSString stringWithCharacters:characters + keyStart length:keyLength]);
		return nil;
	}
	
	id value = parameters[identifier];
	if (value == nil)
	{
		Warn(characters, length, @"Template substitution uses unknown key \"%@\".", identifier);
		return nil;
	}
	
	while (value != nil && characters[cursor] == '|')
	{
		cursor++;
		NSUInteger opLength;
		isIdentifier = ScanIdentifier(characters, length, cursor, &opLength);
		if (!isIdentifier)
		{
			Warn(characters, length, @"Expected identifier after | in {%@}.", [NSString stringWithCharacters:characters + keyStart length:keyLength]);
			return nil;
		}
		
		NSString *operator = [NSString stringWithCharacters:characters + cursor length:opLength];
		cursor += opLength;
		
		NSString *argument = nil;
		if (characters[cursor] == ':')
		{
			// Everything up to the next | or } is the argument.
			cursor++;
			NSUInteger argStart = cursor;
			for (; cursor < length; cursor++)
			{
				if (characters[cursor] == '|' || characters[cursor] == '}')
				{
					break;
				}
			}
			
			argument = [NSString stringWithCharacters:characters + argStart length:cursor - argStart];
		}
		
		value = [value jatemplatePerformOperator:operator withArgument:argument variables:parameters];
	}
	
	return [value jatemplateCoerceToString];
}


static void JATemplateAppendCharacters(NSMutableString *buffer, const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger end)
{
	NSCParameterAssert(buffer != nil);
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(start <= end);
	NSCParameterAssert(start <= length);
	NSCParameterAssert(end <= length);
	if (start == end)  return;
	
	CFStringAppendCharacters((__bridge CFMutableStringRef)buffer, characters + start, end - start);
}


static NSString * const kIdentifierStartChars = @"qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM_$0123456789";
static NSString * const kIdentifierChars = @"qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM_$";


static bool IsIdentifierStartChar(unichar value)
{
	static NSCharacterSet *initialChars;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		initialChars = [NSCharacterSet characterSetWithCharactersInString:kIdentifierStartChars];
	});
	
	return [initialChars characterIsMember:value];
}


static bool IsIdentifierChar(unichar value)
{
	static NSCharacterSet *identifierChars;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		identifierChars = [NSCharacterSet characterSetWithCharactersInString:kIdentifierChars];
	});
	
	return [identifierChars characterIsMember:value];
}


#ifndef NS_BLOCK_ASSERTIONS
static bool IsValidIdentifier(NSString *candidate)
{
	NSCParameterAssert(candidate != nil);
	
	static NSCharacterSet *nonIdentifierChars;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		nonIdentifierChars = [[NSCharacterSet characterSetWithCharactersInString:kIdentifierChars] invertedSet];
	});
	
	return IsIdentifierStartChar([candidate characterAtIndex:0]) &&
		   [candidate rangeOfCharacterFromSet:nonIdentifierChars].location == NSNotFound;
}
#endif


static bool ScanIdentifier(const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger *outIdentifierLength)
{
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(start < length);
	NSCParameterAssert(outIdentifierLength != NULL);
	
	if (!IsIdentifierStartChar(characters[start]))  return false;
	
	NSUInteger end;
	for (end = start + 1; end < length; end++)
	{
		if (!IsIdentifierChar(characters[end]))  break;
	}
	
	*outIdentifierLength = end - start;
	return true;
}


#if JATEMPLATE_SYNTAX_WARNINGS
static void Warn(const unichar characters[], NSUInteger length, NSString *format, ...)
{
	va_list args;
	va_start(args, format);
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
	va_end(args);
	
	if (characters != NULL)
	{
		message = [NSString stringWithFormat:@"%@ (Template: \"%@\")", message, [NSString stringWithCharacters:characters length:length]];
	}
	
	NSLog(@"%@", message);
}
#endif


#pragma mark - Operators

@implementation NSObject (JATTemplateOperators)

- (id) jatemplatePerformOperator:(NSString *)operator withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	// Dogfood note: it would be a bad idea to use an operator in this template.
	NSString *opImplementationName = JATExpandLiteral(@"jatemplatePerform_{operator}_withArgument:variables:", operator);
	SEL selector = NSSelectorFromString(opImplementationName);
	
	if ([self respondsToSelector:selector])
	{
		typedef id (*OperatorIMP)(id, SEL, NSString *, NSDictionary *);
		OperatorIMP imp = (OperatorIMP)[self methodForSelector:selector];
		return imp(self, selector, argument, variables);
	}
	else
	{
		Warn(NULL, 0, @"Unknown operator \"%@\" in template expansion.", operator);
		return nil;
	}
}


- (NSString *) jatemplateCoerceToString
{
	return [self description];
}


- (NSNumber *) jatemplateCoerceToNumber
{
	if ([self respondsToSelector:@selector(doubleValue)])
	{
		return @([(id)self doubleValue]);
	}
	if ([self respondsToSelector:@selector(floatValue)])
	{
		return @([(id)self floatValue]);
	}
	if ([self respondsToSelector:@selector(integerValue)])
	{
		return @([(id)self integerValue]);
	}
	if ([self respondsToSelector:@selector(intValue)])
	{
		return @([(id)self intValue]);
	}
	
	return nil;
}


- (NSNumber *) jatemplateCoerceToBoolean
{
	if ([self respondsToSelector:@selector(boolValue)])
	{
		return [(id)self boolValue] ? @YES : @NO;
	}
	return nil;
}


#ifndef JATEMPLATE_SUPPRESS_DEFAULT_OPERATORS

- (id) jatemplatePerform_num_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if ([argument isEqual:@"decimal"] || [argument isEqual:@"dec"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterDecimalStyle];
	}
	if ([argument isEqual:@"noloc"])
	{
		return [value description];
	}
	if ([argument isEqual:@"currency"] || [argument isEqual:@"cur"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterCurrencyStyle];
	}
	if ([argument isEqual:@"percent"] || [argument isEqual:@"pct"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterPercentStyle];
	}
	if ([argument isEqual:@"scientific"] || [argument isEqual:@"sci"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterScientificStyle];
	}
	if ([argument isEqual:@"spellout"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterSpellOutStyle];
	}
	if ([argument isEqual:@"filebytes"] || [argument isEqual:@"file"] || [argument isEqual:@"bytes"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleFile];
	}
	if ([argument isEqual:@"memorybytes"] || [argument isEqual:@"memory"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleMemory];
	}
	if ([argument isEqual:@"decimalbytes"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleDecimal];
	}
	if ([argument isEqual:@"binarybytes"])
	{
		return [NSByteCountFormatter stringFromByteCount:value.longLongValue countStyle:NSByteCountFormatterCountStyleBinary];
	}
	
	NSNumberFormatter *formatter = [NSNumberFormatter new];
	formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
	formatter.format = argument;
	
	return [formatter stringFromNumber:value];
}


- (id) jatemplatePerform_round_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	long long rounded = llround(value.doubleValue);
	
	return [NSNumber numberWithLongLong:rounded];
}


- (id) jatemplatePerform_plural_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		Warn(NULL, 0, @"Template operator plural: used with no argument.");
	}
	
	NSArray *components = [argument componentsSeparatedByString:@";"];
	
	bool isPlural = ![value isEqual:@(1)];
	
	NSUInteger count = components.count;
	if (count == 1)
	{
		// One argument: use argument for plural, empty string for singular.
		return isPlural ? argument : @"";
	}
	else if (count == 2)
	{
		// Two arguments: singular;plural
		return isPlural ? components[1] : components[0];
	}
	else if (count == 3)
	{
		// Two arguments: singular;dual;plural
		if (!isPlural)  return components[0];
		else if ([value isEqual:@(2)])
		{
			return components[1];
		}
		else
		{
			return components[2];
		}
	}
	else
	{
		Warn(NULL, 0, @"Template operator plural: requires one to three arguments, got \"%@\".", argument);
		return nil;
	}
}


- (id) jatemplatePerform_not_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToBoolean];
	if (value == nil)  return nil;
	
	return value.boolValue ? @NO : @YES;
}


- (id) jatemplatePerform_if_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToBoolean];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		Warn(NULL, 0, @"Template operator if: used with no argument.");
	}
	
	NSArray *components = [argument componentsSeparatedByString:@";"];
	
	id trueValue = components[0], falseValue = @"";
	if (components.count > 1)  falseValue = components[1];
	
	return value.boolValue ? trueValue : falseValue;
}


- (id) jatemplatePerform_ifuse_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToBoolean];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		Warn(NULL, 0, @"Template operator ifuse: used with no argument.");
	}
	
	NSArray *components = [argument componentsSeparatedByString:@";"];
	
	NSString *trueKey = components[0], *falseKey = nil;
	if (components.count > 1)  falseKey = components[1];
	
	NSString *selectedKey = value.boolValue ? trueKey : falseKey;
	
	if (selectedKey != nil)
	{
		NSString *result = variables[selectedKey];
		if (result == nil)
		{
			Warn(NULL, 0, @"Template substitution uses unknown key \"%@\" in ifuse: operator.", selectedKey);
		}
		return result;
	}
	else
	{
		return @"";
	}
}


- (id) jatemplatePerform_uppercase_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseStringWithLocale:nil];
}


- (id) jatemplatePerform_lowercase_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseStringWithLocale:nil];
}


- (id) jatemplatePerform_capitalize_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedStringWithLocale:nil];
}


- (id) jatemplatePerform_uppercase_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseString];
}


- (id) jatemplatePerform_lowercase_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseString];
}


- (id) jatemplatePerform_capitalize_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedString];
}


- (id) jatemplatePerform_trim_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}


- (id) jatemplatePerform_length_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return @(value.length);
}


- (id) jatemplatePerform_fold_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	NSStringCompareOptions optionMask = 0;
	for (NSString *option in [argument componentsSeparatedByString:@","])
	{
		if ([option isEqual:@"case"])
		{
			optionMask |= NSCaseInsensitiveSearch;
		}
		else if ([option isEqual:@"diacritics"])
		{
			optionMask |= NSDiacriticInsensitiveSearch;
		}
		else if ([option isEqual:@"width"])
		{
			optionMask |= NSWidthInsensitiveSearch;
		}
		else
		{
			Warn(NULL, 0, @"Unknown option \"%@\" for \"fold\" template operator.", option);
		}
	}
	
	if (optionMask == 0)  return value;
	
	return [value stringByFoldingWithOptions:optionMask locale:NSLocale.currentLocale];
}


- (id) jatemplatePerform_debugdesc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	if ([self respondsToSelector:@selector(debugDescription)])
	{
		return [self debugDescription];
	}
	else
	{
		return [self description];
	}
}

#endif

@end


@implementation NSString (JATTemplateOperators)

- (NSString *) jatemplateCoerceToString
{
	return self;
}

@end


@implementation NSNull (JATTemplateOperators)

- (NSString *) jatemplateCoerceToString
{
	return @"(null)";
}


- (NSNumber *) jatemplateCoerceToBoolean
{
	return @NO;
}

@end


@implementation NSNumber (JATTemplateOperators)

- (NSString *) jatemplateCoerceToString
{
	return [NSNumberFormatter localizedStringFromNumber:self numberStyle:NSNumberFormatterDecimalStyle];
}


- (NSNumber *) jatemplateCoerceToNumber
{
	return self;
}

@end
