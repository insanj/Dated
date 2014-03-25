// Dated (commercial tweak)
// Created by Julian (insanj) Weiss 2014
// Source and license available on Git

#import "Dated.h"

/**************************** Global Converstion Methods ****************************/

@implementation DDAutoupdatingDateFormatter

//static NSString *dated_previewDateComponents()
+ (NSString *)templateStringFromSavedComponents {
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Preferences/com.insanj.dated.plist"]];

	NSString *year = [[settings objectForKey:@"year"] boolValue] ? @"y" : @"";
	NSString *month = ![[settings objectForKey:@"month"] boolValue] ? @"M" : @"";
	NSString *day = ![[settings objectForKey:@"day"] boolValue] ? @"d" : @"";
	NSString *hour = ![[settings objectForKey:@"hour"] boolValue] ? @"H" : @"";
	NSString *min = ![[settings objectForKey:@"minute"] boolValue] ? @"m" : @"";
	NSString *sec = [[settings objectForKey:@"second"] boolValue] ? @"s" : @"";
	NSString *ampm = ![[settings objectForKey:@"ampm"] boolValue] ? @"j" : @"";
	return [NSString stringWithFormat:@"%@%@%@%@%@%@%@", year, month, day, hour, min, sec, ampm];
}

// static NSString *dated_previewDateWithComponents(NSDate *date, NSString *components)
+ (NSString *)stringFromDate:(NSDate *)date usingTemplate:(NSString *)components {
	if (MODERN_IOS) {
		CKAutoupdatingDateFormatter *formatter = [[[objc_getClass("CKAutoupdatingDateFormatter") alloc] initWithTemplate:components] autorelease];
		return [formatter stringFromDate:date];
	}

	else {
		NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
		[formatter setDateFormat:[NSDateFormatter dateFormatFromTemplate:components options:0 locale:[NSLocale currentLocale]]];
		return [formatter stringFromDate:date];
	}
}

@end

/**************************** Timestamp Hooks ****************************/

%group Modern

%hook CKAutoupdatingDateFormatter

// CKAutoupdatingDateFormatter templates don't strictly follow NSDateFormatter,
// instead, they steal away the components specified in the template, and arrage
// them based on the system localization (the translation follows %orig(XXX)).

// Templates come in four variants:
//	EEEE (@"Saturday")
//	EEEEjm (@"Saturday 11:42 AM")
//	jm (@"11:42 AM")

- (id)initWithTemplate:(id)arg1 {
	if ([arg1 isEqualToString:@"jm"]) {
		NSLog(@"[Dater] Heard initialization attempt on per-message dateFormatter, replacing with long form...");
		return %orig([DDAutoupdatingDateFormatter templateStringFromSavedComponents]); // default is @"Mdjmm" -> @"3/15, 11:44 AM"
	}

	else {
		return %orig(arg1);
	}
}

%end

/*************************** Drawer Size Hooks ***************************/

// The method I chose for expanding the label size with %hook'ing the
// -layoutSubviews for the entire ballon. This method is guaranteed to work,
// although it may not be the most efficient. The numbered methods in the .h
// were other tempting methods, but didn't get called as consistently.

%hook CKTranscriptBalloonCell

- (void)layoutSubviews {
	%orig();

	UILabel *label = self.drawerLabel;

	// Will be invalidated by CKUIBehavior if too large.
	CGFloat requiredWidth =  [label.text sizeWithFont:label.font].width;
	[label setFrame:CGRectMake(label.frame.origin.x, label.frame.origin.y, fmin(requiredWidth, CKDRAWERWIDTH), label.frame.size.height)];

	label.minimumScaleFactor = 0.5;
	label.adjustsFontSizeToFitWidth = YES;
}

%end

%end // %group Modern


%group Ancient

%hook CKTimestampCell

- (void)setDate:(NSDate *)date {
	UILabel *label = MSHookIvar<UILabel *>(self, "_label");
	[label setText:[DDAutoupdatingDateFormatter stringFromDate:date usingTemplate:[DDAutoupdatingDateFormatter templateStringFromSavedComponents]]];
}

%end

%hook CKTranscriptBubbleData

- (BOOL)_shouldShowTimestampForDate:(id)arg1 {
	NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[NSHomeDirectory() stringByAppendingPathComponent:@"/Library/Preferences/com.insanj.dated.plist"]];
	return %orig() || [[settings objectForKey:@"allmessages"] boolValue];
}

%end

%end // %group Ancient


%ctor {
	if (MODERN_IOS) {
		NSLog(@"[Dated] Injecting modern hooks into ChatKit...");
		%init(Modern);
	}

	else {
		NSLog(@"[Dated] Injecting ancient hooks into ChatKit...");
		%init(Ancient);
	}
}
