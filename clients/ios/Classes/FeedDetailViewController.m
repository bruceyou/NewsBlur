//
//  FeedDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FeedDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "FeedDetailTableCell.h"
#import "ASIFormDataRequest.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "NSString+HTML.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "JSON.h"
#import "StringHelper.h"
#import "Utilities.h"
#import "UIBarButtonItem+WEPopover.h"
#import "WEPopoverController.h"
#import "UIBarButtonItem+Image.h"
#import "FeedDetailMenuViewController.h"
#import "NBNotifier.h"
#import "NBLoadingCell.h"
#import "FMDatabase.h"
#import "NBBarButtonItem.h"
#import "UIImage+Resize.h"
#import "TMCache.h"
#import "AFImageRequestOperation.h"
#import "DashboardViewController.h"
#import "StoriesCollection.h"

#define kTableViewRowHeight 38;
#define kTableViewRiverRowHeight 60;
#define kTableViewShortRowDifference 15;
#define kMarkReadActionSheet 1;
#define kSettingsActionSheet 2;

@interface FeedDetailViewController ()

@property (nonatomic) UIActionSheet* actionSheet_;  // add this line

@end

@implementation FeedDetailViewController

@synthesize popoverController;
@synthesize storyTitlesTable, feedMarkReadButton;
@synthesize settingsBarButton;
@synthesize separatorBarButton;
@synthesize titleImageBarButton;
@synthesize spacerBarButton, spacer2BarButton;
@synthesize appDelegate;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize actionSheet_;
@synthesize finishedAnimatingIn;
@synthesize notifier;
@synthesize isOnline;
@synthesize isShowingFetching;
@synthesize isDashboardModule;
@synthesize storiesCollection;
@synthesize showContentPreview;
@synthesize showImagePreview;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}
 
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(preferredContentSizeChanged:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];

    popoverClass = [WEPopoverController class];
    self.storyTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    
    spacerBarButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacerBarButton.width = 0;
    spacer2BarButton = [[UIBarButtonItem alloc]
                        initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacer2BarButton.width = 0;
    
    UIImage *separatorImage = [UIImage imageNamed:@"bar-separator.png"];
    separatorBarButton = [UIBarButtonItem barItemWithImage:separatorImage target:nil action:nil];
    [separatorBarButton setEnabled:NO];
    
    UIImage *settingsImage = [UIImage imageNamed:@"nav_icn_settings.png"];
    settingsBarButton = [UIBarButtonItem barItemWithImage:settingsImage target:self action:@selector(doOpenSettingsActionSheet:)];

    UIImage *markreadImage = [UIImage imageNamed:@"markread.png"];
    feedMarkReadButton = [UIBarButtonItem barItemWithImage:markreadImage target:self action:@selector(doOpenMarkReadActionSheet:)];

    titleImageBarButton = [UIBarButtonItem alloc];

    UILongPressGestureRecognizer *longpress = [[UILongPressGestureRecognizer alloc]
                                               initWithTarget:self action:@selector(handleLongPress:)];
    longpress.minimumPressDuration = 1.0;
    longpress.delegate = self;
    [self.storyTitlesTable addGestureRecognizer:longpress];

    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc]
                                                initWithTarget:self action:nil];
    doubleTapGesture.numberOfTapsRequired = 2;
    [self.storyTitlesTable addGestureRecognizer:doubleTapGesture];
    doubleTapGesture.delegate = self;

    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching stories..." inView:self.view];
    [self.view addSubview:self.notifier];
}


- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    //    NSLog(@"Gesture double tap: %ld - %ld", touch.tapCount, gestureRecognizer.state);
    inDoubleTap = (touch.tapCount == 2);
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    //    NSLog(@"Gesture should multiple? %ld (%ld) - %d", gestureRecognizer.state, UIGestureRecognizerStateEnded, inDoubleTap);
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded && inDoubleTap) {
        CGPoint p = [gestureRecognizer locationInView:self.storyTitlesTable];
        NSIndexPath *indexPath = [self.storyTitlesTable indexPathForRowAtPoint:p];
        NSDictionary *story = [self getStoryAtRow:indexPath.row];
        if (!story) return YES;
        NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
        BOOL openOriginal = NO;
        BOOL showText = NO;
        BOOL markUnread = NO;
        BOOL saveStory = NO;
        if (gestureRecognizer.numberOfTouches == 2) {
            NSString *twoFingerTap = [preferences stringForKey:@"two_finger_double_tap"];
            if ([twoFingerTap isEqualToString:@"open_original_story"]) {
                openOriginal = YES;
            } else if ([twoFingerTap isEqualToString:@"show_original_text"]) {
                showText = YES;
            } else if ([twoFingerTap isEqualToString:@"mark_unread"]) {
                markUnread = YES;
            } else if ([twoFingerTap isEqualToString:@"save_story"]) {
                saveStory = YES;
            }
        } else {
            NSString *doubleTap = [preferences stringForKey:@"double_tap_story"];
            if ([doubleTap isEqualToString:@"open_original_story"]) {
                openOriginal = YES;
            } else if ([doubleTap isEqualToString:@"show_original_text"]) {
                showText = YES;
            } else if ([doubleTap isEqualToString:@"mark_unread"]) {
                markUnread = YES;
            } else if ([doubleTap isEqualToString:@"save_story"]) {
                saveStory = YES;
            }
        }
        if (openOriginal) {
            [appDelegate
             showOriginalStory:[NSURL URLWithString:[story objectForKey:@"story_permalink"]]];
        } else if (showText) {
            [appDelegate.storyDetailViewController fetchTextView];
        } else if (markUnread) {
            [storiesCollection toggleStoryUnread:story];
            [self reloadData];
        } else if (saveStory) {
            [storiesCollection toggleStorySaved:story];
            [self reloadData];
        }
        inDoubleTap = NO;
    }
    return YES;
}

- (void)preferredContentSizeChanged:(NSNotification *)aNotification {
    [self.storyTitlesTable reloadData];
}

- (void)reloadData {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    self.showContentPreview = [userPreferences boolForKey:@"story_list_preview_description"];
    self.showImagePreview = [userPreferences boolForKey:@"story_list_preview_images"];

    [self.storyTitlesTable reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                         duration:(NSTimeInterval)duration {
    [self setUserAvatarLayout:toInterfaceOrientation];
    [self.notifier setNeedsLayout];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self checkScroll];
    NSLog(@"Feed detail did re-orient.");
    
}

- (void)viewWillAppear:(BOOL)animated {
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];

    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self setUserAvatarLayout:orientation];
    self.finishedAnimatingIn = NO;
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    self.showContentPreview = [userPreferences boolForKey:@"story_list_preview_description"];
    self.showImagePreview = [userPreferences boolForKey:@"story_list_preview_images"];
    
    // set right avatar title image
    spacerBarButton.width = 0;
    spacer2BarButton.width = 0;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        spacerBarButton.width = -6;
        spacer2BarButton.width = 10;
    }
    if (storiesCollection.isSocialView) {
        spacerBarButton.width = -6;
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [storiesCollection.activeFeed objectForKey:@"id"]];
        UIImage *titleImage  = [appDelegate getFavicon:feedIdStr isSocial:YES];
        titleImage = [Utilities roundCorneredImage:titleImage radius:6];
        [((UIButton *)titleImageBarButton.customView).imageView removeFromSuperview];
        titleImageBarButton = [UIBarButtonItem barItemWithImage:titleImage
                                                         target:self
                                                         action:@selector(showUserProfile)];
        titleImageBarButton.customView.frame = CGRectMake(0, 0, 32, 32);
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                   spacerBarButton,
                                                   titleImageBarButton,
                                                   spacer2BarButton,
                                                   separatorBarButton,
                                                   feedMarkReadButton, nil];
    } else {
        self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:
                                                   spacerBarButton,
                                                   settingsBarButton,
                                                   spacer2BarButton,
                                                   separatorBarButton,
                                                   feedMarkReadButton,
                                                   nil];
    }
    
    // set center title
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone &&
        !self.navigationItem.titleView) {
        self.navigationItem.titleView = [appDelegate makeFeedTitle:storiesCollection.activeFeed];
    }
    
    if ([storiesCollection.activeFeedStories count]) {
        [self.storyTitlesTable reloadData];
    }
    
    appDelegate.originalStoryCount = (int)[appDelegate unreadCount];
    
    if ((storiesCollection.isSocialRiverView ||
         storiesCollection.isSocialView ||
         storiesCollection.isSavedView)) {
        settingsBarButton.enabled = NO;
    } else {
        settingsBarButton.enabled = YES;
    }
    
    if (storiesCollection.isSocialRiverView ||
        storiesCollection.isSavedView) {
        feedMarkReadButton.enabled = NO;
    } else {
        feedMarkReadButton.enabled = YES;
    }
        
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self fadeSelectedCell];
    }
    
    [self.notifier setNeedsLayout];
    [appDelegate hideShareView:YES];
    
    if (!isDashboardModule &&
        UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
        (appDelegate.masterContainerViewController.storyTitlesOnLeft ||
         !UIInterfaceOrientationIsPortrait(orientation)) &&
        !self.isMovingFromParentViewController &&
        !appDelegate.masterContainerViewController.interactiveOriginalTransition) {
        [appDelegate.masterContainerViewController transitionToFeedDetail:NO];
    }

    [self testForTryFeed];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (appDelegate.inStoryDetail && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        appDelegate.inStoryDetail = NO;
        [appDelegate.storyPageControl resetPages];
        [self checkScroll];
    }
    
    self.finishedAnimatingIn = YES;
    if ([storiesCollection.activeFeedStories count] ||
        self.isDashboardModule) {
        [self.storyTitlesTable reloadData];
    }
    NSLog(@"Detail did appear");
    [self.notifier setNeedsLayout];
}

- (void)viewDidDisappear:(BOOL)animated {
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
        self.isMovingToParentViewController &&
        (appDelegate.masterContainerViewController.storyTitlesOnLeft ||
         !UIInterfaceOrientationIsPortrait(orientation))) {
        [appDelegate.masterContainerViewController transitionFromFeedDetail:NO];
    }
}

- (void)fadeSelectedCell {
    [self fadeSelectedCell:YES];
}

- (void)fadeSelectedCell:(BOOL)deselect {
    [self.storyTitlesTable reloadData];
    NSInteger location = storiesCollection.locationOfActiveStory;
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:location inSection:0];
    
    if (indexPath && location >= 0) {
        [self.storyTitlesTable selectRowAtIndexPath:indexPath
                                           animated:NO
                                     scrollPosition:UITableViewScrollPositionMiddle];
        if (deselect) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,  0.4 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^(void) {
                [self.storyTitlesTable deselectRowAtIndexPath:indexPath
                                                     animated:YES];
            });
        }
    }
    
    if (deselect) {
        appDelegate.activeStory = nil;
    }
}

- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && storiesCollection.isSocialView) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            NBBarButtonItem *avatar = (NBBarButtonItem *)titleImageBarButton.customView;
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(32, 32);
            avatar.frame = buttonFrame;
        } else {
            NBBarButtonItem *avatar = (NBBarButtonItem *)titleImageBarButton.customView;
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(28, 28);
            avatar.frame = buttonFrame;
        }
    }
}

#pragma mark -
#pragma mark Initialization

- (void)resetFeedDetail {
    appDelegate.hasLoadedFeedDetail = NO;
    self.navigationItem.titleView = nil;
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.isOnline = YES;
    self.isShowingFetching = NO;
//    self.feedPage = 1;
    appDelegate.activeStory = nil;
    if (!self.isDashboardModule) {
        [appDelegate.storyPageControl resetPages];
    }
    [self.notifier hideIn:0];
    [self cancelRequests];
    [self beginOfflineTimer];
    [appDelegate.cacheImagesOperationQueue cancelAllOperations];
}

- (void)reloadPage {
    [self resetFeedDetail];

    [storiesCollection setStories:nil];
    storiesCollection.storyCount = 0;
    storiesCollection.activeClassifiers = [NSMutableDictionary dictionary];
    storiesCollection.activePopularAuthors = [NSArray array];
    storiesCollection.activePopularTags = [NSArray array];
        
    if (storiesCollection.isRiverView) {
        [self fetchRiverPage:1 withCallback:nil];
    } else {
        [self fetchFeedDetail:1 withCallback:nil];
    }

    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)beginOfflineTimer {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (self.isDashboardModule ? 3 : 1) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!storiesCollection.storyLocationsCount && !self.pageFinished &&
            storiesCollection.feedPage == 1 && self.isOnline) {
            self.isShowingFetching = YES;
            self.isOnline = NO;
            [self showLoadingNotifier];
            [self loadOfflineStories];
        }
    });
}

- (void)cacheStoryImages:(NSArray *)storyImageUrls {
    NSBlockOperation *cacheImagesOperation = [NSBlockOperation blockOperationWithBlock:^{
        for (NSString *storyImageUrl in storyImageUrls) {
//            NSLog(@"Fetching image: %@", storyImageUrl);
            NSMutableURLRequest *request = [NSMutableURLRequest
                                            requestWithURL:[NSURL URLWithString:storyImageUrl]];
            [request addValue:@"image/*" forHTTPHeaderField:@"Accept"];
            [request setTimeoutInterval:5.0];
            AFImageRequestOperation *requestOperation = [[AFImageRequestOperation alloc]
                                                         initWithRequest:request];
            [requestOperation start];
            [requestOperation waitUntilFinished];
            
            UIImage *image = requestOperation.responseImage;
            
            if (!image || image.size.height < 50 || image.size.width < 50) {
                [appDelegate.cachedStoryImages setObject:[NSNull null]
                                                  forKey:storyImageUrl];
                continue;
            }
            
            CGSize maxImageSize = CGSizeMake(300, 300);
            image = [image imageByScalingAndCroppingForSize:maxImageSize];
            [appDelegate.cachedStoryImages setObject:image
                                              forKey:storyImageUrl];
            if (self.isDashboardModule) {
                [appDelegate.dashboardViewController.storiesModule
                 showStoryImage:storyImageUrl];
            } else {
                [appDelegate.feedDetailViewController
                 showStoryImage:storyImageUrl];
            }
        }
    }];
    [cacheImagesOperation setThreadPriority:0];
    [cacheImagesOperation setQueuePriority:NSOperationQueuePriorityVeryLow];
    [appDelegate.cacheImagesOperationQueue addOperation:cacheImagesOperation];
}

- (void)showStoryImage:(NSString *)imageUrl {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isDashboardModule &&
            appDelegate.navigationController.visibleViewController == appDelegate.feedDetailViewController) {
            return;
        }
        
        for (FeedDetailTableCell *cell in [self.storyTitlesTable visibleCells]) {
            if (![cell isKindOfClass:[FeedDetailTableCell class]]) return;
            if ([cell.storyImageUrl isEqualToString:imageUrl]) {
                NSIndexPath *indexPath = [self.storyTitlesTable indexPathForCell:cell];
//                NSLog(@"Reloading cell (dashboard? %d): %@ (%ld)", self.isDashboardModule, cell.storyTitle, (long)indexPath.row);
                [self.storyTitlesTable beginUpdates];
                [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                             withRowAnimation:UITableViewRowAnimationNone];
                [self.storyTitlesTable endUpdates];
                break;
            }
        }
    });
}

#pragma mark -
#pragma mark Regular and Social Feeds

- (void)fetchNextPage:(void(^)())callback {
    if (storiesCollection.isRiverView) {
        [self fetchRiverPage:storiesCollection.feedPage+1 withCallback:callback];
    } else {
        [self fetchFeedDetail:storiesCollection.feedPage+1 withCallback:callback];
    }
}

- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback {
    NSString *theFeedDetailURL;

    if (!storiesCollection.activeFeed) return;
    
    if (!callback && (self.pageFetching || self.pageFinished)) return;
    
    storiesCollection.feedPage = page;
    self.pageFetching = YES;
    NSInteger storyCount = storiesCollection.storyCount;
    if (storyCount == 0) {
        [self.storyTitlesTable reloadData];
        [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    }
    if (storiesCollection.feedPage == 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [appDelegate.database inDatabase:^(FMDatabase *db) {
                [appDelegate prepareActiveCachedImages:db];
            }];
        });
    }
    
    if (!self.isOnline) {
        [self loadOfflineStories];
        if (!self.isShowingFetching) {
            [self showOfflineNotifier];
        }
        return;
    } else {
        [self.notifier hide];
    }
    
    if (storiesCollection.isSocialView) {
        theFeedDetailURL = [NSString stringWithFormat:@"%@/social/stories/%@/?page=%d",
                            NEWSBLUR_URL,
                            [storiesCollection.activeFeed objectForKey:@"user_id"],
                            storiesCollection.feedPage];
    } else if (storiesCollection.isSavedView) {
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/starred_stories/?page=%d&v=2&tag=%@",
                            NEWSBLUR_URL,
                            storiesCollection.feedPage,
                            [storiesCollection.activeSavedStoryTag urlEncode]];
    } else {
        theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/feed/%@/?page=%d",
                            NEWSBLUR_URL,
                            [storiesCollection.activeFeed objectForKey:@"id"],
                            storiesCollection.feedPage];
    }
    
    theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                        theFeedDetailURL,
                        [storiesCollection activeOrder]];
    theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                        theFeedDetailURL,
                        [storiesCollection activeReadFilter]];
    
    [self cancelRequests];
    __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setUserInfo:@{@"feedPage": [NSNumber numberWithInt:storiesCollection.feedPage]}];
    [request setFailedBlock:^(void) {
        NSLog(@"in failed block %@", request);
        if (request.isCancelled) {
            NSLog(@"Cancelled");
            return;
        } else {
            self.isOnline = NO;
            storiesCollection.feedPage = 1;
            [self loadOfflineStories];
            [self showOfflineNotifier];
        }
        [self.storyTitlesTable reloadData];
    }];
    [request setCompletionBlock:^(void) {
        if (!storiesCollection.activeFeed) return;
        [self finishedLoadingFeed:request];
        if (callback) {
            callback();
        }
    }];
    [request setTimeOutSeconds:30];
    [request setTag:[[[storiesCollection activeFeed] objectForKey:@"id"] intValue]];
    [request startAsynchronous];
    [requests addObject:request];
}

- (void)loadOfflineStories {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
    [appDelegate.database inDatabase:^(FMDatabase *db) {
        NSArray *feedIds;
        NSInteger limit = 12;
        NSInteger offset = (storiesCollection.feedPage - 1) * limit;
        
        if (storiesCollection.isRiverView) {
            feedIds = storiesCollection.activeFolderFeeds;
        } else if (storiesCollection.activeFeed) {
            feedIds = @[[storiesCollection.activeFeed objectForKey:@"id"]];
        } else {
            return;
        }
        
        NSString *orderSql;
        if ([storiesCollection.activeOrder isEqualToString:@"oldest"]) {
            orderSql = @"ASC";
        } else {
            orderSql = @"DESC";
        }
        NSString *readFilterSql;
        if ([storiesCollection.activeReadFilter isEqualToString:@"unread"]) {
            readFilterSql = @"INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash";
        } else {
            readFilterSql = @"";
        }
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM stories s %@ WHERE s.story_feed_id IN (%@) ORDER BY s.story_timestamp %@ LIMIT %ld OFFSET %ld",
                         readFilterSql,
                         [feedIds componentsJoinedByString:@","],
                         orderSql,
                         (long)limit, (long)offset];
        FMResultSet *cursor = [db executeQuery:sql];
        NSMutableArray *offlineStories = [NSMutableArray array];
        
        while ([cursor next]) {
            NSDictionary *story = [cursor resultDictionary];
            [offlineStories addObject:[NSJSONSerialization
                                       JSONObjectWithData:[[story objectForKey:@"story_json"]
                                                           dataUsingEncoding:NSUTF8StringEncoding]
                                       options:nil error:nil]];
        }
        [cursor close];
        
        if ([storiesCollection.activeReadFilter isEqualToString:@"all"]) {
            NSString *unreadHashSql = [NSString stringWithFormat:@"SELECT s.story_hash FROM stories s INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash WHERE s.story_feed_id IN (%@)",
                             [feedIds componentsJoinedByString:@","]];
            FMResultSet *unreadHashCursor = [db executeQuery:unreadHashSql];
            NSMutableDictionary *unreadStoryHashes;
            if (storiesCollection.feedPage == 1) {
                unreadStoryHashes = [NSMutableDictionary dictionary];
            } else {
                unreadStoryHashes = appDelegate.unreadStoryHashes;
            }
            while ([unreadHashCursor next]) {
                [unreadStoryHashes setObject:[NSNumber numberWithBool:YES] forKey:[unreadHashCursor objectForColumnName:@"story_hash"]];
            }
            appDelegate.unreadStoryHashes = unreadStoryHashes;
            [unreadHashCursor close];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.isOnline) {
                NSLog(@"Online before offline rendered. Tossing offline stories.");
                return;
            }
            if (![offlineStories count]) {
                self.pageFinished = YES;
                [self.storyTitlesTable reloadData];
            } else {
                [self renderStories:offlineStories];
            }
            if (!self.isShowingFetching) {
                [self showOfflineNotifier];
            }
        });
    }];
    });
}

- (void)showOfflineNotifier {
//    [self.notifier hide];
    self.notifier.style = NBOfflineStyle;
    self.notifier.title = @"Offline";
    [self.notifier show];
}

- (void)showLoadingNotifier {
    [self.notifier hide];
    self.notifier.style = NBLoadingStyle;
    self.notifier.title = @"Fetching recent stories...";
    [self.notifier show];
}

#pragma mark -
#pragma mark River of News

- (void)fetchRiver {
    [self fetchRiverPage:storiesCollection.feedPage withCallback:nil];
}

- (void)fetchRiverPage:(int)page withCallback:(void(^)())callback {
    if (self.pageFetching || self.pageFinished) return;
//    NSLog(@"Fetching River in storiesCollection (pg. %ld): %@", (long)page, storiesCollection);

    storiesCollection.feedPage = page;
    self.pageFetching = YES;
    NSInteger storyCount = storiesCollection.storyCount;
    if (storyCount == 0) {
        [self.storyTitlesTable reloadData];
        [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
//            [self.notifier initWithTitle:@"Loading more..." inView:self.view];

    }
    
    if (storiesCollection.feedPage == 1) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void) {
            [appDelegate.database inDatabase:^(FMDatabase *db) {
                [appDelegate prepareActiveCachedImages:db];
            }];
        });
    }
    
    if (!self.isOnline) {
        [self loadOfflineStories];
        return;
    } else {
        [self.notifier hide];
    }
    
    NSString *theFeedDetailURL;
    
    if (storiesCollection.isSocialRiverView) {
        if ([storiesCollection.activeFolder isEqualToString:@"river_global"]) {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"%@/social/river_stories/?global_feed=true&page=%d",
                                NEWSBLUR_URL,
                                storiesCollection.feedPage];
            
        } else {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"%@/social/river_stories/?page=%d", 
                                NEWSBLUR_URL,
                                storiesCollection.feedPage];
        }
    } else if (storiesCollection.isSavedView) {
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/starred_stories/?page=%d&v=2",
                            NEWSBLUR_URL,
                            storiesCollection.feedPage];
    } else {
        theFeedDetailURL = [NSString stringWithFormat:
                            @"%@/reader/river_stories/?f=%@&page=%d", 
                            NEWSBLUR_URL,
                            [storiesCollection.activeFolderFeeds componentsJoinedByString:@"&f="],
                            storiesCollection.feedPage];
    }
    
    
    theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                        theFeedDetailURL,
                        [storiesCollection activeOrder]];
    theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                        theFeedDetailURL,
                        [storiesCollection activeReadFilter]];

    [self cancelRequests];
    __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setUserInfo:@{@"feedPage": [NSNumber numberWithInt:storiesCollection.feedPage]}];
    [request setFailedBlock:^(void) {
        if (request.isCancelled) {
            NSLog(@"Cancelled");
            return;
        } else {
            self.isOnline = NO;
            self.isShowingFetching = NO;
//            storiesCollection.feedPage = 1;
            [self loadOfflineStories];
            [self showOfflineNotifier];
        }
    }];
    [request setCompletionBlock:^(void) {
        [self finishedLoadingFeed:request];
        if (callback) {
            callback();
        }
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

#pragma mark -
#pragma mark Processing Stories

- (void)finishedLoadingFeed:(ASIHTTPRequest *)request {
    if (request.isCancelled) {
        NSLog(@"Cancelled");
        return;
    } else if ([request responseStatusCode] >= 500) {
        self.isOnline = NO;
        self.isShowingFetching = NO;
//        storiesCollection.feedPage = 1;
        [self loadOfflineStories];
        [self showOfflineNotifier];
        if ([request responseStatusCode] == 503) {
            [self informError:@"In maintenance mode"];
            self.pageFinished = YES;
        } else {
            [self informError:@"The server barfed."];
        }
        [self.storyTitlesTable reloadData];
        
        return;
    }
    appDelegate.hasLoadedFeedDetail = YES;
    self.isOnline = YES;
    self.isShowingFetching = NO;
    storiesCollection.feedPage = [[request.userInfo objectForKey:@"feedPage"] intValue];
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    id feedId = [results objectForKey:@"feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    
    if (!(storiesCollection.isRiverView ||
          storiesCollection.isSavedView ||
          storiesCollection.isSocialView ||
          storiesCollection.isSocialRiverView)
        && request.tag != [feedId intValue]) {
        return;
    }
    if (storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView ||
        storiesCollection.isSavedView) {
        NSArray *newFeeds = [results objectForKey:@"feeds"];
        for (int i = 0; i < newFeeds.count; i++){
            NSString *feedKey = [NSString stringWithFormat:@"%@", [[newFeeds objectAtIndex:i] objectForKey:@"id"]];
            [appDelegate.dictActiveFeeds setObject:[newFeeds objectAtIndex:i] 
                      forKey:feedKey];
        }
        [self loadFaviconsFromActiveFeed];
    }

    NSMutableDictionary *newClassifiers = [[results objectForKey:@"classifiers"] mutableCopy];
    if (storiesCollection.isRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView) {
        for (id key in [newClassifiers allKeys]) {
            [storiesCollection.activeClassifiers setObject:[newClassifiers objectForKey:key] forKey:key];
        }
    } else if (newClassifiers) {
        [storiesCollection.activeClassifiers setObject:newClassifiers forKey:feedIdStr];
    }
    storiesCollection.activePopularAuthors = [results objectForKey:@"feed_authors"];
    storiesCollection.activePopularTags = [results objectForKey:@"feed_tags"];
    
    NSArray *newStories = [results objectForKey:@"stories"];
    NSMutableArray *confirmedNewStories = [[NSMutableArray alloc] init];
    if (storiesCollection.feedPage == 1) {
        confirmedNewStories = [newStories copy];
    } else {
        NSMutableSet *storyIds = [NSMutableSet set];
        for (id story in storiesCollection.activeFeedStories) {
            [storyIds addObject:[story objectForKey:@"story_hash"]];
        }
        for (id story in newStories) {
            if (![storyIds containsObject:[story objectForKey:@"story_hash"]]) {
                [confirmedNewStories addObject:story];
            }
        }
    }

    // Adding new user profiles to appDelegate.activeFeedUserProfiles

    NSArray *newUserProfiles = [[NSArray alloc] init];
    if ([results objectForKey:@"user_profiles"] != nil) {
        newUserProfiles = [results objectForKey:@"user_profiles"];
    }
    // add self to user profiles
    if (storiesCollection.feedPage == 1) {
        newUserProfiles = [newUserProfiles arrayByAddingObject:appDelegate.dictSocialProfile];
    }
    
    if ([newUserProfiles count]){
        NSMutableArray *confirmedNewUserProfiles = [NSMutableArray array];
        if ([storiesCollection.activeFeedUserProfiles count]) {
            NSMutableSet *userProfileIds = [NSMutableSet set];
            for (id userProfile in storiesCollection.activeFeedUserProfiles) {
                [userProfileIds addObject:[userProfile objectForKey:@"id"]];
            }
            for (id userProfile in newUserProfiles) {
                if (![userProfileIds containsObject:[userProfile objectForKey:@"id"]]) {
                    [confirmedNewUserProfiles addObject:userProfile];
                }
            }
        } else {
            confirmedNewUserProfiles = [newUserProfiles copy];
        }
        
        
        if (storiesCollection.feedPage == 1) {
            [storiesCollection setFeedUserProfiles:confirmedNewUserProfiles];
        } else if (newUserProfiles.count > 0) {        
            [storiesCollection addFeedUserProfiles:confirmedNewUserProfiles];
        }
    }

    self.pageFinished = NO;
    [self renderStories:confirmedNewStories];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.storyPageControl resizeScrollView];
        [appDelegate.storyPageControl setStoryFromScroll:YES];
    }
    [appDelegate.storyPageControl advanceToNextUnread];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSDictionary *story in confirmedNewStories) {
                [db executeUpdate:@"INSERT into stories"
                 "(story_feed_id, story_hash, story_timestamp, story_json) VALUES "
                 "(?, ?, ?, ?)",
                 [story objectForKey:@"story_feed_id"],
                 [story objectForKey:@"story_hash"],
                 [story objectForKey:@"story_timestamp"],
                 [story JSONRepresentation]
                 ];
            }
            //    NSLog(@"Inserting %d stories: %@", [confirmedNewStories count], [db lastErrorMessage]);
        }];
    });

    [self.notifier hide];

}

#pragma mark -
#pragma mark Stories

- (void)renderStories:(NSArray *)newStories {
    NSInteger newStoriesCount = [newStories count];
    
    if (newStoriesCount > 0) {
        if (storiesCollection.feedPage == 1) {
            [storiesCollection setStories:newStories];
        } else {
            [storiesCollection addStories:newStories];
        }
    } else {
        self.pageFinished = YES;
    }

    [self.storyTitlesTable reloadData];
    
    
    if (self.finishedAnimatingIn) {
        [self testForTryFeed];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController syncNextPreviousButtons];
    }
    
    NSMutableArray *storyImageUrls = [NSMutableArray array];
    for (NSDictionary *story in newStories) {
        if ([story objectForKey:@"image_urls"] && [[story objectForKey:@"image_urls"] count]) {
            [storyImageUrls addObject:[[story objectForKey:@"image_urls"] objectAtIndex:0]];
        }
    }
    [self performSelector:@selector(cacheStoryImages:) withObject:storyImageUrls afterDelay:0.2];

    self.pageFetching = NO;
}

- (void)testForTryFeed {
    if (self.isDashboardModule ||
        !appDelegate.inFindingStoryMode ||
        !appDelegate.tryFeedStoryId) return;

    NSLog(@"Test for try feed");

    for (int i = 0; i < [storiesCollection.activeFeedStories count]; i++) {
        NSString *storyIdStr = [[storiesCollection.activeFeedStories
                                 objectAtIndex:i] objectForKey:@"id"];
        NSString *storyHashStr = [[storiesCollection.activeFeedStories
                                   objectAtIndex:i] objectForKey:@"story_hash"];
        if ([storyHashStr isEqualToString:appDelegate.tryFeedStoryId] ||
            [storyIdStr isEqualToString:appDelegate.tryFeedStoryId]) {
            NSDictionary *feed = [storiesCollection.activeFeedStories objectAtIndex:i];
            
            NSInteger score = [NewsBlurAppDelegate computeStoryScore:[feed objectForKey:@"intelligence"]];
            
            if (score < appDelegate.selectedIntelligence) {
                [self changeIntelligence:score];
            }
            NSInteger locationOfStoryId = [storiesCollection locationOfStoryId:storyHashStr];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:locationOfStoryId inSection:0];
            
            [self.storyTitlesTable selectRowAtIndexPath:indexPath
                                               animated:NO
                                         scrollPosition:UITableViewScrollPositionMiddle];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                FeedDetailTableCell *cell = (FeedDetailTableCell *)[self.storyTitlesTable cellForRowAtIndexPath:indexPath];
                [self loadStory:cell atRow:indexPath.row];
            });
            
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            // found the story, reset the two flags.
            appDelegate.tryFeedStoryId = nil;
            appDelegate.inFindingStoryMode = NO;
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription]);
    
    self.pageFetching = NO;
    
	// User clicking on another link before the page loads is OK.
	if ([error code] != NSURLErrorCancelled) {
		[self informError:error];
	}
}

- (UITableViewCell *)makeLoadingCell {
    NSInteger height = 40;
    UITableViewCell *cell = [[UITableViewCell alloc]
                             initWithStyle:UITableViewCellStyleSubtitle
                             reuseIdentifier:@"NoReuse"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }

        fleuron.frame = CGRectMake(0, 0, self.view.frame.size.width, height);
        fleuron.contentMode = UIViewContentModeCenter;
        fleuron.tag = 99;
        [cell.contentView addSubview:fleuron];
        cell.backgroundColor = [UIColor clearColor];
        return cell;
    } else {//if ([appDelegate.storyLocationsCount]) {
        NBLoadingCell *loadingCell = [[NBLoadingCell alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, height)];
        return loadingCell;
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { 
    NSInteger storyCount = storiesCollection.storyLocationsCount;

    // The +1 is for the finished/loading bar.
    return storyCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *cellIdentifier;
    NSDictionary *feed ;
    
    if (indexPath.row >= storiesCollection.storyLocationsCount) {
        return [self makeLoadingCell];
    }
    
    
    if (storiesCollection.isRiverView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSavedView) {
        cellIdentifier = @"FeedRiverDetailCellIdentifier";
    } else {
        cellIdentifier = @"FeedDetailCellIdentifier";
    }
    
    FeedDetailTableCell *cell = (FeedDetailTableCell *)[tableView
                                                        dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[FeedDetailTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:cellIdentifier];
    }
    
    for (UIView *view in cell.contentView.subviews) {
        if ([view isKindOfClass:[UIImageView class]] && ((UIImageView *)view).tag == 99) {
            [view removeFromSuperview];
            break;
        }
    }
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    
    id feedId = [story objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    
    if (storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView) {
        feed = [appDelegate.dictActiveFeeds objectForKey:feedIdStr];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
    
    cell.inDashboard = self.isDashboardModule;
    
    NSString *siteTitle = [feed objectForKey:@"feed_title"];
    cell.siteTitle = siteTitle; 

    NSString *title = [story objectForKey:@"story_title"];
    cell.storyTitle = [title stringByDecodingHTMLEntities];
    
    cell.storyDate = [story objectForKey:@"short_parsed_date"];
    cell.storyTimestamp = [[story objectForKey:@"story_timestamp"] integerValue];
    cell.isSaved = [[story objectForKey:@"starred"] boolValue];
    cell.isShared = [[story objectForKey:@"shared"] boolValue];
    cell.storyImageUrl = nil;
    if (self.showImagePreview &&
        [story objectForKey:@"image_urls"] && [[story objectForKey:@"image_urls"] count]) {
        cell.storyImageUrl = [[story objectForKey:@"image_urls"] objectAtIndex:0];
    }
    
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor = [[story objectForKey:@"story_authors"] uppercaseString];
    } else {
        cell.storyAuthor = @"";
    }
    
    cell.storyContent = nil;
    if (self.isDashboardModule || self.showContentPreview) {
        cell.storyContent = [[story objectForKey:@"story_content"]
                             stringByConvertingHTMLToPlainText];
    }
    
    // feed color bar border
    unsigned int colorBorder = 0;
    NSString *faviconColor = [feed valueForKey:@"favicon_fade"];

    if ([faviconColor class] == [NSNull class] || !faviconColor) {
        faviconColor = @"707070";
    }    
    NSScanner *scannerBorder = [NSScanner scannerWithString:faviconColor];
    [scannerBorder scanHexInt:&colorBorder];

    cell.feedColorBar = UIColorFromRGB(colorBorder);
    
    // feed color bar border
    NSString *faviconFade = [feed valueForKey:@"favicon_color"];
    if ([faviconFade class] == [NSNull class] || !faviconFade) {
        faviconFade = @"505050";
    }    
    scannerBorder = [NSScanner scannerWithString:faviconFade];
    [scannerBorder scanHexInt:&colorBorder];
    cell.feedColorBarTopBorder =  UIColorFromRGB(colorBorder);
    
    // favicon
    cell.siteFavicon = [appDelegate getFavicon:feedIdStr];
    cell.hasAlpha = NO;
    
    // undread indicator
    
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    cell.storyScore = score;
    
    cell.isRead = ![storiesCollection isStoryUnread:story];
    
    cell.isShort = NO;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
        !self.isDashboardModule &&
        !appDelegate.masterContainerViewController.storyTitlesOnLeft &&
        UIInterfaceOrientationIsPortrait(orientation)) {
        cell.isShort = YES;
    }
    
    cell.isRiverOrSocial = NO;
    if (storiesCollection.isRiverView ||
        storiesCollection.isSavedView ||
        storiesCollection.isSocialView ||
        storiesCollection.isSocialRiverView) {
        cell.isRiverOrSocial = YES;
    }

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && !self.isDashboardModule) {
        NSInteger rowIndex = [storiesCollection locationOfActiveStory];
        if (rowIndex == indexPath.row) {
            [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } 
    }
    
    [cell setupGestures];
    
    [cell setNeedsDisplay];
    
    return cell;
}

- (void)loadStory:(FeedDetailTableCell *)cell atRow:(NSInteger)row {
    NSInteger storyIndex = [storiesCollection indexFromLocation:row];
    appDelegate.activeStory = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
    if ([storiesCollection isStoryUnread:appDelegate.activeStory]) {
        [storiesCollection markStoryRead:appDelegate.activeStory];
        [storiesCollection syncStoryAsRead:appDelegate.activeStory];
    }
    [self setTitleForBackButton];
    [appDelegate loadStoryDetailView];
    [self redrawUnreadStory];
}

- (void)setTitleForBackButton {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        NSString *feedTitle;
        if (storiesCollection.isRiverView) {
            if ([storiesCollection.activeFolder isEqualToString:@"river_blurblogs"]) {
                feedTitle = @"All Shared Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"river_global"]) {
                feedTitle = @"Global Shared Stories";
            } else if ([storiesCollection.activeFolder isEqualToString:@"everything"]) {
                feedTitle = @"All Stories";
            } else if (storiesCollection.isSavedView && storiesCollection.activeSavedStoryTag) {
                feedTitle = storiesCollection.activeSavedStoryTag;
            } else if ([storiesCollection.activeFolder isEqualToString:@"saved_stories"]) {
                feedTitle = @"Saved Stories";
            } else {
                feedTitle = storiesCollection.activeFolder;
            }
        } else {
            feedTitle = [storiesCollection.activeFeed objectForKey:@"feed_title"];
        }
        
        if ([feedTitle length] >= 12) {
            feedTitle = [NSString stringWithFormat:@"%@...", [feedTitle substringToIndex:MIN(9, [feedTitle length])]];
        }
        UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:feedTitle style: UIBarButtonItemStylePlain target: nil action: nil];
        [self.navigationItem setBackBarButtonItem: newBackButton];
    }
}

- (void)redrawUnreadStory {
    NSInteger rowIndex = [storiesCollection locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    cell.isRead = ![storiesCollection isStoryUnread:appDelegate.activeStory];
    cell.isShared = [[appDelegate.activeStory objectForKey:@"shared"] boolValue];
    cell.isSaved = [[appDelegate.activeStory objectForKey:@"starred"] boolValue];
    [cell setNeedsDisplay];
}

- (void)changeActiveStoryTitleCellLayout {
    NSInteger rowIndex = [storiesCollection locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    cell.isRead = YES;
    [cell setNeedsLayout];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < storiesCollection.storyLocationsCount) {
        // mark the cell as read
        
        if (self.isDashboardModule) {
            NSInteger storyIndex = [storiesCollection indexFromLocation:indexPath.row];
            NSDictionary *activeStory = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
            appDelegate.activeStory = activeStory;
            [appDelegate openDashboardRiverForStory:[activeStory objectForKey:@"story_hash"] showFindingStory:NO];
        } else {
            FeedDetailTableCell *cell = (FeedDetailTableCell*) [tableView cellForRowAtIndexPath:indexPath];
            NSInteger storyIndex = [storiesCollection indexFromLocation:indexPath.row];
            NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
                appDelegate.activeStory &&
                [[story objectForKey:@"story_hash"]
                 isEqualToString:[appDelegate.activeStory objectForKey:@"story_hash"]]) {
                return;
            }
            [self loadStory:cell atRow:indexPath.row];
        }
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell class] == [NBLoadingCell class]) {
        [(NBLoadingCell *)cell endAnimation];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell class] == [NBLoadingCell class]) {
        [(NBLoadingCell *)cell animate];
    }
    if ([indexPath row] == ((NSIndexPath*)[[tableView indexPathsForVisibleRows] lastObject]).row) {
        [self performSelector:@selector(checkScroll)
                   withObject:nil
                   afterDelay:0.1];
    }
}

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSInteger storyCount = storiesCollection.storyLocationsCount;
    
    if (storyCount && indexPath.row == storyCount) {
        return 40;
    } else if (storiesCollection.isRiverView ||
               storiesCollection.isSavedView ||
               storiesCollection.isSocialView ||
               storiesCollection.isSocialRiverView) {
        NSInteger height = kTableViewRiverRowHeight;
        if ([self isShortTitles]) {
            height = height - kTableViewShortRowDifference;
        }
        UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
        UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        if ([self isShortTitles] && self.showContentPreview) {
            return height + font.pointSize*3.25;
        } else if (self.isDashboardModule || self.showContentPreview) {
            return height + font.pointSize*5;
        } else {
            return height + font.pointSize*2;
        }
    } else {
        NSInteger height = kTableViewRowHeight;
        if ([self isShortTitles]) {
            height = height - kTableViewShortRowDifference;
        }
        UIFontDescriptor *fontDescriptor = [self fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
        UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        if ([self isShortTitles] && self.showContentPreview) {
            return height + font.pointSize*3.25;
        } else if (self.isDashboardModule || self.showContentPreview) {
            return height + font.pointSize*5;
        } else {
            return height + font.pointSize*2;
        }
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    // This will create a "invisible" footer
    return 0.01f;
}
- (void)scrollViewDidScroll: (UIScrollView *)scroll {
    [self checkScroll];
}

- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle {
    UIFontDescriptor *fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];

    if (![userPreferences boolForKey:@"use_system_font_size"]) {
        if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xs"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:10.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"small"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:11.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:12.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:14.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:16.0f];
        }
    }
    return fontDescriptor;
}

- (BOOL)isShortTitles {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
        !appDelegate.masterContainerViewController.storyTitlesOnLeft &&
        UIInterfaceOrientationIsPortrait(orientation) &&
        !self.isDashboardModule;
}

- (void)checkScroll {
    NSInteger currentOffset = self.storyTitlesTable.contentOffset.y;
    NSInteger maximumOffset = self.storyTitlesTable.contentSize.height - self.storyTitlesTable.frame.size.height;
    
    if (self.pageFetching) {
        return;
    }
    if (![storiesCollection.activeFeedStories count]) return;
    
    if (maximumOffset - currentOffset <= 500.0 ||
        (appDelegate.inFindingStoryMode)) {
        if (storiesCollection.isRiverView && storiesCollection.activeFolder) {
            [self fetchRiverPage:storiesCollection.feedPage+1 withCallback:nil];
        } else {
            [self fetchFeedDetail:storiesCollection.feedPage+1 withCallback:nil];
        }
    }
}

- (void)changeIntelligence:(NSInteger)newLevel {
    NSInteger previousLevel = [appDelegate selectedIntelligence];
    
    if (newLevel == previousLevel) return;
    
    if (newLevel < previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
        NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
        [userPreferences setInteger:(newLevel + 1) forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        [storiesCollection calculateStoryLocations];
    }
    
    [self.storyTitlesTable reloadData];
}

- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow {
    if (indexPathRow >= [[storiesCollection activeFeedStoryLocations] count]) return nil;
    id location = [[storiesCollection activeFeedStoryLocations] objectAtIndex:indexPathRow];
    if (!location) return nil;
    NSInteger row = [location intValue];
    return [storiesCollection.activeFeedStories objectAtIndex:row];
}


#pragma mark - MCSwipeTableViewCellDelegate

// When the user starts swiping the cell this method is called
- (void)swipeTableViewCellDidStartSwiping:(MCSwipeTableViewCell *)cell {
//    NSLog(@"Did start swiping the cell!");
}

// When the user is dragging, this method is called and return the dragged percentage from the border
- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell didSwipWithPercentage:(CGFloat)percentage {
//    NSLog(@"Did swipe with percentage : %f", percentage);
}

- (void)swipeTableViewCell:(MCSwipeTableViewCell *)cell
didEndSwipingSwipingWithState:(MCSwipeTableViewCellState)state
                      mode:(MCSwipeTableViewCellMode)mode {
    NSIndexPath *indexPath = [self.storyTitlesTable indexPathForCell:cell];
    if (!indexPath) {
        // This can happen if the user swipes on a cell that is being refreshed.
        return;
    }
    
    NSInteger storyIndex = [storiesCollection indexFromLocation:indexPath.row];
    NSDictionary *story = [[storiesCollection activeFeedStories] objectAtIndex:storyIndex];

    if (state == MCSwipeTableViewCellState1) {
        // Saved
        [storiesCollection toggleStorySaved:story];
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
    } else if (state == MCSwipeTableViewCellState3) {
        // Read
        [storiesCollection toggleStoryUnread:story];
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
        if (self.isDashboardModule) {
            [appDelegate refreshFeedCount:[story objectForKey:@"story_feed_id"]];
        }
    }
}

#pragma mark -
#pragma mark Feed Actions

- (void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer {
    CGPoint p = [gestureRecognizer locationInView:self.storyTitlesTable];
    NSIndexPath *indexPath = [self.storyTitlesTable indexPathForRowAtPoint:p];
    FeedDetailTableCell *cell = (FeedDetailTableCell *)[self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    
    if (gestureRecognizer.state != UIGestureRecognizerStateBegan) return;
    if (indexPath == nil) return;
    
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    
    NSUserDefaults *preferences = [NSUserDefaults standardUserDefaults];
    NSString *longPressStoryTitle = [preferences stringForKey:@"long_press_story_title"];
    if ([longPressStoryTitle isEqualToString:@"open_send_to"]) {
        appDelegate.activeStory = story;
        [appDelegate showSendTo:self sender:cell];
    } else if ([longPressStoryTitle isEqualToString:@"mark_unread"]) {
        [storiesCollection toggleStoryUnread:story];
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
    } else if ([longPressStoryTitle isEqualToString:@"save_story"]) {
        [storiesCollection toggleStorySaved:story];
        [self.storyTitlesTable reloadRowsAtIndexPaths:@[indexPath]
                                     withRowAnimation:UITableViewRowAnimationFade];
    } else if ([longPressStoryTitle isEqualToString:@"train_story"]) {
        [appDelegate openTrainStory:cell];
    }
}

- (void)markFeedsReadWithAllStories:(BOOL)includeHidden {
    if (storiesCollection.isRiverView && includeHidden &&
        [storiesCollection.activeFolder isEqualToString:@"everything"]) {
        // Mark folder as read
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_all_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setDelegate:nil];
        [request startAsynchronous];
        
        [appDelegate markActiveFolderAllRead];
    } else if (storiesCollection.isRiverView && includeHidden) {
        // Mark folder as read
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        for (id feed_id in [appDelegate.dictFolders objectForKey:storiesCollection.activeFolder]) {
            [request addPostValue:feed_id forKey:@"feed_id"];
        }
        [request setUserInfo:@{@"feeds": storiesCollection.activeFolderFeeds}];
        [request setDelegate:self];
        [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request startAsynchronous];
        
        [appDelegate markActiveFolderAllRead];
    } else if (!storiesCollection.isRiverView && includeHidden) {
        // Mark feed as read
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[storiesCollection.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
        [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setUserInfo:@{@"feeds": @[[storiesCollection.activeFeed objectForKey:@"id"]]}];
        [request setDelegate:self];
        [request startAsynchronous];
        [appDelegate markFeedAllRead:[storiesCollection.activeFeed objectForKey:@"id"]];
    } else if (!includeHidden) {
        // Mark visible stories as read
        NSDictionary *feedsStories = [appDelegate markVisibleStoriesRead];
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_stories_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[feedsStories JSONRepresentation] forKey:@"feeds_stories"]; 
        [request setDelegate:self];
        [request setUserInfo:@{@"stories": feedsStories}];
        [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
        [request setDidFailSelector:@selector(requestFailedMarkStoryRead:)];
        [request startAsynchronous];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.navigationController popToRootViewControllerAnimated:YES];
        [appDelegate.masterContainerViewController transitionFromFeedDetail];
    } else {
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    }
}

- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request {
    //    [self informError:@"Failed to mark story as read"];
    [appDelegate markStoriesRead:[request.userInfo objectForKey:@"stories"]
                         inFeeds:[request.userInfo objectForKey:@"feeds"]
                 cutoffTimestamp:nil];
}

- (void)finishMarkAllAsRead:(ASIFormDataRequest *)request {
    if (request.responseStatusCode != 200) {
        [self requestFailedMarkStoryRead:request];
        return;
    }
    
    if ([request.userInfo objectForKey:@"feeds"]) {
        [appDelegate markFeedReadInCache:@[[request.userInfo objectForKey:@"feeds"]]];
    }
}

- (IBAction)doOpenMarkReadActionSheet:(id)sender {
    // already displaying action sheet?
    if (self.actionSheet_) {
        [self.actionSheet_ dismissWithClickedButtonIndex:-1 animated:YES];
        self.actionSheet_ = nil;
        return;
    }
    
    // Individual sites just get marked as read, no action sheet needed.
    if (!storiesCollection.isRiverView) {
        [self markFeedsReadWithAllStories:YES];
        return;
    }
    
    NSString *title = storiesCollection.isRiverView ?
                      storiesCollection.activeFolder :
                      [storiesCollection.activeFeed objectForKey:@"feed_title"];
    UIActionSheet *options = [[UIActionSheet alloc] 
                              initWithTitle:title
                              delegate:self
                              cancelButtonTitle:nil
                              destructiveButtonTitle:nil
                              otherButtonTitles:nil];
    
    self.actionSheet_ = options;
    [storiesCollection calculateStoryLocations];
    NSInteger visibleUnreadCount = storiesCollection.visibleUnreadCount;
    NSInteger totalUnreadCount = [appDelegate unreadCount];
    NSArray *buttonTitles = nil;
    BOOL showVisible = YES;
    BOOL showEntire = YES;
//    if ([appDelegate.activeFolder isEqualToString:@"everything"]) showEntire = NO;
    if (visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0) showVisible = NO;
    NSString *entireText = [NSString stringWithFormat:@"Mark %@ read", 
                            storiesCollection.isRiverView ?
                            [storiesCollection.activeFolder isEqualToString:@"everything"] ?
                            @"everything" :
                            @"entire folder" : 
                            @"this site"];
    NSString *visibleText = [NSString stringWithFormat:@"Mark %@ read", 
                             visibleUnreadCount == 1 ? @"this story as" : 
                                [NSString stringWithFormat:@"these %ld stories", 
                                 (long)visibleUnreadCount]];
    if (showVisible && showEntire) {
        buttonTitles = [NSArray arrayWithObjects:visibleText, entireText, nil];
        options.destructiveButtonIndex = 1;
    } else if (showVisible && !showEntire) {
        buttonTitles = [NSArray arrayWithObjects:visibleText, nil];
        options.destructiveButtonIndex = -1;
    } else if (!showVisible && showEntire) {
        buttonTitles = [NSArray arrayWithObjects:entireText, nil];
        options.destructiveButtonIndex = 0;
    }
    
    for (id title in buttonTitles) {
        [options addButtonWithTitle:title];
    }
    options.cancelButtonIndex = [options addButtonWithTitle:@"Cancel"];
    
    options.tag = kMarkReadActionSheet;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [options showFromBarButtonItem:self.feedMarkReadButton animated:YES];
    } else {
        [options showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
//    NSLog(@"Action option #%d on %d", buttonIndex, actionSheet.tag);
    if (actionSheet.tag == 1) {
        NSInteger visibleUnreadCount = storiesCollection.visibleUnreadCount;
        NSInteger totalUnreadCount = [appDelegate unreadCount];
        BOOL showVisible = YES;
        BOOL showEntire = YES;
//        if ([appDelegate.activeFolder isEqualToString:@"everything"]) showEntire = NO;
        if (visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0) showVisible = NO;
//        NSLog(@"Counts: %d %d = %d", visibleUnreadCount, totalUnreadCount, visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0);
        
        if (showVisible && showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:NO];
            } else if (buttonIndex == 1) {
                [self markFeedsReadWithAllStories:YES];
            }               
        } else if (showVisible && !showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:NO];
            }   
        } else if (!showVisible && showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:YES];
            }
        }
    } else if (actionSheet.tag == 2) {
        if (buttonIndex == 0) {
            [self confirmDeleteSite];
        } else if (buttonIndex == 1) {
            [self openMoveView];
        } else if (buttonIndex == 2) {
            [self instafetchFeed];
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // just set to nil
    actionSheet_ = nil;
}

- (IBAction)doOpenSettingsActionSheet:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showFeedDetailMenuPopover:self.settingsBarButton];
    } else {
        if (self.popoverController == nil) {
            self.popoverController = [[WEPopoverController alloc]
                                      initWithContentViewController:(UIViewController *)appDelegate.feedDetailMenuViewController];
            [appDelegate.feedDetailMenuViewController buildMenuOptions];
            self.popoverController.delegate = self;
        } else {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
        
        if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
            [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
        }
        NSInteger menuCount = [appDelegate.feedDetailMenuViewController.menuOptions count] + 2;
        [self.popoverController setPopoverContentSize:CGSizeMake(260, 38 * menuCount)];
        [self.popoverController presentPopoverFromBarButtonItem:self.settingsBarButton
                                       permittedArrowDirections:UIPopoverArrowDirectionUp
                                                       animated:YES];
    }

}

- (void)confirmDeleteSite {
    UIAlertView *deleteConfirm = [[UIAlertView alloc] 
                                  initWithTitle:@"Positive?" 
                                  message:nil 
                                  delegate:self 
                                  cancelButtonTitle:@"Cancel" 
                                  otherButtonTitles:@"Delete", 
                                  nil];
    [deleteConfirm show];
    [deleteConfirm setTag:0];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 0) {
        if (buttonIndex == 0) {
            return;
        } else {
            if (storiesCollection.isRiverView) {
                [self deleteFolder];
            } else {
                [self deleteSite];
            }
        }
    }
}

- (void)deleteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/delete_feed", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[storiesCollection.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
    [request addPostValue:[appDelegate extractFolderName:storiesCollection.activeFolder] forKey:@"in_folder"];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setCompletionBlock:^(void) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
    [request setTimeOutSeconds:30];
    [request setTag:[[storiesCollection.activeFeed objectForKey:@"id"] intValue]];
    [request startAsynchronous];
}

- (void)deleteFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/delete_folder", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[appDelegate extractFolderName:storiesCollection.activeFolder]
                   forKey:@"folder_to_delete"];
    [request addPostValue:[appDelegate extractFolderName:[appDelegate
                                                          extractParentFolderName:storiesCollection.activeFolder]]
                   forKey:@"in_folder"];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setCompletionBlock:^(void) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

- (void)openMoveView {
    [appDelegate showMoveSite];
}

- (void)openTrainSite {
    [appDelegate openTrainSite];
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@",
                                       [storiesCollection.activeFeed objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@",
                                         [storiesCollection.activeFeed objectForKey:@"username"]];
    [appDelegate showUserProfileModal:titleImageBarButton];
}

- (void)changeActiveFeedDetailRow {
    NSInteger rowIndex = [storiesCollection locationOfActiveStory];
    int offset = 1;
    if ([[self.storyTitlesTable visibleCells] count] <= 4) {
        offset = 0;
    }
                    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    NSIndexPath *offsetIndexPath = [NSIndexPath indexPathForRow:(rowIndex - offset) inSection:0];

    [storyTitlesTable selectRowAtIndexPath:indexPath 
                                  animated:YES 
                            scrollPosition:UITableViewScrollPositionNone];
    
    // check to see if the cell is completely visible
    CGRect cellRect = [storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    cellRect = [storyTitlesTable convertRect:cellRect toView:storyTitlesTable.superview];
    
    BOOL completelyVisible = CGRectContainsRect(storyTitlesTable.frame, cellRect);
    if (!completelyVisible) {
        [storyTitlesTable scrollToRowAtIndexPath:offsetIndexPath 
                                atScrollPosition:UITableViewScrollPositionTop 
                                        animated:YES];
    }
}

#pragma mark -
#pragma mark Story Actions - save

- (void)finishMarkAsSaved:(ASIFormDataRequest *)request {

}

- (void)failedMarkAsSaved:(ASIFormDataRequest *)request {
    [self informError:@"Failed to save story"];
    
    [self.storyTitlesTable reloadData];
}

- (void)finishMarkAsUnsaved:(ASIFormDataRequest *)request {

}

- (void)failedMarkAsUnsaved:(ASIFormDataRequest *)request {
    [self informError:@"Failed to unsave story"];

    [self.storyTitlesTable reloadData];
}

- (void)failedMarkAsUnread:(ASIFormDataRequest *)request {
    [self informError:@"Failed to unread story"];
    
    [self.storyTitlesTable reloadData];
}

#pragma mark -
#pragma mark instafetchFeed

// called when the user taps refresh button

- (void)instafetchFeed {
    NSString *urlString = [NSString
                           stringWithFormat:@"%@/reader/refresh_feed/%@", 
                           NEWSBLUR_URL,
                           [storiesCollection.activeFeed objectForKey:@"id"]];
    [self cancelRequests];
    ASIHTTPRequest *request = [self requestWithURL:urlString];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setDidFinishSelector:@selector(finishedRefreshingFeed:)];
    [request setDidFailSelector:@selector(failRefreshingFeed:)];
    [request setTimeOutSeconds:60];
    [request startAsynchronous];
    
    [storiesCollection setStories:nil];
    storiesCollection.feedPage = 1;
    self.pageFetching = YES;
    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)finishedRefreshingFeed:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    [self renderStories:[results objectForKey:@"stories"]];    
}

- (void)failRefreshingFeed:(ASIHTTPRequest *)request {
    NSLog(@"Fail: %@", request);
    [self informError:[request error]];
    [self fetchFeedDetail:1 withCallback:nil];
}

#pragma mark -
#pragma mark loadSocial Feeds

- (void)loadFaviconsFromActiveFeed {
    NSArray * keys = [appDelegate.dictActiveFeeds allKeys];
    
    if (![keys count]) {
        // if no new favicons, return
        return;
    }
    
    NSString *feedIdsQuery = [NSString stringWithFormat:@"?feed_ids=%@", 
                               [[keys valueForKey:@"description"] componentsJoinedByString:@"&feed_ids="]];        
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/favicons%@",
                           NEWSBLUR_URL,
                           feedIdsQuery];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest  *request = [ASIHTTPRequest  requestWithURL:url];

    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request {

    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSMutableDictionary *feed = [[appDelegate.dictActiveFeeds objectForKey:feed_id] mutableCopy];
            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
            [appDelegate.dictActiveFeeds setValue:feed forKey:feed_id];
            
            NSString *favicon = [feed objectForKey:@"favicon"];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [appDelegate saveFavicon:faviconImage feedId:feed_id];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.storyTitlesTable reloadData];
        });
    });
    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

#pragma mark -
#pragma mark WEPopoverControllerDelegate implementation

- (void)popoverControllerDidDismissPopover:(WEPopoverController *)thePopoverController {
	//Safe to release the popover here
	self.popoverController = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(WEPopoverController *)thePopoverController {
	//The popover is automatically dismissed if you click outside it, unless you return NO here
	return YES;
}

- (WEPopoverContainerViewProperties *)improvedContainerViewProperties {
	
	WEPopoverContainerViewProperties *props = [WEPopoverContainerViewProperties alloc];
	NSString *bgImageName = nil;
	CGFloat bgMargin = 0.0;
	CGFloat bgCapSize = 0.0;
	CGFloat contentMargin = 5.0;
	
	bgImageName = @"popoverBg.png";
	
	// These constants are determined by the popoverBg.png image file and are image dependent
	bgMargin = 13; // margin width of 13 pixels on all sides popoverBg.png (62 pixels wide - 36 pixel background) / 2 == 26 / 2 == 13
	bgCapSize = 31; // ImageSize/2  == 62 / 2 == 31 pixels
	
	props.leftBgMargin = bgMargin;
	props.rightBgMargin = bgMargin;
	props.topBgMargin = bgMargin;
	props.bottomBgMargin = bgMargin;
	props.leftBgCapSize = bgCapSize;
	props.topBgCapSize = bgCapSize;
	props.bgImageName = bgImageName;
	props.leftContentMargin = contentMargin;
	props.rightContentMargin = contentMargin - 1; // Need to shift one pixel for border to look correct
	props.topContentMargin = contentMargin;
	props.bottomContentMargin = contentMargin;
	
	props.arrowMargin = 4.0;
	
	props.upArrowImageName = @"popoverArrowUp.png";
	props.downArrowImageName = @"popoverArrowDown.png";
	props.leftArrowImageName = @"popoverArrowLeft.png";
	props.rightArrowImageName = @"popoverArrowRight.png";
	return props;
}


@end
