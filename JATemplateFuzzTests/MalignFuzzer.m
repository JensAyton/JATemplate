#import <Foundation/Foundation.h>
#import "JATemplate.h"
#import "JATConstructFuzzTest.h"


// If set, prints the first 25 templates and then exits.
#define DUMP_EXAMPLE_TEMPLATES	0


static NSString *CorruptTemplate(NSString *template);
static void ReportException(NSException *ex, NSString *template, NSDictionary *parameters);

#define Print(TEMPLATE, ...)   fputs([JATExpandLiteral(TEMPLATE, ##__VA_ARGS__) UTF8String], stdout)
#define EPrint(TEMPLATE, ...)  fputs([JATExpandLiteral(TEMPLATE, ##__VA_ARGS__) UTF8String], stderr)


int main(int argc, const char * argv[])
{
	srandomdev();
	
	@autoreleasepool
	{
		Print(@"Starting evil fuzz testing...\n");
		
		NSUInteger count = 0;
		
		@try
		{
			for (;;)
			{
				@autoreleasepool
				{
					count++;
					
					NSString *template;
					NSDictionary *parameters;
					bool OK = JATConstructFuzzTest(&template, &parameters);
					
					if (!OK)
					{
						EPrint(@"Failed to construct test case number {count}.", @(count));
						return EXIT_FAILURE;
					}
					
					template = CorruptTemplate(template);
					
					#if DUMP_EXAMPLE_TEMPLATES
						Print(@"{template}\n\n", template);
						if (count == 25)  exit(0);
					#endif
					
					@try
					{
						(void)JATExpandLiteralWithParameters(template, parameters);
					}
					@catch (NSException *ex)
					{
						ReportException(ex, template, parameters);
						return EXIT_FAILURE;
					}
					
					if ((count % 1000) == 0)
					{
						Print(@"{count} grumpy customers served.\n", @(count));
					}
				}
			}
		}
		@catch (NSException *ex)
		{
			NSString *name = ex.name;
			NSString *reason = ex.reason;
			
			EPrint(@"An exception occurred outside of template expansion.\n\nException: {name}\n\nReason: {reason}\n", name, reason);
			return EXIT_FAILURE;
		}
	}
}


static NSString *RandomCharacter(void)
{
	unichar character = random() % (256 - 32) + 32;	
	return [NSString stringWithCharacters:&character length:1];
}


static NSString *CorruptTemplate(NSString *template)
{
	// Make random edits to induce parse errors.
	NSMutableString *corrupt = [template mutableCopy];
	NSUInteger changeCount = random() % ((template.length / 20) + 1) + 1;
	
	while (changeCount--)
	{
		if (corrupt.length == 0)
		{
			[corrupt insertString:RandomCharacter() atIndex:0];
		}
		
		NSUInteger select = random() % 3;
		NSUInteger target = random() % corrupt.length;
		if (select == 0)
		{
			[corrupt deleteCharactersInRange:(NSRange){ target, 1 }];
		}
		else if (select == 1)
		{
			[corrupt insertString:RandomCharacter() atIndex:target];
		}
		else
		{
			[corrupt replaceCharactersInRange:(NSRange){ target, 1 }
								   withString:RandomCharacter()];
		}
	}
	
	return corrupt;
}


static void ReportException(NSException *ex, NSString *template, NSDictionary *parameters)
{
	NSString *name = ex.name;
	NSString *reason = ex.reason;
	
	EPrint(@"An exception occurred during template expansion.\n\nException: {name}\n\nReason: {reason}\n", name, reason);
}
