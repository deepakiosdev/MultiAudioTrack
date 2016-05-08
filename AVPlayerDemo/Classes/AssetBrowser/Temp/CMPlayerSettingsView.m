//
//  CMPlayerSettingsView.m
//  CM Library
//
//  Created by dipak on 5/6/16.
//  Copyright © 2016 Prime Focus Technologies. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "CMPlayerSettingsView.h"
#import "CMPlayerSettings.h"
#import "CMUtilities.h"
#import "CMProductConstants.h"
#import "CLLoadingView.h"


@interface CMPlayerSettingsView()
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *audioLeading;

@property (nonatomic, assign) CMPlayerSettingCategoryName selectedCategory;
@property (nonatomic, strong) CMPlayerSettings *settingData;
//@property (nonatomic, strong) NSArray *audioTracks;
//@property (nonatomic, strong) NSArray *bitrates;
@property (nonatomic, weak) IBOutlet UIScrollView *scrollView;
@property (nonatomic, weak) IBOutlet UIButton *audioBtn;
@property (nonatomic, weak) IBOutlet UIButton *bitrateBtn;

@end

@implementation CMPlayerSettingsView


-(id)initWithCoder:(NSCoder*)decoder
{
    self = [super initWithCoder:decoder];
    if (self) {
        [CLLoadingView showLoadingView];
    }
    return  self;
}

#pragma mark- Private methods

-(NSString *)getFullLangugaeNameFromLanguageCode:(NSString *)languageCode {
    NSString *displayName   = @"";
    if (languageCode.length == 0 || [languageCode isEqualToString:@"und"]) {
        return displayName;
    }
    
    NSLocale *englishLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
    displayName             = [[englishLocale
                                displayNameForKey:NSLocaleLanguageCode
                                value:languageCode
                                ] capitalizedString];
    DLog(@"displayName:%@",displayName);
    return displayName;
}

- (void)createAndAddButtonsOnScrollView
{
    for (UIView *view in self.scrollView.subviews) {
        [view removeFromSuperview];
    }
    
    NSArray *dataArray;
    NSUInteger selectedIndex = 0;
    if (self.selectedCategory == CMAutioTrack)
    {
        dataArray = self.settingData.audioTracks;
        if ([dataArray containsObject:self.settingData.selectedAudioTrack]) {
            selectedIndex = [dataArray indexOfObject:self.settingData.selectedAudioTrack];
        }
    } else {
        if ([dataArray containsObject:self.settingData.selectedBitrate]) {
            selectedIndex = [dataArray indexOfObject:self.settingData.selectedBitrate];
        }
    }
    
    int btnWidth    = 100;
    int btnXorigin  = 0;
    
    for (int index = 0; index < dataArray.count; index++)
    {
        {
            //** Get Buttons Title from data array.
            id obj = dataArray[index];
            NSString *title;
            if ([obj isKindOfClass:[AVAssetTrack class]]) {
                title = [self getFullLangugaeNameFromLanguageCode:((AVAssetTrack *)obj).languageCode];
            } else if ([obj isKindOfClass:[AVMediaSelectionOption class]]) {
                title = ((AVMediaSelectionOption*)obj).displayName;
            } else if ([obj isKindOfClass:[CMM3u8Media class]]) {
                double bitrate = ((CMM3u8Media *)obj).bitrate;
                if (bitrate < 1024) {
                    title = [NSString stringWithFormat:@"%f Kbps",bitrate];
                } else {
                    bitrate = bitrate/1024;
                    bitrate = round(100 * bitrate)/ 100;
                    title = [NSString stringWithFormat:@"%.2f Mbps",bitrate];
                }
                
                if (index == 0)
                {
                    title = [NSString stringWithFormat:@"Auto - %@",title];
                }
            }
            //NSString *title = dataArray[index];
            btnXorigin = index*btnWidth;
            UIButton *titleButton = [[UIButton alloc] initWithFrame:CGRectMake(btnXorigin, 0, btnWidth, 52)];
            [titleButton setTitle:title forState:UIControlStateNormal];
            [titleButton setTitleColor:[UIColor blueColor] forState:UIControlStateSelected];
            
            [titleButton setTag:index];
            [titleButton addTarget:self action:@selector(selectedOptionButtonAction:) forControlEvents:UIControlEventTouchUpInside];
            
            if (index == selectedIndex)
            {
                titleButton.selected = YES;
            }
            
            [self.scrollView addSubview:titleButton];
        }
        self.scrollView.contentSize = CGSizeMake(btnWidth*(index+1), self.scrollView.frame.size.height);
    }
}

-(void)selectedOptionButtonAction:(UIButton *)sender
{
    if (self.playerSettingDelegate && [self.playerSettingDelegate respondsToSelector:@selector(selectedPlayerOption:andCategoryName:)])
    {
        id selectedOption = self.selectedCategory == CMAutioTrack ? self.settingData.audioTracks[sender.tag] : self.settingData.bitrates[sender.tag];
        [self.playerSettingDelegate selectedPlayerOption:selectedOption andCategoryName:self.selectedCategory];
    }
}

#pragma mark- Action methods

- (IBAction)audioTrackButtonAction:(UIButton *)sender
{
    if (!sender.selected)
    {
        sender.selected             = !sender.selected;
        self.selectedCategory       = CMAutioTrack;
        self.bitrateBtn.selected    = NO;
        [self createAndAddButtonsOnScrollView];
    }
}

- (IBAction)bitrateButtonAction:(UIButton *)sender
{
    if (!sender.selected)
    {
        sender.selected             = !sender.selected;
        self.selectedCategory       = CMBitrate;
        self.audioBtn.selected      = NO;
        [self createAndAddButtonsOnScrollView];
    }
}

#pragma mark- CMQueuePlayerDelegate methods

- (void)showPlayerSettingsOptionWithData:(CMPlayerSettings *)settingData
{
    self.settingData = settingData;
    //self.audioTracks            = settingData.audioTracks;
    //self.audioTracks            = settingData.bitrates;
    //self.audioTracks = [[NSArray alloc] initWithObjects:@"Hindi", @"English", @"Tamil", @"French", @"Spanish", @"Urdu", nil];
   // self.bitrates = [[NSArray alloc] initWithObjects:@"922 Kbps", @"1024 Kbps", @"1.235 Mbps", @"2.976 Mbps", @"2.495 Mbps", @"3.055 Mbps", nil];
   
    self.selectedCategory  = CMAutioTrack;
    self.audioBtn.selected = YES;
    
    if (self.self.settingData.bitrates.count == 0)
    {
        self.bitrateBtn.hidden      = YES;
        self.audioLeading.constant  = (self.frame.size.width - self.audioBtn.frame.size.width)/2;
    }
    [self createAndAddButtonsOnScrollView];
    [CLLoadingView hideLoadingView];
}

- (void)hidePlayerSettingsOption
{
    if (self.playerSettingDelegate && [self.playerSettingDelegate respondsToSelector:@selector(hidePlayerSettingsView)])
    {
        [self.playerSettingDelegate hidePlayerSettingsView];
    }
}

@end

