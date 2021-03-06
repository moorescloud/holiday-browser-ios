//
//  HDYViewController.m
//  HolidayFinder
//
//  Created by Jon Manning on 3/10/13.
//  Copyright (c) 2013 Secret Lab. All rights reserved.
//

#import "HDYViewController.h"
#import "ServerBrowser.h"
#import "Reachability.h"
#import "GCDAsyncSocket.h"

#define SERVICE_TYPE @"_iotas._tcp"
#define HELP_URL @"http://support.moorescloud.com/ios-browser-holiday/"

@interface HolidayCell : UICollectionViewCell
@property (strong) IBOutlet UILabel* label;

@end

@implementation HolidayCell

@end

@interface HDYViewController () <ServerBrowserDelegate, UICollectionViewDataSource, UICollectionViewDelegate> {
    ServerBrowser* _browser;
    BOOL _isShowingHolidays;
    Reachability* _reachability;
    NSTimer* _reachabilityTimer;
}

@property (strong, nonatomic) IBOutlet UICollectionView *holidayCollectionView;
@property (strong, nonatomic) IBOutlet UILabel *connectToWifiLabel;

@property (strong, nonatomic) IBOutlet UIView *searchingView;
@property (strong, nonatomic) IBOutlet UILabel *searchingTakingTooLongView;


@end

@implementation HDYViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Do any additional setup after loading the view, typically from a nib.
    
    _reachability = [Reachability reachabilityForLocalWiFi];
    [_reachability startNotifier];
    
    [self beginSearching];
    
    _reachabilityTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateReachability:) userInfo:nil repeats:YES];
    
    self.connectToWifiLabel.alpha = 0.0;
    
    
}

- (void) updateReachability:(NSTimer*) timer {
    
    BOOL hidden = (_reachability.currentReachabilityStatus == ReachableViaWiFi);

    
    [UIView animateWithDuration:0.25 animations:^{
        if (hidden) {
            self.connectToWifiLabel.alpha = 0.0;
        } else {
            self.connectToWifiLabel.alpha = 1.0;
        }
    }];
}

-(UIStatusBarStyle)preferredStatusBarStyle{
    return UIStatusBarStyleLightContent;
}

- (void)viewDidAppear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationWillResignActive:(NSNotification*)notification {
    _browser = nil;
    self.holidayCollectionView.alpha = 0.0;
    self.searchingView.alpha = 0.0;
    [self.holidayCollectionView reloadData];
    
}

- (NSUInteger)supportedInterfaceOrientations {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    }
    return UIInterfaceOrientationMaskPortrait;
}

- (void) applicationDidBecomeActive:(NSNotification*)notification {
    
    [self beginSearching];
}

- (void) beginSearching {
    
    _browser = [[ServerBrowser alloc] initWithServerType:SERVICE_TYPE port:-1];
    _browser.delegate = self;
    
    _isShowingHolidays = NO;
	
    self.searchingView.alpha = 0.0;
    self.searchingTakingTooLongView.hidden = YES;
    
    [UIView animateWithDuration:0.25 animations:^{
        self.holidayCollectionView.alpha = 0.0;
        self.searchingView.alpha = 1.0;
    } completion:^(BOOL finished) {
        
    }];
    
    double delayInSeconds = 6.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (_browser.discoveredServers.count <= 0)
            self.searchingTakingTooLongView.hidden = NO;
    });
}


- (void) stopSearching:(NSUInteger)numberOfServicesFound {
    
    if (_isShowingHolidays == YES)
        return;
    
    _isShowingHolidays = YES;
    
    [UIView animateWithDuration:0.1 animations:^{
        self.searchingView.alpha = 0.0;
        self.holidayCollectionView.alpha = 1.0;
    }];
    
    CAKeyframeAnimation* keyframe = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
    
    [keyframe setValues:@[@0.8, @1.1, @1.0]];
    [keyframe setKeyTimes:@[@0.0, @0.9, @1.0]];
    
    [keyframe setDuration:0.25];
    
    [self.holidayCollectionView.layer addAnimation:keyframe forKey:@"pop"];
    
    
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _browser.discoveredServers.count;
}

- (UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    HolidayCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"HolidayCell" forIndexPath:indexPath];
    
    NSNetService* service = [_browser.discoveredServers objectAtIndex:indexPath.item];
    NSString* computerName = service.name;
    
    cell.label.text = computerName;
    
    return cell;
}

- (IBAction)showHelp:(id)sender {
    NSURL* helpURL = [NSURL URLWithString:HELP_URL];
    
    [[UIApplication sharedApplication] openURL:helpURL];
}

- (void)serverBrowserFoundService:(NSNetService *)service {
    
    int index = [_browser.discoveredServers indexOfObject:service];
    
    [self.holidayCollectionView insertItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:index inSection:0]]];
    
    [self stopSearching:_browser.discoveredServers.count];
}

- (void)serverBrowserLostService:(NSNetService *)service index:(NSUInteger)index {
    
    [self.holidayCollectionView deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:index inSection:0]]];
    
    if (_browser.discoveredServers.count <= 0) {
        [self beginSearching];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    NSNetService* host = [_browser.discoveredServers objectAtIndex:indexPath.item];
    
    if (host.addresses.count <= 0) {
        NSLog(@"Selected holiday (%@) had no addresses..", host.hostName);
        return;
    }
    
    NSData* address = [host.addresses objectAtIndex:0];
    
    NSString* addressString = [GCDAsyncSocket hostFromAddress:address];
    NSString* portString = [NSString stringWithFormat:@"%i", [GCDAsyncSocket portFromAddress:address]];
    
    NSString* urlString = [NSString stringWithFormat:@"http://%@:%@/", addressString, portString];
    
    NSURL* url = [NSURL URLWithString:urlString];
    
    if (url)
        [[UIApplication sharedApplication] openURL:url];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
