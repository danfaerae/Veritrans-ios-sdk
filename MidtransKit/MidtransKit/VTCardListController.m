//
//  VTCardListController.m
//  MidtransKit
//
//  Created by Nanang Rafsanjani on 2/23/16.
//  Copyright © 2016 Veritrans. All rights reserved.
//

#import "VTCardListController.h"

#import "PushAnimator.h"

#import "VTClassHelper.h"
#import "VTAddCardController.h"
#import "VTTwoClickController.h"
#import "VTTextField.h"
#import "VTCCBackView.h"
#import "VTCCFrontView.h"
#import "VTHudView.h"
#import "VTPaymentStatusViewModel.h"
#import "VTCardControllerConfig.h"
#import "VTSuccessStatusController.h"
#import "VTErrorStatusController.h"
#import "VTConfirmPaymentController.h"
#import "UIViewController+Modal.h"
#import <MidtransCoreKit/VTClient.h>
#import <MidtransCoreKit/VTMerchantClient.h>
#import <MidtransCoreKit/VTPaymentCreditCard.h>
#import <MidtransCoreKit/VTTransactionDetails.h>

//#import <CardIO.h>

@interface VTCardListController () <VTCardCellDelegate, VTAddCardControllerDelegate, UINavigationControllerDelegate, UIActionSheetDelegate/*, CardIOPaymentViewControllerDelegate*/>
@property (strong, nonatomic) IBOutlet UIPageControl *pageControl;
@property (strong, nonatomic) IBOutlet UIView *emptyCardView;
@property (strong, nonatomic) IBOutlet UIView *cardsView;
@property (strong, nonatomic) IBOutlet UILabel *amountLabel;
@property (strong, nonatomic) IBOutlet UIButton *addCardButton;
@property (nonatomic) IBOutlet NSLayoutConstraint *addCardButtonHeight;

@property (nonatomic) NSMutableArray *cards;
@property (nonatomic) BOOL editingCell;
@end

@implementation VTCardListController {
    VTHudView *_hudView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = UILocalizedString(@"creditcard.list.title", nil);
    [self.pageControl setNumberOfPages:0];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cardsUpdated:) name:VTMaskedCardsUpdated object:nil];
    self.amountLabel.text = self.token.transactionDetails.grossAmount.formattedCurrencyNumber;
    [self updateView];
    // [self reloadMaskedCards];
    [self.collectionView registerNib:[UINib nibWithNibName:@"VTCardCell" bundle:VTBundle] forCellWithReuseIdentifier:@"VTCardCell"];
    [self.collectionView addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(startEditing:)]];
    self.editingCell = false;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setEditingCell:(BOOL)editingCell {
    _editingCell = editingCell;
    [self.collectionView reloadData];
}

- (void)startEditing:(id)sender {
    self.editingCell = true;
}

- (void)reloadMaskedCards {
    [self showLoadingHud];
    __weak VTCardListController *weakSelf = self;
    [[VTMerchantClient sharedClient] fetchMaskedCardsWithCompletion:^(NSArray *maskedCards, NSError *error) {
        [self hideLoadingHud];
        if (maskedCards) {
            weakSelf.cards = [NSMutableArray arrayWithArray:maskedCards];
        } else {
            [self showAlertViewWithTitle:@"Error"
                              andMessage:error.localizedDescription
                          andButtonTitle:@"Close"];
        }
        
        [self updateView];
    }];
}


- (void)updateView {
    if (self.cards.count) {
        self.addCardButton.hidden = true;
        self.addCardButtonHeight.constant = 0;
        self.emptyCardView.hidden = true;
        self.cardsView.hidden = false;
    } else {
        self.addCardButton.hidden = false;
        self.addCardButtonHeight.constant = 50.;
        self.emptyCardView.hidden = false;
        self.cardsView.hidden = true;
    }
}

- (void)cardsUpdated:(id)sender {
    [self reloadMaskedCards];
}

- (void)setCards:(NSMutableArray *)cards {
    _cards = cards;
    
    [self.pageControl setNumberOfPages:[cards count]];
    [self.collectionView reloadData];
}

- (IBAction)addCardPressed:(id)sender {
    VTAddCardController *vc = [[VTAddCardController alloc] initWithToken:self.token];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:YES];
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                  animationControllerForOperation:(UINavigationControllerOperation)operation
                                               fromViewController:(UIViewController*)fromVC
                                                 toViewController:(UIViewController*)toVC {
    if (operation == UINavigationControllerOperationPush) {
        return [PushAnimator new];;
    }
    
    return nil;
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.cards count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    VTCardCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"VTCardCell" forIndexPath:indexPath];
    cell.delegate = self;
    cell.maskedCard = _cards[indexPath.row];
    cell.editing = self.editingCell;
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pageWidth = scrollView.frame.size.width; // you need to have a **iVar** with getter for scrollView
    float fractionalPage = scrollView.contentOffset.x / pageWidth;
    NSInteger page = lround(fractionalPage);
    self.pageControl.currentPage = page; // you need to have a **iVar** with getter for pageControl
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.editingCell) {
        self.editingCell = false; return;
    }
    
    VTMaskedCreditCard *maskedCard = _cards[indexPath.row];
    
    if ([[VTCardControllerConfig sharedInstance] enableOneClick]) {
        VTConfirmPaymentController *vc = [[VTConfirmPaymentController alloc] initWithCardNumber:maskedCard.maskedNumber
                                                                                    grossAmount:self.token.transactionDetails.grossAmount];
        [vc showOnViewController:self.navigationController clickedButtonsCompletion:^(NSUInteger selectedIndex) {
            if (selectedIndex == 1) {
                [self payWithToken:maskedCard.savedTokenId];
            }
        }];
    } else {
        VTTwoClickController *vc = [[VTTwoClickController alloc] initWithToken:self.token
                                                                    maskedCard:maskedCard];
        [self.navigationController setDelegate:self];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma mark - Helper

- (void)payWithToken:(NSString *)token {
    [_hudView showOnView:self.navigationController.view];
    
    VTPaymentCreditCard *paymentDetail =
    [[VTPaymentCreditCard alloc] initWithFeature:VTCreditCardPaymentFeatureOneClick
                                           token:token];
    VTTransaction *transaction =
    [[VTTransaction alloc] initWithPaymentDetails:paymentDetail
                                            token:self.token];
    [[VTMerchantClient sharedClient] performTransaction:transaction completion:^(VTTransactionResult *result, NSError *error) {
        [_hudView hide];
        
        if (error) {
            [self handleTransactionError:error];
        } else {
            [self handleTransactionSuccess:result];
        }
    }];
}

#pragma mark - VTAddCardControllerDelegate

- (void)viewController:(VTAddCardController *)viewController didRegisterCard:(VTMaskedCreditCard *)registeredCard {
    [self.navigationController popViewControllerAnimated:YES];
    [self reloadMaskedCards];
}

#pragma mark - VTCardCellDelegate

- (void)cardCellShouldRemoveCell:(VTCardCell *)cell {
    NSIndexPath *indexPath = [_collectionView indexPathForCell:cell];
    VTMaskedCreditCard *card = _cards[indexPath.row];
    [[VTMerchantClient sharedClient] deleteMaskedCard:card completion:^(BOOL success, NSError *error) {
        if (success) {
            [_cards removeObjectAtIndex:indexPath.row];
            [_collectionView deleteItemsAtIndexPaths:@[indexPath]];
            [_pageControl setNumberOfPages:[_cards count]];
            
            self.editingCell = false;
            
        } else {
            [self showAlertViewWithTitle:@"Error"
                              andMessage:error.localizedDescription
                          andButtonTitle:@"Close"];
        }
        
        [self updateView];
    }];
}

#pragma MARK - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(self.view.frame.size.width, 200);
}

@end
