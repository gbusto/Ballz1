//
//  AdHandler.swift
//  Ballz1
//
//  Created by Gabriel Busto on 12/7/18.
//  Copyright © 2018 Self. All rights reserved.
//

import Foundation

class AdHandler {
    static private var production = true
    static private var ADMOB_ID = "ca-app-pub-4215818305477568~5618851558"
    static private var BANNER_AD_ID = "ca-app-pub-4215818305477568/4449116409"
    static private var INTERSTITIAL_AD_ID = "ca-app-pub-4215818305477568/6603865820"
    static private var REWARD_AD_ID = "ca-app-pub-4215818305477568/6867110770"
    
    static private var BANNER_AD_TEST_ID = "ca-app-pub-3940256099942544/2934735716"
    static private var INTERSTITIAL_AD_TEST_ID = "ca-app-pub-3940256099942544/5135589807"
    // This test ad code is for static interstitial ads; the one above is for videos
    //static private var INTERSTITIAL_AD_TEST_ID = "ca-app-pub-3940256099942544/4411468910"
    static private var REWARD_AD_TEST_ID = "ca-app-pub-3940256099942544/1712485313"
    
    static public func getAdModID() -> String {
        return AdHandler.ADMOB_ID
    }
    
    static public func getBannerAdID() -> String {
        if AdHandler.production {
            return AdHandler.BANNER_AD_ID
        }
        return AdHandler.BANNER_AD_TEST_ID
    }
    
    static public func getInterstitialAdID() -> String {
        if AdHandler.production {
            return AdHandler.INTERSTITIAL_AD_ID
        }
        return AdHandler.INTERSTITIAL_AD_TEST_ID
    }
    
    static public func getRewardAdID() -> String {
        if AdHandler.production {
            return AdHandler.REWARD_AD_ID
        }
        return AdHandler.REWARD_AD_TEST_ID
    }
    
    static public func getTestDevices() -> [String] {
        if AdHandler.production {
            return []
        }
        return ["a543785da9d827253d37825f6ce98d31"]
    }
}
