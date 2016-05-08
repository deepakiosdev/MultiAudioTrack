//
//  CMPlayerController.h
//  CM Library
//
//  Created by Saravana Kumar on 11/24/15.
//  Copyright © 2015 Prime Focus Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CBCScreenerPreviewInterface.h"
#import "CMPlayerDelegate.h"
#import "CBCScreenerPreviewSegment.h"
#import "CBCScreenerPreviewData.h"
#import "CBCScreenerPreviewClip.h"
#import "CMQueuePlayer.h"
#import "CMPlayerControlsController.h"
#import "CMWaterMarkView.h"
#import "CMPlayerSettingsView.h"

#define ON_SCREEN_PLAYER    1
#define OFF_SCREEN_PLAYER   0

#define TOP_LEFT                @"TOP_LEFT"
#define TOP_RIGHT               @"TOP_RIGHT"
#define CENTER                  @"CENTER"
#define BOTTOM_LEFT             @"BOTTOM_LEFT"
#define BOTTOM_RIGHT            @"BOTTOM_RIGHT"
#define CENTER_LEFT             @"LEFT"
#define CENTER_RIGHT            @"RIGHT"
#define CENTER_BOTTOM           @"BOTTOM_CENTER"
#define CENTER_TOP              @"TOP_CENTER"

@interface CMPlayerController : UIViewController

@property (nonatomic, weak) IBOutlet CMQueuePlayer              *offScreenPlayer;
@property (nonatomic, weak) IBOutlet CMQueuePlayer              *onScreenPlayer;
@property (nonatomic, weak) IBOutlet UIView                     *headerView;
@property (nonatomic, weak) IBOutlet UIView                     *waterMarkHolderView;
@property (nonatomic, weak) IBOutlet UIView                     *settingsHolderView;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView    *progressInd;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint         *waterMarkHolderX;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint         *waterMarkHolderY;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint         *waterMarkWidth;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint         *waterMarkHeight;


@property (nonatomic, weak) id <CMPlayerDelegate>               delegate;
@property (nonatomic, strong) CBCScreenerPreviewInterface       *interface;
@property (nonatomic, strong) CBCScreenerPreviewData            *dataSource;
@property (nonatomic, strong) CMWaterMarkView                   *watermarkView;
@property (nonatomic, strong) CMPlayerSettingsView              *playerSettingsView;

@property (nonatomic, assign) NSInteger                         selectedClip;
@property (nonatomic, assign) NSInteger                         prevClip;
@property (nonatomic, assign) NSInteger                         playersReady;
@property (nonatomic, assign) NSInteger                         activePlayer;
@property (nonatomic, assign) NSInteger                         currentSegment;

@property (nonatomic, assign) CGFloat                           seekedSeconds;
@property (nonatomic, assign) CGFloat                           reelPlayed;
@property (nonatomic, assign) CGFloat                           totalReelTime;

@property (nonatomic, assign) BOOL                              isReelMode;
@property (nonatomic, assign) BOOL                              playerStopped;
@property (nonatomic, assign) BOOL                              advancedPlayer;
@property (nonatomic, assign) BOOL                              isPlayerInitialised;
@property (nonatomic, assign) BOOL                              autoPause;
@property (nonatomic, assign) BOOL                              autoPlay;
@property (nonatomic, assign) BOOL                              isSeeked;
@property (nonatomic, assign) BOOL                              fromReel;
@property (nonatomic, assign) BOOL                              isFullscreen;
@property (nonatomic, assign) BOOL                              isPlaylistClipSequenceMode; // To play selected clips of playlist in sequence..
@property (nonatomic, assign) BOOL                              isOnScreenPlayerInitialised; // To check which player is initialised.
@property (nonatomic, assign) BOOL                              isOffScreenPlayerInitialised; // To check which player is initialised.

@property (nonatomic, strong) NSString                          *segmentStartTime;
@property (nonatomic, strong) NSString                          *segmentEndTime;
@property (nonatomic, strong) NSString                          *segmentSwapTime;

-(CGFloat)calculateDuration;
-(void)playerReadyToPlay;
-(void)defaultToClip:(NSInteger)index;
-(void)initialiseReelModeFromIndex:(NSInteger)index;
-(void)playActivePlayer;
-(void)swapPlayers;
-(void)pausePlayers;
-(void)stopPlayers;
-(void)updateProgress:(CGFloat)progress withFrame:(NSInteger)frame;
-(void)updateTimelineForClipInReel;
-(void)updatePauseIconForButton;

-(void)reelPlaybackFinished;
-(void)findSeekInReel:(CGFloat)seconds;
-(void)playFromSeekedTime:(CGFloat)seekedTime;
-(void)seekToTime:(CGFloat)time withAutoPlay:(BOOL)autoPlay;
-(void)seekToTimeWithPosition:(CGFloat)position withAutoPlay:(BOOL)autoPlay;
-(void)adjustPlayerSpeed:(CGFloat)playbackRate;

-(NSArray*)getNextTimeSegment:(NSInteger)segment forClip:(NSInteger)clip;
-(NSArray*)getCurrentTimeSegment;
-(CGFloat)getReelTimeFromIndex:(NSInteger)index;

-(void)setIsFullScreen:(BOOL)isFullscreen;

-(void)createSegment;
-(void)cancelSegment;
-(void)initSegment;
-(void)pointSegment;

-(void)showAnnotationComment:(CGFloat)timeCode;
-(void)showRangeComment:(CGFloat)timeCodeIn andTimeCodeEnd:(CGFloat)timeCodeEnd;

//-(void)waterMarkSecureDataAndDisplay:(id)waterMarkData;
//-(void)setWaterMarkPosition:(NSString*)position;
//-(void)setWaterMarkSizeaccordingtoValue:(NSString*)position;
-(void)playScene:(NSString*)timeIn andOut:(NSString*)timeOut;
//-(void)initWithSeekInPlaylistClipForPlayer:(NSInteger)player;

@end
