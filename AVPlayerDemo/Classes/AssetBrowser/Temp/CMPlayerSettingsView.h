//
//  CMPlayerSettingsView.h
//  CM Library
//
//  Created by dipak on 5/6/16.
//  Copyright © 2016 Prime Focus Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>

/**
 *  CMPlayer Setting Category Name
 */
typedef NS_ENUM (NSInteger, CMPlayerSettingCategoryName) {
    CMAutioTrack,
    CMBitrate
};

@protocol CMPlayerSettingDelegate <NSObject>

-(void)selectedPlayerOption:(id)option andCategoryName:(CMPlayerSettingCategoryName)categoryName;
-(void)hidePlayerSettingsView;

@end

@interface CMPlayerSettingsView : UIView

@property (nonatomic, strong) id<CMPlayerSettingDelegate> playerSettingDelegate;

@end
