//
//  PaymentViewController.swift
//  MyWok
//
//  Created by Maxence DUTHOO on 11/20/19.
//  Copyright © 2019 Altomobile. All rights reserved.
//

import UIKit
import Stripe
import SafariServices

class PaymentViewController: UIViewController {

    var order:Order?
    
    @IBAction func payAction(_ sender: Any) {
        //#1 - show the Stripe native AddCardViewController
        showAddCardViewController()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    //===----------------------------------------------------------------------===//
    // MARK: - Payment utils
    //===----------------------------------------------------------------------===//

    func showAddCardViewController(){
        let addCardViewController = STPAddCardViewController()
        addCardViewController.delegate = self
        addCardViewController.title = ""
        navigationController?.pushViewController(addCardViewController, animated: true)
    }
    
    func payWithPaymentMethod(paymentMethod: STPPaymentMethod){
        
        let orderToken = OrderToken.init(fromOrder: self.order!)

        orderToken.paymentMethodId = paymentMethod.stripeId
        orderToken.customerId = User.getUserId().description
        orderToken.locale = "fr"
        
        // #3 - Contact our backend, and try to charge the user (one time payment)
        DataManager.sharedInstance.order(order: orderToken, authCode: User.getUserAuthToken()!) { (dataResponse, response) in
            
            switch response.result {
                
            case .success:
                
                // #4 - API: /order -> call successful.
                
                if let paymentIntentClientSecret = dataResponse?.orderActionRequired?.payment_intent_client_secret {
                    
                    // #4.A - Payment requires 3DS verification
                    
                    self.handleNextAction(with: paymentIntentClientSecret)
                    
                }else{
                    
                    // #4.B - Order successful. Payment didn't require 3DS verification
                    
                    Debug.Log("DataManager.order() : Successful", showLog: true)
                    
                    Cart.shared.emptyCart()
                    //Show success view here
                    // ...
                }
                
            case .failure(let error):
                
                Debug.Error("orders/v2 : \(error.localizedDescription)", showLog: true)
                if response.response?.statusCode == 401 {
                    Debug.Log("401 error", showLog: true)
                } else if response.result.error?._domain == NSURLErrorDomain || response.result.error?._code == NSURLErrorNotConnectedToInternet {
                    self.showBanner(theme: .error, title: "Oups", message: "Problème de connection internet", position: .top)
                } else{
                    self.showBanner(theme: .error, title: "Oups", message: "Erreur serveur", position: .top)
                }
            }
        }
    }
    
    func handleNextAction(with paymentIntentClientSecret: String){
        
        STPPaymentConfiguration.shared().stripeAccount = "acct_17aTOmARwF8KSWdB"
        
        let paymentHandler = STPPaymentHandler.shared()
        
        // #5 - calling Stripe SDK: handleNextAction
        
        paymentHandler.handleNextAction(forPayment: paymentIntentClientSecret, authenticationContext: self, returnURL: nil) { status, paymentIntent, handleActionError in
            
            // #6 - Stripe SDK: handleNextAction response
            
            switch (status) {
            case .failed:
                Debug.Log("handleNextAction :: .failed:  message: \(handleActionError?.localizedDescription)", showLog: true)
                break
            case .canceled:
                Debug.Log("handleNextAction :: .canceled", showLog: true)
                break
            case .succeeded:
                Debug.Log("handleNextAction :: .succeeded", showLog: true)
                if let paymentIntent = paymentIntent, paymentIntent.status == STPPaymentIntentStatus.requiresConfirmation {
                    Debug.Log("Re-confirming PaymentIntent after handling action", showLog: true)
                    //                                self?.pay(withPaymentIntent: paymentIntent.stripeId)
                }
                else {
                    //                                self?.displayAlert(title: "Payment succeeded", message: paymentIntent?.description ?? "", restartDemo: true)
                }
                break
            @unknown default:
                fatalError()
                break
            }
        }
    }
    
}

//===----------------------------------------------------------------------===//
// MARK: - STPAddCardViewControllerDelegate
//===----------------------------------------------------------------------===//

extension PaymentViewController: STPAddCardViewControllerDelegate {
    
    func addCardViewControllerDidCancel(_ addCardViewController: STPAddCardViewController) {
        Debug.Log("user canceled", showLog: true)
    }
    
    func addCardViewController(_ addCardViewController: STPAddCardViewController, didCreatePaymentMethod paymentMethod: STPPaymentMethod, completion: @escaping STPErrorBlock) {
        
        // #2 - User entered a valid card. PaymentMethod returned by Stripe.
        navigationController?.popViewController(animated: true)
        payWithPaymentMethod(paymentMethod: paymentMethod)
    }
    
}

//===----------------------------------------------------------------------===//
// MARK: - STPAuthenticationContext
//===----------------------------------------------------------------------===//

extension PaymentViewController: STPAuthenticationContext {
    
    func authenticationPresentingViewController() -> UIViewController {
        Debug.Log("STPAuthenticationContext : authenticationPresentingViewController", showLog: true)
        return self
    }
    
    func prepare(forPresentation completion: @escaping STPVoidBlock) {
        Debug.Log("STPAuthenticationContext : prepareforPresentation", showLog: true)
    }
    
    func authenticationContextWillDismiss(_ viewController: UIViewController) {
        Debug.Log("STPAuthenticationContext : authenticationContextWillDismiss", showLog: true)
    }
    
    func configureSafariViewController(_ viewController: SFSafariViewController) {
        Debug.Log("configureSafariViewController", showLog: true)
    }
    
}
