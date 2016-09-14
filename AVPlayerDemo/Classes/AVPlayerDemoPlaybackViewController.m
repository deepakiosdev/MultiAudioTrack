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
#import "M3u8Media.h"
#import "PreviewCell.h"

@interface AVPlayerDemoPlaybackViewController  () <UIPopoverPresentationControllerDelegate>
{
    int index;
}
@property (weak, nonatomic) IBOutlet UICollectionView *previewCollectionView;
@property (weak, nonatomic) IBOutlet UIImageView *previewImageView;

@property (nonatomic, strong) NSMutableArray* audioTracks;
@property (nonatomic, strong) NSMutableArray* selectedAudioTracks;
@property (nonatomic, strong) NSMutableArray* thumbnailsArray;

@property (nonatomic, strong) AVMediaSelectionOption* selectedAudioOption;
@property (nonatomic) float lastBitRate;
@property (nonatomic, strong) NSArray *bandwidthArray;
@property (nonatomic, assign) BOOL isBitrateSwitching;
@property (strong) AVPlayerItem* playerItem;
@property (nonatomic, strong) M3u8Media *selectedBitrate;
@property (nonatomic) CMTime lastTime;
@property (nonatomic) double scrubTime;
@property (nonatomic, strong) AVPlayerItemVideoOutput* output;

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
    contentVC.audioTracks = [[NSArray alloc] initWithArray:self.bandwidthArray];

  //  contentVC.audioTracks = [[NSArray alloc] initWithArray:self.audioTracks];
    //contentVC.audioTracks = [self getAvailableAudioTracks];
    contentVC.popoverPresentationController.sourceRect = self.btnSelectLanguage.frame; // 15
    //contentVC.popoverPresentationController.sourceRect = CGRectMake(300, 400, 20, 20); // 15

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
    //[self playSelectedAudioTracks:self.selectedAudioTracks];
    double bitrate = ((NSNumber *)self.selectedAudioTracks.firstObject).doubleValue;
    self.mPlayer.currentItem.preferredPeakBitRate = bitrate;
    
    NSLog(@"preferredPeakBitRate:%f",self.mPlayer.currentItem.preferredPeakBitRate);
    [self getBitRateFromAVPlayerItem:self.mPlayer.currentItem];
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
        mURL = [NSURL URLWithString:@"http://content.jwplatform.com/manifests/vM7nH0Kl.m3u8"];
        //mURL = [NSURL URLWithString:@"http://10.1.177.32:100/unencrypted/25fps/rekkit_new/index.m3u8"];
           //mURL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"];
                //mURL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear4/prog_index.m3u8"];  //737777
     //  mURL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear3/prog_index.m3u8"];  //484444
       // mURL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear2/prog_index.m3u8"];  //311111
        
        
        // mURL = [NSURL URLWithString:@"https://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8"];
       // mURL = [NSURL URLWithString:@"http://www.example.com/hls-vod/audio-only/video1.mp4.m3u8"];
       // mURL = [NSURL URLWithString:@"https://devimages.apple.com.edgekey.net/streaming/examples/bipbop_16x9/gear2/prog_index.m3u8"];


        //
 
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mURL options:nil];
        //NSArray *requestedKeys = @[@"playable"];
        NSArray *requestedKeys = @[@"playable"];

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

- (void)switchToNextURL:(NSURL*)URL
{
    ++index;

    switch (index) {
        case 1:
            NSLog(@"Set Prefred bitrate:311111");
           // URL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear2/prog_index.m3u8"];  //311111
            self.playerItem.preferredPeakBitRate = 311111;
            break;
        case 2:
            NSLog(@"Set Prefred bitrate:484444");
            //URL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear3/prog_index.m3u8"];  //484444

            self.playerItem.preferredPeakBitRate = 484444;

            break;
        case 3:
            NSLog(@"Set Prefred bitrate:737777");

            //URL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/gear4/prog_index.m3u8"];  //737777

            self.playerItem.preferredPeakBitRate = 737777;

            break;
        case 4:
            NSLog(@"Set Prefred bitrate:200000");

           // URL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"]; //200000
            self.playerItem.preferredPeakBitRate = 200000;

            break;
        default:
            NSLog(@"Set Prefred bitrate:200000");

             //URL = [NSURL URLWithString:@"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"];
            self.playerItem.preferredPeakBitRate = 200000;
            break;
    }
    if (index == 4) {
        index = 0;
    }
    self.lastTime = self.player.currentItem.currentTime;
    if (mURL != URL)
    {
        mURL = [URL copy];
        
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mURL options:nil];
        //NSArray *requestedKeys = @[@"playable"];
        NSArray *requestedKeys = @[@"playable"];
        
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
    
  // self.mPlayer.currentItem.preferredPeakBitRate = 4454545454545;
}

- (CMTime)getCurrentTime {
    return [self.player.currentItem currentTime];
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
/**
 * Set selected bitrate.
 */

#pragma mark - AVAssetResourceLoader delegate methods
- (BOOL) resourceLoader:(AVAssetResourceLoader *)resourceLoader shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    return YES;
}

- (void)switchToSelectedBitrate:(M3u8Media *)m3u8Media {
    
    NSLog(@"Current preferredPeakBitRate:%f, selected bitrate:%f",self.player.currentItem.preferredPeakBitRate, m3u8Media.bitrate);
    NSLog(@"Current indicatedBitrate:%f",self.player.currentItem.accessLog.events.lastObject.indicatedBitrate);
    
    if (m3u8Media != nil && self.selectedBitrate != m3u8Media) {
        self.selectedBitrate    = m3u8Media;
        self.isBitrateSwitching = YES;
        [self.player pause];
        NSURL *url = [NSURL URLWithString:[self.selectedBitrate.playlistUrl stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
     NSLog(@"queue player URLS %@", url);
        
        NSMutableDictionary * headers = [NSMutableDictionary dictionary];
        [headers setObject:@"iPad" forKey:@"User-Agent"];
        
        AVURLAsset *asset           = [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
        
        AVAssetResourceLoader *resourceLoader = asset.resourceLoader;
        //[resourceLoader setDelegate:self queue:dispatch_queue_create("CMQueuePlayerAsset loader", nil)];
        [resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
        //AVPlayerItem *playerItem    = [[AVPlayerItem alloc] initWithAsset:asset];
        self.playerItem    = [[AVPlayerItem alloc] initWithAsset:asset];
        
        
        if (self.isBitrateSwitching && self.playerItem && self.player.currentItem != self.playerItem)
        {
            
            dispatch_async(dispatch_get_main_queue(), ^
                           {
                               CMTime time = [self getCurrentTime];
                               [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
                               NSLog(@"2=====Current URL:%@",[((AVURLAsset *)self.player.currentItem.asset) URL]);
                               
                               [self seekToCMTime:time completionHandler:^(BOOL success) {
                                   NSLog(@"After selection preferredPeakBitRate:%f, indicatedBitrate:%f",self.player.currentItem.preferredPeakBitRate, self.player.currentItem.accessLog.events.lastObject.indicatedBitrate);
                                   NSLog(@"3=====Current URL:%@",[((AVURLAsset *)self.player.currentItem.asset) URL]);
                                   
                               }];
                               self.isBitrateSwitching = NO;
                           });
        }
        
        
        //         AVURLAsset *asset = [AVURLAsset URLAssetWithURL:mURL options:nil];
        //         //NSArray *requestedKeys = @[@"playable"];
        //         NSArray *requestedKeys = @[@"playable", @"status"];
        //
        //         // Tells the asset to load the values of any of the specified keys that are not already loaded.
        //        [asset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:
        //         ^{
        //             dispatch_async( dispatch_get_main_queue(),
        //                            ^{
        //                                // IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem.
        //                                [self prepareToPlayAsset:asset withKeys:requestedKeys];
        //                            });
        //         }];
        
        
        
        
        /* Make our new AVPlayerItem the AVPlayer's current item. */
        //        if (self.player.currentItem != self.playerItem)
        //        {
        //
        //            /* Replace the player item with a new player item. The item replacement occurs
        //             asynchronously; observe the currentItem property to find out when the
        //             replacement will/did occur
        //
        //             If needed, configure player item here (example: adding outputs, setting text style rules,
        //             selecting media options) before associating it with a player
        //             */
        //
        //            CMTime time = [self getCurrentTime];
        //            dispatch_async(dispatch_get_main_queue(), ^
        //                           {
        //                               [self.player replaceCurrentItemWithPlayerItem:self.playerItem];
        //                               DLog(@"2=====Current URL:%@",[((AVURLAsset *)self.player.currentItem.asset) URL]);
        //
        //                               [self seekToCMTime:time completionHandler:^(BOOL success) {
        //                                   DLog(@"After selection preferredPeakBitRate:%f, indicatedBitrate:%f",self.player.currentItem.preferredPeakBitRate, self.player.currentItem.accessLog.events.lastObject.indicatedBitrate);
        //                                   DLog(@"3=====Current URL:%@",[((AVURLAsset *)self.player.currentItem.asset) URL]);
        //
        //                               }];
        //                           });
        //        }
        
        /*self.selectedBitrate = newBitrate;
         if (newBitrate != nil && self.player.currentItem.preferredPeakBitRate != newBitrate.bitrate) {
         self.player.currentItem.preferredPeakBitRate = newBitrate.bitrate;
         DLog(@"After selecttion preferredPeakBitRate:%f",self.player.currentItem.preferredPeakBitRate);
         }*/
        
    }
}


/**
 * Parse bandwidths from master .m3u8 file and return sorted array of bandwidths in Asse
 */
-(NSArray*)getBandwidthsFromM3u8:(NSString*)m3u8String
{
//    if ([m3u8String isEqualToString:@""] || [m3u8String isEqual:nil]) {
//        return nil;
//    }
    
    //m3u8String = @"http://nmstream2.clearhub.tv/nmdcPFTDemo/20150328/a27b07b0-a7de-4e4a-b84e-70567fb1738b/sec-hls/a27b07b0-a7de-4e4a-b84e-70567fb1738b.m3u8";
//    NSString *fileName = @"bipbop_16x9_variant(1)";
    NSString *fileName = @"test";

    NSString* path = [[NSBundle mainBundle] pathForResource:fileName
                                                     ofType:@"m3u8"];
    
    //Then loading the content into a NSString is even easier.
    
    m3u8String = [NSString stringWithContentsOfFile:path
                                           encoding:NSUTF8StringEncoding
                                              error:NULL];
    
    NSMutableArray *bandwidths = [NSMutableArray new];
    NSArray *m3u8Playlist = [m3u8String componentsSeparatedByString:@"\n"];
    
    if([m3u8String rangeOfString:@"BANDWIDTH="].location != NSNotFound)
    {
        NSMutableArray *bandwidthStrings = [[NSMutableArray alloc] init];
        int index = 1;
        for (NSString *streamString in m3u8Playlist)
        {
            if([streamString rangeOfString:@"BANDWIDTH="].location != NSNotFound)
            {
                [bandwidthStrings addObject:streamString];
                
                NSRange bandwidthRange = [streamString rangeOfString:@"BANDWIDTH="];
                NSString *bandwidthString = [streamString substringFromIndex:bandwidthRange.location + bandwidthRange.length];
                NSString *value;
                NSRange commaRange = [bandwidthString rangeOfString:@","];
                if (NSNotFound == commaRange.location) {
                    value = bandwidthString;
                } else {
                    value = [bandwidthString substringToIndex:commaRange.location];
                }
                NSString *playlistURL = m3u8Playlist[index];
                if (playlistURL) {
                    M3u8Media *media    = [M3u8Media new];
                    media.bitrate       = value.doubleValue;
                    media.playlistUrl   = playlistURL;
                    [bandwidths addObject:media];
                }
            }
            ++index;
        }
        
        NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"bitrate"  ascending:YES];
        NSArray *sortedArray = [bandwidths sortedArrayUsingDescriptors:[NSArray arrayWithObjects:descriptor, nil]];
        //DLog(@"Bandwidths Array:%@",sortedArray);
        for (M3u8Media *media in sortedArray) {
        NSLog(@"Sorted bitrate:%f, playlistUrl:%@",media.bitrate, media.playlistUrl);
        }
        return sortedArray;
    }
    return nil;
}


-(NSArray*)parseM3u8:(NSString*)m3u8String
{
    
    NSString* path = [[NSBundle mainBundle] pathForResource:@"bipbop_16x9_variant(1)"
                                                     ofType:@"m3u8"];
    
    //Then loading the content into a NSString is even easier.
    
     m3u8String = [NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
    
    if ([m3u8String isEqualToString:@""] || [m3u8String isEqual:nil]) {
        return nil;
    }
    else
    {
        NSMutableArray *bandwidths = [NSMutableArray new];
        NSArray *m3u8Playlist = [m3u8String componentsSeparatedByString:@"\n"];
        
        //Parse the least bandwidth M3u8 file to downlod
        if([m3u8String rangeOfString:@"BANDWIDTH"].location != NSNotFound)
        {
            NSMutableArray *bandwidthStrings = [[NSMutableArray alloc] init];
            
            for (NSString *streamString in m3u8Playlist)
            {
                if([streamString rangeOfString:@"BANDWIDTH"].location != NSNotFound)
                {
                    [bandwidthStrings addObject:streamString];
                    
                    NSRange bandwidthRange = [streamString rangeOfString:@"BANDWIDTH="];
                    NSString *bandwidthString = [streamString substringFromIndex:bandwidthRange.location + bandwidthRange.length];
                    NSString *value;
                    NSRange commaRange = [bandwidthString rangeOfString:@","];
                    if (NSNotFound == commaRange.location) {
                        value = bandwidthString;
                    } else {
                        value = [bandwidthString substringToIndex:commaRange.location];
                    }
                    [bandwidths addObject:value];
                }
                
            }
            
            
            NSArray *sortedArray = [bandwidths sortedArrayUsingComparator:^(NSString *str1, NSString *str2) {
                return [str1 compare:str2 options:NSNumericSearch];
            }];
            NSLog(@"sortedArray:%@",sortedArray);
            return sortedArray;

    }
    }
    return nil;
}


- (void)getBitRateFromAVPlayerItem:(AVPlayerItem *)playerItem {
    
    AVPlayerItemAccessLog *accessLog = [playerItem accessLog];

    for (AVPlayerItemAccessLogEvent* event in accessLog.events) {
        NSLog(@"event:%@",event);
        NSLog(@"1========indicatedBitrate:%f",event.indicatedBitrate);
        NSLog(@"1========observedBitrate:%f",event.observedBitrate);

    }
}

- (void)handleAVPlayerAccess:(NSNotification *)notif {
    AVPlayerItemAccessLog *accessLog = [((AVPlayerItem *)notif.object) accessLog];
    AVPlayerItemAccessLogEvent *lastEvent = accessLog.events.lastObject;
    float lastEventNumber = lastEvent.indicatedBitrate;
    if (lastEventNumber != self.lastBitRate) {
        //Here is where you can increment a variable to keep track of the number of times you switch your bit rate.
        NSLog(@"Switch indicatedBitrate from: %f to: %f", self.lastBitRate, lastEventNumber);
        self.lastBitRate = lastEventNumber;
    }
    
    for (AVPlayerItemAccessLogEvent *event in accessLog.events) {
        NSLog(@"indicatedBitrate: %f", event.indicatedBitrate);

    }
}

- (void)stringEqualityTest {
    
    NSString *str1 = @"Track";
    NSString *str2 = @"track";
    
    
    if ([str1 isEqualToString:str2]) {
        NSLog(@"Test one is done");
    }

    if ([str1 caseInsensitiveCompare:str2]) {
        NSLog(@"Test two is done");
    }
    
    if ([str1 compare:str2]) {
        NSLog(@"Test three is done");
    }
    
}

-(NSArray*)getAudioTracks
{
    [self stringEqualityTest];
    NSMutableArray *audioTracks = [NSMutableArray new];
    AVURLAsset *asset            = (AVURLAsset *)self.player.currentItem.asset;
    
    AVMediaSelectionGroup *audio = [asset mediaSelectionGroupForMediaCharacteristic:AVMediaCharacteristicAudible];
    
    for (AVMediaSelectionOption *option in audio.options)
    {
        [audioTracks addObject:[option displayName]];
    }
    
    for (NSUInteger i = 0; i < [[asset tracksWithMediaType:AVMediaTypeAudio] count]; i++)
    {
        AVAssetTrack *option = [asset tracksWithMediaType:AVMediaTypeAudio][i];
        
        NSString *displayName = [self getLanguageNameFromLanguageCode:[option languageCode]];
        
        NSInteger indexObj = [audioTracks indexOfObjectPassingTest:^BOOL(AVMediaSelectionOption *obj, NSUInteger idx, BOOL * _Nonnull stop) {
             NSLog(@"indexObj=========");

            NSLog(@"displayName:%@",[obj displayName]);

            return (![[obj displayName] caseInsensitiveCompare:displayName]);
        }];
        NSLog(@"indexObj:%ld",(long)indexObj);

        
        if([displayName caseInsensitiveCompare:@"Track"]) {
            displayName = [NSString stringWithFormat:@"Track %lu", (unsigned long)i];
        }
        
        if(indexObj == NSNotFound)
        {
            [audioTracks addObject:displayName];
        }
    }
    NSLog(@"Using new logic audioTracks:%@",audioTracks);
    return audioTracks;
}

/**
  * Get Audio track's full language name from language code
  */
-(NSString *)getLanguageNameFromLanguageCode:(NSString *)languageCode
{
    NSString *displayName  = @"Track";
    if (languageCode.length == 0 || [languageCode isEqualToString:@"und"]) {
          return displayName;
        }
     NSLocale *englishLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
     displayName = [[englishLocale displayNameForKey:NSLocaleLanguageCode value:languageCode] capitalizedString];
   
    return displayName;
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
        
        
        for (AVAssetTrack *track in allAudioTracks)
        {
            [self getFullLangugaeNameFromLanguageCode:track.languageCode];
        }

    }
    ////////
    NSLog(@"All Audio Tracks Array: %@", allAudioTracks);
    [self.audioTracks removeAllObjects];
    self.audioTracks = allAudioTracks;
    return allAudioTracks;
}

- (NSString *)getFullLangugaeNameFromLanguageCode:(NSString *)languageCode {
    
    NSLog(@"languageCode:%@",languageCode);
    NSString *displayName = @"";
    if ([languageCode isEqualToString:@"und"]) {
        return displayName;
    }
    NSLocale *englishLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
    displayName             = [[englishLocale
                              displayNameForKey:NSLocaleLanguageCode
                              value:languageCode
                              ] capitalizedString];
    NSLog(@"displayName:%@",displayName);
    
    return displayName;
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
                NSLog(@"languageCode:%@",track.languageCode);
                NSLocale *englishLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en"];
               NSString *displayName = [[englishLocale
                                displayNameForKey:NSLocaleLanguageCode
                                value:track.languageCode
                                ] capitalizedString];
                AVMutableAudioMixInputParameters *audioInputParams = [AVMutableAudioMixInputParameters audioMixInputParameters];
                NSLog(@"displayName:%@",displayName);

                
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
    //[self playMultipleAudioTracks];
    [self switchToNextURL:nil];
    //[self switchToSelectedBitrate:self.bandwidthArray[0]];
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
- (IBAction)scrub:(UISlider *)sender
{
    
}

-(void)generateHLSPreviewImageForSecond:(double)second
{
    CMTime timeSec = CMTimeMakeWithSeconds(second, [self getCurrentTime].timescale);

    CVPixelBufferRef pixelBuffer = [_output copyPixelBufferForItemTime:timeSec itemTimeForDisplay:nil];
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
   /* CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(pixelBuffer),
                                                 CVPixelBufferGetHeight(pixelBuffer))];*/
    
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 100,
                                                 100)];
    
    UIImage *image = [UIImage imageWithCGImage:videoImage];
    //image = [image cropImageToSize:maxSize withProportionDiffLargerThan:IMAGE_PROPORTION_DIFF];
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       _previewImageView.hidden = NO;
                       _previewImageView.image = image;
                   });
    if ( videoImage )
    {
        CGImageRelease(videoImage);
    }
}

-(void)generatePreviewImageForSecond:(double)second
{
    
    AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:self.player.currentItem.asset];
    imageGenerator.appliesPreferredTrackTransform = YES;
    CGSize maxSize = CGSizeMake(100, 100);
    imageGenerator.maximumSize = maxSize;
    
    CMTime timeSec = CMTimeMakeWithSeconds(second, [self getCurrentTime].timescale);
    CGImageRef imgRef = [imageGenerator copyCGImageAtTime:timeSec actualTime:NULL error:nil];
    UIImage *thumbNailImage = [[UIImage alloc] initWithCGImage:imgRef];
    
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       _previewImageView.hidden = NO;
                       _previewImageView.image = thumbNailImage;
                   });
    
}

- (void)onSliderValChanged:(UISlider*)sender forEvent:(UIEvent*)event
{
    
    UITouch *touchEvent = [[event allTouches] anyObject];
    switch (touchEvent.phase) {
        case UITouchPhaseBegan:
            // handle drag began
            NSLog(@"UITouchPhaseBegan");
            break;
        case UITouchPhaseMoved:
            // handle drag moved
            NSLog(@"UITouchPhaseMoved");
            if (sender.value == _scrubTime) {
                return;
            }
            
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
                    _scrubTime = time;
                    ////

                    CGRect _thumbRect = [sender thumbRectForBounds:sender.bounds
                                                         trackRect:[sender trackRectForBounds:sender.bounds]
                                                             value:sender.value];
                    CGRect thumbRect = [self.view convertRect:_thumbRect fromView:sender];
                    CGRect frame    = _previewImageView.frame;
                    frame.origin.x  = (thumbRect.origin.x + thumbRect.size.width/2) - _previewImageView.frame.size.width/2;
                    _previewImageView.frame = frame;
                    if(![[self getCurrentURLFromPlayer].pathExtension caseInsensitiveCompare:@"m3u8"]) {
                        [self generateHLSPreviewImageForSecond:time];
                    } else {
                       [self generatePreviewImageForSecond:time];
                    }
                   
                    /////
                    
                    [self.mPlayer seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                           // _previewImageView.hidden = NO;
                           // _previewImageView.image = _thumbnailsArray[(int)time];
                            isSeeking = NO;
                        });
                    }];
                }
            }
            
            break;
        case UITouchPhaseEnded:
            // handle drag ended
            NSLog(@"UITouchPhaseEnded");
            break;
        default:
            NSLog(@"default");

            break;
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
    
    [self performSelector:@selector(hidePreviewImageView) withObject:nil afterDelay:.5];

}

- (IBAction)endDraging:(UISlider *)sender {
    _previewImageView.hidden = YES;

}

-(void)hidePreviewImageView
{
    _previewImageView.hidden = YES;

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
    [super viewDidLoad];

    [_previewCollectionView registerNib:[UINib nibWithNibName:@"PreviewCell" bundle:nil]
             forCellWithReuseIdentifier:@"Cell"];
    _thumbnailsArray = [[NSMutableArray alloc] initWithCapacity:0];
    _previewCollectionView.hidden = YES;
    [mScrubber addTarget:self action:@selector(onSliderValChanged:forEvent:) forControlEvents:UIControlEventValueChanged];
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAVPlayerAccess:)
                                                 name:AVPlayerItemNewAccessLogEntryNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[self.mPlayer pause];
	
	[super viewWillDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
    self.bandwidthArray = [NSMutableArray new];
    [super viewWillAppear:animated];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

-(NSString*)getCurrentURLFromPlayer {
    return [[((AVURLAsset *)self.player.currentItem.asset) URL] absoluteString];
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
        
        NSDictionary* settings = @{ (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] };
        _output = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:settings];
        [self.player.currentItem addOutput:_output];
        
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
    if (CMTIME_IS_INVALID(self.lastTime)) {
        [self.mScrubber setValue:0.0];
    }
    
    
    
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
               // self.bandwidthArray = [self parseM3u8:nil];
                
                if (CMTIME_IS_VALID(self.lastTime)) {
                    [self seekToCMTime:self.lastTime completionHandler:^(BOOL success) {
                        NSLog(@"After selection preferredPeakBitRate:%f, indicatedBitrate:%f",self.player.currentItem.preferredPeakBitRate, self.player.currentItem.accessLog.events.lastObject.indicatedBitrate);
                        NSLog(@"3=====Current URL:%@",[((AVURLAsset *)self.player.currentItem.asset) URL]);
                        self.lastTime = kCMTimeInvalid;
                        
                    }];
                }
                
                AVURLAsset *asset = (AVURLAsset *)[[self.mPlayer currentItem] asset];

                NSLog(@"URL---%@",asset.URL);
                if (!_thumbnailsArray.count) {
                     [self generateThumbImage];
                }
               
                
                //self.bandwidthArray = [self getBandwidthsFromM3u8:@""];

               // NSLog(@"parseM3u8:%@",self.bandwidthArray);

                 self.selectedTrackIndex = nil;
                [self.audioTracks removeAllObjects];
                [self.selectedAudioTracks removeAllObjects];
                
                //[self getAvailableAudioTracks];
                //[self getAudioTracks];

               // [self getAllMediaCharacteristics];
                //[self checkEnabledAudioTracks];
                
                [self getBitRateFromAVPlayerItem:self.mPlayer.currentItem];
                /*[self getAvailableAudioTracks];
                [self enableAllTracks];
                [self checkEnabledAudioTracks];*/

                //[self getAvailableAudioTracks];
                //[self playSelectedAudioTracks:self.selectedAudioTracks];
                
                
                //==================
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

-(void)generateThumbImage
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
                   {
                       AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc]initWithAsset:self.player.currentItem.asset];
                       imageGenerator.appliesPreferredTrackTransform = YES;
                       CGSize maxSize = CGSizeMake(100, 100);
                       imageGenerator.maximumSize = maxSize;
                       
                       float duration = CMTimeGetSeconds([self playerItemDuration]);
                       
                       for(float i = 0.0; i < duration; ++i)
                       {
                           CMTime timeSec = CMTimeMakeWithSeconds(i, [self getCurrentTime].timescale);
                           CGImageRef imgRef = [imageGenerator copyCGImageAtTime:timeSec actualTime:NULL error:nil];
                           UIImage *thumbNailImage = [[UIImage alloc] initWithCGImage:imgRef];
                           
                           if (thumbNailImage) {
                               [_thumbnailsArray addObject:thumbNailImage];
                           }
                       }
                       
                       dispatch_async(dispatch_get_main_queue(), ^
                                      {
                                          [_previewCollectionView reloadData];
                                          
                                      });
                   });
    
}

#pragma  mark - UICollectionViewDataSource methods

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_thumbnailsArray count];
}

-(UICollectionViewCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    PreviewCell  *cell     = (PreviewCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
    cell.thumbNail.image                = _thumbnailsArray[indexPath.item];
    
    return cell;
}


#pragma  mark - UICollectionViewDelegate methods

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    
}


@end

