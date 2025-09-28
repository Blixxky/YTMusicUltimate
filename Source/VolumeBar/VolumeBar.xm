#include "GSVolBar.h"

static BOOL YTMU(NSString *key) {
    NSDictionary *YTMUltimateDict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"YTMUltimate"];
    return [YTMUltimateDict[key] boolValue];
}

static BOOL volumeBar = YTMU(@"YTMUltimateIsEnabled") && YTMU(@"volBar");

@interface YTMWatchView: UIView
@property (readonly, nonatomic) BOOL isExpanded;
@property (nonatomic, strong) UIView *tabView;
@property (nonatomic) long long currentLayout;
@property (nonatomic, strong) GSVolBar *volumeBar;

- (void)updateVolBarVisibility;
@end

%hook YTMWatchView
%property (nonatomic, strong) GSVolBar *volumeBar;

- (instancetype)initWithColorScheme:(id)scheme {
    self = %orig;

    if (self && volumeBar) {
        self.volumeBar = [[GSVolBar alloc] initWithFrame:CGRectMake(self.frame.size.width / 2 - (self.frame.size.width / 2) / 2, 0, self.frame.size.width / 2, 25)];

        [self addSubview:self.volumeBar];
    }

    return self;
}

- (void)layoutSubviews {
    %orig;

    if (volumeBar) {
        self.volumeBar.frame = CGRectMake(self.frame.size.width / 2 - (self.frame.size.width / 2) / 2, CGRectGetMinY(self.tabView.frame) - 25, self.frame.size.width / 2, 25);
    }
}

- (void)updateColorsAfterLayoutChangeTo:(long long)arg1 {
    %orig;

    if (volumeBar) {
        [self updateVolBarVisibility];
    }
}

- (void)updateColorsBeforeLayoutChangeTo:(long long)arg1 {
    %orig;

    if (volumeBar) {
        self.volumeBar.hidden = YES;
    }
}

%new
- (void)updateVolBarVisibility {
    if (volumeBar) {
        // Read the properties into local variables before the dispatch block.
        // This resolves the "variable length array" error by simplifying what the block needs to capture.
        BOOL isExpanded = self.isExpanded;
        long long currentLayout = self.currentLayout;
        BOOL shouldHide = !(isExpanded && currentLayout == 2);

        dispatch_async(dispatch_get_main_queue(), ^(void){
            // Use the simple local variable within the block.
            self.volumeBar.hidden = shouldHide;
        });
    }
}

%end
