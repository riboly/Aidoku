//
//  NavigationController.swift
//  Aidoku (iOS)
//
//  Created by axiel7 on 11/02/2024.
//

import UIKit

class NavigationController: UINavigationController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Own the delegate so the edge-swipe-back fix below runs for
        // every pushed screen. (A pushed view controller may still
        // replace the delegate for its own flow, e.g.
        // NewSourceViewController; that only opts that stack out.)
        delegate = self
    }

    // This is a workaround to fix an iOS bug that occurs when mixing UIKit with SwiftUI,
    // that causes the current TabBarItem title to be lost when navigating inside SwiftUI views.
    // See: https://stackoverflow.com/questions/62662313/uitabbar-containing-swiftui-view
    private var storedTabBarItem: UITabBarItem?
    override var tabBarItem: UITabBarItem! {
        get { storedTabBarItem ?? super.tabBarItem }
        set { storedTabBarItem = newValue }
    }

    // fix for incognito mode banner status bar text being the wrong color sometimes on ios 26+
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if AppSettings.general.incognitoMode.get() {
            traitCollection.userInterfaceStyle == .light ? .darkContent : .lightContent
        } else {
            .default
        }
    }
}

// MARK: - Edge-swipe-back priority
extension NavigationController: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // SwiftUI Lists (library, manga details, chapter list, settings)
        // put a scroll view under the user's finger, and its pan gesture
        // often claims a touch starting at the left edge before the
        // system's edge-swipe-back gesture can begin, so going back
        // takes several tries. Make every scroll pan wait for the
        // pop gesture to fail first: a real edge swipe then wins, and
        // any other touch fails the pop gesture within a few points of
        // movement, so scrolling is not delayed. Taps and buttons are
        // untouched — this only orders the two pan gestures.
        guard let popGesture = interactivePopGestureRecognizer else { return }
        wireScrollPans(in: viewController.view, toRequireFailureOf: popGesture)
    }

    private func wireScrollPans(in view: UIView, toRequireFailureOf gesture: UIGestureRecognizer) {
        if let scrollView = view as? UIScrollView {
            scrollView.panGestureRecognizer.require(toFail: gesture)
        }
        for subview in view.subviews {
            wireScrollPans(in: subview, toRequireFailureOf: gesture)
        }
    }
}
