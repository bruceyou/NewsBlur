//
//  FontPopover.m
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FontSettingsViewController.h"
#import "NewsBlurAppDelegate.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "FeedDetailViewController.h"
#import "MenuTableViewCell.h"
#import "NBContainerViewController.h"
#import "StoriesCollection.h"

@implementation FontSettingsViewController

#define kMenuOptionHeight 38

@synthesize appDelegate;
@synthesize fontStyleSegment;
@synthesize fontSizeSegment;
@synthesize lineSpacingSegment;
@synthesize menuTableView;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
}

- (void)viewWillAppear:(BOOL)animated {
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences stringForKey:@"fontStyle"]) {
        if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-helvetica"]) {
            [fontStyleSegment setSelectedSegmentIndex:0];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-palatino"]) {
            [fontStyleSegment setSelectedSegmentIndex:1];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-georgia"]) {
            [fontStyleSegment setSelectedSegmentIndex:2];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-avenir"]) {
            [fontStyleSegment setSelectedSegmentIndex:3];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-avenirnext"]) {
            [fontStyleSegment setSelectedSegmentIndex:4];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-f1"]) {
            [fontStyleSegment setSelectedSegmentIndex:5];
        }
    }

    if([userPreferences stringForKey:@"story_font_size"]){
        NSString *fontSize = [userPreferences stringForKey:@"story_font_size"];
        if ([fontSize isEqualToString:@"xs"]) {
            [fontSizeSegment setSelectedSegmentIndex:0];
        } else if ([fontSize isEqualToString:@"small"]) {
            [fontSizeSegment setSelectedSegmentIndex:1];
        } else if ([fontSize isEqualToString:@"medium"]) {
            [fontSizeSegment setSelectedSegmentIndex:2];
        } else if ([fontSize isEqualToString:@"large"]) {
            [fontSizeSegment setSelectedSegmentIndex:3];
        } else if ([fontSize isEqualToString:@"xl"]) {
            [fontSizeSegment setSelectedSegmentIndex:4];
        }
    }
    
    if([userPreferences stringForKey:@"story_line_spacing"]){
        NSString *lineSpacing = [userPreferences stringForKey:@"story_line_spacing"];
        if ([lineSpacing isEqualToString:@"xs"]) {
            [lineSpacingSegment setSelectedSegmentIndex:0];
        } else if ([lineSpacing isEqualToString:@"small"]) {
            [lineSpacingSegment setSelectedSegmentIndex:1];
        } else if ([lineSpacing isEqualToString:@"medium"]) {
            [lineSpacingSegment setSelectedSegmentIndex:2];
        } else if ([lineSpacing isEqualToString:@"large"]) {
            [lineSpacingSegment setSelectedSegmentIndex:3];
        } else if ([lineSpacing isEqualToString:@"xl"]) {
            [lineSpacingSegment setSelectedSegmentIndex:4];
        }
    }
    
    [self.menuTableView reloadData];
}

- (void)viewDidUnload
{

    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (IBAction)changeFontStyle:(id)sender {
    if ([sender selectedSegmentIndex] == 0) {
        [self setHelvetica];
    } else if ([sender selectedSegmentIndex] == 1) {
        [self setPalatino];
    } else if ([sender selectedSegmentIndex] == 2) {
        [self setGeorgia];
    } else if ([sender selectedSegmentIndex] == 3) {
        [self setAvenir];
    } else if ([sender selectedSegmentIndex] == 4) {
        [self setAvenirNext];
    }
    
    [self.menuTableView reloadData];
}

- (IBAction)changeFontSize:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [appDelegate.storyPageControl changeFontSize:@"xs"];
        [userPreferences setObject:@"xs" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [appDelegate.storyPageControl changeFontSize:@"small"];
        [userPreferences setObject:@"small" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [appDelegate.storyPageControl changeFontSize:@"medium"];
        [userPreferences setObject:@"medium" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [appDelegate.storyPageControl changeFontSize:@"large"];
        [userPreferences setObject:@"large" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [appDelegate.storyPageControl changeFontSize:@"xl"];
        [userPreferences setObject:@"xl" forKey:@"story_font_size"];
    }
    [userPreferences synchronize];
}

- (IBAction)changeLineSpacing:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [appDelegate.storyPageControl changeLineSpacing:@"xs"];
        [userPreferences setObject:@"xs" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [appDelegate.storyPageControl changeLineSpacing:@"small"];
        [userPreferences setObject:@"small" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [appDelegate.storyPageControl changeLineSpacing:@"medium"];
        [userPreferences setObject:@"medium" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [appDelegate.storyPageControl changeLineSpacing:@"large"];
        [userPreferences setObject:@"large" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [appDelegate.storyPageControl changeLineSpacing:@"xl"];
        [userPreferences setObject:@"xl" forKey:@"story_line_spacing"];
    }
    [userPreferences synchronize];
}

- (void)setHelvetica {
    [fontStyleSegment setSelectedSegmentIndex:0];
    [appDelegate.storyPageControl setFontStyle:@"Helvetica"];
}

- (void)setPalatino {
    [fontStyleSegment setSelectedSegmentIndex:1];
    [appDelegate.storyPageControl setFontStyle:@"Palatino"];
}

- (void)setGeorgia {
    [fontStyleSegment setSelectedSegmentIndex:2];
    [appDelegate.storyPageControl setFontStyle:@"Georgia"];
}

- (void)setAvenir {
    [fontStyleSegment setSelectedSegmentIndex:3];
    [appDelegate.storyPageControl setFontStyle:@"Avenir"];
}

- (void)setAvenirNext {
    [fontStyleSegment setSelectedSegmentIndex:4];
    [appDelegate.storyPageControl setFontStyle:@"AvenirNext"];
}


#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 8;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (indexPath.row == 5) {
        return [self makeFontSelectionTableCell];
    } else if (indexPath.row == 6) {
        return [self makeFontSizeTableCell];
    } else if (indexPath.row == 7) {
        return [self makeLineSpacingTableCell];
    }
    
    if (cell == nil) {
        cell = [[MenuTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier];
    }
        
    if (indexPath.row == 0) {
        bool isSaved = [[appDelegate.activeStory objectForKey:@"starred"] boolValue];
        if (isSaved) {
            cell.textLabel.text = [@"Unsave this story" uppercaseString];
        } else {
            cell.textLabel.text = [@"Save this story" uppercaseString];
        }
        cell.imageView.image = [UIImage imageNamed:@"clock.png"];
    } else if (indexPath.row == 1) {
        bool isRead = [[appDelegate.activeStory objectForKey:@"read_status"] boolValue];
        if (isRead) {
            cell.textLabel.text = [@"Mark as unread" uppercaseString];
        } else {
            cell.textLabel.text = [@"Mark as read" uppercaseString];
        }
        cell.imageView.image = [UIImage imageNamed:@"g_icn_unread.png"];
    } else if (indexPath.row == 2) {
        cell.textLabel.text = [@"Send to..." uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_mail.png"];
    } else if (indexPath.row == 3) {
        cell.textLabel.text = [@"Train this story" uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_train.png"];
    } else if (indexPath.row == 4) {
        cell.textLabel.text = [@"Share this story" uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_share.png"];
    }

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kMenuOptionHeight;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= 5) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        [appDelegate.storiesCollection toggleStorySaved];
        [appDelegate.feedDetailViewController reloadData];
        [appDelegate.storyPageControl refreshHeaders];
    } else if (indexPath.row == 1) {
        [appDelegate.storiesCollection toggleStoryUnread];
        [appDelegate.feedDetailViewController reloadData];
        [appDelegate.storyPageControl refreshHeaders];
    } else if (indexPath.row == 2) {
        [appDelegate.storyPageControl openSendToDialog:appDelegate.storyPageControl.fontSettingsButton];
    } else if (indexPath.row == 3) {
        [appDelegate openTrainStory:appDelegate.storyPageControl.fontSettingsButton];
    } else if (indexPath.row == 4) {
        [appDelegate.storyPageControl.currentPage openShareDialog];
    }

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (indexPath.row != 2 && indexPath.row != 3) {
            // if we're opening another popover, then don't animate out - it looks strange
            [appDelegate.masterContainerViewController hidePopover];
        }
    } else {
        [appDelegate.storyPageControl.popoverController dismissPopoverAnimated:YES];
        appDelegate.storyPageControl.popoverController = nil;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

- (UITableViewCell *)makeFontSelectionTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    fontStyleSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    if (fontStyleSegment.selectedSegmentIndex == 0) {
        [fontStyleSegment setTitle:[@"Helvetica" uppercaseString] forSegmentAtIndex:0];
    } else {
        [fontStyleSegment setTitle:[@"Helv" uppercaseString] forSegmentAtIndex:0];
    }
    if (fontStyleSegment.selectedSegmentIndex == 1) {
        [fontStyleSegment setTitle:[@"Palatino" uppercaseString] forSegmentAtIndex:1];
    } else {
        [fontStyleSegment setTitle:[@"Pala" uppercaseString] forSegmentAtIndex:1];
    }
    if (fontStyleSegment.selectedSegmentIndex == 2) {
        [fontStyleSegment setTitle:[@"Georgia" uppercaseString] forSegmentAtIndex:2];
    } else {
        [fontStyleSegment setTitle:[@"Geor" uppercaseString] forSegmentAtIndex:2];
    }
    if (fontStyleSegment.selectedSegmentIndex == 3) {
        [fontStyleSegment setTitle:[@"Avenir" uppercaseString] forSegmentAtIndex:3];
    } else {
        [fontStyleSegment setTitle:[@"Aven" uppercaseString] forSegmentAtIndex:3];
    }
    if (fontStyleSegment.selectedSegmentIndex == 4) {
        [fontStyleSegment setTitle:[@"Av. Cond." uppercaseString] forSegmentAtIndex:4];
    } else {
        [fontStyleSegment setTitle:[@"AvCd" uppercaseString] forSegmentAtIndex:4];
    }
    [fontStyleSegment setTintColor:UIColorFromRGB(0x738570)];
    [fontStyleSegment
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    for (int i=0; i <= 4; i++) {
        [fontStyleSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:i];
    }
    fontStyleSegment.apportionsSegmentWidthsByContent = YES;
    
    [cell addSubview:fontStyleSegment];
    
    return cell;
}

- (UITableViewCell *)makeFontSizeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    
    fontSizeSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [fontSizeSegment setTitle:@"XS" forSegmentAtIndex:0];
    [fontSizeSegment setTitle:@"S" forSegmentAtIndex:1];
    [fontSizeSegment setTitle:@"M" forSegmentAtIndex:2];
    [fontSizeSegment setTitle:@"L" forSegmentAtIndex:3];
    [fontSizeSegment setTitle:@"XL" forSegmentAtIndex:4];
    [fontSizeSegment setTintColor:UIColorFromRGB(0x738570)];
    [fontSizeSegment
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    [fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    [fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:2];
    [fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:3];
    [fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:4];
    
    [cell addSubview:fontSizeSegment];
    
    return cell;
}

- (UITableViewCell *)makeLineSpacingTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    
    lineSpacingSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_xs"] forSegmentAtIndex:0];
    [lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_s"] forSegmentAtIndex:1];
    [lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_m"] forSegmentAtIndex:2];
    [lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_l"] forSegmentAtIndex:3];
    [lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_xl"] forSegmentAtIndex:4];
    [lineSpacingSegment setTintColor:UIColorFromRGB(0x738570)];
    
    [cell addSubview:lineSpacingSegment];
    
    return cell;
}


@end
