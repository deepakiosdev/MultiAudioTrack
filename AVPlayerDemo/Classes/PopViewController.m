//
//  PopViewController.m
//  AVPlayerDemo
//
//  Created by Deepak on 23/04/16.
//
//

#import <AVFoundation/AVFoundation.h>

#import "PopViewController.h"

@interface PopViewController ()

@end

@implementation PopViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // add touch recogniser to dismiss this controller
   // UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(dismissMe)];
    //[self.view addGestureRecognizer:tap];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)dismissMe {
    
    NSLog(@"Popover was dismissed with internal tap");
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark Table view Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.audioTracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    cell.accessoryType  = UITableViewCellAccessoryCheckmark;
    
    id audioTrack = [self.audioTracks objectAtIndex:indexPath.row];
    if ([audioTrack isKindOfClass:[AVAssetTrack class]]) {
        cell.textLabel.text = [NSString stringWithFormat:@"Track %ld",((long)indexPath.row + 1)];

    } else if ([audioTrack isKindOfClass:[AVMediaSelectionOption class]]){
        cell.textLabel.text = ((AVMediaSelectionOption*)[self.audioTracks objectAtIndex:indexPath.row]).displayName;

    } else {
        double bitrate = ((NSNumber *)audioTrack).doubleValue;

        cell.textLabel.text = [NSString stringWithFormat:@"%f",bitrate];
    }
    
    
    return cell;
}

#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *track = [self.audioTracks objectAtIndex:indexPath.row];
    NSLog(@"Selected Track:%@",track);
}


@end
