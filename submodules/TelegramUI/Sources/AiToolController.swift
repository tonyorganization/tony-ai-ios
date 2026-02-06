import UIKit
import AsyncDisplayKit
import Display
import AccountContext
import TelegramPresentationData
import Foundation
import TelegramCore
import SwiftSignalKit
import SettingsUI
import AppBundle

final class AiToolController: ViewController {
	
	// Context and theme
	private let context: AccountContext
	private var presentationData: PresentationData
	private var presentationDataDisposable: Disposable?
	
	// Views
	private let navBarTitleNode : AiNavBarTitleNode

	private var aiNode: AiToolControllerNode {
		return self.displayNode as! AiToolControllerNode
	}

	
	// Args
	private let userInputText: String?
	private let translatedText: String?
	public var onTextApplied: ((String) -> Void)?
	private var listDisposable: Disposable?
	public var onTextTranslated: ((String) -> Void)?
	let fetchLanguages : Signal<[LanguageItemInfo]?, NoError>
	


	public init(
		context: AccountContext,
		userInputText: String? = nil,
		translatedText: String? = nil
	) {
		//
		self.context = context
		self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
		
		//
		self.navBarTitleNode = AiNavBarTitleNode(context: context)
		
		//
		self.userInputText = userInputText
		self.translatedText = translatedText
		self.fetchLanguages = context.sharedContext.fetchLanguages()
		
		super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
		
		self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(
			backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back,
			target: self,
			action: #selector(self.closePressed)
		)
		
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: self.presentationData.strings.Theme_Context_Apply,
			style: .plain,
			target: self,
			action: #selector(self.applyTapped)
		)
		
		self.navigationItem.titleView = navBarTitleNode.view
		self.updateThemeAndStrings(theme: self.presentationData.theme)
		self.presentationDataDisposable = (context.sharedContext.presentationData
										   |> deliverOnMainQueue).start(next: { [weak self] presentationData in
			if let strongSelf = self {
				let previousTheme = strongSelf.presentationData.theme
				let previousStrings = strongSelf.presentationData.strings
				if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
					strongSelf.updateThemeAndStrings(theme: presentationData.theme)
				}
				strongSelf.presentationData = presentationData
			}
		}).strict()
		
	}
	
	deinit {
		self.presentationDataDisposable?.dispose()
	}
	
	required public init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override public func loadDisplayNode() {
		self.displayNode = AiToolControllerNode(
			context: self.context,
			controller: self
		)
		self.displayNodeDidLoad()
	}
	
	@objc private func closePressed() {
		if let nav = self.navigationController, nav.viewControllers.first != self {
			self.navigationController?.popViewController(animated: true)
		} else {
			dismiss(animated: true, completion: nil)
		}
	}
	
	@objc private func applyTapped() {
		print("Apply button tapped")
		
	}
	
	private func updateThemeAndStrings(theme: PresentationTheme){
		if let navBar = self.navigationBar {
			navBar.updateColor(color: theme.custom.modalBackground)
		}
	}
	
	override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
		super.containerLayoutUpdated(layout, transition: transition)
		let actualNavigationBarHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
		self.navBarTitleNode.containerLayoutUpdated(
			layout,
			navigationBarHeight: self.cleanNavigationHeight,
			actualNavigationBarHeight: actualNavigationBarHeight,
			transition: transition
		)
		self.aiNode.containerLayoutUpdated(
			layout,
			navigationBarHeight: self.cleanNavigationHeight,
			actualNavigationBarHeight: actualNavigationBarHeight,
			transition: transition
		)
	}
}



final class AiToolControllerNode: ASDisplayNode {
	
	private let context: AccountContext
	private var presentationData: PresentationData
	private let controller: ViewController
	private var tabContainer: ASDisplayNode
	private let historyButton : AiMenuButton
	private var tabSeparator: ASDisplayNode
	public var menuTabBar: AiMenuTabBar
	private let inputNode : AiInputNode
	
	private var pageNodes: [ASDisplayNode] = []
	private let pageScrollNode: ASScrollNode
	private let tabWidth : CGFloat
	
	
	public init(context: AccountContext, controller: ViewController) {
		// Context and theme
		self.context = context
		let presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.presentationData = presentationData
		
		// Views
		self.controller = controller
		self.tabContainer = ASDisplayNode()
		self.historyButton = AiMenuButton(context: context, feature: .history)
		self.tabWidth  = 80.0
		self.tabSeparator = ASDisplayNode()
		self.menuTabBar = AiMenuTabBar(context: context, tabWidth: tabWidth)
		self.pageScrollNode = ASScrollNode()
		self.inputNode = AiInputNode(context: context)
		
		super.init()
		
		self.automaticallyManagesSubnodes = true
		self.backgroundColor = self.presentationData.theme.custom.modalBackground
		
		self.tabContainer.backgroundColor = self.presentationData.theme.custom.backgroundColor
		self.addSubnode(self.tabContainer)
		
		self.historyButton.setActionHightlighTap(onTap: { feature in
			
		})
		self.tabContainer.addSubnode(self.historyButton)
		
		self.tabSeparator.backgroundColor = self.presentationData.theme.custom.unselectButton2
		self.tabContainer.addSubnode(self.tabSeparator)
		
		self.menuTabBar.selectByIndex(0)
		self.menuTabBar.onTabChanged = { feature, index in
			self.scrollToPage(index)
		}
		self.tabContainer.addSubnode(self.menuTabBar)
		
		self.pageScrollNode.view.isPagingEnabled = true
		self.pageScrollNode.view.showsHorizontalScrollIndicator = false
		self.pageScrollNode.view.alwaysBounceHorizontal = true
		self.pageScrollNode.view.alwaysBounceVertical = false
		self.pageScrollNode.view.bounces = true
		self.pageScrollNode.view.delegate = self
		self.addSubnode(self.pageScrollNode)
		
		for feature in self.menuTabBar.features {
			let page = PageHolderNode(context: self.context, feature: feature)
			self.pageNodes.append(page)
			self.pageScrollNode.addSubnode(page)
		}
		self.addSubnode(self.inputNode)
	}
	
	func containerLayoutUpdated(
		_ layout: ContainerViewLayout,
		navigationBarHeight: CGFloat,
		actualNavigationBarHeight: CGFloat,
		transition: ContainedViewLayoutTransition
	){
		let bounds = self.bounds
		let safeTop = self.safeAreaInsets.top + actualNavigationBarHeight
		
		
		// Layout tab bar
		
		let tabHeight = 80.0
		self.tabContainer.frame = CGRect(
			x : 0,
			y: safeTop,
			width: bounds.width,
			height: tabHeight
		)
		
		self.historyButton.frame = CGRect(
			x : 0,
			y: 0,
			width: tabWidth,
			height: tabHeight
		)
		let separateHeight = tabHeight * 0.7
		self.tabSeparator.frame = CGRect(
			x : tabWidth,
			y: floor((tabHeight - separateHeight) / 2),
			width: 2,
			height: separateHeight
		)
		let tabX = tabWidth + 2
		self.menuTabBar.frame = CGRect(
			x : tabX,
			y: 0,
			width: bounds.width - tabX,
			height: tabHeight
		)
		
		
		
		// Layout page view
		let tabBottom = self.tabContainer.frame.maxY
		let pageWidth = bounds.width
		let pageHeight = bounds.height - tabBottom
		self.pageScrollNode.frame = CGRect(
			x: 0,
			y: tabBottom,
			width: pageWidth,
			height: pageHeight
		)
		
		// layout pages horizontally
		
		for (index, page) in self.pageNodes.enumerated() {
			page.frame = CGRect(
				x: CGFloat(index) * pageWidth ,
				y: 0,
				width: pageWidth,
				height: pageHeight
			)
		}
		self.pageScrollNode.view.contentSize = CGSize(
			width: CGFloat(self.pageNodes.count) * pageWidth,
			height: pageHeight
		)
	
		self.inputNode.updateLayout(layout: layout)
	
	}
}

extension AiToolControllerNode: UIScrollViewDelegate {
	
	public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		self.onPageChanged(scrollView)
	}
	
	public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		self.onPageChanged(scrollView)
	}
	
	func onPageChanged(_ scrollView: UIScrollView){
		let pageW = scrollView.bounds.width
		let index = Int(round(scrollView.contentOffset.x / pageW))
		if index >= 0 && index < self.pageNodes.count {
			self.menuTabBar.selectByIndex(index)
		}
	}
	
	func scrollToPage(_ page: Int, animated: Bool = true) {
		if page != self.currentPage {
			let pageWidth = self.pageScrollNode.bounds.width
			let offsetX = CGFloat(page) * pageWidth
			
			self.pageScrollNode.view.setContentOffset(
				CGPoint(x: offsetX, y: 0),
				animated: animated
			)
		}
	}
	
	var currentPage: Int {
		let scrollView = self.pageScrollNode.view
		let pageW = scrollView.bounds.width
		return Int(round(scrollView.contentOffset.x / pageW))
	}
}




