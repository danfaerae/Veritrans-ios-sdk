//
//  VTPaymentListView.m
//  MidtransKit
//
//  Created by Arie on 6/17/16.
//  Copyright © 2016 Veritrans. All rights reserved.
//

#import "VTPaymentListView.h"
#import "MidtransUIListCell.h"
#import "MidtransItemCell.h"
#import "VTClassHelper.h"
#import <MidtransCoreKit/MidtransCoreKit.h>
#import "MidtransTransactionDetailViewController.h"

@interface VTPaymentListView()<UITableViewDelegate, UITableViewDataSource>
@property (nonatomic) NSArray *paymentMethods;
@property (nonatomic) BOOL shouldExpand;
@property (nonatomic,strong) MidtransPaymentRequestV2Response *responsePayment;
@property (nonatomic) NSArray *items;
@end

@implementation VTPaymentListView

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.shouldExpand = NO;
    
    self.headerView = [[VTBundle loadNibNamed:@"MidtransPaymentMethodHeader" owner:self options:nil] lastObject];
    [self.headerView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(headerTapped:)]];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerNib:[UINib nibWithNibName:@"MidtransUIListCell" bundle:VTBundle] forCellReuseIdentifier:@"MidtransUIListCell"];
}

- (void)setPaymentMethods:(NSArray *)paymentMethods andItems:(NSArray *)items withResponse:(MidtransPaymentRequestV2Response *)response {
    
    self.responsePayment = response;
    self.items = items;
    self.headerView.priceAmountLabel.text = [items formattedPriceAmount];
    
    self.paymentMethods = paymentMethods;
    [self.tableView reloadData];
}

- (void)headerTapped:(id)sender {
    MidtransTransactionDetailViewController *vc = [[MidtransTransactionDetailViewController alloc] init];
    [vc presentAtPositionOfView:self.headerView items:self.items];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.paymentMethods.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MidtransUIListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MidtransUIListCell"];
    if (!cell) {
        cell = [[MidtransUIListCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MidtransUIListCell"];
    }
    [cell configurePaymetnList:self.paymentMethods[indexPath.row] withFullPaymentResponse:self.responsePayment];
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    static dispatch_once_t onceToken = 0;
    dispatch_once(&onceToken, ^{
        [[SNPUITrackingManager shared] trackEventName:@"Page Scrolled" additionalParameters:@{@"Name":@"Payment list"}];
    });
}
#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
        MidtransPaymentListModel *paymentModel = self.paymentMethods[indexPath.row];
    if ([paymentModel.status isEqualToString:@"down"]) {
        return;
    }
    if ([self.delegate respondsToSelector:@selector(paymentListView:didSelectAtIndex:)]) {
        [self.delegate paymentListView:self didSelectAtIndex:indexPath.row];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return self.headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 50;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
     MidtransPaymentListModel *paymentModel = self.paymentMethods[indexPath.row];
    if ([paymentModel.status isEqualToString:@"down"]) {
        return 120;
    }
   return 80;
}

@end
