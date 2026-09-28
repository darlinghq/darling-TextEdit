#!/usr/bin/env ruby
# Execute the full save method with controlled workspace/storage/controller adapters.
require 'tmpdir'
root = ARGV.shift or abort 'usage: ruby tests/windowless-save.rb GNUSTEP_ROOT [Document.m]'
source = File.read(ARGV.shift || File.expand_path('../Document.m', __dir__))
method = source[/- \(id\)fileWrapperOfType:.*?\n\}/m] or abort 'save method missing'
constants = method.scan(/\b(?:NS\w+DocumentAttribute|NS\w+DocumentType|NSTextLayoutSectionsAttribute|kUTType\w+|SimpleTextType|Word97Type|Word2007Type|Word2003XMLType|OpenDocumentTextType|UseXHTMLDocType|UseTransitionalDocType|UseEmbeddedCSS|UseInlineCSS|PreserveWhitespace|HTMLEncoding)\b/).uniq
Dir.mktmpdir('textedit-save-') do |dir|
  code = "#import <Foundation/Foundation.h>\n#include <assert.h>\n"
  code += constants.map { |name| "static NSString * const #{name} = @\"#{name}\";" }.join("\n") + "\n"
  code += <<~'OBJC'
    enum { NSSaveOperation = 0, NSSaveAsOperation = 1 };
    static const NSStringEncoding NoStringEncoding = 0;
    static NSDictionary *captured;
    static int wrapperCalls, dataCalls, controllerCalls;
    static BOOL failSerialization;
    @interface NSWorkspace : NSObject
    +(id)sharedWorkspace;
    -(BOOL)type:(NSString*)type conformsToType:(NSString*)other;
    @end
    @implementation NSWorkspace
    +(id)sharedWorkspace { return [[[self alloc] init] autorelease]; }
    -(BOOL)type:(NSString*)type conformsToType:(NSString*)other { return [type isEqual:other]; }
    @end
    @interface NSTextStorage : NSObject
    -(NSUInteger)length;
    -(id)fileWrapperFromRange:(NSRange)range documentAttributes:(NSDictionary*)attributes error:(NSError**)error;
    -(id)dataFromRange:(NSRange)range documentAttributes:(NSDictionary*)attributes error:(NSError**)error;
    @end
    @implementation NSTextStorage
    -(NSUInteger)length { return 7; }
    -(NSData*)capture:(NSRange)range attributes:(NSDictionary*)attributes error:(NSError**)error {
      assert(range.location == 0 && range.length == 7);
      [captured release]; captured = [attributes copy];
      if (failSerialization) {
        if (error) *error = [NSError errorWithDomain:@"fixture" code:42 userInfo:nil];
        return nil;
      }
      return [@"fixture" dataUsingEncoding:NSUTF8StringEncoding];
    }
    -(id)fileWrapperFromRange:(NSRange)range documentAttributes:(NSDictionary*)attributes error:(NSError**)error {
      ++wrapperCalls;
      NSData *data = [self capture:range attributes:attributes error:error];
      return data ? [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease] : nil;
    }
    -(id)dataFromRange:(NSRange)range documentAttributes:(NSDictionary*)attributes error:(NSError**)error {
      ++dataCalls; return [self capture:range attributes:attributes error:error];
    }
    @end
    @interface Controller : NSObject { @public NSArray *sections; }
    -(NSArray*)layoutOrientationSections;
    @end
    @implementation Controller
    -(NSArray*)layoutOrientationSections { ++controllerCalls; return sections; }
    @end
    @interface Margins : NSObject
    -(double)leftMargin; -(double)rightMargin; -(double)topMargin; -(double)bottomMargin;
    @end
    @implementation Margins
    -(double)leftMargin { return 1; } -(double)rightMargin { return 2; }
    -(double)topMargin { return 3; } -(double)bottomMargin { return 4; }
    @end
    @interface Document : NSObject {
      @public NSArray *fixtureControllers, *original;
      NSStringEncoding documentEncodingForSaving, savedEncoding;
      int currentSaveOperation, encodingUpdates;
    }
    -(id)fileWrapperOfType:(NSString*)type error:(NSError**)error;
    @end
    @implementation Document
    -(NSTextStorage*)textStorage { return [[[NSTextStorage alloc] init] autorelease]; }
    -(NSSize)paperSize { return NSMakeSize(600, 800); }
    -(NSSize)viewSize { return NSZeroSize; }
    -(BOOL)isReadOnly { return NO; }
    -(float)hyphenationFactor { return 0; }
    -(Margins*)printInfo { return [[[Margins alloc] init] autorelease]; }
    -(BOOL)hasMultiplePages { return NO; }
    -(BOOL)usesScreenFonts { return YES; }
    -(double)scaleFactor { return 1; }
    -(id)backgroundColor { return nil; }
    -(NSStringEncoding)encoding { return NSUTF8StringEncoding; }
    -(NSStringEncoding)suggestedDocumentEncoding { return NSUTF8StringEncoding; }
    -(void)setEncoding:(NSStringEncoding)value { savedEncoding = value; ++encodingUpdates; }
    -(BOOL)isOpenedIgnoringRichText { return NO; }
    -(NSArray*)windowControllers { return fixtureControllers; }
    -(NSArray*)originalOrientationSections { return original; }
    -(NSArray*)knownDocumentProperties { return [NSArray array]; }
    -(NSDictionary*)documentPropertyToAttributeNameMappings { return [NSDictionary dictionary]; }
  OBJC
  code += method + "\n@end\n"
  code += <<~'OBJC'
    int main(void) {
      @autoreleasepool {
        Document *doc = [[[Document alloc] init] autorelease];
        NSArray *original = [NSArray arrayWithObject:@"original-sections"];
        NSArray *live = [NSArray arrayWithObject:@"live-sections"];
        Controller *controller = [[[Controller alloc] init] autorelease];
        NSArray *types = [NSArray arrayWithObjects:kUTTypePlainText, kUTTypeRTF, kUTTypeRTFD, nil];
        NSArray *formats = [NSArray arrayWithObjects:NSPlainTextDocumentType, NSRTFTextDocumentType, NSRTFDTextDocumentType, nil];
        for (NSUInteger t = 0; t < [types count]; ++t) {
          for (int scenario = 0; scenario < 4; ++scenario) {
            doc->fixtureControllers = scenario < 2 ? [NSArray array] : [NSArray arrayWithObject:controller];
            doc->original = scenario == 0 ? nil : original;
            controller->sections = scenario == 3 ? live : nil;
            for (int failure = 0; failure < 2; ++failure) {
              failSerialization = failure;
              wrapperCalls = dataCalls = controllerCalls = doc->encodingUpdates = 0;
              NSError *error = nil;
              NSFileWrapper *result = [doc fileWrapperOfType:[types objectAtIndex:t] error:&error];
              assert((result == nil) == (failure != 0));
              if (failure) assert([error code] == 42);
              else assert([[result regularFileContents] isEqual:[@"fixture" dataUsingEncoding:NSUTF8StringEncoding]]);
              id expected = scenario == 1 ? original : scenario == 3 ? live : nil;
              assert([captured objectForKey:NSTextLayoutSectionsAttribute] == expected);
              assert([[captured objectForKey:NSDocumentTypeDocumentAttribute] isEqual:[formats objectAtIndex:t]]);
              assert(controllerCalls == (scenario < 2 ? 0 : 1));
              assert(wrapperCalls == (t == 1 ? 0 : 1) && dataCalls == (t == 1 ? 1 : 0));
              assert(doc->encodingUpdates == (t == 0 && !failure ? 1 : 0));
            }
          }
        }
        [captured release]; captured = nil;
      }
      puts("PASS: full save method, 24 headless/controller/format/failure cases");
    }
  OBJC
  File.write("#{dir}/probe.m", code)
  gcc_include = IO.popen(['gcc', '-print-file-name=include'], &:read).strip
  system('clang', '-fobjc-runtime=gcc', '-fconstant-string-class=NSConstantString', "-I#{root}/usr/include/GNUstep", "-I#{gcc_include}", "#{dir}/probe.m", "-L#{root}/usr/lib", "-Wl,-rpath,#{root}/usr/lib", '-lgnustep-base', '-lobjc', '-o', "#{dir}/probe", exception: true)
  system("#{dir}/probe", exception: true)
end
