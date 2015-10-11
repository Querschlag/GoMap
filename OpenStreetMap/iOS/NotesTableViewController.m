//
//  NotesTableViewController.m
//  Go Map!!
//
//  Created by Bryce on 11/4/14.
//  Copyright (c) 2014 Bryce. All rights reserved.
//

#import <MapKit/MapKit.h>

#import "MapView.h"
#import "OsmNotesDatabase.h"
#import "NotesTableViewController.h"


@interface NotesCommentCell : UITableViewCell
@property (strong,nonatomic)	IBOutlet	UILabel		*	date;
@property (strong,nonatomic)	IBOutlet	UILabel		*	user;
@property (strong,nonatomic)	IBOutlet	UITextView	*	comment;
@property (strong,nonatomic)	IBOutlet	UIView		*	commentBackground;
@end
@implementation NotesCommentCell
@end

@interface NotesResolveCell : UITableViewCell
@property (strong,nonatomic)	IBOutlet	UITextView		*	text;
@property (strong,nonatomic)	IBOutlet	UIButton		*	commentButton;
@property (strong,nonatomic)	IBOutlet	UIButton		*	resolveButton;
@end
@implementation NotesResolveCell
@end


@implementation NotesTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

	// add extra space at bottom so keyboard doesn't cover elements
	UIEdgeInsets rc = self.tableView.contentInset;
	rc.bottom += 70;
	self.tableView.contentInset = rc;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return self.note.comments ? 2 : 1;
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if ( self.note.comments && section == 0 )
		return @"Note History";
	else
		return @"Update";
}

-(NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	if ( section == 1 ) {
		return @"\n\n\n\n\n\n\n\n\n";
	}
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return self.note.comments && section == 0 ? self.note.comments.count : 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ( self.note.comments && indexPath.section == 0 ) {
		NotesCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"noteCommentCell" forIndexPath:indexPath];
		OsmNoteComment * comment = self.note.comments[ indexPath.row ];
		cell.date.text		= comment.date;
		cell.user.text		= [NSString stringWithFormat:@"%@ - %@", comment.user ?: @"anonymous", comment.action];
		if ( comment.text.length == 0 ) {
			cell.commentBackground.hidden	= YES;
			cell.comment.text				= nil;
		} else {
			cell.commentBackground.hidden					= NO;
			cell.commentBackground.layer.cornerRadius		= 5;
			cell.commentBackground.layer.backgroundColor	= [UIColor colorWithRed:0.9 green:0.9 blue:1.0 alpha:1.0].CGColor;
			cell.commentBackground.layer.borderColor		= UIColor.blackColor.CGColor;
			cell.commentBackground.layer.borderWidth		= 1.0;
			cell.commentBackground.layer.masksToBounds		= YES;
			cell.comment.text								= comment.text;
		}
		return cell;
	} else if ( indexPath.row == 0 ) {
		NotesResolveCell *cell = (id) [tableView dequeueReusableCellWithIdentifier:@"noteResolveCell" forIndexPath:indexPath];
		cell.text.layer.cornerRadius	= 5.0;
		cell.text.layer.borderColor		= UIColor.blackColor.CGColor;
		cell.text.layer.borderWidth		= 1.0;
		cell.text.delegate				= self;
		cell.text.text					= _newComment;
		cell.commentButton.enabled		= NO;
		cell.resolveButton.enabled		= self.note.comments != nil;
		return cell;
	} else {
		UITableViewCell *cell = (id) [tableView dequeueReusableCellWithIdentifier:@"noteDirectionsCell" forIndexPath:indexPath];
		return cell;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[self.view endEditing:YES];

	if ( self.note.comments && indexPath.section == 0 ) {
		// ignore
	} else if ( indexPath.row == 1 ) {
		// get directions
		CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(self.note.lat, self.note.lon);
		MKPlacemark * placemark = [[MKPlacemark alloc] initWithCoordinate:coordinate addressDictionary:nil];
		MKMapItem * note = [[MKMapItem alloc] initWithPlacemark:placemark];
		[note setName:@"OSM Note"];
		MKMapItem * current = [MKMapItem mapItemForCurrentLocation];
		NSDictionary * options = @{ MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving };
		[MKMapItem openMapsWithItems:@[current, note] launchOptions:options];
	}
}


-(void)commentAndResolve:(BOOL)resolve sender:(id)sender
{
	[self.view endEditing:YES];

	NotesResolveCell * cell = (id)[sender superview];
	while ( cell && ![cell isKindOfClass:[NotesResolveCell class]] )
		cell = (id) [cell superview];
	if ( cell ) {
		NSString * s = [cell.text.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		_alert = [[UIAlertView alloc] initWithTitle:@"Updating Note..." message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
		[_alert show];
		[self.mapView.notesDatabase updateNote:self.note close:resolve comment:s completion:^(OsmNote * newNote, NSString *errorMessage) {
			[_alert dismissWithClickedButtonIndex:0 animated:YES];
			_alert = nil;
			if ( newNote ) {
				self.note = newNote;
				[self done:nil];
				[self.mapView refreshNoteButtonsFromDatabase];
			} else {
				UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMessage delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:NULL];
				[alert show];
			}
		}];
	}
}

- (IBAction)doComment:(id)sender
{
	[self commentAndResolve:NO sender:sender];
}

- (IBAction)doResolve:(id)sender
{
	[self commentAndResolve:YES sender:sender];
}

- (void)textViewDidChange:(UITextView *)textView
{
	NotesResolveCell * cell = (id)[textView superview];
	while ( cell && ![cell isKindOfClass:[NotesResolveCell class]] )
		cell = (id) [cell superview];
	if ( cell ) {
		_newComment = cell.text.text;
		NSString * s = [_newComment stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		cell.commentButton.enabled = s.length > 0;
	}
}

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ( self.note.comments && indexPath.section == 0 ) {
		OsmNoteComment * comment = self.note.comments[ indexPath.row ];

		if ( comment.text.length > 0 ) {
			NSMutableParagraphStyle * paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
			[paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
			NSDictionary * attrs = @{
									 NSFontAttributeName : [UIFont systemFontOfSize:17],
									 NSParagraphStyleAttributeName : paragraphStyle
									 };
			
			CGRect rc = [comment.text boundingRectWithSize:CGSizeMake(self.view.bounds.size.width-60-20, 5000) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:attrs context:nil];
			return ceil(rc.size.height) + 85;
		} else {
			return 55;
		}
	} else if ( indexPath.row == 0 ) {
		return 176;
	} else {
		return 44;
	}
}

- (IBAction)done:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
