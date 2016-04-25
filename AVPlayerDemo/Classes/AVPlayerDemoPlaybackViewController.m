/*
     File: AVPlayerDemoPlaybackViewController.m
 Abstract: UIViewController managing a playback view, thumbnail view, and associated playback UI.
  Version: 1.3
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */


#import "AVPlayerDemoPlaybackViewController.h"
#import "AVPlayerDemoPlaybackView.h"
#import "AVPlayerDemoMetadataViewController.h"
#import "PopViewController.h"

@interface AVPlayerDemoPlaybackViewController  () <UIPopoverPresentationControllerDelegate>
{

}

@property (nonatomic, strong) NSMutableArray* audioTracks;
@property (nonatomic, strong) NSMutableArray* selectedAudioTracks;
@property (nonatomic, strong) AVMediaSelectionOption* selectedAudioOption;


@property (nonatomic) NSUInteger selectedTrackIndex;
@property (nonatomic, strong) UIButton *btnSelectLanguage;

- (void)play:(id)sender;
- (void)pause:(id)sender;
- (void)showMetadata:(id)sender;
- (void)initScrubberTimer;
- (void)showPlayButton;
- (void)showStopButton;
- (void)syncScrubber;
- (IBAction)beginScrubbing:(id)sender;
- (IBAction)scrub:(id)sender;
- (IBAction)endScrubbing:(id)sender;
- (BOOL)isScrubbing;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
- (id)init;
- (void)dealloc;
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;
- (void)viewDidLoad;
- (void)viewWillDisappear:(BOOL)animated;
- (void)handleSwipe:(UISwipeGestureRecognizer*)gestureRecognizer;
- (void)syncPlayPauseButtons;
- (void)setURL:(NSURL*)URL;
- (NSURL*)URL;
@end

@interface AVPlayerDemoPlaybackViewController (Player)
- (void)removePlayerTimeObserver;
- (CMTime)playerItemDuration;
- (BOOL)isPlaying;
- (void)playerItemDidReachEnd:(NSNotification *)notification ;
- (void)observeValueForKeyPath:(NSString*) path ofObject:(id)object change:(NSDictionary*)change context:(void*)context;
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys;
@end

static void *AVPlayerDemoPlaybackViewControllerRateObservationContext = &AVPlayerDemoPlaybackViewControllerRateObservationContext;
static void *AVPlayerDemoPlaybackViewControllerStatusObservationContext = &AVPlayerDemoPlaybackViewControllerStatusObservationContext;
static void *AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext = &AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext;

#pragma mark -
@implementation AVPlayerDemoPlaybackViewController

@synthesize mPlayer, mPlayerItem, mPlaybackView, mToolbar, mPlayButton, mStopButton, mScrubber;

#pragma mark - PopoverView Methods

- (IBAction)selectTrackButtonPressed:(id)sender {
    
    if (self.audioTracks.count < 1)
        return;
    
    self.btnSelectLanguage.selected = !self.btnSelectLanguage.selected;
    self.selectedAudioTracks        = nil;
    PopViewController* contentVC = [[PopViewController alloc]     initWithNibName:@"PopViewController" bundle:nil];
    // present the controller
    // on iPad, this will be a Popover
    // on iPhone, this will be an action sheet
    contentVC.modalPresentationStyle = UIModalPresentationPopover;
    contentVC.audioTracks = [[NSArray alloc] initWithArray:self.audioTracks];
    //contentVC.audioTracks = [self getAvailableAudioTracks];
    contentVC.popoverPresentationController.sourceRect = self.btnSelectLanguage.frame; // 15
    contentVC.popoverPresentationController.sourceView = self.view; // 16
    
    // configure the Popover presentation controller
    UIPopoverPresentationController *popController = [contentVC popoverPresentationController];
    popController.permittedArrowDirections = UIPopoverArrowDirectionAny;
    //popController.barButtonItem = self.navigationItem.rightBarButtonItem;
    popController.delegate = self;
    
    [self presentViewController:contentVC animated:YES completion:nil];

}


- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    NSLog(@"%s",__FUNCTION__);
    self.btnSelectLanguage.selected = !self.btnSelectLanguage.selected ;
    // called when a Popover is dismissed
}

- (BOOL)popoverPresentationControllerShouldDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    NSLog(@"%s",__FUNCTION__);

    // return YES if the Popover should be dismissed
    // return NO if the Popover should not be dismissed
    
   PopViewController *popViewController  = (PopViewController *)popoverPresentationController.presentedViewController;
    
    NSArray *selectedRows       = popViewController.tableView.indexPathsForSelectedRows;
    self.selectedAudioTracks    = [[NSMutableArray alloc] init];
    
    for (NSIndexPath *indexPath in selectedRows) {
        NSLog(@"Track:%@",[popViewController.audioTracks objectAtIndex:indexPath.row]);
        [self.selectedAudioTracks addObject:[popViewController.audioTracks objectAtIndex:indexPath.row]];
    }
    [self playSelectedAudioTracks:self.selectedAudioTracks];
    return YES;
}

- (void)popoverPresentationController:(UIPopoverPresentationController *)popoverPresentationController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView *__autoreleasing  _Nonnull *)view {
    NSLog(@"%s",__FUNCTION__);

    // called when the Popover changes positon
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    
    return UIModalPresentationNone; //UIModalPresentationPopover
}


#pragma mark Asset URL

- (void)setURL:(NSURL*)URL
{
	if (mURL != URL)
	{
		  mURL = [URL copy];
        //mURL = [NSURL URLWithString:@"http://content.jwplatform.com/manifests/vM7nH0Kl.m3u8"];
        //mURL = [NSURL URLWithString:@"http://10.1.177.32:100/unencrypted/25fps/rekkit_new/index.m3u8"];
        //mURL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"];
        //mURL = [NSURL URLWithString:@"https://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"];
       // mURL = [NSURL URLWithString:@"http://www.example.com/hls-vod/audio-only/video1.mp4.m3u8"];


        //
 
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mURL options:nil];
        //NSArray *requestedKeys = @[@"playable"];
        NSArray *requestedKeys = @[@"playable", @"status"];

        /* Tells the asset to load the values of any of the specified keys that are not already loaded. */
        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
         ^{		 
             dispatch_async( dispatch_get_main_queue(), 
                            ^{
                                /* IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem. */
                                [self prepareToPlayAsset:asset withKeys:requestedKeys];
                            });
         }];
	}
}

- (NSURL*)URL
{
	return mURL;
}

#pragma mark -
#pragma mark Movie controller methods

#pragma mark
#pragma mark Button Action Methods
float volume = 0.0;

- (IBAction)play:(id)sender
{
	/* If we are at the end of the movie, we must seek to the beginning first 
		before starting playback. */
    
	if (YES == seekToZeroBeforePlay) 
	{
		seekToZeroBeforePlay = NO;
		[self.mPlayer seekToTime:kCMTimeZero];
	}
	[self.mPlayer play];
    [self showStopButton];
}

- (NSArray *)getAvailableAudioTracks
{
    NSLog(@"%s",__FUNCTION__);

    NSMutableArray *allAudioTracks = [NSMutableArray new];
    AVURLAsset *asset = (AVURLAsset *)[[self.mPlayer currentItem] asset];

    //** 1st Way
    AVMediaSelectionGroup *audioTracks = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    
    NSLog(@"audio tracks 1: %@", audioTracks);
    
    for (AVMediaSelectionOption *option in audioTracks.options)
    {

        NSLog(@"Audio Track Display Name: %@", option.displayName);
        [allAudioTracks addObject:option];
    }
    
    //** 2nd way
    NSArray *audiTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    NSLog(@"audio tracks 2: %@", audiTracks);

    if(allAudioTracks.count == 0) {
       allAudioTracks = [NSMutableArray arrayWithArray:audiTracks];
    }
    ////////
    NSLog(@"All Audio Tracks Array: %@", allAudioTracks);
    [self.audioTracks removeAllObjects];
    self.audioTracks = allAudioTracks;
    return allAudioTracks;
}


- (void)changeAudioTrackWithSelectedAudioOption:(AVMediaSelectionOption *)selectedAudioOption {
    NSLog(@"%s",__FUNCTION__);

    AVAsset *asset              = [[self.mPlayer currentItem] asset];
    AVMediaSelectionGroup *audoTracks = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    [[self.mPlayer currentItem] selectMediaOption:selectedAudioOption inMediaSelectionGroup:audoTracks];
}

- (void)getAllMediaCharacteristics {
    NSArray *tracks = [[self.player currentItem] tracks];
    NSLog(@"%s,\nAll Media Tracks:%@",__FUNCTION__, tracks);
    
    NSLog(@"\n\n\n\n=======================================\n\n\n\n");

    AVAsset *asset = [[self.mPlayer currentItem] asset];
    NSArray *mediaCharacteristics = asset.availableMediaCharacteristicsWithMediaSelectionOptions;
    NSLog(@"Media Characteristics Array:%@",mediaCharacteristics);
    
    for (NSString* characteristic in mediaCharacteristics) {
        NSLog(@"characteristic:%@",characteristic);
        AVMediaSelectionGroup *group = [asset mediaSelectionGroupForMediaCharacteristic:characteristic];
        
        for (AVMediaSelectionOption *option in group.options) {
            NSLog(@"option: %@", option.displayName);
            
        }
    }
}

- (AVMediaSelectionOption *)getSelectedAudioOption {
    NSLog(@"%s",__FUNCTION__);

    AVAsset *asset = [[self.mPlayer currentItem] asset];
    AVMediaSelectionGroup *audoTracks = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    AVMediaSelectionOption *selectedOption = [[self.mPlayer currentItem] selectedMediaOptionInMediaSelectionGroup:audoTracks];
    NSLog(@"Selected Audio Option:%@", selectedOption);

    return selectedOption;
}

- (void)checkEnabledAudioTracks {
    NSLog(@"%s",__FUNCTION__);

    AVURLAsset *asset = (AVURLAsset *)[[self.mPlayer currentItem] asset];
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];

    for (AVAssetTrack *audioAsset in audioTracks) {
        NSLog(@"audioAsset:%@ 1====enabled:%d",audioAsset, audioAsset.enabled);
    }
}

- (void)enableAudioTrack:(AVAssetTrack *)audioTrack {
    
    if (audioTrack.enabled)
        return;
    
    AVURLAsset *asset = (AVURLAsset *)[[self.mPlayer currentItem] asset];

    AVMutableComposition *composition = [AVMutableComposition composition];

    AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:[audioTrack trackID]];
    NSError* error = NULL;

    [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,asset.duration)
                                   ofTrack:audioTrack
                                    atTime:kCMTimeZero
                                     error:&error];
    
    NSLog(@"Error : %@", error);

}

- (void)enableAllTracks {
    NSLog(@"%s",__FUNCTION__);
    AVURLAsset *asset = (AVURLAsset *)[[self.mPlayer currentItem] asset];
    
    AVMutableComposition *composition = [AVMutableComposition composition];
    
//    AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

    NSError* error = NULL;
    
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,asset.duration)
                                   ofTrack:[[asset tracksWithMediaType:AVMediaTypeVideo]objectAtIndex:0]
                                    atTime:kCMTimeZero
                                     error:&error];
    NSLog(@"error : %@", error);

    NSArray *allAudio = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    for (AVAssetTrack *audioAsset in allAudio) {
        NSError* audioError = NULL;
        
       // AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:[audioAsset trackID]];

        NSLog(@"2====enabled:%d",audioAsset.enabled);
        [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,asset.duration)
                                       ofTrack:audioAsset
                                        atTime:kCMTimeZero
                                         error:&error];
        
        NSLog(@"audioError : %@", audioError);
        
    }
}
- (IBAction)pause:(id)sender
{
	[self.mPlayer pause];
    [self showPlayButton];
}

- (void)playSelectedAudioTracks:(NSArray *)selectedAudioTracks {
    NSLog(@"%s",__FUNCTION__);

    if (selectedAudioTracks.count == 0 || self.audioTracks.count <2) {
        return;
    }
    
    for (id audioTrack in selectedAudioTracks) {
        
        if ([audioTrack isKindOfClass:[AVMediaSelectionOption class]]) {
            [self changeAudioTrackWithSelectedAudioOption: audioTrack];
            
        } else if ([audioTrack isKindOfClass:[AVAssetTrack class]]) {
            
            AVAsset *asset = [[self.mPlayer currentItem] asset];
            NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
            
            NSMutableArray *allAudioParams = [NSMutableArray array];
            
            for (AVAssetTrack *track in audioTracks)
            {
                float trackVolume = 0.0;
                
                if ([selectedAudioTracks containsObject:track]) {
                    trackVolume = 1.0;
                }

                NSLog(@"enabled:%d",track.enabled);
               // NSLog(@"languageCode:%@",track.languageCode);
                
                AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
                
                
                [audioInputParams setVolume:trackVolume atTime:kCMTimeZero];
                [audioInputParams setTrackID:[track trackID]];
                [allAudioParams addObject:audioInputParams];
            }
            AVMutableAudioMix *audioZeroMix = [AVMutableAudioMix audioMix];
            [audioZeroMix setInputParameters:allAudioParams];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [[self.mPlayer currentItem] setAudioMix:audioZeroMix];
            });
        }
    }
    [self getSelectedAudioOption];
}

- (void)playMultipleAudioTracks {
    
    AVAsset *asset = [[self.mPlayer currentItem] asset];
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    
    if (audioTracks.count <2) {
        return;
    }
    
    ++_selectedTrackIndex;
    
    NSLog(@"selectedTrackIndex:%lu,\n self.audioTracks.count:%lu ",(unsigned long)self.selectedTrackIndex, audioTracks.count);
    
    NSMutableArray *allAudioParams = [NSMutableArray array];
    NSUInteger i = 0;
    
    for (AVAssetTrack *track in audioTracks)
    {
        float trackVolume = 0.0;
        /*if (i == self.selectedTrackIndex)
        {
            trackVolume = 1.0;
        }*/
        
        if (i == 1 || i == 2)
        {
            trackVolume = 1.0;
        }

        NSLog(@"enabled:%d",track.enabled);
        
        NSLog(@"languageCode:%@",track.languageCode);
        NSLog(@"extendedLanguageTag:%@",track.extendedLanguageTag);
        
        //        if ([track.languageCode isEqualToString:@"hin"]) {
        //            trackVolume = 1;
        //        }
        
        AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
        
        
        [audioInputParams setVolume:trackVolume atTime:kCMTimeZero];
        [audioInputParams setTrackID:[track trackID]];
        [allAudioParams addObject:audioInputParams];
        ++i;
    }
    AVMutableAudioMix *audioZeroMix = [AVMutableAudioMix audioMix];
    [audioZeroMix setInputParameters:allAudioParams];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self.mPlayer currentItem] setAudioMix:audioZeroMix];
    });
    
    
    if (self.selectedTrackIndex == audioTracks.count) {
        _selectedTrackIndex = 0;
    }
    [self getSelectedAudioOption];
}

/* Display AVMetadataCommonKeyTitle and AVMetadataCommonKeyCopyrights metadata. */
- (IBAction)showMetadata:(id)sender
{
    //[self playSelectedAudioTracks];
    [self playMultipleAudioTracks];
    return;
    
	AVPlayerDemoMetadataViewController* metadataViewController = [[AVPlayerDemoMetadataViewController alloc] init];

	[metadataViewController setMetadata:[[[self.mPlayer currentItem] asset] commonMetadata]];
	
	[self presentViewController:metadataViewController animated:YES completion:NULL];

}

#pragma mark -
#pragma mark Play, Stop buttons

/* Show the stop button in the movie player controller. */
-(void)showStopButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mStopButton];
    self.mToolbar.items = toolbarItems;
}

/* Show the play button in the movie player controller. */
-(void)showPlayButton
{
    NSMutableArray *toolbarItems = [NSMutableArray arrayWithArray:[self.mToolbar items]];
    [toolbarItems replaceObjectAtIndex:0 withObject:self.mPlayButton];
    self.mToolbar.items = toolbarItems;
}

/* If the media is playing, show the stop button; otherwise, show the play button. */
- (void)syncPlayPauseButtons
{
	if ([self isPlaying])
	{
        [self showStopButton];
	}
	else
	{
        [self showPlayButton];        
	}
}

-(void)enablePlayerButtons
{
    self.mPlayButton.enabled = YES;
    self.mStopButton.enabled = YES;
}

-(void)disablePlayerButtons
{
    self.mPlayButton.enabled = NO;
    self.mStopButton.enabled = NO;
}

#pragma mark -
#pragma mark Movie scrubber control

/* ---------------------------------------------------------
**  Methods to handle manipulation of the movie scrubber control
** ------------------------------------------------------- */

/* Requests invocation of a given block during media playback to update the movie scrubber control. */
-(void)initScrubberTimer
{
	double interval = .1f;	
	
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		return;
	} 
	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		CGFloat width = CGRectGetWidth([self.mScrubber bounds]);
		interval = 0.5f * duration / width;
	}

	/* Update the scrubber during normal playback. */
	__weak AVPlayerDemoPlaybackViewController *weakSelf = self;
	mTimeObserver = [self.mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(interval, NSEC_PER_SEC) 
								queue:NULL /* If you pass NULL, the main queue is used. */
								usingBlock:^(CMTime time) 
                                            {
                                                [weakSelf syncScrubber];
                                            }];
}

/* Set the scrubber based on the player current time. */
- (void)syncScrubber
{
	CMTime playerDuration = [self playerItemDuration];
	if (CMTIME_IS_INVALID(playerDuration)) 
	{
		mScrubber.minimumValue = 0.0;
		return;
	} 

	double duration = CMTimeGetSeconds(playerDuration);
	if (isfinite(duration))
	{
		float minValue = [self.mScrubber minimumValue];
		float maxValue = [self.mScrubber maximumValue];
		double time = CMTimeGetSeconds([self.mPlayer currentTime]);
		
		[self.mScrubber setValue:(maxValue - minValue) * time / duration + minValue];
	}
}

/* The user is dragging the movie controller thumb to scrub through the movie. */
- (IBAction)beginScrubbing:(id)sender
{
	mRestoreAfterScrubbingRate = [self.mPlayer rate];
	[self.mPlayer setRate:0.f];
	
	/* Remove previous timer. */
	[self removePlayerTimeObserver];
}

/* Set the player current time to match the scrubber position. */
- (IBAction)scrub:(id)sender
{
	if ([sender isKindOfClass:[UISlider class]] && !isSeeking)
	{
		isSeeking = YES;
		UISlider* slider = sender;
		
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) {
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			float minValue = [slider minimumValue];
			float maxValue = [slider maximumValue];
			float value = [slider value];
			
			double time = duration * (value - minValue) / (maxValue - minValue);
			
			[self.mPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
				dispatch_async(dispatch_get_main_queue(), ^{
					isSeeking = NO;
				});
			}];
		}
	}
}

/* The user has released the movie thumb control to stop scrubbing through the movie. */
- (IBAction)endScrubbing:(id)sender
{
	if (!mTimeObserver)
	{
		CMTime playerDuration = [self playerItemDuration];
		if (CMTIME_IS_INVALID(playerDuration)) 
		{
			return;
		} 
		
		double duration = CMTimeGetSeconds(playerDuration);
		if (isfinite(duration))
		{
			CGFloat width = CGRectGetWidth([self.mScrubber bounds]);
			double tolerance = 0.5f * duration / width;
			
			__weak AVPlayerDemoPlaybackViewController *weakSelf = self;
			mTimeObserver = [self.mPlayer addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(tolerance, NSEC_PER_SEC) queue:NULL usingBlock:
			^(CMTime time)
			{
				[weakSelf syncScrubber];
			}];
		}
	}

	if (mRestoreAfterScrubbingRate)
	{
		[self.mPlayer setRate:mRestoreAfterScrubbingRate];
		mRestoreAfterScrubbingRate = 0.f;
	}
}

- (BOOL)isScrubbing
{
	return mRestoreAfterScrubbingRate != 0.f;
}

-(void)enableScrubber
{
    self.mScrubber.enabled = YES;
}

-(void)disableScrubber
{
    self.mScrubber.enabled = NO;    
}

#pragma mark
#pragma mark View Controller

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		[self setPlayer:nil];
		
		[self setEdgesForExtendedLayout:UIRectEdgeAll];
	}
	
	return self;
}

- (id)init
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) 
    {
        return [self initWithNibName:@"AVPlayerDemoPlaybackView-iPad" bundle:nil];
	} 
    else 
    {
        return [self initWithNibName:@"AVPlayerDemoPlaybackView" bundle:nil];
	}
}

- (void)viewDidUnload
{
    self.mPlaybackView = nil;
	
    self.mToolbar = nil;
    self.mPlayButton = nil;
    self.mStopButton = nil;
    self.mScrubber = nil;
	
	[super viewDidUnload];
}

- (void)viewDidLoad
{
    
    self.audioTracks = [[NSMutableArray alloc] init];
    // Add select track button
    self.btnSelectLanguage = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnSelectLanguage.frame = CGRectMake(self.view.frame.size.width - 120, 5, 120, 30);
    self.btnSelectLanguage.backgroundColor = [UIColor brownColor];
    [self.btnSelectLanguage setTitle: @"Select Track" forState: UIControlStateNormal];
    [self.btnSelectLanguage setTitle: @"Done" forState: UIControlStateSelected];

    [self.btnSelectLanguage addTarget:self action:@selector(selectTrackButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.btnSelectLanguage];
    self.navigationItem.rightBarButtonItem = rightBarButton;
    
    
    [self setPlayer:nil];
    
    UIView* view  = [self view];
    
    UISwipeGestureRecognizer* swipeUpRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    [swipeUpRecognizer setDirection:UISwipeGestureRecognizerDirectionUp];
    [view addGestureRecognizer:swipeUpRecognizer];
    
    UISwipeGestureRecognizer* swipeDownRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipe:)];
    [swipeDownRecognizer setDirection:UISwipeGestureRecognizerDirectionDown];
    [view addGestureRecognizer:swipeDownRecognizer];
    
    UIBarButtonItem *scrubberItem = [[UIBarButtonItem alloc] initWithCustomView:self.mScrubber];
    UIBarButtonItem *flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(showMetadata:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *infoItem = [[UIBarButtonItem alloc] initWithCustomView:infoButton];
    
    self.mToolbar.items = @[self.mPlayButton, flexItem, scrubberItem, infoItem];
    isSeeking = NO;
    [self initScrubberTimer];
    
    [self syncPlayPauseButtons];
    [self syncScrubber];
    
    [super viewDidLoad];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[self.mPlayer pause];
	
	[super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(void)setViewDisplayName
{
    /* Set the view title to the last component of the asset URL. */
    self.title = [mURL lastPathComponent];
    
    /* Or if the item has a AVMetadataCommonKeyTitle metadata, use that instead. */
	for (AVMetadataItem* item in ([[[self.mPlayer currentItem] asset] commonMetadata]))
	{
		NSString* commonKey = [item commonKey];
		
		if ([commonKey isEqualToString:AVMetadataCommonKeyTitle])
		{
			self.title = [item stringValue];
		}
	}
}

- (void)handleSwipe:(UISwipeGestureRecognizer *)gestureRecognizer
{
	UIView* view = [self view];
	UISwipeGestureRecognizerDirection direction = [gestureRecognizer direction];
	CGPoint location = [gestureRecognizer locationInView:view];
	
	if (location.y < CGRectGetMidY([view bounds]))
	{
		if (direction == UISwipeGestureRecognizerDirectionUp)
		{
			[UIView animateWithDuration:0.2f animations:
			^{
				[[self navigationController] setNavigationBarHidden:YES animated:YES];
			} completion:
			^(BOOL finished)
			{
				[[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationSlide];
			}];
		}
		if (direction == UISwipeGestureRecognizerDirectionDown)
		{
			[UIView animateWithDuration:0.2f animations:
			^{
				[[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationSlide];
			} completion:
			^(BOOL finished)
			{
				[[self navigationController] setNavigationBarHidden:NO animated:YES];
			}];
		}
	}
	else
	{
		if (direction == UISwipeGestureRecognizerDirectionDown)
		{
            if (![self.mToolbar isHidden])
			{
				[UIView animateWithDuration:0.2f animations:
				^{
					[self.mToolbar setTransform:CGAffineTransformMakeTranslation(0.f, CGRectGetHeight([self.mToolbar bounds]))];
				} completion:
				^(BOOL finished)
				{
					[self.mToolbar setHidden:YES];
				}];
			}
		}
		else if (direction == UISwipeGestureRecognizerDirectionUp)
		{
            if ([self.mToolbar isHidden])
			{
				[self.mToolbar setHidden:NO];
				
				[UIView animateWithDuration:0.2f animations:
				^{
					[self.mToolbar setTransform:CGAffineTransformIdentity];
				} completion:^(BOOL finished){}];
			}
		}
	}
}

- (void)dealloc
{
	[self removePlayerTimeObserver];
	
	[self.mPlayer removeObserver:self forKeyPath:@"rate"];
	[mPlayer.currentItem removeObserver:self forKeyPath:@"status"];
	
	[self.mPlayer pause];
	
	
}

@end

@implementation AVPlayerDemoPlaybackViewController (Player)

#pragma mark Player Item

- (BOOL)isPlaying
{
	return mRestoreAfterScrubbingRate != 0.f || [self.mPlayer rate] != 0.f;
}

/* Called when the player item has played to its end time. */
- (void)playerItemDidReachEnd:(NSNotification *)notification 
{
	/* After the movie has played to its end time, seek back to time zero 
		to play it again. */
	seekToZeroBeforePlay = YES;
}

/* ---------------------------------------------------------
 **  Get the duration for a AVPlayerItem. 
 ** ------------------------------------------------------- */

- (CMTime)playerItemDuration
{
	AVPlayerItem *playerItem = [self.mPlayer currentItem];
	if (playerItem.status == AVPlayerItemStatusReadyToPlay)
	{
		return([playerItem duration]);
	}
	
	return(kCMTimeInvalid);
}


/* Cancels the previously registered time observer. */
-(void)removePlayerTimeObserver
{
	if (mTimeObserver)
	{
		[self.mPlayer removeTimeObserver:mTimeObserver];
		mTimeObserver = nil;
	}
}

#pragma mark -
#pragma mark Loading the Asset Keys Asynchronously

#pragma mark -
#pragma mark Error Handling - Preparing Assets for Playback Failed

/* --------------------------------------------------------------
 **  Called when an asset fails to prepare for playback for any of
 **  the following reasons:
 ** 
 **  1) values of asset keys did not load successfully, 
 **  2) the asset keys did load successfully, but the asset is not 
 **     playable
 **  3) the item did not become ready to play. 
 ** ----------------------------------------------------------- */

-(void)assetFailedToPrepareForPlayback:(NSError *)error
{
    [self removePlayerTimeObserver];
    [self syncScrubber];
    [self disableScrubber];
    [self disablePlayerButtons];
    
    /* Display the error. */
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:@"OK"
											  otherButtonTitles:nil];
	[alertView show];
}


#pragma mark Prepare to play asset, URL

/*
 Invoked at the completion of the loading of the values for all keys on the asset that we require.
 Checks whether loading was successfull and whether the asset is playable.
 If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
    /* Make sure that the value of each key has loaded successfully. */
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
			[self assetFailedToPrepareForPlayback:error];
			return;
		}
		/* If you are also implementing -[AVAsset cancelLoading], add your code here to bail out properly in the case of cancellation. */
	}
    
    /* Use the AVAsset playable property to detect whether the asset can be played. */
    if (!asset.playable) 
    {
        /* Generate an error describing the failure. */
		NSString *localizedDescription = NSLocalizedString(@"Item cannot be played", @"Item cannot be played description");
		NSString *localizedFailureReason = NSLocalizedString(@"The assets tracks were loaded, but could not be made playable.", @"Item cannot be played failure reason");
		NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:
								   localizedDescription, NSLocalizedDescriptionKey, 
								   localizedFailureReason, NSLocalizedFailureReasonErrorKey, 
								   nil];
		NSError *assetCannotBePlayedError = [NSError errorWithDomain:@"StitchedStreamPlayer" code:0 userInfo:errorDict];
        
        /* Display the error to the user. */
        [self assetFailedToPrepareForPlayback:assetCannotBePlayedError];
        
        return;
    }
	
	/* At this point we're ready to set up for playback of the asset. */
    
    /* Stop observing our prior AVPlayerItem, if we have one. */
    if (self.mPlayerItem)
    {
        /* Remove existing player item key value observers and notifications. */
        
        [self.mPlayerItem removeObserver:self forKeyPath:@"status"];
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.mPlayerItem];
    }
	
    /* Create a new instance of AVPlayerItem from the now successfully loaded AVAsset. */
    self.mPlayerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [self.mPlayerItem addObserver:self 
                      forKeyPath:@"status"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerStatusObservationContext];
	
    /* When the player item has played to its end time we'll toggle
     the movie controller Pause button to be the Play button */
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:self.mPlayerItem];
	
    seekToZeroBeforePlay = NO;
	
    /* Create new player, if we don't already have one. */
    if (!self.mPlayer)
    {
        /* Get a new AVPlayer initialized to play the specified player item. */
        [self setPlayer:[AVPlayer playerWithPlayerItem:self.mPlayerItem]];	
		
        /* Observe the AVPlayer "currentItem" property to find out when any 
         AVPlayer replaceCurrentItemWithPlayerItem: replacement will/did 
         occur.*/
        [self.player addObserver:self 
                      forKeyPath:@"currentItem"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext];
        
        /* Observe the AVPlayer "rate" property to update the scrubber control. */
        [self.player addObserver:self 
                      forKeyPath:@"rate"
                         options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         context:AVPlayerDemoPlaybackViewControllerRateObservationContext];
    }
    
    /* Make our new AVPlayerItem the AVPlayer's current item. */
    if (self.player.currentItem != self.mPlayerItem)
    {
        /* Replace the player item with a new player item. The item replacement occurs 
         asynchronously; observe the currentItem property to find out when the 
         replacement will/did occur
		 
		 If needed, configure player item here (example: adding outputs, setting text style rules,
		 selecting media options) before associating it with a player
		 */
        [self.mPlayer replaceCurrentItemWithPlayerItem:self.mPlayerItem];
        
        [self syncPlayPauseButtons];
    }
	
    [self.mScrubber setValue:0.0];
    
    
    
}

#pragma mark -
#pragma mark Asset Key Value Observing
#pragma mark

#pragma mark Key Value Observer for player rate, currentItem, player item status

/* ---------------------------------------------------------
**  Called when the value at the specified key path relative
**  to the given object has changed. 
**  Adjust the movie play and pause button controls when the 
**  player item "status" value changes. Update the movie 
**  scrubber control when the player item is ready to play.
**  Adjust the movie scrubber control when the player item 
**  "rate" value changes. For updates of the player
**  "currentItem" property, set the AVPlayer for which the 
**  player layer displays visual output.
**  NOTE: this method is invoked on the main queue.
** ------------------------------------------------------- */

- (void)observeValueForKeyPath:(NSString*) path 
			ofObject:(id)object 
			change:(NSDictionary*)change 
			context:(void*)context
{
	/* AVPlayerItem "status" property value observer. */
	if (context == AVPlayerDemoPlaybackViewControllerStatusObservationContext)
	{
		[self syncPlayPauseButtons];

        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
            /* Indicates that the status of the player is not yet known because 
             it has not tried to load new media resources for playback */
            case AVPlayerItemStatusUnknown:
            {
                [self removePlayerTimeObserver];
                [self syncScrubber];
                
                [self disableScrubber];
                [self disablePlayerButtons];
            }
            break;
                
            case AVPlayerItemStatusReadyToPlay:
            {
                /* Once the AVPlayerItem becomes ready to play, i.e. 
                 [playerItem status] == AVPlayerItemStatusReadyToPlay,
                 its duration can be fetched from the item. */
                 self.selectedTrackIndex = nil;
                [self.audioTracks removeAllObjects];
                [self.selectedAudioTracks removeAllObjects];
                
                [self getAllMediaCharacteristics];
                [self checkEnabledAudioTracks];
                /*[self getAvailableAudioTracks];
                [self enableAllTracks];
                [self checkEnabledAudioTracks];*/

                [self getAvailableAudioTracks];
                [self playSelectedAudioTracks:self.selectedAudioTracks];
                [self initScrubberTimer];
                [self enableScrubber];
                [self enablePlayerButtons];
            }
            break;
                
            case AVPlayerItemStatusFailed:
            {
                AVPlayerItem *playerItem = (AVPlayerItem *)object;
                [self assetFailedToPrepareForPlayback:playerItem.error];
            }
            break;
        }
	}
	/* AVPlayer "rate" property value observer. */
	else if (context == AVPlayerDemoPlaybackViewControllerRateObservationContext)
	{
        [self syncPlayPauseButtons];
	}
	/* AVPlayer "currentItem" property observer. 
        Called when the AVPlayer replaceCurrentItemWithPlayerItem: 
        replacement will/did occur. */
	else if (context == AVPlayerDemoPlaybackViewControllerCurrentItemObservationContext)
	{
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        /* Is the new player item null? */
        if (newPlayerItem == (id)[NSNull null])
        {
            [self disablePlayerButtons];
            [self disableScrubber];
        }
        else /* Replacement of player currentItem has occurred */
        {
            /* Set the AVPlayer for which the player layer displays visual output. */
            [self.mPlaybackView setPlayer:mPlayer];
            
            [self setViewDisplayName];
            
            /* Specifies that the player should preserve the video’s aspect ratio and 
             fit the video within the layer’s bounds. */
            [self.mPlaybackView setVideoFillMode:AVLayerVideoGravityResizeAspect];
            
            [self syncPlayPauseButtons];
        }
	}
	else
	{
		[super observeValueForKeyPath:path ofObject:object change:change context:context];
	}
    
    
    
}


@end

