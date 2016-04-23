//
//  PopViewController.h
//  AVPlayerDemo
//
//  Created by Deepak on 23/04/16.
//
//

#import <UIKit/UIKit.h>

@interface PopViewController : UIViewController

@property (nonatomic, strong) NSArray* audioTracks;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end
