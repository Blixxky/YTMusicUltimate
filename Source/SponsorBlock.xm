#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "Headers/Localization.h"
#import "Headers/YTMToastController.h"
#import "Headers/YTPlayerViewController.h"

#define ytmuBool(key) [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"][key] boolValue]
#define ytmuInt(key) [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"][key] integerValue]

%hook YTPlayerViewController
%property (nonatomic, strong) NSMutableDictionary *sponsorBlockValues;

- (void)playbackController:(id)arg1 didActivateVideo:(id)arg2 withPlaybackData:(id)arg3 {
    %orig;

    if (!ytmuBool(@"sponsorBlock")) return;

    self.sponsorBlockValues = [NSMutableDictionary dictionary];

    // Use NSURLComponents for safer and cleaner URL construction
    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://sponsor.ajay.app/api/skipSegments"];
    NSString *categories = @"[\"music_offtopic\"]";
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"videoID" value:self.currentVideoID],
        [NSURLQueryItem queryItemWithName:@"categories" value:categories]
    ];

    if (!components.URL) {
        NSLog(@"YTMUltimate (SponsorBlock): Invalid URL generated.");
        return;
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:components.URL];

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            NSLog(@"YTMUltimate (SponsorBlock): Network request failed with error: %@", error.localizedDescription);
            return;
        }

        NSError *jsonError = nil;
        id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

        if (jsonError || ![jsonResponse isKindOfClass:[NSArray class]]) {
            NSLog(@"YTMUltimate (SponsorBlock): JSON parsing failed or response is not an array.");
            return;
        }

        NSArray *segmentsArray = (NSArray *)jsonResponse;
        NSMutableDictionary *segmentsState = [NSMutableDictionary dictionaryWithCapacity:segmentsArray.count];

        for (id segmentObj in segmentsArray) {
            if ([segmentObj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *segmentDict = (NSDictionary *)segmentObj;
                NSString *uuid = segmentDict[@"UUID"];
                if ([uuid isKindOfClass:[NSString class]]) {
                    // Initialize all segments as skippable (state 1)
                    [segmentsState setObject:@(1) forKey:uuid];
                }
            }
        }
        
        // Update properties on the main thread to ensure thread safety
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.sponsorBlockValues) {
                [self.sponsorBlockValues setObject:segmentsArray forKey:self.currentVideoID];
                [self.sponsorBlockValues setObject:segmentsState forKey:@"segments"];
            }
        });

    }] resume];
}

- (void)singleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    [self skipSegment];
}

- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    [self skipSegment];
}

%new
- (void)skipSegment {
    if (!ytmuBool(@"sponsorBlock") || !self.sponsorBlockValues) {
        return;
    }

    NSArray *sponsorBlockData = [self.sponsorBlockValues objectForKey:self.currentVideoID];
    if (![sponsorBlockData isKindOfClass:[NSArray class]]) {
        return;
    }

    NSMutableDictionary *segmentSkipValues = [self.sponsorBlockValues objectForKey:@"segments"];

    for (NSDictionary *segmentDict in sponsorBlockData) {
        if (![segmentDict isKindOfClass:[NSDictionary class]]) continue;

        NSString *uuid = segmentDict[@"UUID"];
        NSString *category = segmentDict[@"category"];
        NSArray *segmentTimes = segmentDict[@"segment"];

        if (![uuid isKindOfClass:[NSString class]] || ![category isKindOfClass:[NSString class]] || ![segmentTimes isKindOfClass:[NSArray class]] || segmentTimes.count < 2) {
            continue; // Skip malformed segment
        }

        NSNumber *segmentSkipValue = [segmentSkipValues objectForKey:uuid];
        if (![segmentSkipValue isEqual:@(1)] || ![category isEqual:@"music_offtopic"]) {
            continue;
        }

        float startTime = [segmentTimes[0] floatValue];
        float endTime = [segmentTimes[1] floatValue];

        BOOL isWithinSegment = self.currentVideoMediaTime >= startTime && self.currentVideoMediaTime <= (endTime - 1.0f);

        if (isWithinSegment) {
            // Mark this segment as processed to prevent re-triggering
            [segmentSkipValues setObject:@(0) forKey:uuid];
            [self.sponsorBlockValues setObject:segmentSkipValues forKey:@"segments"];

            // --- Handler Block Refactoring ---
            // The main fix: local variables `startTime` and `endTime` are captured by the blocks.
            // This is simple for the compiler and avoids the Variable Length Array (VLA) error.
            
            GOOHUDMessageAction *unskipAction = [[%c(GOOHUDMessageAction) alloc] init];
            unskipAction.title = LOC(@"UNSKIP");
            [unskipAction setHandler:^{
                [self seekToTime:startTime];
            }];
            
            GOOHUDMessageAction *skipAction = [[%c(GOOHUDMessageAction) alloc] init];
            skipAction.title = LOC(@"SKIP");
            [skipAction setHandler:^{
                [self seekToTime:endTime];
                [[%c(YTMToastController) alloc] showMessage:LOC(@"SEGMENT_SKIPPED") HUDMessageAction:unskipAction infoType:0 duration:ytmuInt(@"sbDuration")];
            }];

            if (ytmuInt(@"sbSkipMode") == 0) { // Auto-skip mode
                [self seekToTime:endTime];
                [[%c(YTMToastController) alloc] showMessage:LOC(@"SEGMENT_SKIPPED") HUDMessageAction:unskipAction infoType:0 duration:ytmuInt(@"sbDuration")];
            } else { // Manual-skip mode
                [[%c(YTMToastController) alloc] showMessage:LOC(@"FOUND_SEGMENT") HUDMessageAction:skipAction infoType:0 duration:ytmuInt(@"sbDuration")];
            }

            // A segment was found and handled, so we can exit the loop.
            break;
        }
    }
}
%end

%ctor {
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"]];

    if (mutableDict[@"sbSkipMode"] == nil) {
        [mutableDict setObject:@(0) forKey:@"sbSkipMode"];
    }

    if (mutableDict[@"sbDuration"] == nil) {
        [mutableDict setObject:@(10) forKey:@"sbDuration"];
    }

    [[NSUserDefaults standardUserDefaults] setObject:mutableDict forKey:@"YTMUltimate"];
}
