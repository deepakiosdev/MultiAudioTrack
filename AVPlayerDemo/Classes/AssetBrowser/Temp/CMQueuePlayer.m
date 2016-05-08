//
//  CBCAVPlayer.m
//  ClearBCProduct
//
//  Created by Bishwajit on 7/25/14.
//  Copyright (c) 2014 Prime Focus Technology. All rights reserved.
//

#import "CMQueuePlayer.h"

#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "CBCDownloadManager.h"

#import "CBCRCPlayerDelegate.h"
#import "CMProductConstants.h"
#import "CMRestInterface.h"
#import "NSData+MD5.h"
#import "CMUtilities.h"
#import "Base64.h"
#import "CBCProductEntity.h"
#import "CMProductDataManager.h"
#import "CMProductConstants.h"
#import "CMServicesUtilities.h"
#import "CBCDigitalWatermarkQuery.h"
#import "CMRestInterface.h"
#import "CBCDigitalWatermarkResult.h"
#import "CBCDigitalWaterMark.h"
//#import "CBCWaterMarkView.h"
#import "CMDataMacros.h"


#define BUFFER_RESUME       5.0f

// Contexts for KVO
static void *kAirplayKVO                = &kAirplayKVO;
static void *kBufferEmptyKVO            = &kBufferEmptyKVO;
static void *kStatusDidChangeKVO        = &kStatusDidChangeKVO;
static void *kTimeRangesKVO             = &kTimeRangesKVO;
static void *kBufferKeepup              = &kBufferKeepup;


@interface CMQueuePlayer() <AVAssetResourceLoaderDelegate>

@property (nonatomic, weak) id <CBCRCPlayerDelegate> delegate;
@property (nonatomic, readonly) AVPlayerLayer *playerLayer;

@property (nonatomic, strong)   AVQueuePlayer *player;
@property (nonatomic, strong)   id playerTimeObserver;

@property (nonatomic, assign)   CMTime duration;

@property (nonatomic, assign)   Float64 framerateFractionValue;

@property (nonatomic, assign)   CGFloat playSpeedRate;

@property (nonatomic, retain) UILabel *userNameWaterMarkLabel;

@property (nonatomic, retain) UILabel *timerWaterMarkLabel;
@property (nonatomic, retain) NSDateFormatter *dateFormatter;
@property (nonatomic, retain) NSTimer* timer;
//@property (nonatomic, retain) CBCWaterMarkView *waterMarkView;

@property (nonatomic, assign) double lastBitRate;
@property (nonatomic, assign) BOOL isBitrateSwitching;
@property (nonatomic, assign) CMTime bitRateSwitchTime;
@property (nonatomic, strong) NSArray *videos;
@property (nonatomic, strong) CMPlayerSettings *playerSettingData;

@end

@implementation CMQueuePlayer

@dynamic player;
@dynamic playerLayer;
@dynamic duration;

#pragma mark - private methods
-(void)setup
{
    
    [self.playerLayer setOpacity:1.0];
    [self.playerLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    [self.playerLayer setNeedsDisplayOnBoundsChange:YES];
    [self.layer setNeedsDisplayOnBoundsChange:YES];

    if (_framesPerSecond == 0) {
        _framesPerSecond = 25.0f;
    }
    _framerateFractionValue = 0.2f;
    _playSpeedRate = 1.0f;
    
    self.player = [[AVQueuePlayer alloc] init];
    
    //    [self addSubview:[self userNameWaterMarkLabel]];
    //    [self addSubview:[self timerWaterMarkLabel]];
    //[self addWaterMark:self.frame];
}


/*- (void)addWaterMark:(CGRect)frame
 {
 [_waterMarkView removeFromSuperview];
 if(!_waterMarkView) {
 NSBundle *resourceBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:CBC_RESOURCE_BUNDLE_NAME ofType:@"bundle"]];
 [resourceBundle loadAndReturnError:nil];
 _waterMarkView = [[resourceBundle loadNibNamed:@"CBCWaterMarkView" owner:nil options:nil] lastObject];
 }
 CGRect playerFrame = self.bounds;
 [_waterMarkView setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin)];
 [_waterMarkView setFrame:CGRectMake(playerFrame.size.width /4+300, frame.size.height - 300 , _waterMarkView.frame.size.width, _waterMarkView.frame.size.height)];
 [_waterMarkView setWaterMarkinPlayer:_isSecuredPlay];
 [self.window addSubview:_waterMarkView];
 //    [self bringSubviewToFront:_waterMarkView];
 }*/

- (void)addObservers
{
    //remove all old observers
    [self removeObservers];
    
    [self.player addObserver:self forKeyPath:@"currentItem.playbackBufferEmpty"         options:NSKeyValueObservingOptionNew context:kBufferEmptyKVO];
    [self.player addObserver:self forKeyPath:@"airPlayVideoActive"                      options:NSKeyValueObservingOptionNew context:kAirplayKVO];
    [self.player addObserver:self forKeyPath:@"currentItem.status"                      options:NSKeyValueObservingOptionNew context:kStatusDidChangeKVO];
    [self.player addObserver:self forKeyPath:@"currentItem.loadedTimeRanges"            options:NSKeyValueObservingOptionNew context:kTimeRangesKVO];
    [self.player addObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"      options:NSKeyValueObservingOptionNew context:kBufferKeepup];
    
    // [self.player addObserver:self forKeyPath:@"currentItem" options:NSKeyValueObservingOptionNew context:nil];
    
    [self initTimer];
    
}

-(void)removeObservers
{
    @try
    {
        [self.player removeObserver:self forKeyPath:@"currentItem.playbackBufferEmpty"      context:kBufferEmptyKVO];
        [self.player removeObserver:self forKeyPath:@"airPlayVideoActive"                   context:kAirplayKVO];
        [self.player removeObserver:self forKeyPath:@"currentItem.status"                   context:kStatusDidChangeKVO];
        [self.player removeObserver:self forKeyPath:@"currentItem.loadedTimeRanges"         context:kTimeRangesKVO];
        [self.player removeObserver:self forKeyPath:@"currentItem.playbackLikelyToKeepUp"   context:kBufferKeepup];
        
        //[self.player removeObserver:self forKeyPath:@"currentItem" context:nil];
        
        [self.timer invalidate];
        [self setTimer:nil];
        
        if (_playerTimeObserver) {
            [self.player removeTimeObserver:self.playerTimeObserver];
        }
    }
    @catch (NSException *exception) {
        
    }
    
    _playerTimeObserver = nil;
}

- (void)playerTimeUpdate
{
    [[CBCDownloadManager sharedInstance] refreshSessionLock];
    
    if([[self delegate] respondsToSelector:@selector(playerTimeUpdate:time:)])
    {
        CMTime curTime = self.player.currentTime;

        if([[self delegate] respondsToSelector:@selector(playerTimeUpdate:time:withFrameRate:)]) {
            [[self delegate] playerTimeUpdate:self.tag time:curTime withFrameRate:_framesPerSecond];
        }
    }
}

#pragma mark - Self methods
+ (Class)layerClass {
    return [AVPlayerLayer class];
}

+ (void)initialize
{
    if (self == [CMQueuePlayer class]) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

-(id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self setup];
    }
    
    return self;
}

- (void)dealloc
{
    [self removeObservers];
    
    self.player = nil;
    _playerTimeObserver = nil;
}

- (AVPlayer *)player {
    return [(AVPlayerLayer *)[self layer] player];
}

- (void)setPlayer:(AVQueuePlayer *)player
{
    [(AVPlayerLayer *) [self layer] setPlayer:player];
    
    // Optimize for airplay if possible
    if ([player respondsToSelector:@selector(allowsAirPlayVideo)])
    {
        //Fix for: Bug #40259:While streaming via AirPlay to my AppleTV and the dynamic watermark is missing on the TV
        // Property setAllowsExternalPlayback should be NO to disable playing of video when mirroring is turned off
        [player setAllowsExternalPlayback:NO];
        // Property UsesExternalPlaybackWhileExternalScreenIsActive should be NO to enable mirroring via Air play
        [player setUsesExternalPlaybackWhileExternalScreenIsActive:NO];
    }
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)[self layer];
}


#pragma mark - public methods
-(void)initWithURLString:(NSString*)urlString andDelegate:(id)delegate
{
    if (!urlString) {
        urlString = @"";
    }
    
    [self initWithURLList:@[urlString] andDelegate:delegate];
}

-(void)initWithURLList:(NSArray *)urlList andDelegate:(id)delegate
{
    [self clearUserSettingsData];
    _delegate = delegate;
    [self reloadItems:urlList];
    [self setPlaybackRate:1.0f];
    [self addObservers];
}

#pragma mark - time handlers
- (CMTime)duration
{
    // Pefered in HTTP Live Streaming.
    if ([self.player.currentItem respondsToSelector:@selector(duration)])
    {
        if (CMTIME_IS_VALID(self.player.currentItem.duration)) {
            return self.player.currentItem.duration;
        }
    }
    else if (CMTIME_IS_VALID(self.player.currentItem.asset.duration)) {
        return self.player.currentItem.asset.duration;
    }
    
    return kCMTimeInvalid;
}

- (CGFloat)durationInSeconds
{
    CMTime time = [self duration];
    if(!CMTIME_IS_VALID(time)) {
        return 0.0f;
    }
    
    return (CGFloat)time.value / (CGFloat)time.timescale;
}

-(CGFloat)currentPosInSeconds
{
    CMTime currentTime = self.player.currentItem.currentTime;
    CGFloat curPos = CMTimeGetSeconds(currentTime);
    return curPos;
}

#pragma mark - volume handlers
-(void)setPlayerVolume:(CGFloat)volume {
    [self.player setVolume:volume];
}

-(CGFloat)getPlayerVolume {
    return [self.player volume];
}

#pragma mark - playback handlers
- (void)play:(id)sender {
    [self.player setRate:_playSpeedRate];
}

- (void)pause:(id)sender {
    [self.player pause];
}

-(void)replaceCurrentItem:(NSString*)urlString {
    [self reloadItems:@[urlString]];
}

-(void)reloadItems:(NSArray*)items
{
    [self.player pause];
    
    [self.player removeAllItems];
    
    for (NSString *urlString in items)
    {
        NSURL *url                  = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
//          url = [NSURL URLWithString:@"http://192.168.150.205:1001/nmdcVIACOMUSA/20160125/others/89.mp4"];

        DLog(@"queue player URLS %@", url);
        
        NSMutableDictionary * headers = [NSMutableDictionary dictionary];
        [headers setObject:@"iPad" forKey:@"User-Agent"];
        
        AVURLAsset *asset           = [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
        
        AVAssetResourceLoader *resourceLoader = asset.resourceLoader;
        [resourceLoader setDelegate:self queue:dispatch_queue_create("CMQueuePlayerAsset loader", nil)];
        
        AVPlayerItem *playerItem    = [[AVPlayerItem alloc] initWithAsset:asset];
        if([self.player canInsertItem:playerItem afterItem:nil]) {
            [self.player insertItem:playerItem afterItem:nil];
        }
    }
}

-(void)advanceNextItem {
    [self.player advanceToNextItem];
}

- (BOOL)isPlaying
{
    if (self.player.rate > 0 && !self.player.error) {
        return YES;
    }
    
    return NO;
}

- (void)setPlaybackRate:(float)rateVal
{
    if(rateVal != _playSpeedRate) {
        _playSpeedRate = rateVal;
    }
}

- (void)stepFrame:(BOOL)next
{
    CMTime currentTime = [self.player.currentItem currentTime];
    CMTime currentTimeScale = CMTimeConvertScale(currentTime, _framesPerSecond, kCMTimeRoundingMethod_Default);
    
    if(!next) {
        --currentTimeScale.value;
    }
    else {
        ++currentTimeScale.value;
    }
    
    [self.player seekToTime:currentTimeScale toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        [self.player pause];
    }];
}

-(void)seekToCMTime:(CMTime)seekTime completionHandler:(void (^)(BOOL success))completionHandler
{
    if(!CMTIME_IS_VALID(seekTime))
    {
        if(completionHandler) {
            completionHandler(YES);
        }
    }
    else
    {
        [self.player seekToTime:seekTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished)
         {
             if(completionHandler) {
                 completionHandler(finished);
             }
         }];
    }
}

- (void)seekToTimeCode:(NSString *)timeCode completionHandler:(void (^)(BOOL success))completionHandler
{
    if ([timeCode isEqualToString:@""])
    {
        if(completionHandler) {
            completionHandler(YES);
        }
    }
    else
    {
        CMTime seekTime = CMTimeMakeWithSeconds([CMUtilities getSecondsFromTimeCode:timeCode], NSEC_PER_SEC);
        [self seekToCMTime:seekTime completionHandler:^(BOOL success)
         {
             if(completionHandler) {
                 completionHandler(success);
             }
         }];
    }
}

- (void)seekToLastPlaybackTimeCode:(CGFloat)timeCode completionHandler:(void (^)(BOOL success))completionHandler
{
    CMTime seekTime = CMTimeMakeWithSeconds(timeCode, NSEC_PER_SEC);
    [self seekToCMTime:seekTime completionHandler:^(BOOL success)
     {
         if(completionHandler) {
             completionHandler(success);
         }
     }];
}

-(CMTime)getSOM {
    return self.player.currentTime;
}

-(CMTime)getDuration {
    return self.duration;
}

-(Float64)getFrameRate {
    return _framesPerSecond;
}

- (NSString *) getCurrentTimeWithFramePrecision
{
    NSString *currentTimeInString;
    
    CMTime currentTime = [[self.player currentItem] currentTime];
    if (CMTIME_IS_VALID(currentTime))
    {
        currentTime = [self getCurrentSomTimeWithFramePrecision:currentTime];
        CMTime currentTime25F = CMTimeConvertScale(currentTime, self.framesPerSecond, kCMTimeRoundingMethod_Default);
        
        int tempFrame = self.framesPerSecond;
        
        NSInteger frames = currentTime25F.value % tempFrame;
        
        NSInteger currentSeconds = (NSInteger)currentTime25F.value/tempFrame;
        
        NSInteger seconds = currentSeconds % 60;
        NSInteger minutes = (currentSeconds / 60) % 60;
        NSInteger hours = (currentSeconds / 60) / 60;
        
        currentTimeInString = [NSString stringWithFormat:@"%02ld:%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds,(long)frames];
        DLog(@"currrent time in string %@  frame %0.2f",currentTimeInString,_framesPerSecond);
    }
    else {
        currentTimeInString = @"";
    }
    
    return currentTimeInString;
}

-(CGFloat)getCurrentTimeInseconds
{
    CMTime time = [[self.player currentItem] currentTime];
    
    CMTime currentTime25F = CMTimeConvertScale(time, self.framesPerSecond, kCMTimeRoundingMethod_Default);
    
    NSInteger currentSeconds = (NSInteger)currentTime25F.value/self.framesPerSecond;
    
    return currentSeconds;
}

-(CGFloat)frameRateFromAVPlayer
{
    CGFloat fps = 25.00;
    
    AVPlayerItem *item = self.player.currentItem;
    for (AVPlayerItemTrack *track in item.tracks)
    {
        if ([track.assetTrack.mediaType isEqualToString:AVMediaTypeVideo]) {
            fps = track.currentVideoFrameRate;
        }
    }
    if (fps == 0) {
        
        if (self.player.currentItem.asset)
        {
            AVAssetTrack *videoATrack = [[self.player.currentItem.asset tracksWithMediaType:AVMediaTypeVideo] lastObject];
            
            if(videoATrack) {
                fps = videoATrack.nominalFrameRate;
            }
        }
        if (fps == 0) {
            fps = 25.00;
            return fps;
        }
    }
    return fps;
    
}

#pragma mark Player settings methods
-(void)setFrameRateForVideo:(Float64)frames {
    _framesPerSecond = frames;
    //[self setFramesPerSecond:frames];
}

-(CMTime)getCurrentSomTimeWithFramePrecision:(CMTime)presentTime
{
    CMTime frameTime = CMTimeAdd(_currentSomTime, presentTime);
    return frameTime;
}

-(void)addPeriodicTimer
{
    if (!_playerTimeObserver)
    {
        Float64 frame = 1.0f/_framesPerSecond;
        
        __unsafe_unretained CMQueuePlayer *weakSelf = self;
        _playerTimeObserver = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(frame, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) { [weakSelf playerTimeUpdate]; }];
    }
}


#pragma mark Player observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    AVPlayerItemStatus status = self.player.currentItem.status;
    
    if(context == kStatusDidChangeKVO)
    {
        if(status == AVPlayerItemStatusReadyToPlay)
        {
            
            if (self.isBitrateSwitching && CMTIME_IS_VALID(self.bitRateSwitchTime)) {
                [self seekToCMTime:self.bitRateSwitchTime completionHandler:^(BOOL success) {
                    NSLog(@"After selection preferredPeakBitRate:%f, indicatedBitrate:%f",self.player.currentItem.preferredPeakBitRate, self.player.currentItem.accessLog.events.lastObject.indicatedBitrate);
                    NSLog(@"3=====Current URL:%@",[((AVURLAsset *)self.player.currentItem.asset) URL]);
                    self.bitRateSwitchTime  = kCMTimeInvalid;
                    self.isBitrateSwitching = NO;
                }];
            } else {
                
                if (!_framesPerSecond) {
                    _framesPerSecond = [self frameRateFromAVPlayer];
                }
                
                [self addPeriodicTimer];
                
                if([[self delegate] respondsToSelector:@selector(playerInitialised:)]) {
                    [[self delegate] playerInitialised:self.tag];
                }
 
            }
        }
    }
    else if(context == kBufferEmptyKVO)
    {
        if([[self delegate] respondsToSelector:@selector(playerDidPause:)]) {
            [[self delegate] playerDidPause:self.tag];
        }
    }
    else if(context == kTimeRangesKVO)
    {
        NSArray *timeRanges = (NSArray *)[change objectForKey:NSKeyValueChangeNewKey];
        
        if (![timeRanges isKindOfClass:[NSNull class]] && [timeRanges count])
        {
            CMTimeRange timerange = [[timeRanges objectAtIndex:0] CMTimeRangeValue];
            Float64 bufferedSeconds = CMTimeGetSeconds(CMTimeAdd(timerange.start, timerange.duration));
            if(bufferedSeconds > BUFFER_RESUME)
            {
                if([[self delegate] respondsToSelector:@selector(playerDidResumePlay:)]) {
                    [[self delegate] playerDidResumePlay:self.tag];
                }
            }
        }
    }
    else
    {
        /*if ([keyPath isEqualToString:@"currentItem"])
         {
         if (change[NSKeyValueChangeNewKey] == [NSNull null])
         {
         if([[self delegate] respondsToSelector:@selector(playerDidEndClip:)]) {
         [[self delegate] playerDidEndClip:self.tag];
         }
         }
         }*/
    }
}

#pragma mark - Properties
- (void)cleanup
{
    [self removeObservers];
    
    [self.player pause];
    [self.player removeAllItems];
    
    _delegate = nil;
}

- (int64_t)getCurrentTimeInTicks
{
    CMTime tempTime = [self getCurrentSomTimeWithFramePrecision:[self.player.currentItem currentTime]];
    
    Float64 tempTime_value_float = (Float64) tempTime.value;
    
    Float64 temp_float = (tempTime_value_float / tempTime.timescale);
    
    int64_t temp_int = temp_float * self.framesPerSecond;
    
    return temp_int;
}


- (BOOL)isMediaInitialized
{
    if (CMTIME_IS_VALID(self.player.currentTime) && CMTIME_IS_VALID(self.duration)) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)isUrlLiveStreaming: (NSURL *) URL
{
    BOOL flag = YES;
    
    NSString *URLinString = [URL absoluteString];
    
    if ([URLinString rangeOfString:M3U8 options:NSCaseInsensitiveSearch].location == NSNotFound)
    {
        flag = NO;
    }
    
    return flag;
}

- (void)scrub:(float)progressValue completionHandler:(void (^)(BOOL))completionHandler
{
    CMTime seekBarTime = CMTimeMake(progressValue, self.framesPerSecond);
    
    if (CMTIME_COMPARE_INLINE(seekBarTime, <=, self.duration))
    {
        [self.player seekToTime:CMTimeMakeWithSeconds(progressValue, self.framesPerSecond) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
            if (finished) {
                completionHandler(finished);
            }
        }];
    }
}

- (CMTime)getCurrentTime {
    return [self.player.currentItem currentTime];
}

- (CMTime)getCurrentTimeWithTime {
    return [self.player.currentItem currentTime];
}


#pragma mark - AVAssetResourceLoader delegate methods
- (BOOL) resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    NSString *scheme = [[loadingRequest.request URL] scheme];
    
    if([scheme rangeOfString:@"key"].location != NSNotFound)
    {
        NSString *str   = [[loadingRequest.request URL] absoluteString];
        NSInteger colon = [str rangeOfString:@":"].location;
        if (colon != NSNotFound)
        {
            NSString *fromStr   = [str substringFromIndex:colon];
            NSString *toStr     = [str substringToIndex:colon];
            
            NSString *schemeStr = [toStr stringByReplacingOccurrencesOfString:@"key" withString:@"http"];
            
            str = [schemeStr stringByAppendingString:fromStr];
        }
        
        NSString *keyURL = [[NSURL URLWithString:str] absoluteString];
        DLog(@"resource loader called...! %@", keyURL);
        [CMRestInterface asyncDataDownload:keyURL withProgressHandler:nil andCompletionHandler:^(NSData *response, NSUInteger errorCode)
         {
             dispatch_async(dispatch_get_main_queue(), ^
                            {
                                if(errorCode == TRACE_CODE_SUCCESS)
                                {
                                    NSString *strKey        = [CMServicesUtilities getStreamDecryptionKey];
                                    NSData *decryptedKey    = [response decryptDataWithKey:strKey];
                                    [loadingRequest.dataRequest respondWithData:decryptedKey];
                                    [loadingRequest finishLoading];
                                }
                                else {
                                    DLog(@"error in key response  %@", response);
                                }
                            });
         }];
        
        return YES;
    }
    
    return NO;
}

#pragma mark - WaterMark label

-(UILabel *) userNameWaterMarkLabel
{
    if (!_userNameWaterMarkLabel)
    {
        _userNameWaterMarkLabel = [[UILabel alloc] initWithFrame:CGRectMake(-20,self.bounds.size.height-180, self.bounds.size.width-30, 30.)];
        [_userNameWaterMarkLabel setBackgroundColor:[UIColor clearColor]];
        [_userNameWaterMarkLabel setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin)];
        [_userNameWaterMarkLabel setTextAlignment:NSTextAlignmentRight];
        _userNameWaterMarkLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:24];
        _userNameWaterMarkLabel.textColor = [UIColor lightTextColor] ;
        
        _userNameWaterMarkLabel.shadowColor = [UIColor blackColor];
        _userNameWaterMarkLabel.shadowOffset = CGSizeMake(1.0f, 1.0f);
        [_userNameWaterMarkLabel setAlpha:0.3];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId = %@", [[NSUserDefaults standardUserDefaults] valueForKey:CURRENT_USER_ID]];
        CBCProductEntity *entity = [[CMProductDataManager sharedInstance] fetchEntity:nil forModel:NSStringFromClass([CBCProductEntity class]) withPredicate:predicate withSortKey:nil andAscending:NO];
        if(!entity) {
            DLog( @"Comments initialisation failed, reason : core date fetch no records...");
        }
        if(entity.userName) {
            _userNameWaterMarkLabel.text = entity.userName;
        }
        else {
            _userNameWaterMarkLabel.text = @"";
        }
    }
    
    return _userNameWaterMarkLabel;
}


#pragma mark - Watermark Timer

-(UILabel *) timerWaterMarkLabel
{
    if (!_timerWaterMarkLabel)
    {
        _timerWaterMarkLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,self.bounds.size.height-160, self.bounds.size.width-50, 30.)];
        [_timerWaterMarkLabel setBackgroundColor:[UIColor clearColor]];
        [_timerWaterMarkLabel setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleTopMargin)];
        [_timerWaterMarkLabel setTextAlignment:NSTextAlignmentRight];
        _timerWaterMarkLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:22];
        _timerWaterMarkLabel.textColor = [UIColor lightTextColor] ;
        
        _timerWaterMarkLabel.shadowColor = [UIColor blackColor];
        _timerWaterMarkLabel.shadowOffset = CGSizeMake(1.0f, 1.0f);
        [_timerWaterMarkLabel setAlpha:0.3];
        [_timerWaterMarkLabel setTextAlignment:NSTextAlignmentRight];
        
        //dateFormat to show in watermark
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = DATE_FORMAT;
        [_dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    }
    
    return _timerWaterMarkLabel;
}

#pragma mark -- adding time in watermark

-(void) initTimer
{
    if (!_timer)
    {
        _timer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(watermarkTimeCode) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
    }
}

-(void) watermarkTimeCode
{
    [self.timerWaterMarkLabel setText:[_dateFormatter stringFromDate:[NSDate date]]];
}


/*#pragma mark -- Digital watermark methods
 -(void) setDigitalWatermarkView
 {
 NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId = %@", [[NSUserDefaults standardUserDefaults] valueForKey:CURRENT_USER_ID]];
 CBCProductEntity *entity = [[CMProductDataManager sharedInstance] fetchEntity:nil forModel:NSStringFromClass([CBCProductEntity class]) withPredicate:predicate withSortKey:nil andAscending:NO];
 if(!entity) {
 DLog( @"Comments initialisation failed, reason : core date fetch no records...");
 }
 watermarkQuery = [[CBCDigitalWatermarkQuery alloc]init];
 watermarkQuery.tenantId = [entity.tenantId integerValue];
 watermarkQuery.userId = [entity.userId integerValue];
 watermarkQuery.authToken = @"";
 [CMRestInterface asyncDigitalWatermark:watermarkQuery withCompletionHandler:^(CBCDigitalWatermarkResult *response, NSUInteger errorCode) {
 watermarkResponse = [[CBCDigitalWatermarkResult alloc]init];
 watermarkResponse = response;
 [self addDigitalWatermarkView];
 }];
 }
 
 -(void)addDigitalWatermarkView
 {
 NSString *usernameStr;
 NSPredicate *predicate = [NSPredicate predicateWithFormat:@"userId = %@", [[NSUserDefaults standardUserDefaults] valueForKey:CURRENT_USER_ID]];
 CBCProductEntity *entity = [[CMProductDataManager sharedInstance] fetchEntity:nil forModel:NSStringFromClass([CBCProductEntity class]) withPredicate:predicate withSortKey:nil andAscending:NO];
 if(!entity) {
 DLog( @"Comments initialisation failed, reason : core date fetch no records...");
 }
 if (![entity.firstName isEqualToString:@"NA"]) {
 if ([entity.lastName isEqualToString:@"NA"]) {
 usernameStr = entity.firstName;
 }
 else{
 usernameStr = [entity.firstName stringByAppendingFormat:@" %@",entity.lastName];
 }
 }
 watermarkView = [[CBCDigitalWaterMark alloc]initViewAtPosition:watermarkResponse.position withWatermarkModel:watermarkResponse inView:self username:usernameStr andLoginid:[NSString stringWithFormat:@"(%@)",@"0"]];
 [watermarkView setWaterMarkDateAndTime];
 [watermarkView initWatermarkTimer];
 
 }*/

#pragma mark - Player setting handler methods

/**
 * Get list of all audio tracks available in a video
 */
- (NSMutableArray *)getAvailableAudioTracks
{
    DLog(@"");
    if (self.playerSettingData.audioTracks) {
        return self.playerSettingData.audioTracks;
    }
    
    NSMutableArray *audioTracks     = [NSMutableArray new];
    AVURLAsset *asset               = (AVURLAsset *)self.player.currentItem.asset;
    
    //** 1st Way
    // Apple reccommented this (1st) way but some time it fails.
    //https://developer.apple.com/library/mac/releasenotes/AudioVideo/RN-AVFoundation/index.html#//apple_ref/doc/uid/TP40010717-CH1-DontLinkElementID_2
    AVMediaSelectionGroup *audio = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    
    for (AVMediaSelectionOption *option in audio.options)
    {
        [audioTracks addObject:option];
    }
    
    // If 1st way is failed then try to get audio tracks with this way.
    //** 2nd way
    if(self.playerSettingData.audioTracks.count == 0)
    {
        audioTracks  = (NSMutableArray *)[asset tracksWithMediaType:AVMediaTypeAudio];
    }
    
    DLog(@"Audio Tracks: %@", audioTracks);
    return audioTracks;
}


/**
 * Play selected audio track based on user selection.
 */
- (void)playSelectedAudioTrack:(id)track
{
    DLog(@"");
    if (track == nil && self.playerSettingData.selectedAudioTrack == track) {
        return;
    }
    self.playerSettingData.selectedAudioTrack = track;
    
    if ([self.playerSettingData.selectedAudioTrack isKindOfClass:[AVMediaSelectionOption class]]) {
        [self changeAudioTrackWithSelectedAudioOption:self.playerSettingData.selectedAudioTrack];
        
    } else if ([self.playerSettingData.selectedAudioTrack isKindOfClass:[AVAssetTrack class]]) {
        
        AVAsset *asset                  = self.player.currentItem.asset;
        NSArray *audioTracks            = [asset tracksWithMediaType:AVMediaTypeAudio];
        NSMutableArray *allAudioParams  = [NSMutableArray array];
        
        for (AVAssetTrack *track in audioTracks)
        {
            float trackVolume = 0.0;
            if (self.playerSettingData.selectedAudioTrack == track)
            {
                trackVolume = 1.0;
            }
            AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
            
            [audioInputParams setVolume:trackVolume atTime:kCMTimeZero];
            [audioInputParams setTrackID:[track trackID]];
            [allAudioParams addObject:audioInputParams];
        }
        AVMutableAudioMix *audioZeroMix = [AVMutableAudioMix audioMix];
        [audioZeroMix setInputParameters:allAudioParams];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.player.currentItem setAudioMix:audioZeroMix];
        });
    }
}

- (void)changeAudioTrackWithSelectedAudioOption:(AVMediaSelectionOption *)selectedAudioOption {
    DLog("");
    AVURLAsset *asset                   = (AVURLAsset *)self.player.currentItem.asset;
    AVMediaSelectionGroup *audoTracks   = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    [self.player.currentItem selectMediaOption:selectedAudioOption inMediaSelectionGroup:audoTracks];
    
}

/**
 * Called when a new access log entry has been added. TODO:Dipak This is for testing purpose remove it.
 */
- (void)handleAVPlayerAccess:(NSNotification *)notif {
    AVPlayerItemAccessLog *accessLog = [((AVPlayerItem *)notif.object) accessLog];
    AVPlayerItemAccessLogEvent *lastEvent = accessLog.events.lastObject;
    float lastEventNumber = lastEvent.indicatedBitrate;
    if (lastEventNumber != self.lastBitRate) {
        //Here is where you can increment a variable to keep track of the number of times you switch your bit rate.
        NSLog(@"Switch indicatedBitrate from: %f to: %f", self.lastBitRate, lastEventNumber);
        // self.selectedBitrate.bitrate. = lastEventNumber;
        self.lastBitRate = lastEventNumber;
    }
    
    //    for (AVPlayerItemAccessLogEvent *event in accessLog.events) {
    //        NSLog(@"indicatedBitrate: %f", event.indicatedBitrate);
    //    }
    
    DLog(@"Current URL:%@",[((AVURLAsset *)self.player.currentItem.asset) URL]);
}


//-(void)replaceCurrentItemWithUrl:(NSString*)urlString
- (void)replaceCurrentItemWithSelectedMedia:(CMM3u8Media *)selectedMedia;
{
    if (selectedMedia && selectedMedia == self.playerSettingData.selectedBitrate) {
        return;
    }
    //    if([[self playerDelegate] respondsToSelector:@selector(playPause:)]) {
    //        [[self playerDelegate] playPause:NO];
    //    }
    
    
    self.isBitrateSwitching                 = YES;
    self.bitRateSwitchTime                  = [self getCurrentTime];
    self.playerSettingData.selectedBitrate  = selectedMedia;
    DLog(@"Selected url String:%@", selectedMedia.playlistUrl);
    NSURL *url              = [NSURL URLWithString:[selectedMedia.playlistUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    DLog(@"Encoded url:%@", url);
    
    NSMutableDictionary * headers   = [NSMutableDictionary dictionary];
    [headers setObject:@"iPad" forKey:@"User-Agent"];
    
    AVURLAsset *asset               = [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
    
    AVAssetResourceLoader *resourceLoader = asset.resourceLoader;
    [resourceLoader setDelegate:self queue:dispatch_queue_create("CMQueuePlayerAsset loader", nil)];
    
    AVPlayerItem *playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
    [self.player replaceCurrentItemWithPlayerItem:playerItem];
    //self.playerItem  = [[AVPlayerItem alloc] initWithAsset:asset];
}


- (void)showAvailableBitRates
{
    NSInteger index = [self.player.items indexOfObject:self.player.currentItem];
   
    //TODO: Remove it after testing
    if (index >= _videos.count) {
        if(self.playerDelegate && [self.playerDelegate respondsToSelector:@selector(showPlayerSettingsOptionWithData:)])
        {
            [self.playerDelegate showPlayerSettingsOptionWithData:self.playerSettingData];
        }
        return;
    }
    
    NSString *urlString = _videos[index];
    
    [[CBCDownloadManager sharedInstance] downloadM3u8AndParseBandwidth:urlString andCompletionHandler:^(NSArray *bandWidths, NSUInteger errorCode)
     {
         self.playerSettingData.bitrates = [[NSArray alloc] initWithArray:bandWidths];
         if(errorCode == TRACE_CODE_SUCCESS)
         {
             for (CMM3u8Media *media in self.playerSettingData.bitrates)
             {
                 DLog(@"Sorted bitrate:%f, playlistUrl:%@",media.bitrate, media.playlistUrl);
             }
         }
         else {
             //alert the error that no bit rates video available
             DLog(@"No bitrates are available.");
         }
         
         if(self.playerDelegate && [self.playerDelegate respondsToSelector:@selector(showPlayerSettingsOptionWithData:)])
         {
             [self.playerDelegate showPlayerSettingsOptionWithData:self.playerSettingData];
         }
     }];
}

- (void)clearUserSettingsData
{
    if(self.playerDelegate && [self.playerDelegate respondsToSelector:@selector(hidePlayerSettingsOption)])
    {
        [self.playerDelegate hidePlayerSettingsOption];
    }
    self.playerDelegate     = nil;
    self.playerSettingData  = nil;
    self.isBitrateSwitching = NO;
    self.bitRateSwitchTime  = kCMTimeInvalid;
}

/**
 * Fetch Audio tracks and bitrates from video.
 */
- (void)fetchSettingData:(id)delegate
{
    self.playerDelegate = delegate;
    if (!self.playerSettingData)
    {
        self.playerSettingData              = [CMPlayerSettings new];
        self.playerSettingData.audioTracks  = [self getAvailableAudioTracks];
        [self showAvailableBitRates];
    } else {
        if(self.playerDelegate && [self.playerDelegate respondsToSelector:@selector(showPlayerSettingsOptionWithData:)])
        {
            [self.playerDelegate showPlayerSettingsOptionWithData:self.playerSettingData];
        }
    }
}

@end
