//
//  CMPlayerController.m
//  CM Library
//
//  Created by Saravana Kumar on 11/24/15.
//  Copyright © 2015 Prime Focus Technologies. All rights reserved.
//

#import "CMPlayerController.h"
#import "CMQueuePlayer.h"
#import "CMUtilities.h"
#import "CMProductConstants.h"
#import "CMDataMacros.h"
#import "UIColor+MBCategory.h"
#import "CLReviewPlayerControlsController.h"
#import "CMPlayerControlsContainer.h"
#import "CMServicesConstants.h"

#define IPAD_WATER_MARK_SIZE                      CGSizeMake(500.0f, 80.0f)
#define IPHONE_WATER_MARK_SIZE                    CGSizeMake(250.0f, 50.0f)
#define IPHONE6_LANDSCAPE_WATER_MARK_SIZE         CGSizeMake(220.0f, 50.0f)
#define IPHONE6P_LANDSCAPE_WATER_MARK_SIZE        CGSizeMake(210.0f, 50.0f)


@interface CMPlayerController ()<watermarkDelegate, CMPlayerSettingDelegate>

@property (nonatomic, weak)     UIView                      *superView;
@property (nonatomic, assign)   CGFloat                      initialSeekIn;
@property (nonatomic, assign)   CGFloat                      initialSeekOut;
@property (nonatomic, assign)   CGRect                      superviewFrame;

@property (nonatomic,assign)    BOOL                         isScene;

@property (nonatomic,weak)      CMPlayerControlsContainer * container;
@end

@implementation CMPlayerController


#pragma mark - private methods
-(void)initHUD
{
    _superView = [self.view superview];
}

-(void)updateWatermarkConstraints
{
    NSDictionary *viewsDictionary = @{@"watermarkView":_watermarkView};
    
    [_watermarkView setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    for(NSLayoutConstraint *c in [_waterMarkHolderView constraints])
    {
        if(c.firstItem == _watermarkView || c.secondItem == _watermarkView) {
            [_waterMarkHolderView removeConstraint:c];
        }
    }
    
    [_waterMarkHolderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[watermarkView]-0-|" options:NSLayoutFormatAlignAllBaseline metrics:NSDictionaryOfVariableBindings(_watermarkView) views:viewsDictionary]];
    [_waterMarkHolderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[watermarkView]-0-|" options:NSLayoutFormatAlignAllBaseline metrics:NSDictionaryOfVariableBindings(_watermarkView) views:viewsDictionary]];
    
    [_waterMarkHolderView layoutSubviews];
}

/**
 * Return active player's object
 */
-(CMQueuePlayer *)getActivePlayer {
    
    if(self.activePlayer == ON_SCREEN_PLAYER) {
        return self.onScreenPlayer;
    } else {
        return self.offScreenPlayer;
    }
}

#pragma mark - public methods
-(CGFloat)calculateDuration
{
    CGFloat duration = 0.0f;
    
    if(self.isReelMode)
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];

        if ([[clip segments]count])
        {
            CBCScreenerPreviewSegment *segment = [clip.segments firstObject];
            clip.clipModDuration = [NSString stringWithFormat:@"%f",segment.segmentEndTime - segment.segmentStartTime];
        }
        duration = [[clip clipModDuration] floatValue];
    }
    else
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];
        
        if([clip.clipDuration floatValue] <= 0.0f)
        {
            if(self.activePlayer == ON_SCREEN_PLAYER) {
                clip.clipDuration = [NSString stringWithFormat:@"%f", [self.onScreenPlayer durationInSeconds]];
            }
            else {
                clip.clipDuration = [NSString stringWithFormat:@"%f", [self.offScreenPlayer durationInSeconds]];
            }
        }

        duration = [[clip clipDuration] floatValue];
    }
    
    return duration;
}

-(void)playerReadyToPlay
{
    self.isPlayerInitialised = YES;
    
    if(self.autoPlay) {
        [self playActivePlayer];
    }
    
    [self.progressInd stopAnimating];
}

-(void)defaultToClip:(NSInteger)index
{
    [self.onScreenPlayer cleanup];
    [self.offScreenPlayer cleanup];        
    
    self.isPlayerInitialised = NO;
    
    if(index >= [[self.dataSource clips] count]) {
        return;
    }
    
    [_progressInd startAnimating];
    
    _prevClip = _selectedClip;
    _selectedClip = index;
    
    self.playersReady = 0;
    
    [self.onScreenPlayer setAlpha:0.0f];
    [self.offScreenPlayer setAlpha:1.0f];
    
    self.activePlayer = OFF_SCREEN_PLAYER;
}

-(void)calculateTotalReelModeTime:(NSInteger)index
{
    CGFloat reelTime = 0.0f;

    for (NSInteger i = index; i < [[self.dataSource clips] count]; i++)
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][i];
        
        NSString *clipURL = [clip clipSrc];
        NSArray *segments = [clip segments];
        
        if([segments count])
        {
            for (NSInteger j = 0; j < [segments count]; j++)
            {
                NSArray *timeCode = [segments[j] segmentInterval];
                CGFloat startTime = [CMUtilities getSecondsFromTimeCode:timeCode[0]];
                CGFloat endTime   = [CMUtilities getSecondsFromTimeCode:timeCode[1]];
                
                CGFloat segmentTime = endTime - startTime;
                
                reelTime += segmentTime;
            }
        }
        else {
            reelTime += [[clip clipDuration] floatValue];
        }
        
        if (![clipURL isEqualToString:@""]) {
            clipURL = [self getDecodedM3U8:clipURL];
        }
    }
    self.totalReelTime =  reelTime;
}

-(void)initialiseReelModeFromIndex:(NSInteger)index
{
    self.isReelMode = YES;
    self.fromReel = YES;
    self.isSeeked = NO;
    self.isPlayerInitialised = NO;
    
    [self.progressInd startAnimating];
    
    self.prevClip       = self.selectedClip;
    self.selectedClip   = index;
    
    self.currentSegment = 0;
    if([[self.dataSource clips] count] > 1) {
        self.playersReady   = 0;
    }
    else {
        self.playersReady = 1;
    }
    
    [self calculateTotalReelModeTime:index];
    
    self.reelPlayed = 0.0f;
    
    NSMutableArray *onScreenPlayerUrls = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *offScreenPlayerUrls = [NSMutableArray arrayWithCapacity:0];
    
    for (NSInteger i = 0; i < [[self.dataSource clips] count]; i++)
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][i];
        
        if (i % 2 == 0) {
            [onScreenPlayerUrls addObject:clip.clipSrc];
        } else {
            [offScreenPlayerUrls addObject:clip.clipSrc];
        }
    }
    
    [self.onScreenPlayer initWithURLList:onScreenPlayerUrls andDelegate:self];
    [self.offScreenPlayer initWithURLList:offScreenPlayerUrls andDelegate:self];

    [[NSNotificationCenter defaultCenter] postNotificationName:EDITOR_UPDATE_PROGRESS object:@{TOTOAL_REEL_TIME:[NSNumber numberWithFloat:self.totalReelTime],REEL_TIME:[NSNumber numberWithFloat:self.reelPlayed]}];
}

-(void)showAnnotationComment:(CGFloat)timeCode {
    
}

-(void)showRangeComment:(CGFloat)timeCodeIn andTimeCodeEnd:(CGFloat)timeCodeEnd {
    
}

-(NSArray*)getNextTimeSegment:(NSInteger)segment forClip:(NSInteger)clip
{
    if(clip >= [[self.dataSource clips] count]) {
        return nil;
    }
    
    NSArray *segments = [[self.dataSource clips][clip] segments];
    
    NSArray *segmentTime = nil;
    
    NSInteger nextSegment = segment + 1;
    if(nextSegment < [segments count])
    {
        segmentTime = [segments[nextSegment] segmentInterval];
        return segmentTime;
    }
    
    NSInteger nextClip = clip + 1;
    nextSegment = -1;
    
    if(nextClip < [[self.dataSource clips] count])
    {
        if(self.activePlayer == ON_SCREEN_PLAYER)
        {
//            [self.offScreenPlayer advanceNextItem];
//            [self.offScreenPlayer advanceNextItem];

            _advancedPlayer = ON_SCREEN_PLAYER;
        }
        else
        {
//            [self.onScreenPlayer advanceNextItem];
//            [self.onScreenPlayer advanceNextItem];

            _advancedPlayer = OFF_SCREEN_PLAYER;
        }
        
        NSArray *nextClipSegments = [[self.dataSource clips][nextClip] segments];
        if([nextClipSegments count]) {
            return [self getNextTimeSegment:nextSegment forClip:nextClip];
        }
        else
        {
            CBCScreenerPreviewClip *segment = [self.dataSource clips][nextClip];
            segmentTime = @[@"00:00:00:00", [CMUtilities getTimeCodeFromSeconds:[[segment clipDuration] floatValue]]];
            
            return segmentTime;
        }
    }
    
    return segmentTime;
}

-(void)swapPlayers
{
    
    [[NSNotificationCenter defaultCenter] postNotificationName:EDITOR_MOVE_TO_NEXT_CLIP object:@{TOTOAL_REEL_TIME:[NSNumber numberWithFloat:self.totalReelTime],SELECTED_CLIP:[NSNumber numberWithInteger:_selectedClip]}];
    
    self.activePlayer = !self.activePlayer;
    
    //calculate the next segment
    NSArray *timeCode = [self getNextTimeSegment:self.currentSegment forClip:self.selectedClip];
    
    if(self.activePlayer == ON_SCREEN_PLAYER)
    {
        [self.onScreenPlayer setAlpha:1.0f];
        [self.offScreenPlayer setAlpha:0.0f];
        
        if(_advancedPlayer == ON_SCREEN_PLAYER)
        {
            [self.offScreenPlayer advanceNextItem];
            _advancedPlayer = -1;
        }
        
        if(timeCode)
        {
            [self.offScreenPlayer seekToTimeCode:timeCode[0] completionHandler:^(BOOL success) {
                [self.offScreenPlayer pause:nil];
            }];
        }
        else {
            //reel play ended
        }
    }
    else
    {
        [self.offScreenPlayer setAlpha:1.0f];
        [self.onScreenPlayer setAlpha:0.0f];
        
        if(_advancedPlayer == OFF_SCREEN_PLAYER)
        {
            [self.onScreenPlayer advanceNextItem];
            _advancedPlayer = -1;
        }
        
        if(timeCode)
        {
            [self.onScreenPlayer seekToTimeCode:timeCode[0] completionHandler:^(BOOL success) {
                [self.onScreenPlayer pause:nil];
            }];
        }
        else {
            //reel play ended
        }
    }
    
    [self playActivePlayer];
}

-(void)playActivePlayer
{
    if(self.activePlayer == ON_SCREEN_PLAYER)
    {
        if(![self.onScreenPlayer isPlaying]) {
            [self.onScreenPlayer play:nil];
        }
    }
    else
    {
        if(![self.offScreenPlayer isPlaying]) {
            [self.offScreenPlayer play:nil];
        }
    }
}

-(void)pausePlayers
{
    [self.onScreenPlayer pause:nil];
    [self.offScreenPlayer pause:nil];
}

-(void)stopPlayers
{
    [_offScreenPlayer cleanup];
    [_onScreenPlayer cleanup];
    
    self.isPlayerInitialised = NO;
    self.playerStopped = YES;
    self.autoPlay = NO;
    self.autoPause = NO;
    
    if(self.isReelMode) {
        [self reelPlaybackFinished];
    }
    else {
        [self defaultToClip:self.selectedClip];
    }
}

-(NSString*)getDecodedM3U8:(NSString*)clipURL {
    return clipURL;
}

-(NSArray*)getCurrentTimeSegment
{
    NSArray *segments      = [[self.dataSource clips][self.selectedClip] segments];
    NSArray *timeSegment = nil;
    if([segments count]) {
        timeSegment    = [segments[self.currentSegment] segmentInterval];
    }
    else
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];
        timeSegment = @[@"00:00:00:00", [CMUtilities getTimeCodeFromSeconds:[[clip clipDuration] floatValue]]];
    }
    
    return timeSegment;
}

-(void)initRelativeWithSegment
{
    self.advancedPlayer = -1;
    
    self.activePlayer = ON_SCREEN_PLAYER;
    
    [self.onScreenPlayer setAlpha:1.0f];
    [self.offScreenPlayer setAlpha:0.0f];
    
    NSArray *currentSegment = [self getCurrentTimeSegment];
    
    if(currentSegment)
    {
        [self.onScreenPlayer seekToTimeCode:currentSegment[0] completionHandler:^(BOOL success)
        {
            //calculate the next segment
            NSArray *timeCode = [self getNextTimeSegment:self.currentSegment forClip:self.selectedClip];
            if(timeCode)
            {
                [self.offScreenPlayer seekToTimeCode:timeCode[0] completionHandler:^(BOOL success) {
                     [self.offScreenPlayer pause:nil];
                }];
            }
             
            [self.progressInd stopAnimating];
            
            [self playerReadyToPlay];
        }];
    }
    else {
        //TODO:: error
    }
}

-(void)initWithSeekReel
{
    self.advancedPlayer = -1;
    
    self.activePlayer = ON_SCREEN_PLAYER;
    
    [self.onScreenPlayer setAlpha:1.0f];
    [self.offScreenPlayer setAlpha:0.0f];
    
    NSString *timeCode = [CMUtilities getTimeCodeFromSeconds:_seekedSeconds];
    
    [self.onScreenPlayer seekToTimeCode:timeCode completionHandler:^(BOOL success)
    {
         //calculate the next segment
         NSArray *timeCode = [self getNextTimeSegment:self.currentSegment forClip:self.selectedClip];
         if(timeCode)
         {
             [self.offScreenPlayer seekToTimeCode:timeCode[0] completionHandler:^(BOOL success) {
                 [self.offScreenPlayer pause:nil];
             }];
         }
         
         [self.progressInd stopAnimating];
         
         self.isSeeked = NO;
         
        [self playerReadyToPlay];
    }];
}

-(void)updateProgress:(CGFloat)progress withFrame:(NSInteger)frame {
    
}

-(void)updateTimelineForClipInReel {
    
}

-(void)updatePauseIconForButton {
    
}

-(void)reelPlaybackFinished {
    
}

-(CGFloat)getReelTimeFromIndex:(NSInteger)index
{
    CGFloat reelTime = 0.3f;
    
    if(index >= [[self.dataSource clips] count]) {
        return  reelTime;
    }
    
    for (NSInteger i = 0; i < index; i++)
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][i];
        
        NSArray *segments = [clip segments];
        
        if([segments count])
        {
            for (NSInteger j = 0; j < [segments count]; j++)
            {
                NSArray *timeCode = [segments[j] segmentInterval];
                CGFloat startTime = [CMUtilities getSecondsFromTimeCode:timeCode[0]];
                CGFloat endTime   = [CMUtilities getSecondsFromTimeCode:timeCode[1]];
                
                CGFloat segmentTime = endTime - startTime;
                
                reelTime += segmentTime;
            }
        }
        else {
            reelTime += [[clip clipDuration] floatValue];
        }
    }
    
    return reelTime;
}

-(void)findSeekInReel:(CGFloat)seconds
{
    CGFloat reelTime = 0.0f;
    BOOL doBreak = NO;
    
    for (NSInteger i = 0; ((i < [[self.dataSource clips] count]) && (!doBreak)); i++)
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][i];
        
        NSArray *segments = [clip segments];
        if([segments count])
        {
            for (NSInteger j = 0; j < [segments count]; j++)
            {
                NSArray *timeCode = [segments[j] segmentInterval];
                CGFloat startTime = [CMUtilities getSecondsFromTimeCode:timeCode[0]];
                CGFloat endTime   = [CMUtilities getSecondsFromTimeCode:timeCode[1]];
                
                CGFloat segmentTime = endTime - startTime;
                reelTime += segmentTime;
                
                if(reelTime >= seconds)
                {
                    self.prevClip = self.selectedClip;
                    
                    self.selectedClip = i;
                    
                    self.currentSegment = j;
                    
                    _reelPlayed = reelTime - segmentTime;
                    
                    CGFloat seekTime = segmentTime - (reelTime - seconds);
                    
                    [self seekInReel:seekTime];
                    
                    doBreak = YES;
                    break;
                }
            }
        }
        else
        {
            CGFloat segmentTime = [[clip clipDuration] floatValue];
            reelTime += segmentTime;
            if(reelTime >= seconds)
            {
                self.prevClip = self.selectedClip;
                
                self.selectedClip = i;
                self.currentSegment = 0;
                
                _reelPlayed = reelTime - segmentTime;
                
                CGFloat seekTime = segmentTime - (reelTime - seconds);
                
                [self seekInReel:seekTime];
                
                doBreak = YES;
            }
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:EDITOR_MOVE_TO_NEXT_CLIP object:@{TOTOAL_REEL_TIME:[NSNumber numberWithFloat:self.totalReelTime],SELECTED_CLIP:[NSNumber numberWithInteger:_selectedClip]}];

}

-(void)seekInReel:(CGFloat)seekSeconds
{
    _fromReel = YES;
    self.isSeeked = YES;
    
    [self.progressInd startAnimating];
    
    self.playersReady = 0;
    self.isPlayerInitialised = NO;
    
    NSMutableArray *urls = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *clips = [self.dataSource clips];
    for (NSInteger i = self.selectedClip; i < [clips count]; i++)
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][i];
        
        NSString *clipURL = [clip clipSrc];
        
        if ([clipURL length])
        {
            clipURL = [self getDecodedM3U8:clipURL];
            [urls addObject:clipURL];
        }
    }
    
    NSArray *timeSegment = [self getCurrentTimeSegment];
    self.seekedSeconds = [CMUtilities getSecondsFromTimeCode:timeSegment[0]] + seekSeconds;
    
    //load all the items into the queue
    [self.onScreenPlayer initWithURLList:urls andDelegate:self];
    [self.offScreenPlayer initWithURLList:urls andDelegate:self];
}

-(void)dragActionBegan
{
    self.autoPause = NO;
    [self pausePlayers];
}

-(void)playFromSeekedTime:(CGFloat)seekedTime
{
    self.autoPause = YES;
    
    [self.progressInd startAnimating];
    
    CMTime seekTime = CMTimeMakeWithSeconds(seekedTime, NSEC_PER_SEC);
    if(!self.isReelMode)
    {
        [self.offScreenPlayer seekToCMTime:seekTime completionHandler:^(BOOL success)
        {
            [self playActivePlayer];
            [self.progressInd stopAnimating];
        }];
    }
    else {
        [self findSeekInReel:seekedTime];
    }
}

-(void)seekToTimeWithPosition:(CGFloat)position withAutoPlay:(BOOL)autoPlay
{
    CGFloat seekTime = position;
    if(self.isReelMode) {
        seekTime = position * self.totalReelTime;
    }
    else {
        seekTime = position *  [self calculateDuration];
    }
    
    [self seekToTime:seekTime withAutoPlay:YES];
}

-(void)seekToTime:(CGFloat)time withAutoPlay:(BOOL)autoPlay
{
    self.autoPause = autoPlay;
    
    [self.progressInd startAnimating];
    
    CMTime seekTime = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    if(!self.isReelMode)
    {
        [self.offScreenPlayer seekToCMTime:seekTime completionHandler:^(BOOL success)
        {
             [self.progressInd stopAnimating];
            if(self.autoPlay) {
                [self playActivePlayer];
            }
        }];
    }
    else {
        [self findSeekInReel:time];
    }
}

-(void)adjustPlayerSpeed:(CGFloat)playbackRate
{
    //show the overlay
    [self.onScreenPlayer setPlaybackRate:playbackRate];
    [self.offScreenPlayer setPlaybackRate:playbackRate];
    
    [self pausePlayers];
    
    if(self.activePlayer == ON_SCREEN_PLAYER) {
        [self.onScreenPlayer play:nil];
    }
    else {
        [self.offScreenPlayer play:nil];
    }
}

-(void)stepFrameActionHandler:(NSInteger)isNext
{
    self.autoPlay = NO;
    self.autoPause = NO;
    
    [self pausePlayers];
    
    if(self.activePlayer == ON_SCREEN_PLAYER) {
        [self.onScreenPlayer stepFrame:isNext];
    }
    else {
        [self.offScreenPlayer stepFrame:isNext];
    }
}

-(void)setIsFullScreen:(BOOL)isFullscreen
{
    if (!_superView) {
        _superView = [self.view superview];
    }
    
    if(isFullscreen)
    {
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        _superView = [self.view superview];
//        _superviewFrame = _superView.frame;
        
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        [self.view setFrame:[window bounds]];
        [window addSubview:self.view];
    }
    else
    {
        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        
//        [_superView setFrame:_superviewFrame];
        
        [self.view setFrame:_superView.bounds];
        [_superView addSubview:self.view];
    }
    
    [self.view setNeedsLayout];
    [self.view updateConstraintsIfNeeded];
    [self.view setTranslatesAutoresizingMaskIntoConstraints:YES];
    //[[self.navigationController view] setNeedsLayout];
    
    self.isFullscreen = isFullscreen;
    
    [CMUtilities decryptWaterMarkSecureInfo:^(id decryptedSecureInfo, NSUInteger errorCode)
    {
        if (errorCode == TRACE_CODE_SUCCESS)
        {
            _watermarkView.isFullScreen = self.isFullscreen;
            [_watermarkView waterMarkSecureDataAndDisplay:decryptedSecureInfo];
        }
    }];
}


#pragma mark - self methods
- (void)viewDidLoad {
    [super viewDidLoad];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self initHUD];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _watermarkView  = (CMWaterMarkView*)[CMUtilities getViewWithXIBId:@"CMWaterMarkView" owner:self];
    
    [_watermarkView setWatermarkViewDelegate:(id)self];
    [_watermarkView decryptWatermarkSecureInfo];
    
    //[_watermarkView setIsOffline:[self.interface isOffline]];
    
    [_waterMarkHolderView addSubview:_watermarkView];
    
    [self updateWatermarkConstraints];
    [[self view]layoutIfNeeded];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear: animated];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [_offScreenPlayer cleanup];
    [_onScreenPlayer cleanup];
    
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(void)dealloc {
    
}

#pragma mark - CMQueuePlayer delegate methods
-(void)playerInitialised:(NSInteger)player
{
    CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];
    if([clip.clipDuration floatValue] <= 0.0f)
    {
        if(self.activePlayer == ON_SCREEN_PLAYER) {
            clip.clipDuration = [NSString stringWithFormat:@"%f", [self.onScreenPlayer durationInSeconds]];
        }
        else {
            clip.clipDuration = [NSString stringWithFormat:@"%f", [self.offScreenPlayer durationInSeconds]];
        }
    }

    if(self.isPlayerInitialised) {
        return;
    }
    
    [self pausePlayers];
    
    if(self.isReelMode)
    {
        ++self.playersReady;
        if(self.playersReady == 2)
        {
            if(!_isSeeked) {
                [self initRelativeWithSegment];
            }
            else {
                [self initWithSeekReel];
            }
        }
    }
    else
    {
        self.fromReel = NO;
        [self playerReadyToPlay];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"PlayerInitialised" object:nil userInfo:nil];
}

-(void)playerTimeUpdate:(NSInteger)player time:(CMTime)time
{
    if(!self.isPlayerInitialised) {
        return;
    }
    
    int frameRate = 25;
    
    //avoid playing inactive player
    if(self.activePlayer != player)
    {
        if(player == OFF_SCREEN_PLAYER)
        {
            [self.offScreenPlayer pause:nil];
            frameRate = [self.offScreenPlayer framesPerSecond];
        }
        else
        {
            [self.onScreenPlayer pause:nil];
            frameRate = [self.onScreenPlayer framesPerSecond];
        }
        
        return;
    }
    
    if([self.progressInd isAnimating]) {
        [self.progressInd stopAnimating];
    }
    
    CGFloat seconds = CMTimeGetSeconds(time);
    CMTime currentTime25F = CMTimeConvertScale(time, frameRate, kCMTimeRoundingMethod_Default);
    int frame = currentTime25F.value % frameRate;
    
    if(self.isReelMode)
    {
        NSArray *timeCode       = [self getCurrentTimeSegment];
        CGFloat startSegment    = [CMUtilities getSecondsFromTimeCode:timeCode[0]];
        CGFloat endSegment      = [CMUtilities getSecondsFromTimeCode:timeCode[1]];
        
        //update the reel played in the progress bar
        //TODO: played frames- enable for reel mode, not sequence mode
        //        CGFloat playedFrames    = _reelPlayed + (seconds - startSegment);
        
        //        [[NSNotificationCenter defaultCenter] postNotificationName:EDITOR_UPDATE_PROGRESS object:@{TOTOAL_REEL_TIME:[NSNumber numberWithFloat:self.totalReelTime],REEL_TIME:[NSNumber numberWithFloat:playedFrames]}];
        
        CGFloat clipFrames      =  (seconds - startSegment);
        
        [self updateProgress:clipFrames withFrame:frame];
        
        if(seconds > endSegment)
        {
            //calculate the total reel has been played
            _reelPlayed += (endSegment - startSegment);
            
            ++self.currentSegment;
            
            NSArray *segments = [[self.dataSource clips][self.selectedClip] segments];
            
            if(self.currentSegment >= [segments count])
            {
                self.prevClip = self.selectedClip;
                
                ++self.selectedClip;
                
                //reset the current segment to first segment of the next clip
                self.currentSegment = 0;
                
                if(self.selectedClip >= [[self.dataSource clips] count])
                {
                    [self stopPlayers];
                    return;
                }
            }
            
            [self updateTimelineForClipInReel];
            
            [self swapPlayers];
        }
    }
    else
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];
        if((seconds > [[clip clipDuration] floatValue]) || isnan(seconds)) {
            [self stopPlayers];
        }
        else {
            [self updateProgress:seconds withFrame:frame];
        }
    }
}

-(void)playerTimeUpdate:(NSInteger)player time:(CMTime)time withFrameRate:(Float64)frameRate
{
    if(!self.isPlayerInitialised) {
        return;
    }
    
    CGFloat seconds = (CGFloat)time.value / (CGFloat)time.timescale;
    
    CMTime currentTime25F = CMTimeConvertScale(time, (int)frameRate, kCMTimeRoundingMethod_Default);
    int frame = currentTime25F.value % (int)frameRate;
    //    DLog(@"playerTimeUpdate fps : %f, frame %d",frameRate, frame);
    //avoid playing inactive player
    if(self.activePlayer != player)
    {
        if(player == OFF_SCREEN_PLAYER) {
            [self.offScreenPlayer pause:nil];
        }
        else {
            [self.onScreenPlayer pause:nil];
        }
        return;
    }
    
    if(self.isReelMode)
    {
        NSArray *timeCode       = [self getCurrentTimeSegment];
        CGFloat startSegment    = [CMUtilities getSecondsFromTimeCode:timeCode[0]];
        CGFloat endSegment      = [CMUtilities getSecondsFromTimeCode:timeCode[1]];
        
        //update the reel played in the progress bar
        //TODO: played frames- enable for reel mode, not sequence mode
        //        CGFloat playedFrames    = _reelPlayed + (seconds - startSegment);
        
        //        [[NSNotificationCenter defaultCenter] postNotificationName:EDITOR_UPDATE_PROGRESS object:@{TOTOAL_REEL_TIME:[NSNumber numberWithFloat:self.totalReelTime],REEL_TIME:[NSNumber numberWithFloat:playedFrames]}];
        
        CGFloat clipFrames      =  (seconds - startSegment);
        
        [self updateProgress:clipFrames withFrame:frame];
        
        if(seconds > endSegment)
        {
            //calculate the total reel has been played
            _reelPlayed += (endSegment - startSegment);
            
            ++self.currentSegment;
            
            NSArray *segments = [[self.dataSource clips][self.selectedClip] segments];
            
            if(self.currentSegment >= [segments count])
            {
                self.prevClip = self.selectedClip;
                
                ++self.selectedClip;
                
                //reset the current segment to first segment of the next clip
                self.currentSegment = 0;
                
                if(self.selectedClip >= [[self.dataSource clips] count])
                {
                    [self stopPlayers];
                    return;
                }
            }
            
            [self updateTimelineForClipInReel];
            
            [self swapPlayers];
        }
    }
    else
    {
        CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];
        if((seconds > [[clip clipDuration] floatValue]) || isnan(seconds)) {
            [self stopPlayers];
        }
        else {
            [self updateProgress:seconds withFrame:frame];
        }
    }
}

-(void)playerDidEndClip:(NSInteger)player
{
    if(!self.isReelMode) {
        [self stopPlayers];
    }
    else {
    }
}

-(void)playerDidResumePlay:(NSInteger)player
{
    if(_isPlayerInitialised) {
        [self.progressInd stopAnimating];
    }
    
    if(self.autoPause)
    {
        if(self.activePlayer == player) {
            [self playActivePlayer];
        }
    }
    
}

-(void)playerDidPause:(NSInteger)player
{
    DLog(@"playerDidPause..%ld",(long)player);
    
    if(_isPlayerInitialised || player == _activePlayer) {
        [self.progressInd startAnimating];
    }
    
    if(self.isReelMode)
    {
        if (player==ON_SCREEN_PLAYER)
        {
            [_onScreenPlayer pause:nil];
        }else{
            [_offScreenPlayer pause:nil];
        }
        
        //TODO: check with saro
        //If active player is paused in reel mode, update the button icon to pause.
        if (player==_activePlayer) {
            [self updatePauseIconForButton];
        }
    }
    else{
        [self pausePlayers];
    }


/*    if(_isPlayerInitialised) {
        [self.progressInd startAnimating];
    }
    
    [self pausePlayers];
  */
}

#pragma mark - segment handlers

-(void)createSegment
{
    self.autoPause = NO;
    [self pausePlayers];

    CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];
    
    if(self.activePlayer == OFF_SCREEN_PLAYER) {
        self.segmentEndTime = [CMUtilities getTimeCodeFromTime:[self.offScreenPlayer getCurrentTime] forFrameRate:[self.offScreenPlayer framesPerSecond] som:[clip clipStartOfMedia]];
    }
    else {
        self.segmentEndTime = [CMUtilities getTimeCodeFromTime:[self.onScreenPlayer getCurrentTime] forFrameRate:[self.onScreenPlayer framesPerSecond] som:[clip clipStartOfMedia]];
    }
    
    if([self.segmentStartTime isEqualToString:@""]) {
        self.segmentStartTime = @"00:00:00:00";
    }
    
    if([self.segmentEndTime isEqualToString:@""]) {
        self.segmentEndTime = @"00:00:00:00";
    }
}

-(void)cancelSegment
{
    self.segmentStartTime = nil;
    self.segmentEndTime = nil;
}

-(void)initSegment
{
    CBCScreenerPreviewClip *clip = [self.dataSource clips][self.selectedClip];
    
    if(self.activePlayer == OFF_SCREEN_PLAYER)
    {
        self.segmentStartTime = [CMUtilities getTimeCodeFromTime:[self.offScreenPlayer getCurrentTimeWithTime] forFrameRate:[self.offScreenPlayer framesPerSecond] som:[clip clipStartOfMedia]];
    }
    else
    {
        self.segmentStartTime = [CMUtilities getTimeCodeFromTime:[self.onScreenPlayer getCurrentTimeWithTime] forFrameRate:[self.onScreenPlayer framesPerSecond] som:[clip clipStartOfMedia]];
    }
    
    DLog(@"on screen seconds %f", [self.onScreenPlayer currentPosInSeconds]);
    DLog(@"off screen seconds %f", [self.offScreenPlayer currentPosInSeconds]);
    
    DLog(@"onScreenPlayer==clipStartOfMedia =%f,segmentStartTime =%@ ",[clip clipStartOfMedia],self.segmentStartTime);
}

-(void)pointSegment
{
    //[self pausePlayers];
    [self initSegment];
    [self createSegment];
    //    if ([[_interface orderConfigName] caseInsensitiveCompare:CONTENT_TYPE_PREVIEW_VIDEO ] == NSOrderedSame) {
    //        [self createPointSegment];
    //    }
    //    else {
    //        [self createSegment];
    //    }

}

-(void)createPointSegment {
    
}

-(void)playScene:(NSString*)timeIn andOut:(NSString*)timeOut
{
    _isScene = YES;
    _initialSeekIn = [CMUtilities getSecondsFromTimeCode:timeIn];
    _initialSeekOut = [CMUtilities getSecondsFromTimeCode:timeOut];
    
    [self seekActivePlayer:[CMUtilities getTimeCodeFromSeconds:_initialSeekIn]];
}

-(void)seekActivePlayer:(NSString*)seekTime
{
    if(self.activePlayer == ON_SCREEN_PLAYER)
    {
        [self.onScreenPlayer seekToTimeCode:seekTime completionHandler:^(BOOL success) {
            [self.onScreenPlayer play:nil];
        }];
    }
    else
    {
        [self.offScreenPlayer seekToTimeCode:seekTime completionHandler:^(BOOL success) {
            [self.offScreenPlayer play:nil];
        }];
    }
}

-(void)showSettingsView:(BOOL)isShow
{
    _settingsHolderView.hidden = !isShow;

    [_playerSettingsView removeFromSuperview];
    _playerSettingsView = nil;
    
//    [_playerSettingsView setTranslatesAutoresizingMaskIntoConstraints:NO];
//    
//    for(NSLayoutConstraint *c in [_settingsHolderView constraints])
//    {
//        if(c.firstItem == _playerSettingsView || c.secondItem == _playerSettingsView) {
//            [_settingsHolderView removeConstraint:c];
//        }
//    }
    
    if(isShow)
    {
        _playerSettingsView = (CMPlayerSettingsView*)[CMUtilities getViewWithXIBId:@"CMPlayerSettingsView" owner:self];
        _playerSettingsView.playerSettingDelegate = self;
        [_settingsHolderView addSubview:_playerSettingsView];
        
        NSDictionary *viewsDictionary = @{@"playerSettingsView":_playerSettingsView};
        
        [_settingsHolderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[playerSettingsView]-0-|" options:NSLayoutFormatAlignAllBaseline metrics:NSDictionaryOfVariableBindings(_playerSettingsView) views:viewsDictionary]];
        [_settingsHolderView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[playerSettingsView]-0-|" options:NSLayoutFormatAlignAllBaseline metrics:NSDictionaryOfVariableBindings(_playerSettingsView) views:viewsDictionary]];
        
        [_settingsHolderView layoutSubviews];
        [[self getActivePlayer] fetchSettingData:_playerSettingsView];
    }
}

- (IBAction)tapGestureAction:(UITapGestureRecognizer *)sender
{
    if (_playerSettingsView)
    {
        [self showSettingsView:NO];
    }
}

#pragma mark - UIGesture delegate method

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isDescendantOfView:_playerSettingsView])
    {
        return NO;
    }
    return YES;
}

#pragma mark - CMPlayerSettingDelegate delegate method

-(void)selectedPlayerOption:(id)option andCategoryName:(CMPlayerSettingCategoryName)categoryName
{
    DLog(@"option:%@, name:%ld",option, (long)categoryName);
    [self showSettingsView:NO];
    
    if (categoryName == CMAutioTrack) {
        [[self getActivePlayer] playSelectedAudioTrack:option];
    } else {
        [[self getActivePlayer] replaceCurrentItemWithSelectedMedia:option];
    }
}

- (void)hidePlayerSettingsView
{
    [self showSettingsView:NO];
}

#pragma mark - watermark position delegate method
-(void)updateWatermarkWidthHeight:(CGFloat)width height:(CGFloat)height
{
    _waterMarkWidth.constant  = width;
    _waterMarkHeight.constant = height;
}

-(void)updateWatermarkXYPosition:(CGFloat)X YPosition:(CGFloat)Y
{
    _waterMarkHolderX.constant = X;
    _waterMarkHolderY.constant = Y;
    
}
-(BOOL)enablePlayerControls {
    return YES;
}

@end
