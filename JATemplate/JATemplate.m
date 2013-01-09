//
//  JATemplate.m
//  JATemplate
//
//  Created by Jens Ayton on 2013-01-07.
//  Copyright (c) 2013 Jens Ayton. All rights reserved.
//

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


static NSArray *JATemplateParseNames(NSString *nameString, NSUInteger expectedCount);
static NSArray *JATemplateParseNamesUncached(NSString *nameString, NSUInteger expectedCount);
static NSString *JATemplateParseOneName(NSString *name);

static NSString *JAExpandInternal(const unichar *stringBuffer, NSUInteger length, NSDictionary *parameters);
static NSString *JAExpandOneSub(const unichar characters[], NSUInteger length, NSUInteger idx, NSUInteger *replaceLength, NSDictionary *parameters);
static NSString *JAExpandOneSimpleSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters);
static NSString *JAExpandOneFancyPantsSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters);

static void JATemplateAppendCharacters(NSMutableString *buffer, const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger end);

static bool IsIdentifierStartChar(unichar value);
static bool IsIdentifierChar(unichar value);
#ifndef NS_BLOCK_ASSERTIONS
static bool IsValidIdentifier(NSString *candidate);
#endif
static bool ScanIdentifier(const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger *outEnd);


#pragma mark - Template parsing

/*
	JAExpandTemplateUsingMacroKeysAndValues(templateString, names, paddedObjectArray, expectedCount)
	
		- templateString is the string to expand - for example, @"foo = {foo}, bar = {bar}".
		- names is the preprocessor stringification of the parameter list -
		  for example, "foo, @(bar)". Note that the preprocessor will remove
		  comments for us.
		- objects is an array of the parameter values.
		- expectedCount is the number of parameters. This can be inferred from
		  <names>, but we use a value calculated using the preprocessor for
		  sanity checking.
*/
NSString *JAExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSString *names, __unsafe_unretained id objects[], NSUInteger expectedCount)
{
	NSCParameterAssert(templateString != nil);
	NSCParameterAssert(names != nil);
	NSCParameterAssert(objects != NULL);
	
	/*	Non-optimization: it's tempting to short-circuit here if there are no
		parameters, but that breaks if there are {(} escapes.
	*/
	
	// Parse <names> into an array of identifiers. This also strips boxing @() syntax.
	NSArray *parameterNames = JATemplateParseNames(names, expectedCount);
	if (parameterNames == nil)  return templateString;
	
	// Stick parameter values in an array.
	NSArray *parameterValues = [NSArray arrayWithObjects:objects count:expectedCount];
	
	// Build dictionary of parameters.
	NSDictionary *parameters = [NSDictionary dictionaryWithObjects:parameterValues forKeys:parameterNames];
	
	/*
		Extract template string into a buffer on the stack or, if it's big,
		a malloced buffer.
	*/
	NSUInteger length = templateString.length;
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
		[templateString getCharacters:stringBuffer];
		
		// Do the work.
		return JAExpandInternal(stringBuffer, length, parameters);
	}
	@finally
	{
		if (useHeapAllocation)  free(stringBuffer);
	}
}


/*
	JALocalizeAndExpandTemplateUsingMacroKeysAndValues(...)
	
	Equivalent to using one of the NSLocalizedString macro family before calling
	JAExpandTemplateUsingMacroKeysAndValues().
*/
NSString *JALocalizeAndExpandTemplateUsingMacroKeysAndValues(NSString *templateString, NSBundle *bundle, NSString *localizationTable, NSString *names, __unsafe_unretained id paddedObjectArray[], NSUInteger count)
{
	// Perform the equivalent of NSLocalizedString*().
	if (bundle == nil)  bundle = [NSBundle mainBundle];
	templateString = [bundle localizedStringForKey:templateString value:@"" table:localizationTable];
	
	return JAExpandTemplateUsingMacroKeysAndValues(templateString, names, paddedObjectArray, count);
}


/*
	JATemplateParseNames(nameString, expectedCount)
	
	Convert a string produced by stringifying __VA_ARGS__ in one of the wrapper
	macros to an array of <expectedCount> identifiers.
	
	The string will be a comma-separated list of expressions with comments
	stripped, but with whitespace otherwise intact.
	
	If an item is wrapped in @(), this is removed, allowing boxing expressions
	to be used directly. For example, JAExpand(@"{foo}{bar}", foo, @(bar))
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


/*
	JAExpandInternal(characters, length, parameters)
	
	Parse a template string and substitute the parameters. In other words, do
	the actual work after the faffing about parsing names and so forth.
*/
static NSString *JAExpandInternal(const unichar characters[], NSUInteger length, NSDictionary *parameters)
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
			replacement = JAExpandOneSub(characters, length, idx, &replaceLength, parameters);
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


static NSString *JAExpandOneSub(const unichar characters[], NSUInteger length, NSUInteger idx, NSUInteger *replaceLength, NSDictionary *parameters)
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
		return JAExpandOneSimpleSub(characters, length, keyStart, keyLength, parameters);
	}
	else
	{
		return JAExpandOneFancyPantsSub(characters, length, keyStart, keyLength, parameters);
	}
}


/*
	JAExpandOneSimpleSub()
	
	Handles cases where the substitution token is a simple identifier.
*/
static NSString *JAExpandOneSimpleSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters)
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
	JAExpandOneFancyPantsSub()
	
	Handles cases where the substitution token is something other than a simple
	identifier. Length is guaranteed not to be zero.
*/
static NSString *JAExpandOneFancyPantsSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters)
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
		
		value = [value jatemplatePerformOperator:operator withArgument:argument];
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
		message = [NSString stringWithFormat:@"%@ (Template: %@)", message, [NSString stringWithCharacters:characters length:length]];
	}
	
	NSLog(@"%@", message);
}
#endif


#pragma mark - Operators

@implementation NSObject (JATemplateOperators)

- (id) jatemplatePerformOperator:(NSString *)operator withArgument:(NSString *)argument
{
	// Dogfood note: it would be a bad idea to use an operator in this template.
	NSString *opImplementationName = JAExpandLiteral(@"jatemplatePerform_{operator}_withArgument:", operator);
	SEL selector = NSSelectorFromString(opImplementationName);
	
	if ([self respondsToSelector:selector])
	{
		typedef id (*OperatorIMP)(id, SEL, NSString *);
		OperatorIMP imp = (OperatorIMP)[self methodForSelector:selector];
		return imp(self, selector, argument);
	}
	else
	{
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


#ifndef JATEMPLATE_SUPPRESS_DEFAULT_OPERATORS

- (id) jatemplatePerform_num_withArgument:(NSString *)argument
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if ([argument isEqual:@"decimal"] || [argument isEqual:@"dec"])
	{
		return [NSNumberFormatter localizedStringFromNumber:value numberStyle:NSNumberFormatterDecimalStyle];
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


- (id) jatemplatePerform_uppercase_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseStringWithLocale:nil];
}


- (id) jatemplatePerform_lowercase_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseStringWithLocale:nil];
}


- (id) jatemplatePerform_capitalize_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedStringWithLocale:nil];
}


- (id) jatemplatePerform_uppercase_noloc_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseString];
}


- (id) jatemplatePerform_lowercase_noloc_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseString];
}


- (id) jatemplatePerform_capitalize_noloc_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedString];
}


- (id) jatemplatePerform_trim_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}


- (id) jatemplatePerform_length_withArgument:(NSString *)argument
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return @(value.length);
}


- (id) jatemplatePerform_fold_withArgument:(NSString *)argument
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

#endif

@end


@implementation NSString (JATemplateOperators)

- (NSString *) jatemplateCoerceToString
{
	return self;
}

@end


@implementation NSNumber (JATemplateOperators)

- (NSNumber *) jatemplateCoerceToNumber
{
	return self;
}

@end