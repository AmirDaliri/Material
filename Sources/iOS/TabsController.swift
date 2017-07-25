/*
 * Copyright (C) 2015 - 2017, Daniel Dahan and CosmicMind, Inc. <http://cosmicmind.com>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *	*	Redistributions of source code must retain the above copyright notice, this
 *		list of conditions and the following disclaimer.
 *
 *	*	Redistributions in binary form must reproduce the above copyright notice,
 *		this list of conditions and the following disclaimer in the documentation
 *		and/or other materials provided with the distribution.
 *
 *	*	Neither the name of CosmicMind nor the names of its
 *		contributors may be used to endorse or promote products derived from
 *		this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit

fileprivate var TabItemKey: UInt8 = 0

open class TabItem: FlatButton {}

@objc(TabBarAlignment)
public enum TabBarAlignment: Int {
    case top
    case bottom
    case hidden
}

extension UIViewController {
    /// tabItem reference.
    public private(set) var tabItem: TabItem {
        get {
            return AssociatedObject.get(base: self, key: &TabItemKey) {
                return TabItem()
            }
        }
        set(value) {
            AssociatedObject.set(base: self, key: &TabItemKey, value: value)
        }
    }
}

extension UIViewController {
    /**
     A convenience property that provides access to the TabsController.
     This is the recommended method of accessing the TabsController
     through child UIViewControllers.
     */
    public var tabsController: TabsController? {
        var viewController: UIViewController? = self
        while nil != viewController {
            if viewController is TabsController {
                return viewController as? TabsController
            }
            viewController = viewController?.parent
        }
        return nil
    }
}

open class TabsController: UIViewController {
    /// The TabBar used to switch between view controllers.
    @IBInspectable
    open fileprivate(set) var tabBar: TabBar?
    
    @IBInspectable
    public let container = UIView()
    
    /// An Array of UIViewControllers.
    open var viewControllers: [UIViewController] {
        didSet {
            oldValue.forEach { [weak self] in
                self?.removeViewController(viewController: $0)
            }
            
            prepareTabBar()
            prepareContainer()
            prepareViewControllers()
            layoutSubviews()
        }
    }
    
    /// A reference to the currently selected view controller index value.
    @IBInspectable
    open var selectedIndex = 0
    
    /// The tabBar alignment.
    open var tabBarAlignment = TabBarAlignment.bottom {
        didSet {
            layoutSubviews()
        }
    }
    
    /// The transition type used during a transition.
    open var motionTransitionType = MotionTransitionType.fade
    
    /**
     An initializer that initializes the object with a NSCoder object.
     - Parameter aDecoder: A NSCoder instance.
     */
    public required init?(coder aDecoder: NSCoder) {
        viewControllers = []
        super.init(coder: aDecoder)
    }
    
    /**
     An initializer that accepts an Array of UIViewControllers.
     - Parameter viewControllers: An Array of UIViewControllers.
     */
    public init(viewControllers: [UIViewController], selectedIndex: Int = 0) {
        self.viewControllers = viewControllers
        self.selectedIndex = selectedIndex
        super.init(nibName: nil, bundle: nil)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutSubviews()
    }
    
    /**
     To execute in the order of the layout chain, override this
     method. `layoutSubviews` should be called immediately, unless you
     have a certain need.
     */
    open func layoutSubviews() {
        layoutTabBar()
        layoutContainer()
        layoutViewController(at: selectedIndex)
    }
    
    /**
     Prepares the view instance when intialized. When subclassing,
     it is recommended to override the prepare method
     to initialize property values and other setup operations.
     The super.prepare method should always be called immediately
     when subclassing.
     */
    open func prepare() {
        view.contentScaleFactor = Screen.scale
        prepareContainer()
        prepareTabBar()
        prepareViewControllers()
    }
}

extension TabsController {
    /**
     Prepares the tabBar buttons.
     - Parameter _ buttons: An Array of UIButtons.
     */
    fileprivate func prepareTabBarButtons(_ buttons: [UIButton]) {
        guard let v = tabBar else {
            return
        }
        
        v.buttons = buttons
        
        for b in v.buttons {
            b.removeTarget(self, action: #selector(handleTabBarButton(button:)), for: .touchUpInside)
            b.addTarget(self, action: #selector(handleTabBarButton(button:)), for: .touchUpInside)
        }
    }
    
    /// Prepares the TabBar.
    fileprivate func prepareTabBar() {
        var buttons = [UIButton]()
        
        for v in viewControllers {
            let button = v.tabItem as UIButton
            v.isMotionEnabled = true
            buttons.append(button)
        }
        
        guard 0 < buttons.count else {
            tabBar?.removeFromSuperview()
            tabBar = nil
            return
        }
        
        guard nil == tabBar else {
            prepareTabBarButtons(buttons)
            return
        }
        
        tabBar = TabBar()
        tabBar?.isLineAnimated = false
        tabBar?.lineAlignment = .top
        view.addSubview(tabBar!)
        
        prepareTabBarButtons(buttons)
    }
    
    /// Prepares the container view.
    fileprivate func prepareContainer() {
        view.addSubview(container)
    }
    
    /// Prepares all the view controllers. 
    fileprivate func prepareViewControllers() {
        let n = viewControllers.count
        
        for i in 0..<n {
            guard i != selectedIndex else {
                continue
            }
            
            prepareViewController(at: i)
        }
        
        prepareViewController(at: selectedIndex)
    }
    
    /**
     Loads a view controller based on its index in the viewControllers Array
     and adds it as a child view controller.
     - Parameter at index: An Int for the viewControllers index.
     */
    fileprivate func prepareViewController(at index: Int) {
        let vc = viewControllers[index]
        
        guard !childViewControllers.contains(vc) else {
            return
        }
        
        addChildViewController(vc)
        vc.didMove(toParentViewController: self)
        vc.view.clipsToBounds = true
        vc.view.contentScaleFactor = Screen.scale
        container.addSubview(vc.view)
    }
}

extension TabsController {
    /// Layout the container view.
    fileprivate func layoutContainer() {
        guard let v = tabBar else {
            container.frame = view.bounds
            return
        }
        
        let p = v.height
        let y = view.height - p
        
        switch tabBarAlignment {
        case .top:
            container.y = p
            container.height = y
        case .bottom:
            container.y = 0
            container.height = y
        case .hidden:
            container.y = 0
            container.height = view.height
        }
        
        container.width = view.width
    }
    
    /// Layout the TabBar.
    fileprivate func layoutTabBar() {
        guard let v = tabBar else {
            return
        }
        
        let y = view.height - v.height
        
        v.width = view.width
        
        switch tabBarAlignment {
        case .top:
            v.isHidden = false
            v.y = 0
        case .bottom:
            v.isHidden = false
            v.y = y
        case .hidden:
            v.isHidden = true
        }
    }
    
    /// Layout the view controller at the given index.
    fileprivate func layoutViewController(at index: Int) {
        viewControllers[index].view.frame.size = container.bounds.size
    }
}

extension TabsController {
    /**
     Removes the view controller as a child view controller with
     the given index.
     - Parameter at index: An Int for the view controller position.
     */
    fileprivate func removeViewController(at index: Int) {
        let v = viewControllers[index]
        
        guard childViewControllers.contains(v) else {
            return
        }
        
        removeViewController(viewController: v)
    }
    
    /**
     Removes a given view controller from the childViewControllers array.
     - Parameter at index: An Int for the view controller position.
     */
    fileprivate func removeViewController(viewController: UIViewController) {
        viewController.willMove(toParentViewController: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParentViewController()
    }
}

extension TabsController {
    /**
     Handles the pageTabBarButton.
     - Parameter button: A UIButton.
     */
    @objc
    fileprivate func handleTabBarButton(button: UIButton) {
        guard let v = tabBar else {
            return
        }
        
        guard let i = v.buttons.index(of: button) else {
            return
        }
        
        guard i != selectedIndex else {
            return
        }
        
        let fvc = viewControllers[selectedIndex]
        let tvc = viewControllers[i]
        
        tvc.view.frame.size = container.bounds.size
        tvc.motionModalTransitionType = motionTransitionType
        
        Motion.shared.transition(from: fvc, to: tvc, in: container)
        
        selectedIndex = i
        
        tabBar?.select(at: selectedIndex)
    }
}
