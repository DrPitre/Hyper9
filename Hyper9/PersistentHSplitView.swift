//
//  PersistentHSplitView.swift
//  Hyper9
//

import SwiftUI
import AppKit

/// A horizontal split view backed by `NSSplitViewController` so that the divider
/// position persists across launches via `splitView.autosaveName`.
///
/// SwiftUI's `HSplitView` does not save the divider position — using a
/// representable wrapper around AppKit gives us that for free.
struct PersistentHSplitView<Left: View, Right: View>: NSViewControllerRepresentable {
    let autosaveName: String
    let leftMinWidth: CGFloat
    let rightMinWidth: CGFloat
    let model: Turbo9ViewModel
    let left: Left
    let right: Right

    init(autosaveName: String,
         leftMinWidth: CGFloat = 360,
         rightMinWidth: CGFloat = 360,
         model: Turbo9ViewModel,
         @ViewBuilder left: () -> Left,
         @ViewBuilder right: () -> Right) {
        self.autosaveName = autosaveName
        self.leftMinWidth = leftMinWidth
        self.rightMinWidth = rightMinWidth
        self.model = model
        self.left = left()
        self.right = right()
    }

    func makeNSViewController(context: Context) -> NSSplitViewController {
        let svc = NSSplitViewController()
        svc.splitView.isVertical = true
        svc.splitView.dividerStyle = .thin
        svc.splitView.autosaveName = autosaveName

        let leftVC  = NSHostingController(rootView: AnyView(left.environmentObject(model)))
        let rightVC = NSHostingController(rootView: AnyView(right.environmentObject(model)))

        let leftItem  = NSSplitViewItem(viewController: leftVC)
        let rightItem = NSSplitViewItem(viewController: rightVC)
        leftItem.minimumThickness  = leftMinWidth
        rightItem.minimumThickness = rightMinWidth
        // Allow either side to grow; neither can collapse to zero because of the minimums above.
        leftItem.holdingPriority  = NSLayoutConstraint.Priority(250)
        rightItem.holdingPriority = NSLayoutConstraint.Priority(250)

        svc.addSplitViewItem(leftItem)
        svc.addSplitViewItem(rightItem)
        return svc
    }

    func updateNSViewController(_ nsViewController: NSSplitViewController, context: Context) {
        guard nsViewController.splitViewItems.count == 2 else { return }
        if let leftVC = nsViewController.splitViewItems[0].viewController as? NSHostingController<AnyView> {
            leftVC.rootView = AnyView(left.environmentObject(model))
        }
        if let rightVC = nsViewController.splitViewItems[1].viewController as? NSHostingController<AnyView> {
            rightVC.rootView = AnyView(right.environmentObject(model))
        }
    }
}
