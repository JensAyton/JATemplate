/*

JATemplateDefaultOperators.m

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


#define OpWarn(TEMPLATE, ...)  JATWrapWarning(NULL, 0, JATExpand(TEMPLATE, __VA_ARGS__))


/*	Core pluralization logic used by plur: and plural: operators.
*/
static NSString *PluralizationRule1(NSUInteger value, NSArray *components);
static NSString *PluralizationRule2(NSUInteger value, NSArray *components);
static NSString *PluralizationRule3(NSUInteger value, NSArray *components);
static NSString *PluralizationRule4(NSUInteger value, NSArray *components);
static NSString *PluralizationRule5(NSUInteger value, NSArray *components);
static NSString *PluralizationRule6(NSUInteger value, NSArray *components);
static NSString *PluralizationRule7(NSUInteger value, NSArray *components);
static NSString *PluralizationRule8(NSUInteger value, NSArray *components);
static NSString *PluralizationRule9(NSUInteger value, NSArray *components);
static NSString *PluralizationRule10(NSUInteger value, NSArray *components);
static NSString *PluralizationRule11(NSUInteger value, NSArray *components);
static NSString *PluralizationRule12(NSUInteger value, NSArray *components);
static NSString *PluralizationRule13(NSUInteger value, NSArray *components);
static NSString *PluralizationRule14(NSUInteger value, NSArray *components);
static NSString *PluralizationRule15(NSUInteger value, NSArray *components);
static NSString *PluralizationRule16(NSUInteger value, NSArray *components);


/*	Array of pluralization rules.
	Each rule has a required component count, which is the expected number of
	elements in the tokenized argument, excluding the first (the rule number).
	For instance, for plur:1;;s the components are @[@"1", @"", @"s"] and the
	required count is 2.
*/
typedef NSString *(*PluralizationRule)(NSUInteger, NSArray *);
static const struct
{
	NSUInteger			requiredComponentCount;
	PluralizationRule	rule;
} sPluralizationRules[] =
{
	[1]  = { 2, PluralizationRule1 },
	[2]  = { 2, PluralizationRule2 },
	[3]  = { 3, PluralizationRule3 },
	[4]  = { 4, PluralizationRule4 },
	[5]  = { 3, PluralizationRule5 },
	[6]  = { 3, PluralizationRule6 },
	[7]  = { 3, PluralizationRule7 },
	[8]  = { 3, PluralizationRule8 },
	[9]  = { 3, PluralizationRule9 },
	[10] = { 4, PluralizationRule10 },
	[11] = { 5, PluralizationRule11 },
	[12] = { 6, PluralizationRule12 },
	[13] = { 4, PluralizationRule13 },
	[14] = { 3, PluralizationRule14 },
	[15] = { 2, PluralizationRule15 },
	[16] = { 6, PluralizationRule16 }
};


enum
{
	kPluralizationRuleCount = sizeof sPluralizationRules / sizeof *sPluralizationRules
};


@implementation NSObject (JATDefaultOperators)

- (id<JATCoercible>) jatemplatePerform_num_withArgument:(NSString *)argument variables:(NSDictionary *)variables
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


- (id<JATCoercible>) jatemplatePerform_round_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	long long rounded = llround(value.doubleValue);
	
	return [NSNumber numberWithLongLong:rounded];
}


- (id<JATCoercible>) jatemplatePerform_plur_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		OpWarn(@"Template operator plur: used with no argument.");
		return nil;
	}
	
	NSArray *components = JATSplitArgumentString(argument, ';');
	
	NSInteger ruleID = [components[0] integerValue];
	PluralizationRule rule = NULL;
	
	if (0 < ruleID && ruleID < kPluralizationRuleCount)
	{
		NSUInteger requiredCount = sPluralizationRules[ruleID].requiredComponentCount;
		if (components.count != requiredCount + 1)
		{
			OpWarn(@"Template operator plur: rule {ruleID} requires {requiredCount} arguments (got plur:{argument}).", @(ruleID), @(requiredCount), argument);
			return nil;
		}
		rule = sPluralizationRules[ruleID].rule;
	}
	
	if (rule == NULL)
	{
		OpWarn(@"Template operator plur: used with invalid rule ID {0}.", components[0]);
		return nil;
	}
	
	NSString *selected = rule([value unsignedIntegerValue], components);
	
	return JATExpandLiteralWithParameters(selected, variables);
}


- (id<JATCoercible>) jatemplatePerform_plural_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		OpWarn(@"Template operator plural: used with no argument.");
		return nil;
	}
	
	NSArray *components = JATSplitArgumentString(argument, ';');
	
	if (components.count == 1)
	{
		components = @[@"1", @"", components[0]];
	}
	else if (components.count == 2)
	{
		components = @[@"1", components[0], components[1]];
	}
	else
	{
		OpWarn(@"Template operator plural: requires one or two arguments, got \"{argument}\".", argument);
		return nil;
	}
	
	NSString *selected = PluralizationRule1(value.integerValue, components);
	
	return JATExpandLiteralWithParameters(selected, variables);
}


- (id<JATCoercible>) jatemplatePerform_pluraz_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		OpWarn(@"Template operator pluraz: used with no argument.");
		return nil;
	}
	
	NSArray *components = JATSplitArgumentString(argument, ';');
	
	if (components.count == 1)
	{
		components = @[@"2", @"", components[0]];
	}
	else if (components.count == 2)
	{
		components = @[@"2", components[0], components[1]];
	}
	else
	{
		OpWarn(@"Template operator pluraz: requires one or two arguments, got \"{argument}\".", argument);
		return nil;
	}
	
	NSString *selected = PluralizationRule2(value.integerValue, components);
	
	return JATExpandLiteralWithParameters(selected, variables);
}


- (id<JATCoercible>) jatemplatePerform_if_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToBoolean];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		OpWarn(@"Template operator if: used with no argument.");
		return nil;
	}
	
	NSArray *components = JATSplitArgumentString(argument, ';');
	
	NSString *trueValue = components[0], *falseValue = @"";
	if (components.count > 1)  falseValue = components[1];
	
	NSString *selected = value.boolValue ? trueValue : falseValue;
	return JATExpandLiteralWithParameters(selected, variables);
}


- (id<JATCoercible>) jatemplatePerform_select_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	if (argument == nil)
	{
		OpWarn(@"Template operator select: used with no argument.");
		return nil;
	}
	
	NSArray *components = JATSplitArgumentString(argument, ';');
	NSUInteger index = [value unsignedIntegerValue];
	NSUInteger max = components.count - 1;
	if (index > max)  index = max;
	
	NSString *selected = components[index];
	return JATExpandLiteralWithParameters(selected, variables);
}


- (id<JATCoercible>) jatemplatePerform_uppercase_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseStringWithLocale:[NSLocale currentLocale]];
}


- (id<JATCoercible>) jatemplatePerform_lowercase_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseStringWithLocale:[NSLocale currentLocale]];
}


- (id<JATCoercible>) jatemplatePerform_capitalize_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedStringWithLocale:[NSLocale currentLocale]];
}


- (id<JATCoercible>) jatemplatePerform_uppercase_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value uppercaseString];
}


- (id<JATCoercible>) jatemplatePerform_lowercase_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value lowercaseString];
}


- (id<JATCoercible>) jatemplatePerform_capitalize_noloc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	return [value capitalizedString];
}


- (id<JATCoercible>) jatemplatePerform_trim_withArgument:(NSString *)argument variables:(NSDictionary *)variables
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


- (id<JATCoercible>) jatemplatePerform_fold_withArgument:(NSString *)argument variables:(NSDictionary *)variables
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
			OpWarn(@"Unknown option \"{option}\" for \"fold\" template operator.", option);
		}
	}
	
	if (optionMask == 0)  return value;
	
	return [value stringByFoldingWithOptions:optionMask locale:NSLocale.currentLocale];
}


typedef enum
{
	kJATAlignModeInvalid,
	kJATAlignModeStart,
	kJATAlignModeCenter,
	kJATAlignModeEnd
} JATAlignMode;


static JATAlignMode InterpretAlignMode(NSString *string, JATAlignMode defaultValue)
{
	if (string == nil || [string isEqualToString:@""])  return defaultValue;
	
	if ([string isEqualToString:@"start"])  return kJATAlignModeStart;
	if ([string isEqualToString:@"center"])  return kJATAlignModeCenter;
	if ([string isEqualToString:@"end"])  return kJATAlignModeEnd;
	return kJATAlignModeInvalid;
}


static NSString *TruncateString(NSString *value, NSUInteger keepLength, JATAlignMode mode)
{
	NSUInteger stringLength = value.length;
	if (stringLength <= keepLength)  return value;
	
	switch (mode)
	{
		case kJATAlignModeStart:
			return [value substringFromIndex:stringLength - keepLength];
			
		case kJATAlignModeCenter:
		{
			NSUInteger keepAfter = keepLength / 2;
			NSUInteger keepBefore = keepLength - keepAfter;
			NSString *before = [value substringToIndex:keepBefore];
			NSString *after = [value substringFromIndex:stringLength - keepAfter];
			return JATExpand(@"{before}{after}", before, after);
		}
		
		case kJATAlignModeEnd:
			return [value substringToIndex:keepLength];
			
		case kJATAlignModeInvalid:
			;
	}
	
	return nil;
}


- (id<JATCoercible>) jatemplatePerform_trunc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	NSArray *arguments = JATSplitArgumentString(argument, ';');
	if (arguments.count < 1)
	{
		OpWarn(@"The trunc: operator reqires at least one argument (width).");
		return nil;
	}
	
	NSString *modeString = nil;
	if (arguments.count > 1)  modeString = JATExpandWithParameters(arguments[1], variables);
	JATAlignMode mode = InterpretAlignMode(modeString, kJATAlignModeEnd);
	if (mode == kJATAlignModeInvalid)
	{
		OpWarn(@"The trunc: operator does not recognize \"{0}\" as a truncation mode. Try start, center or end.", modeString);
		return nil;
	}
	
	NSUInteger truncLength = [JATExpandWithParameters(arguments[0], variables) integerValue];
	
	return TruncateString(value, truncLength, mode);
}


static NSString *PadFitString(NSString *value, NSArray *arguments, NSUInteger stringLength, NSUInteger fitLength, NSDictionary *variables)
{
	NSUInteger padCount = fitLength - stringLength;
	NSString *modeString = nil;
	if (arguments.count >= 2)  modeString = JATExpandWithParameters(arguments[1], variables);
	JATAlignMode padMode = InterpretAlignMode(modeString, kJATAlignModeEnd);
	
	switch (padMode)
	{
		case kJATAlignModeStart:
			return JATExpand(@"{padCount|padding}{value}", value, @(padCount));
			
		case kJATAlignModeCenter:
		{
			NSUInteger padBefore = padCount / 2;
			NSUInteger padAfter = padCount - padBefore;
			return JATExpand(@"{padBefore|padding}{value}{padAfter|padding}", value, @(padBefore), @(padAfter));
		}
			
		case kJATAlignModeEnd:
			return JATExpand(@"{value}{padCount|padding}", value, @(padCount));
			
		default:
			OpWarn(@"The fit: operator does not recognize \"{0}\" as a padding mode. Try start, center or end.", modeString);
			return nil;
	}	
}


static NSString *TruncateFitString(NSString *value, NSArray *arguments, NSUInteger stringLength, NSUInteger fitLength, NSDictionary *variables)
{
	NSString *truncString = @"…";
	NSUInteger truncLength = 1;
	if (arguments.count >= 4)
	{
		truncString = arguments[3];
		truncLength = truncString.length;
	}
	if (truncLength >= fitLength)  return truncString;
	
	NSString *modeString = nil;
	if (arguments.count >= 3)  modeString = JATExpandWithParameters(arguments[2], variables);
	JATAlignMode truncMode = InterpretAlignMode(modeString, kJATAlignModeEnd);
	
	NSUInteger keepLength = fitLength - truncLength;
	switch (truncMode)
	{
		case kJATAlignModeStart:
			value = [value substringFromIndex:stringLength - keepLength];
			return JATExpand(@"{truncString}{value}", value, truncString);
			
		case kJATAlignModeCenter:
		{
			NSUInteger keepAfter = keepLength / 2;
			NSUInteger keepBefore = keepLength - keepAfter;
			NSString *before = [value substringToIndex:keepBefore];
			NSString *after = [value substringFromIndex:stringLength - keepAfter];
			return JATExpand(@"{before}{truncString}{after}", before, truncString, after);
		}
			
		case kJATAlignModeEnd:
			value = [value substringToIndex:keepLength];
			return JATExpand(@"{value}{truncString}", value, truncString);
			
		default:
			OpWarn(@"The fit: operator does not recognize \"{0}\" as a truncation mode. Try start, center or end.", modeString);
			return nil;
	}
}


- (id<JATCoercible>) jatemplatePerform_fit_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSString *value = [self jatemplateCoerceToString];
	if (value == nil)  return nil;
	
	NSArray *arguments = JATSplitArgumentString(argument, ';');
	if (arguments.count < 1)
	{
		OpWarn(@"The fit: operator reqires at least one argument (width).");
		return nil;
	}
	
	NSUInteger stringLength = value.length;
	NSUInteger fitLength = [JATExpandWithParameters(arguments[0], variables) integerValue];
	
	if (stringLength < fitLength)  return PadFitString(value, arguments, stringLength, fitLength, variables);
	if (stringLength > fitLength)  return TruncateFitString(value, arguments, stringLength, fitLength, variables);
	return value;
}


- (id<JATCoercible>) jatemplatePerform_padding_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	NSNumber *value = [self jatemplateCoerceToNumber];
	if (value == nil)  return nil;
	
	NSInteger count = value.integerValue;
	if (count <= 0)  return @"";
	
	char *buffer = malloc(count);
	if (buffer == NULL)  return nil;
	
	memset(buffer, ' ', count);
	return [[NSString alloc] initWithBytesNoCopy:buffer length:count encoding:NSASCIIStringEncoding freeWhenDone:true];
}


- (id<JATCoercible>) jatemplatePerform_pointer_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	id value = self;
	if (self == [NSNull null])  value = nil;
	
	return [NSString stringWithFormat:@"%p", value];
}


- (id<JATCoercible>) jatemplatePerform_basedesc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
{
	id value = self;
	if (self == [NSNull null])  return [self jatemplateCoerceToString];
	id class = [value class];
	
	return JATExpand(@"<{class}: {value|pointer}>", class, value);
}


- (id<JATCoercible>) jatemplatePerform_debugdesc_withArgument:(NSString *)argument variables:(NSDictionary *)variables
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

@end


#pragma mark - Pluralization rules
// These are based on https://developer.mozilla.org/en-US/docs/Localization_and_Plurals

static NSString *PluralizationRule1(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 3);
	
	if (value == 1)  return components[1];
	return components[2];
}


static NSString *PluralizationRule2(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 3);
	
	if (value == 0 || value == 1)  return components[1];
	return components[2];
}


static NSString *PluralizationRule3(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 4);
	
	NSUInteger lastDigit = value % 10;
	if (value == 0)  return components[1];
	if (lastDigit == 1 && value != 11)  return components[2];
	return components[3];
}


static NSString *PluralizationRule4(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 5);
	
	if (value == 1 || value == 11)  return components[1];
	if (value == 2 || value == 12)  return components[2];
	if (3 <= value && value <= 19)  return components[3];
	return components[4];
}


static NSString *PluralizationRule5(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 4);
	
	NSUInteger lastTwoDigits = value % 100;
	if (value == 1)  return components[1];
	if (value == 0 || lastTwoDigits <= 19)  return components[2];
	return components[3];
}


static NSString *PluralizationRule6(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 4);
	
	NSUInteger lastDigit = value % 10;
	NSUInteger lastTwoDigits = value % 100;
	if (lastDigit == 1 && lastTwoDigits != 11)  return components[1];
	if (lastDigit == 0)  return components[2];
	if (11 <= lastTwoDigits && lastTwoDigits <= 19)  return components[2];
	return components[3];
}


static NSString *PluralizationRule7(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 4);
	
	NSUInteger lastDigit = value % 10;
	NSUInteger lastTwoDigits = value % 100;
	if (lastDigit == 1 && lastTwoDigits != 11)  return components[1];
	if (2 <= lastDigit && lastDigit <= 4 && (lastTwoDigits < 12 || lastTwoDigits > 14))  return components[2];
	return components[3];
}


static NSString *PluralizationRule8(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 4);
	
	if (value == 1)  return components[1];
	if (2 <= value && value <= 4)  return components[2];
	return components[3];
}


static NSString *PluralizationRule9(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 4);
	
	NSUInteger lastDigit = value % 10;
	NSUInteger lastTwoDigits = value % 100;
	if (value == 1)  return components[1];
	if (2 <= lastDigit && lastDigit <= 4 && (lastTwoDigits < 12 || lastTwoDigits > 14))  return components[2];
	return components[3];
}


static NSString *PluralizationRule10(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 5);
	
	NSUInteger lastTwoDigits = value % 100;
	if (lastTwoDigits == 1)  return components[1];
	if (lastTwoDigits == 2)  return components[2];
	if (lastTwoDigits == 3 || lastTwoDigits == 4)  return components[3];
	return components[4];
}


static NSString *PluralizationRule11(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 6);
	
	if (value == 1)  return components[1];
	if (value == 2)  return components[2];
	if (3 <= value && value <= 6)  return components[3];
	if (7 <= value && value <= 10)  return components[4];
	return components[5];
}


static NSString *PluralizationRule12(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 7);
	
	NSUInteger lastTwoDigits = value % 100;
	if (value == 0)  return components[6];
	if (value == 1)  return components[1];
	if (value == 2)  return components[2];
	if (lastTwoDigits >= 3 && lastTwoDigits <= 10)  return components[3];
	if (lastTwoDigits <= 2)  return components[5];
	return components[4];
}


static NSString *PluralizationRule13(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 5);
	
	NSUInteger lastTwoDigits = value % 100;
	if (value == 1)  return components[1];
	if (value == 0 || (lastTwoDigits >= 1 && lastTwoDigits <= 10))  return components[2];
	if (lastTwoDigits >= 11 && lastTwoDigits <= 19)  return components[3];
	return components[4];
}


static NSString *PluralizationRule14(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 4);
	
	NSUInteger lastDigit = value % 10;
	if (lastDigit == 1)  return components[1];
	if (lastDigit == 2)  return components[2];
	return components[3];
}


static NSString *PluralizationRule15(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 3);
	
	NSUInteger lastDigit = value % 10;
	if (lastDigit == 1 && value != 11)  return components[1];
	return components[2];
}


static NSString *PluralizationRule16(NSUInteger value, NSArray *components)
{
	NSCParameterAssert(components.count == 7);
	
	NSUInteger lastDigit = value % 10;
	NSUInteger secondLastDigit = (value / 10) % 10;
	if (value == 1)  return components[1];
	if (secondLastDigit != 1 && secondLastDigit != 7 && secondLastDigit != 9)
	{
		if (lastDigit == 1)  return components[2];
		if (lastDigit == 2)  return components[3];
		if (lastDigit == 3 || lastDigit == 4 || lastDigit == 9)  return components[4];
	}
	if (value != 0 && (value % 1000000) == 0)  return components[5];
	return components[6];
}
