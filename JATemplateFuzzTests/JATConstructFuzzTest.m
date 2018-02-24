#import "JATConstructFuzzTest.h"
#import "JAtemplate.h"


// Create a random parameter dictionary.
static NSDictionary *MakeUpParameters(void);

// Core: create a random template.
static NSString *GenerateTemplateExpression(NSArray *paramKeys);


@interface JATMockParameter: NSObject <JATCoercible>

@property (nonatomic) NSUInteger value;

@end


static inline NSUInteger RandomSmall(void)
{
	return ((unsigned long)random()) % 1000;
}


static inline id AnyObject(NSArray *array)
{
	NSUInteger count = array.count;
	if (count == 0)  return nil;
	return array[random() % count];
}


bool JATConstructFuzzTest(NSString **outTemplate, NSDictionary **outParameters)
{
	NSCParameterAssert(outTemplate != NULL && outParameters != NULL);
	
	NSDictionary *parameters = MakeUpParameters();
	NSMutableString *template = [NSMutableString string];
	NSArray *paramKeys = [parameters allKeys];
	
	do
	{
		[template appendString:GenerateTemplateExpression(paramKeys)];
	} while (random() % 3 != 0);
	
	*outTemplate = template;
	*outParameters = parameters;
	return true;
}


NSDictionary *MakeUpParameters(void)
{
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	do
	{
		id key;
		if (random() % 2 == 0)
		{
			// Make a numeric key.
			key = @(RandomSmall());
		}
		else
		{
			// Make a string key.
			key = JATExpand(@"key_{0}", @(RandomSmall()));
		}
		
		[result setObject:[JATMockParameter new] forKey:key];
	} while (random() % 5 != 0);
	
	return result;
}


@implementation JATMockParameter

- (id) init
{
	if ((self = [super init]))
	{
		// Approximately 1/3 mock parameters are zero, 1/3 are 1, and the rest are larger.
		long select = random();
		if (select % 3 == 0)
		{
			_value = 0;
		}
		else if (select % 3 == 1)
		{
			_value = 1;
		}
		else
		{
			_value = RandomSmall();
		}
	}
	
	return self;
}


- (NSString *) jatemplateCoerceToString
{
	NSUInteger value = self.value;
	return JATExpand(@"value-{value}", value);
}


- (NSNumber *) jatemplateCoerceToNumber
{
	return @(self.value);
}


- (NSNumber *) jatemplateCoerceToBoolean
{
	return [NSNumber numberWithBool:self.value != 0];
}


- (NSString *) description
{
	NSUInteger value = self.value;
	return JATExpand(@"{self|basedesc}{{{value}}}", self, value);
}

@end


#pragma mark - Template generation

// Create text not containing braces.
static NSString *GenerateRandomText(void);

// Generate a syntactically valid (one would hope) {expansion} using keys in <paramKeys>.
static NSString *GenerateRandomExpansion(NSArray *paramKeys);

// Generate a syntactically valid operator, not including the |.
static NSString *GenerateRandomOperator(NSArray *paramKeys);


static NSString *GenerateTemplateExpression(NSArray *paramKeys)
{
	NSString *result;
	
	NSUInteger select = random() % 3;
	if (select == 0)
	{
		result = GenerateRandomText();
	}
	else if (select == 1)
	{
		result = GenerateRandomExpansion(paramKeys);
	}
	else
	{
		result = @"";
	}
	
	if (random() % 3 != 0)
	{
		return [result stringByAppendingString:GenerateTemplateExpression(paramKeys)];
	}
	else
	{
		return result;
	}
}


static NSString *GenerateRandomText(void)
{
	// FIXME: randomer text (not likely to matter, but hey, we want to surprise ourselves).
	return @"( filler )";
}


static NSString *GenerateRandomExpansion(NSArray *paramKeys)
{
	id key = AnyObject(paramKeys);
	NSMutableString *expression = [[key description] mutableCopy];
	
	while (random() % 2 == 0)
	{
		JATAppendLiteral(expression, @"|{0}", GenerateRandomOperator(paramKeys));
	}
	
	return JATExpandLiteral(@"{{{expression}}}", expression);
}


/*
	List of constructor functions which create test cases for operators.
*/
typedef NSString *(*OperatorTestConstructor)(const char *name, NSArray *paramKeys);
typedef struct
{
	const char *name;
	OperatorTestConstructor construct;
	
} OperatorDesc;

/*
	Trivial test case constructor for operators with no arguments.
*/
static NSString *BasicOperatorTestConstruct(const char *name, NSArray *paramKeys);

static NSString *NumOperatorTestConstruct(const char *name, NSArray *paramKeys);
static NSString *PlurOperatorTestConstruct(const char *name, NSArray *paramKeys);
static NSString *PluralAndIfOperatorTestConstruct(const char *name, NSArray *paramKeys);
static NSString *SelectOperatorTestConstruct(const char *name, NSArray *paramKeys);
static NSString *FoldOperatorTestConstruct(const char *name, NSArray *paramKeys);


static OperatorDesc sOperators[] =
{
	{ "num:", NumOperatorTestConstruct },
	{ "round", BasicOperatorTestConstruct },
	{ "plur:", PlurOperatorTestConstruct },
	{ "plural:", PluralAndIfOperatorTestConstruct },
	{ "pluraz:", PluralAndIfOperatorTestConstruct },
	{ "if:", PluralAndIfOperatorTestConstruct },
	{ "select:", SelectOperatorTestConstruct },
	{ "uppercase", BasicOperatorTestConstruct },
	{ "lowercase", BasicOperatorTestConstruct },
	{ "capitalize", BasicOperatorTestConstruct },
	{ "uppercase_noloc", BasicOperatorTestConstruct },
	{ "lowercase_noloc", BasicOperatorTestConstruct },
	{ "capitalize_noloc", BasicOperatorTestConstruct },
	{ "trim", BasicOperatorTestConstruct },
	{ "length", BasicOperatorTestConstruct },
	{ "fold:", FoldOperatorTestConstruct },
	{ "pointer", BasicOperatorTestConstruct },
	{ "basedesc", BasicOperatorTestConstruct },
	{ "debugdesc", BasicOperatorTestConstruct }
};

enum
{
	kOperatorCount = sizeof sOperators / sizeof sOperators[0]
};


static NSString *GenerateRandomOperator(NSArray *paramKeys)
{
	@autoreleasepool
	{
		OperatorDesc *operator = &sOperators[random() % kOperatorCount];
		NSString *result = operator->construct(operator->name, paramKeys);
		JATCAssert(result != nil, @"Fuzzer failure: operator test case constructor for \"{0}\" failed.", @(operator->name));
		return result;
	}
}


static NSString *BasicOperatorTestConstruct(const char *name, NSArray *paramKeys)
{
	return @(name);
}


static NSString *NumOperatorTestConstruct(const char *name, NSArray *paramKeys)
{
	static NSArray *arguments;
	if (arguments == nil)
	{
		arguments = @[
			@"$#,##0.00",	// No point constructing random format strings since we’re not testing NSNumberFormatter.
			@"decimal",
			@"dec",
			@"noloc",
			@"currency",
			@"cur",
			@"percent",
			@"pct",
			@"scientific",
			@"sci",
			@"spellout",
			@"filebytes",
			@"file",
			@"bytes",
			@"memorybytes",
			@"memory",
			@"decimalbytes",
			@"binarybytes"
		];
	}
	
	return JATExpand(@"num:{0}", AnyObject(arguments));
}


static NSString *PlurOperatorTestConstruct(const char *name, NSArray *paramKeys)
{
	NSUInteger expectedArgs[] =
	{
		[1]  = 2,
		[2]  = 2,
		[3]  = 3,
		[4]  = 4,
		[5]  = 3,
		[6]  = 3,
		[7]  = 3,
		[8]  = 3,
		[9]  = 3,
		[10] = 4,
		[11] = 5,
		[12] = 6,
		[13] = 4,
		[14] = 3,
		[15] = 2,
		[16] = 6
	};
	
	enum
	{
		kCount = sizeof expectedArgs / sizeof *expectedArgs
	};
	
	NSUInteger ruleID = random() % (kCount - 1) + 1;
	NSUInteger argCount = expectedArgs[ruleID];
	
	NSMutableString *result = [NSMutableString string];
	JATAppendLiteral(result, @"plur:{ruleID}", @(ruleID));
	
	while (argCount--)
	{
		JATAppendLiteral(result, @";{0}", GenerateTemplateExpression(paramKeys));
	}
	
	return result;
}


static NSString *PluralAndIfOperatorTestConstruct(const char *name, NSArray *paramKeys)
{
	NSString *first = GenerateTemplateExpression(paramKeys);
	NSString *second;
	if (random() % 1 == 0)  second = GenerateTemplateExpression(paramKeys);
	
	// Note: {name} is expanded so we can use the same generator for plural:, pluraz: and if:.
	if (second == nil)
	{
		return JATExpand(@"{name}{first}", @(name), first);
	}
	else
	{
		return JATExpand(@"{name}{first};{second}", @(name), first, second);
	}
}


static NSString *SelectOperatorTestConstruct(const char *name, NSArray *paramKeys)
{
	NSMutableArray *elements = [NSMutableArray array];
	do
	{
		[elements addObject:GenerateTemplateExpression(paramKeys)];
	} while (random() % 5 != 0);
	
	return JATExpand(@"select:{0}", [elements componentsJoinedByString:@";"]);
}


static NSString *FoldOperatorTestConstruct(const char *name, NSArray *paramKeys)
{
	NSMutableArray *options = [NSMutableArray array];
	
	while (options.count == 0)
	{
		NSUInteger select = random();
		if (select & 0x1)  [options addObject:@"case"];
		if (select & 0x2)  [options addObject:@"width"];
		if (select & 0x4)  [options addObject:@"diacritics"];
	}
	
	NSString *optionNames = [options componentsJoinedByString:@","];
	return JATExpand(@"fold:{optionNames}", optionNames);
}
