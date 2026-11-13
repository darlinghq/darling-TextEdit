/*
 Copyright (C) 2026 Lubos Dolezel
 Darling is free software under the GNU GPL version 3 or later.
*/
// Saving a document that has no window controller (as when it is saved through scripting) must not
// fail, and must keep the layout orientation sections read from the file (-originalOrientationSections)
// among the attributes handed to the text storage. -[Document fileWrapperOfType:error:] used to index
// [self windowControllers][0] unconditionally and raised NSRangeException.
//
// Built together with the application sources except Edit_main.m:
//   guest-cc.sh -o windowless-save -I. tests/windowless-save.m Document.m DocumentController.m \
//     DocumentPropertiesPanelController.m DocumentWindowController.m Controller.m EncodingManager.m \
//     FontNameTransformer.m LinePanelController.m MultiplePageView.m Preferences.m PrintingTextView.m \
//     PrintPanelAccessoryController.m ScalingScrollView.m -framework AppKit -framework Foundation
// Needs an X display (the document creates AppKit objects). Prints PASS or FAIL lines.
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "Document.h"

static NSDictionary *captured;

static id captureData(id self, SEL _cmd, NSRange range, NSDictionary *attributes, NSError **error) {
	[captured release];
	captured = [attributes copy];
	return [@"fixture" dataUsingEncoding: NSUTF8StringEncoding];
}

static int g_fail;

static void expect(const char *label, BOOL ok) {
	if (!ok) {
		printf("FAIL %s\n", label);
		g_fail++;
	}
}

int main(void) {
	@autoreleasepool {
		[NSApplication sharedApplication];

		Method m = class_getInstanceMethod([NSTextStorage class],
				@selector(dataFromRange:documentAttributes:error:));
		method_setImplementation(m, (IMP)captureData);

		NSArray *sections = [NSArray arrayWithObject:
				[NSDictionary dictionaryWithObject: [NSNumber numberWithInteger: 1] forKey: @"Orientation"]];

		Document *doc = [[[Document alloc] init] autorelease];
		expect("a new document has no window controllers", [[doc windowControllers] count] == 0);

		[doc setOriginalOrientationSections: sections];
		NSError *error = nil;
		id wrapper = nil;
		BOOL raised = NO;
		@try {
			wrapper = [doc fileWrapperOfType: @"public.rtf" error: &error];
		} @catch (NSException *e) {
			raised = YES;
		}
		expect("saving without a window does not raise", !raised);
		expect("saving without a window returns a file wrapper", wrapper != nil);
		expect("sections from the document model are passed on",
				[[captured objectForKey: NSTextLayoutSectionsAttribute] isEqual: sections]);

		[doc setOriginalOrientationSections: nil];
		[captured release];
		captured = nil;
		wrapper = nil;
		raised = NO;
		@try {
			wrapper = [doc fileWrapperOfType: @"public.rtf" error: &error];
		} @catch (NSException *e) {
			raised = YES;
		}
		expect("no sections: saving without a window does not raise", !raised && wrapper != nil);
		expect("no sections: the attribute is absent",
				captured != nil && [captured objectForKey: NSTextLayoutSectionsAttribute] == nil);
	}
	if (g_fail == 0)
		printf("PASS\n");
	return g_fail != 0;
}
