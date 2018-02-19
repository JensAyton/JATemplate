/*

JATemplateCore.m

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

#import "JATemplateInternal.h"

#if !__has_feature(objc_arc)
#error This file requires ARC.
#endif

enum
{
	kStackStringLimit		= 1024	// Largest string length we'll allocate on the stack.
};


static NSString *JATExpandInternal(const unichar *stringBuffer, NSUInteger length, NSDictionary *parameters, NSString *template);

static bool IsIdentifierStartChar(unichar value);
static bool IsIdentifierChar(unichar value);
static bool IsPositionalChar(unichar value);
static bool ScanIdentifier(const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger *outEnd);
static NSNumber *ReadPositional(const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger *outLength);


#pragma mark - Public

NSString *JATExpandLiteralWithParameters(NSString *template, NSDictionary *parameters)
{
	__block NSString *result;
	JATWithCharacters(template, ^(const unichar characters[], NSUInteger length)
	{
		result = JATExpandInternal(characters, length, parameters, template);
	});
	return result;
}


NSString *JATExpandFromTableInBundleWithParameters(NSString *template, NSString *localizationTable, NSBundle *bundle, NSDictionary *parameters)
{
	// Perform the equivalent of NSLocalizedString*().
	if (bundle == nil)  bundle = [NSBundle mainBundle];
	template = [bundle localizedStringForKey:template value:@"" table:localizationTable];
	
	return JATExpandLiteralWithParameters(template, parameters);
}


NSArray *JATSplitArgumentString(NSString *string, unichar separator)
{
	__block NSArray *result;
	JATWithCharacters(string, ^(const unichar characters[], NSUInteger length)
	{
		result = JATSplitStringInternal(string, separator, '{', '}', characters, length, true);
	});
	return result;	
}


void JATPrintToFile(NSString *composedString, FILE *file)
{
	fputs([composedString UTF8String], file);
}


#pragma mark - Template parsing

static NSString *JATExpandOneSub(const unichar characters[], NSUInteger length, NSUInteger idx, NSUInteger *replaceLength, NSDictionary *parameters);
static NSString *JATExpandOneSimpleSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters);
static NSString *JATExpandOnePositionalSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters);
static NSString *JATExpandOneFancyPantsSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters);

static void JATAppendCharacters(NSMutableString *buffer, const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger end);


/*
	JATExpandInternal(characters, length, parameters, template)
	
	Parse a template string and substitute the parameters. In other words, do
	the actual work after the faffing about parsing names and so forth.
*/
static NSString *JATExpandInternal(const unichar characters[], NSUInteger length, NSDictionary *parameters, NSString *template)
{
	NSCParameterAssert(characters != NULL);
	
	// Nothing to expand in an empty string, and the length-1 thing below would be trouble.
	if (length == 0)  return @"";
	
	@autoreleasepool
	{
		NSMutableString *result;
		
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
			else if (thisChar == '}')
			{
				// Detect }} as escape code for }
				replaceLength = 2;
				replacement = @"}";
			}
			// Other types of replacement can easily be chained here.
			
			if (replacement != nil)
			{
				NSCAssert(replaceLength != 0, @"Internal bug in JATemplate: substitution length is zero, which will lead to an infinite loop.");
				
				if (idx == 0 && replaceLength == length)
				{
					// Replacing entire template in one pop.
					return replacement;
				}
				
				if (result == nil)  result = [NSMutableString string];
				
				// Write the pending literal segment to result.
				JATAppendCharacters(result, characters, length, copyRangeStart, idx);
				[result appendString:replacement];
				
				// Skip over replaced part and start a new literal segment.
				idx += replaceLength - 1;
				copyRangeStart = idx + 1;
			}
		}
		
		if (copyRangeStart == 0)
		{
			// No substitutions made.
			return template;
		}
		else
		{
			// Append any trailing literal segment.
			JATAppendCharacters(result, characters, length, copyRangeStart, length);
			return result;
		}
	}
}


static NSString *JATExpandOneSub(const unichar characters[], NSUInteger length, NSUInteger idx, NSUInteger *replaceLength, NSDictionary *parameters)
{
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(idx < length - 1);
	NSCParameterAssert(replaceLength != NULL);
	NSCParameterAssert(characters[idx] == '{');
	
	// Detect {{ as escape code for {
	if (characters[idx + 1] == '{')
	{
		*replaceLength = 2;
		return @"{";
	}
	
	// Find the balancing close brace.
	NSUInteger end, balanceCount = 1;
	bool isIdentifier = IsIdentifierStartChar(characters[idx + 1]);
	bool isPositional = IsPositionalChar(characters[idx + 1]);
	
	for (end = idx + 1; end < length && balanceCount > 0; end++)
	{
		if (characters[end] == '}')  balanceCount--;
		if (characters[end] == '{')  balanceCount++;
		if (balanceCount > 0)
		{
			isIdentifier = isIdentifier && IsIdentifierChar(characters[end]);
			isPositional = isPositional && IsPositionalChar(characters[end]);
		}
	}
	
	// Fail if no balancing bracket. (Not asserted since input is format string.)
	if (balanceCount != 0)
	{
		JATWarn(characters, length, @"Unbalanced braces in template string.");
		return nil;
	}
	
	*replaceLength = end - idx;
	NSUInteger keyStart = idx + 1, keyLength = *replaceLength - 2;
	if (keyLength == 0)
	{
		JATWarn(characters, length, @"Empty substitution expression in template string. To silence this message, use {{{{}}}} instead of {{}}.");
		return nil;
	}
	
	@autoreleasepool
	{
		if (isIdentifier)
		{
			return JATExpandOneSimpleSub(characters, length, keyStart, keyLength, parameters);
		}
		else if (isPositional)
		{
			return JATExpandOnePositionalSub(characters, length, keyStart, keyLength, parameters);
		}
		else
		{
			return JATExpandOneFancyPantsSub(characters, length, keyStart, keyLength, parameters);
		}
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
	
	NSString *identifier = [NSString stringWithCharacters:characters + keyStart length:keyLength];
	id value = parameters[identifier];
	if (value == nil)
	{
		JATWarn(characters, length, @"Template substitution uses unknown parameter \"{identifier}\".", identifier);
	}
	return [value jatemplateCoerceToString];
}


/*
	JATExpandOnePositionalSub()
	
	Handles cases where the substitution token is a simple positional reference.
*/
static NSString *JATExpandOnePositionalSub(const unichar characters[], NSUInteger length, NSUInteger keyStart, NSUInteger keyLength, NSDictionary *parameters)
{
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(keyStart < length);
	NSCParameterAssert(keyStart + keyLength < length);
	
	NSNumber *key = ReadPositional(characters, length, keyStart, NULL);
	NSCAssert(key != nil, @"Failed to scan positional reference that has already been identified as valid.");
	
	id value = parameters[key];
	if (value == nil)
	{
		JATWarn(characters, length, @"Template substitution uses out-of-range positional reference @{key}.", key);
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
	
	id value = nil;
	NSUInteger cursor = keyStart;
	
	bool isIdentifier = ScanIdentifier(characters, length, cursor, &keyLength);
	if (isIdentifier)
	{
		NSString *identifier = [NSString stringWithCharacters:characters + cursor length:keyLength];
		value = parameters[identifier];
		
		if (value == nil)
		{
			JATWarn(characters, length, @"Template substitution uses unknown parameter \"{identifier}\".", identifier);
			return nil;
		}
		
		cursor += keyLength;
	}
	else if (IsPositionalChar(characters[cursor]))
	{
		NSNumber *positional = ReadPositional(characters, length, cursor, &keyLength);
		if (positional != nil)
		{
			value = parameters[positional];
			
			if (value == nil)
			{
				JATWarn(characters, length, @"Template substitution uses out-of-range positional reference @{positional}.", positional);
				return nil;
			}
			
			cursor += keyLength;
		}
		// else fall through to syntax error.
	}
	
	if (value == nil)
	{
		JATWarn(characters, length, @"Unknown template substitution syntax {{{0}}}.", [NSString stringWithCharacters:characters + keyStart length:keyLength]);
		return nil;
	}
	
	// At this point, we expect one or more bars, each followed by an operator expression.
	if (characters[cursor] != '|')
	{
		JATWarn(characters, length, @"Unexpected character '{0}' in template substitution {{{1}}}.", [NSString stringWithCharacters:characters + cursor length:1], [NSString stringWithCharacters:characters + keyStart length:keyLength]);
		return nil;
	}
	
	while (value != nil && characters[cursor] == '|')
	{
		cursor++;
		NSUInteger opLength;
		isIdentifier = ScanIdentifier(characters, length, cursor, &opLength);
		if (!isIdentifier)
		{
			JATWarn(characters, length, @"Expected identifier after | in {{{0}}}.", [NSString stringWithCharacters:characters + keyStart length:keyLength]);
			return nil;
		}
		
		NSString *operator = [NSString stringWithCharacters:characters + cursor length:opLength];
		cursor += opLength;
		
		NSString *argument = nil;
		if (characters[cursor] == ':')
		{
			// Everything up to the next | or } at nesting level 1 is the argument.
			cursor++;
			NSUInteger argStart = cursor;
			NSUInteger balanceCount = 1;
			for (; cursor < length; cursor++)
			{
				if (characters[cursor] == '{')  balanceCount++;
				if (balanceCount == 1)
				{
					if (characters[cursor] == '|' || characters[cursor] == '}')
					{
						break;
					}
				}
				
				if (characters[cursor] == '}')  balanceCount--;
			}
			
			argument = [NSString stringWithCharacters:characters + argStart length:cursor - argStart];
		}
		
		value = [value jatemplatePerformOperator:operator withArgument:argument variables:parameters];
	}
	
	return [value jatemplateCoerceToString];
}


#pragma mark - Utilities

NSArray *JATSplitStringInternal(NSString *string, unichar separator, unichar balanceStart, unichar balanceEnd, const unichar *stringBuffer, NSUInteger length, bool printWarnings)
{
	NSUInteger spanStart = 0;
	NSMutableArray *result = [NSMutableArray array];
	NSUInteger balanceCount = 0;
	
	for (NSUInteger cursor = 0; cursor < length; cursor++)
	{
		unichar curr = stringBuffer[cursor];
		if (curr == balanceStart)  balanceCount++;
		else if (curr == balanceEnd)
		{
			if (balanceCount == 0)
			{
				if (printWarnings)
				{
					JATWarn(NULL, 0, @"Unbalanced brace in template argument string \"{string}\".", string);
					printWarnings = false;
				}
			}
			else
			{
				balanceCount--;
			}
		}
		else if (balanceCount == 0 && curr == separator)
		{
			NSRange range = { spanStart, cursor - spanStart };
			NSString *subString = [string substringWithRange:range];
			[result addObject:subString];
			spanStart = cursor + 1;
		}
	}
	
	if (spanStart == 0)  return @[string];	// No separators found.
	
	NSRange range = { spanStart, length - spanStart };
	NSString *subString = [string substringWithRange:range];
	[result addObject:subString];
	
	return result;
}


static void JATAppendCharacters(NSMutableString *buffer, const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger end)
{
	NSCParameterAssert(buffer != nil);
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(start <= end);
	NSCParameterAssert(start <= length);
	NSCParameterAssert(end <= length);
	if (start == end)  return;
	
	CFStringAppendCharacters((__bridge CFMutableStringRef)buffer, characters + start, end - start);
}


void JATWithCharacters(NSString *string, void(^block)(const unichar characters[], NSUInteger length))
{
	NSCAssert(sizeof(unichar) == sizeof(UniChar), @"This is a silly place.");
	
	if (string == nil)  return;
	NSUInteger length = string.length;
	
	// Fast case: if the string is internally a single UTF-16 buffer, we can peek.
	const unichar *stringBuffer = (const UniChar *)CFStringGetCharactersPtr((__bridge CFStringRef)string);
	if (stringBuffer != NULL)
	{
		block(stringBuffer, length);
		return;
	}
	
	// If the string is small, convert it to UTF-16 on the stack.
	unichar *mutableStringBuffer;
	NSUInteger stackBufferSize = length;
	bool useHeapAllocation = length > kStackStringLimit;
	if (useHeapAllocation)  stackBufferSize = 1;
	unichar stackBuffer[stackBufferSize];
	if (useHeapAllocation)
	{
		// Otherwise, we need to do it on the heap.
		mutableStringBuffer = malloc(sizeof *stringBuffer * length);
		if (stringBuffer == NULL)  return;
	}
	else
	{
		mutableStringBuffer = stackBuffer;
	}
	
	@try
	{
		[string getCharacters:mutableStringBuffer];
		block(mutableStringBuffer, length);
	}
	@finally
	{
		if (useHeapAllocation)  free(mutableStringBuffer);
	}
}


static NSString * const kIdentifierChars = @"qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM_$0123456789";
static NSString * const kIdentifierStartChars = @"qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM_$";


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


static bool IsPositionalChar(unichar value)
{
	return isdigit(value);
}


bool JATIsValidIdentifier(NSString *candidate)
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


static NSNumber *ReadPositional(const unichar characters[], NSUInteger length, NSUInteger start, NSUInteger *outLength)
{
	NSCParameterAssert(characters != NULL);
	NSCParameterAssert(start < length);
	
	NSUInteger value = 0;
	NSUInteger end;
	for (end = start; end < length; end++)
	{
		if (!IsPositionalChar(characters[end]))  break;
		value = value * 10 + characters[end] - '0';
	}
	
	if (end == start)  return nil;
	
	if (outLength != NULL)  *outLength = end - start;
	return @(value);
}


void JATWrapWarning(const unichar characters[], NSUInteger length, NSString *message)
{
	/*	Function exists even if JATEMPLATE_SYNTAX_WARNINGS is off so it can be
		called from JATemplateDefaultOperators without duplicating macro logic
		or moving it to a header.
	*/
#if JATEMPLATE_SYNTAX_WARNINGS
	if (characters != NULL)
	{
		message = [NSString stringWithFormat:@"%@ (Template: \"%@\")", message, [NSString stringWithCharacters:characters length:length]];
	}
	
	JATReportWarning(message);
#endif
}


#pragma mark - Operators

@implementation NSObject (JATCoercible)

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

@end


@implementation NSObject (JATOperatorSupport)

- (id<JATCoercible>) jatemplatePerformOperator:(NSString *)operator withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	// Dogfood note: it would be a bad idea to use an operator in this template.
	NSString *opImplementationName = JATExpandLiteral(@"jatemplatePerform_{operator}_withArgument:variables:", operator);
	SEL selector = NSSelectorFromString(opImplementationName);
	
	if ([self respondsToSelector:selector])
	{
		typedef id<JATCoercible> (*OperatorIMP)(id, SEL, NSString *, NSDictionary *);
		OperatorIMP imp = (OperatorIMP)[self methodForSelector:selector];
		return imp(self, selector, argument, variables);
	}
	else
	{
		JATWarn(NULL, 0, @"Unknown operator \"{operator}\" in template expansion.", operator);
		return nil;
	}
}

@end


@implementation NSString (JATCoercible)

- (NSString *) jatemplateCoerceToString
{
	return self;
}

@end


@implementation NSNull (JATCoercible)

- (NSString *) jatemplateCoerceToString
{
	return @"(null)";
}


- (NSNumber *) jatemplateCoerceToBoolean
{
	return @NO;
}

@end


@implementation NSNumber (JATCoercible)

- (NSString *) jatemplateCoerceToString
{
	return [NSNumberFormatter localizedStringFromNumber:self numberStyle:NSNumberFormatterDecimalStyle];
}


- (NSNumber *) jatemplateCoerceToNumber
{
	return self;
}

@end


@implementation NSArray (JATCoercible)

- (NSString *) jatemplateCoerceToString
{
	bool first = true;
	NSMutableString *result = [NSMutableString string];
	
	for (id value in self)
	{
		if (!first)  [result appendString:@", "];
		else  first = false;
		
		[result appendString:[value jatemplateCoerceToString]];
	}
	
	return result;
}

@end
