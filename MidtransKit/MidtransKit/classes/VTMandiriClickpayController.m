//
//  VTClickpayController.m
//  MidtransKit
//
//  Created by Nanang Rafsanjani on 2/29/16.
//  Copyright © 2016 Veritrans. All rights reserved.
//

#import "VTMandiriClickpayController.h"
#import "VTClassHelper.h"
#import "MidtransUITextField.h"
#import "MidtransUIHudView.h"
#import "MidtransUICardFormatter.h"
#import <MidtransCoreKit/MidtransCoreKit.h>
#import "UIViewController+HeaderSubtitle.h"
#import "VTSubGuideController.h"
static NSString* const ClickpayAPPLI = @"3";

@interface VTMandiriClickpayController () <MidtransUITextFieldDelegate>

@property (strong, nonatomic) IBOutlet MidtransUITextField *debitNumberTextField;
@property (strong, nonatomic) IBOutlet MidtransUITextField *tokenTextField;
@property (strong, nonatomic) IBOutlet UILabel *amountLabel;
@property (strong, nonatomic) IBOutlet UILabel *appliLabel;
@property (strong, nonatomic) IBOutlet UILabel *input1Label;
@property (strong, nonatomic) IBOutlet UILabel *input2Label;
@property (strong, nonatomic) IBOutlet UILabel *input3Label;
@property (weak, nonatomic) IBOutlet UIView *instructionPage;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *instructionviewHeightConstraints;

@property (nonatomic) MidtransUICardFormatter *ccFormatter;

@end

@implementation VTMandiriClickpayController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = self.paymentMethod.title;
    [self.view layoutIfNeeded];
    [self.keyTokenView setNeedsUpdateConstraints];
    [self.keyTokenView updateConstraintsIfNeeded];
    [UIView animateWithDuration:2.0f delay:0.0f options:UIViewAnimationOptionLayoutSubviews animations:^{
        self.keyTokeViewHeightConstraints.constant = 40;
        self.keyTokenView.hidden = NO;
        [self.view layoutIfNeeded];
    } completion:nil];
    
    [self addNavigationToTextFields:@[self.debitNumberTextField, self.tokenTextField]];
    
    self.debitNumberTextField.delegate = self;
    self.tokenTextField.delegate = self;
    
    self.debitNumberTextField.placeholder = [VTClassHelper getTranslationFromAppBundleForString:@"creditcard.Mandiri Debit Card placeholder"];
    
    self.appliLabel.text = ClickpayAPPLI;
    self.input1Label.text = [MidtransMandiriClickpayHelper generateInput1FromCardNumber:self.debitNumberTextField.text];
    self.input2Label.text = [MidtransMandiriClickpayHelper generateInput2FromGrossAmount:self.token.transactionDetails.grossAmount];
    self.input3Label.text = [MidtransMandiriClickpayHelper generateInput3];
    
    self.amountLabel.text = self.token.transactionDetails.grossAmount.formattedCurrencyNumber;
    self.mandiriClickpayStepLabel.text = [NSString stringWithFormat:[VTClassHelper getTranslationFromAppBundleForString:@"%@ step by step"], self.paymentMethod.title];
    self.keyTokenLabel.text = [VTClassHelper getTranslationFromAppBundleForString:@"Key token device is required for this payment method"];
    self.totalAmountLabel.text = [VTClassHelper getTranslationFromAppBundleForString:@"total.amount"];
    [self.confirmButton setTitle:[VTClassHelper getTranslationFromAppBundleForString:@"confirm.payment"] forState:UIControlStateNormal];
    
    NSString* filenameByLanguage = [[MidtransDeviceHelper deviceCurrentLanguage] stringByAppendingFormat:@"_%@", self.paymentMethod.internalBaseClassIdentifier];
    NSString *guidePath = [VTBundle pathForResource:filenameByLanguage ofType:@"plist"];
    if (guidePath == nil) {
        guidePath = [VTBundle pathForResource:[NSString stringWithFormat:@"en_%@",self.paymentMethod.internalBaseClassIdentifier] ofType:@"plist"];
    }
    NSArray *instructions = [VTClassHelper instructionsFromFilePath:guidePath];
    VTSubGuideController *vc = [[VTSubGuideController alloc] initWithInstructions:instructions];
    self.instructionviewHeightConstraints.constant = vc.view.frame.size.height-200;
    [self.view updateConstraintsIfNeeded];
    [self addSubViewController:vc toView:self.instructionPage];

    
    self.ccFormatter = [[MidtransUICardFormatter alloc] initWithTextField:self.debitNumberTextField];
    self.ccFormatter.numberLimit = 16;
}

- (IBAction)confirmPaymentPressed:(UIButton *)sender {
    self.tokenTextField.warning = nil;
    self.debitNumberTextField.warning = nil;
    if ([self.debitNumberTextField.text SNPisValidClickpayNumber] == NO) {
        self.debitNumberTextField.warning = [VTClassHelper getTranslationFromAppBundleForString:@"clickpay.invalid-number"];
        return;
    }
    
    if ([self.tokenTextField.text SNPisValidClickpayToken] == NO) {
        self.tokenTextField.warning = [VTClassHelper getTranslationFromAppBundleForString:@"clickpay.invalid-token"];
        return;
    }
    
    [self showLoadingWithText:[VTClassHelper getTranslationFromAppBundleForString:@"Processing your payment"]];
    
    MidtransPaymentMandiriClickpay *paymentDetails = [[MidtransPaymentMandiriClickpay alloc] initWithCardNumber:self.debitNumberTextField.text
                                                                                                  clickpayToken:self.tokenTextField.text];
    
    MidtransTransaction *transaction = [[MidtransTransaction alloc] initWithPaymentDetails:paymentDetails
                                                                                     token:self.token];
    
    [[MidtransMerchantClient shared] performTransaction:transaction
                                             completion:^(MidtransTransactionResult *result, NSError *error) {
        [self hideLoading];
        if (error) {
            [self handleTransactionError:error];
        } else {
            [self handleTransactionSuccess:result];
        }
    }];
}

- (IBAction)clickpayHelpPressed:(UIButton *)sender {
    [self showGuideViewController];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if ([textField isEqual:self.debitNumberTextField]) {
        //generate challenge 1 number
        NSMutableString *fieldText = textField.text.mutableCopy;
        [fieldText replaceCharactersInRange:range withString:string];
        self.input1Label.text = [MidtransMandiriClickpayHelper generateInput1FromCardNumber:fieldText];
        
        //reformat debit number
        return [self.ccFormatter updateTextFieldContentAndPosition];
    } else if ([textField isEqual:self.tokenTextField]) {
        NSInteger clickpayTokenLenth = 6;
        return [textField filterNumericWithString:string range:range length:clickpayTokenLenth];
    }
    return YES;
}

@end
