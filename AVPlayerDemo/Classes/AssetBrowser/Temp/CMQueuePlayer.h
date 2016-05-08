//
//  CBCAVPlayer.h
//  ClearBCProduct
//
//  Created by Bishwajit on 7/25/14.
//  Copyright (c) 2014 Prime Focus Technology. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <CoreMedia/CMTime.h>
#import "CMPlayerSettings.h"


@protocol CMQueuePlayerDelegate <NSObject>

- (void)showPlayerSettingsOptionWithData:(CMPlayerSettings *)settingData;
- (void)hidePlayerSettingsOption;
@end

@interface CMQueuePlayer : UIView

//@property (nonatomic, assign) BOOL isSecuredPlay;

@property (nonatomic, assign)   CMTime currentSomTime;
@property (nonatomic, assign)   CGFloat framesPerSecond;
@property (nonatomic, weak) id <CMQueuePlayerDelegate>playerDelegate;


- (void)initWithURLString:(NSString*)urlString andDelegate:(id)delegate;
- (void)initWithURLList:(NSArray*)urlList andDelegate:(id)delegate;

- (CGFloat)durationInSeconds;
- (CGFloat)currentPosInSeconds;
- (CGFloat)getPlayerVolume;

- (void)stepFrame:(BOOL)next;
- (void)setPlaybackRate:(float)rateVal;
- (void)setPlayerVolume:(CGFloat)volume;
- (void)setFrameRateForVideo:(Float64)frames;

- (void)play:(id)sender;
- (void)pause:(id)sender;
-(void)replaceCurrentItem:(NSString*)urlString;
-(void)reloadItems:(NSArray*)items;
-(void)advanceNextItem;

- (void)seekToTimeCode:(NSString *)timeCode completionHandler:(void (^)(BOOL success))completionHandler;
- (void)seekToCMTime:(CMTime)seekTime completionHandler:(void (^)(BOOL success))completionHandler;
- (void)seekToLastPlaybackTimeCode:(CGFloat)timeCode completionHandler:(void (^)(BOOL success))completionHandler;

- (NSString*)getCurrentTimeWithFramePrecision;
- (CMTime)getDuration;
- (CMTime)getSOM;
- (Float64)getFrameRate;

- (BOOL)isMediaInitialized;
- (BOOL)isUrlLiveStreaming:(NSURL*)URL;
- (BOOL)isPlaying;

- (CMTime)getCurrentTime;
- (int64_t)getCurrentTimeInTicks;

- (void)cleanup;
- (void)scrub:(float)progressValue completionHandler:(void (^)(BOOL))completionHandler;
- (CGFloat)getCurrentTimeInseconds;
- (CMTime)getCurrentTimeWithTime;

- (void)playSelectedAudioTrack:(id)track;
- (void)replaceCurrentItemWithSelectedMedia:(CMM3u8Media *)selectedMedia;
- (void)fetchSettingData:(id)delegate;

@end
