import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import SettingsUI
import AppBundle

final class DiscoverItem: ListViewItem {
	
	static func initItems(context: AccountContext, width: CGFloat, action: ((Int) -> Void)?) -> [DiscoverItem] {
		let theme = (context.sharedContext.currentPresentationData.with { $0 }).theme
		let items =  [

//			DiscoverItem(
//				id: 3,theme: theme, itemWidth: width,
//				enable: true, color: 0xFF8D28,
//				icon: "Ton/IconWallet", text: "Ton Wallet",
//				action: action
//			),
			DiscoverItem(
				id: 1,theme: theme, itemWidth: width,
				enable: true, color: 0x0088FF,
				icon: "Ton/IconTV", text: "TONtv",
				action: action
			),
			DiscoverItem(
				id: 2,theme: theme, itemWidth: width,
				enable: true, color: 0x00C0E8,
				icon: "Ton/IconApp", text: "Mini Apps",
				action: action
			),
//			DiscoverItem(
//				id: 4,theme: theme, itemWidth: width,
//				enable: false,
//				color: 0xFF2D55, icon: "Ton/IconBot", text: "AI Tony",
//				action: action
//			),
//			DiscoverItem(
//				id: 5,theme: theme, itemWidth: width,
//				enable: false,
//				color: 0x34C759, icon: "Ton/IconCEX", text: "CEX Exchange",
//				action: action
//			),
//			DiscoverItem(
//				id: 6,theme: theme, itemWidth: width,
//				enable: false,
//				color: 0x8B9EE9, icon: "Ton/IconP2P", text: "P2P Exchange",
//				action: action
//			),
			DiscoverItem(
				id: 7,theme: theme, itemWidth: width,
				enable: false,
				color: 0x0088FF, icon: "Ton/IconInfoFlat", text: "TONX",
				action: action
			),
		]
		return items
	}
	
	let id: Int
	
	let color: UInt32
	let icon: String
	let text: String
	let enable: Bool
	var isLast: Bool
	let action: ((Int) -> Void)?
	var selectable: Bool {
		return true
	}
	let itemWidth : CGFloat
	var approximateHeight: CGFloat {
		return DiscoverController.itemHeight
	}
	var headerAccessoryItem: ListViewAccessoryItem? {
		return nil
	}
	private let theme : PresentationTheme
	
	init(
		id: Int,
		theme : PresentationTheme,
		itemWidth: CGFloat,
		enable: Bool,
		isLast: Bool = false,
		color: UInt32,
		icon: String,
		text: String,
		action: ((Int) -> Void)?
	) {
		self.id = id
		self.theme = theme
		self.itemWidth = itemWidth
		self.enable = enable
		self.color = color
		self.icon = icon
		self.text = text
		self.action = action
		self.isLast = isLast
	}
	
	func selected(listView: ListView) {
		listView.clearHighlightAnimated(true)
		self.action?(self.id)
	}
	
	func nodeConfiguredForParams(
		async: @escaping (@escaping () -> Void) -> Void,
		params: ListViewItemLayoutParams,
		synchronousLoads: Bool,
		previousItem: ListViewItem?,
		nextItem: ListViewItem?,
		completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void
	) {
		async {
			let node = DiscoverItemNode(theme: self.theme, item: self)
			let (nodeLayout, nodeApply) = node.asyncLayout()(params)
			node.contentSize = nodeLayout.contentSize
			node.insets = nodeLayout.insets
			Queue.mainQueue().async {
				completion(node, {
					return (nil, { _ in
						nodeApply()
					})
				})
			}
		}
	}
	
	func updateNode(
		async: @escaping (@escaping () -> Void) -> Void,
		node: @escaping () -> ListViewItemNode,
		params: ListViewItemLayoutParams,
		previousItem: ListViewItem?,
		nextItem: ListViewItem?,
		animation: ListViewItemUpdateAnimation,
		completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void
	) {
		Queue.mainQueue().async {
			if let node = node() as? DiscoverItemNode {
				async {
					let (nodeLayout, nodeApply) = node.asyncLayout()(params)
					Queue.mainQueue().async {
						completion(nodeLayout, { _ in
							// not run
							nodeApply()
						})
					}
				}
			}
		}
	}
	
	
}

// TODO: Ton - Discover : ViewController
public class DiscoverController : ViewController {
	
	
	public static let itemHeight : CGFloat = 54.0
	public static let iconSize : CGFloat = 32.0
	private let context: AccountContext
	private var presentationData: PresentationData
	private var presentationDataDisposable: Disposable?
	public var discoverItemClick: ((Int) -> Void)?
	private var discoverNode: DiscoverControllerNode {
		return self.displayNode as! DiscoverControllerNode
	}
	
	public init(context: AccountContext) {
		self.context = context
		
		let presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.presentationData = presentationData
		let navBarTheme = NavigationBarPresentationData(presentationData: presentationData)
		super.init(navigationBarPresentationData: navBarTheme)
		
		self.tabBarItemContextActionType = .always
		
		self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
		
		self.updateThemeAndStrings(theme: self.presentationData.theme)
		
		self.scrollToTop = { [weak self] in
			print("\(self?.debugDescription ?? "nil")")
		}
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
	
	required public init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	deinit {
		self.presentationDataDisposable?.dispose()
	}
	
	override public func loadDisplayNode() {
		self.displayNode = DiscoverControllerNode(context: self.context, action: { id in
			self.onDiscoverItemClick(id: id)
		})
		self.displayNodeDidLoad()
	}
	
	private func updateThemeAndStrings(theme: PresentationTheme) {
		
		self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
		self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
		

		self.title = "Discover"
		self.tabBarItem.title = "Discover"
		
		
		let iconName = "Ton/IconDiscover"
		let image = UIImage(bundleImageName: iconName)?
			.withRenderingMode(.alwaysOriginal)
			.withTintColor(theme.rootController.tabBar.textColor)
		self.tabBarItem.image = image
		
		let selectedImage = UIImage(bundleImageName: iconName)?
			.withRenderingMode(.alwaysOriginal)
			.withTintColor(theme.rootController.tabBar.selectedIconColor)
		self.tabBarItem.selectedImage = selectedImage
		self.tabBarItem.animationName = nil
		
		
		
		self.discoverNode.updateThemeAndStrings(theme: theme)
	}
	
	func applyItems(items: [DiscoverItem])  {
		self.discoverNode.applyItems(items: items)
	}
	
	func onDiscoverItemClick(id: Int)  {
		self.discoverItemClick?(id)
	}
	
	
}

final class DiscoverControllerNode: ASDisplayNode  {
	
	
	// TODO: Ton - Background: adapt
	private let backgroundImage = ASBackgroundImageNode()
	
	private let context: AccountContext
	private let sessionNode : DiscoverSessionNode
	private let action: ((Int) -> Void)?
	
	
	public init(context: AccountContext,action: ((Int) -> Void)?) {
		
		//self.backgroundImage.image = UIImage(named: "Ton/Background1")
		
		self.action = action
		self.context = context
		self.sessionNode = DiscoverSessionNode(context: context)
		
		
		super.init()
		// TODO: Ton - Background: adapt
		self.addSubnode(self.backgroundImage)
		
	
		
		self.addSubnode(self.sessionNode)
		
	}
	
	override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
		return constrainedSize
	}
	
	override func layout() {
		super.layout()
	
		
		// TODO: Ton - Background: adapt
		let theme = (context.sharedContext.currentPresentationData.with { $0 }).theme
		self.backgroundImage.fillParent(color: theme.custom.backgroundColor)
		
		self.updateThemeAndStrings(theme: theme)
		
	
	}
	
	public func setListData(){
		let left = 16.0
		let top = 120.0
		let width = self.bounds.width - (left * 2)
		if width <= 0.0 {
			return
		}
		let items =  DiscoverItem.initItems(context: context, width: width, action: self.action)
		if let lastItem = items.last {
			lastItem.isLast = true
		}
		self.applyItems(items: items)
		self.sessionNode.frame = CGRect(
			x: left,
			y: top,
			width: width,
			height: CGFloat(items.count) * DiscoverController.itemHeight + 8
		)
	}
	
	
	public func applyItems(items: [DiscoverItem])  {
		self.sessionNode.applyItems(items: items)
	}
	
	func updateThemeAndStrings(theme: PresentationTheme) {
		self.backgroundImage.fillParent(color: theme.custom.backgroundColor)
		self.sessionNode.updateThemeAndStrings(theme: theme)
		self.setListData()
		
	}
}

final class DiscoverSessionNode: ASDisplayNode {
	private let context: AccountContext
	private let listView: ListView
	
	
	init(context: AccountContext) {
		self.context = context
		self.listView = ListView()
		self.listView.scrollEnabled = false
		self.listView.scroller.bounces = false
		self.listView.scroller.alwaysBounceVertical = false
		self.listView.scroller.alwaysBounceHorizontal = false
		self.listView.updateNodeHighlightsAnimated(false)
		super.init()
		let theme = (context.sharedContext.currentPresentationData.with { $0 }).theme
		
		self.updateThemeAndStrings(theme: theme)
		self.cornerRadius = 20
		self.clipsToBounds = true
		self.addSubnode(self.listView)
		
	}
	
	override func layout(){
		super.layout()
		let width = self.bounds.width
		if width > 0 {
			let itemCount = DiscoverItem.initItems(context: context, width: 0, action: nil).count
			self.listView.frame = CGRect(
				x: 0,
				y: 4,
				width: width,
				height: CGFloat(itemCount) * DiscoverController.itemHeight
			)
		}
	}
	
	public func applyItems(items: [DiscoverItem])  {
		let insertItems = items.enumerated().map {
			ListViewInsertItem(
				index: $0.offset,
				previousIndex: nil,
				item: $0.element,
				directionHint: nil
			)
		}
		self.listView.transaction(
			deleteIndices: [],
			insertIndicesAndItems: insertItems,
			updateIndicesAndItems: [],
			options: ListViewDeleteAndInsertOptions.Synchronous,
			updateOpaqueState: nil,
		)
		let width = self.bounds.width
		if width > 0 {
			self.listView.frame = CGRect(
				x: 0,
				y: 4,
				width: width,
				height: CGFloat(insertItems.count) * DiscoverController.itemHeight
			)
		}
	}
	
	func updateThemeAndStrings(theme: PresentationTheme) {
		//let isDark = theme.overallDarkAppearance
		self.backgroundColor =  theme.list.itemBlocksBackgroundColor
	}
	
}




final class DiscoverItemNode: ListViewItemNode {
	
	private let item : DiscoverItem
	private let theme : PresentationTheme
	
	private let textNode : ASTextNode
	private let iconNode : DiscoverIconNode
	private let highlightNode : ASDisplayNode
	private let separateNode : ASDisplayNode
	
	private let subtitleNode : ASTextNode
	
	init(theme: PresentationTheme, item: DiscoverItem) {
		self.theme = theme
		self.item = item
		
		
		self.highlightNode = ASDisplayNode()
		self.highlightNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
		self.highlightNode.alpha = 0.0
		self.highlightNode.isLayerBacked = true
		self.separateNode  = ASDisplayNode()
		if !item.isLast {
			self.separateNode.backgroundColor =  theme.list.itemPlainSeparatorColor
		}
		
		self.iconNode  = DiscoverIconNode(color: item.color, icon: item.icon)
		
		// TODO: Ton - Discover page: item UI
		self.textNode  = ASTextNode()
		self.textNode.attributedText = NSAttributedString(
			string: self.item.text,
			font: Font.regular(16),
			textColor: theme.custom.primaryTextColor
		)
		self.subtitleNode  = ASTextNode()
		self.subtitleNode.attributedText = NSAttributedString(
			string: "Coming soon",
			font: Font.regular(12),
			textColor: UIColor(rgb: 0xFF383C)
		)
		super.init(layerBacked: false, dynamicBounce: false)
		
		self.addSubnode(self.highlightNode)
		self.addSubnode(self.separateNode)
		self.addSubnode(self.iconNode)
		self.addSubnode(self.textNode)
		self.addSubnode(self.subtitleNode)
	}
	
	override public var canBeSelected: Bool {
		return true
	}
	
	override func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
		super.setHighlighted(highlighted, at: point, animated: animated)
		
		if highlighted {
			self.highlightNode.alpha = 1.0
			
		} else {
			self.highlightNode.alpha = 0.0
		}
	}
	
	func asyncLayout() -> (ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
		return { params in
			
			let contentWidth = max(200,max(self.item.itemWidth, params.width))
			
			
			
			let layout = ListViewItemNodeLayout(
				contentSize: CGSize(width: contentWidth, height: DiscoverController.itemHeight),
				insets: .zero
			)
			return (layout, {
				// TODO: Ton - Discover page: item UI
				let paddingLeft = 16.0;
		
				let titleTextSize = self.textNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
				let subTextSize = self.subtitleNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
				let textLeft = (paddingLeft * 2) + DiscoverController.iconSize
				let textWidth = self.item.itemWidth - paddingLeft - textLeft
				
				self.highlightNode.frame = CGRect(
					x: 0,
					y: 0,
					width: self.item.itemWidth,
					height: DiscoverController.itemHeight
				)
				
				self.separateNode.frame = CGRect(
					x: textLeft,
					y: DiscoverController.itemHeight - 1,
					width: textWidth,
					height: 1
				)
				
				self.iconNode.frame = CGRect(
					x: 16,
					y: (DiscoverController.itemHeight - DiscoverController.iconSize) / 2,
					width: DiscoverController.iconSize,
					height: DiscoverController.iconSize
				)
				if self.item.enable {
					self.textNode.frame = CGRect(
						x: textLeft,
						y: 6 + (titleTextSize.height/2),
						width: textWidth,
						height: titleTextSize.height
					)
				} else {
					let lineSpace = 0.4
					let textTop = (DiscoverController.itemHeight - titleTextSize.height - subTextSize.height - lineSpace) / 2
					self.textNode.frame = CGRect(
						x: textLeft,
						y: textTop,
						width: textWidth,
						height: titleTextSize.height
					)
					self.subtitleNode.frame = CGRect(
						x: textLeft,
						y: textTop + titleTextSize.height + lineSpace,
						width: textWidth,
						height: subTextSize.height
					)
				}
				
			})
		}
	}
	
}


class DiscoverIconNode : ASDisplayNode {
	let color: UInt32
	let icon: String
	private let imageNode : ASImageNode
	private let backgroundNode : ASDisplayNode
	init(
		color: UInt32,
		icon: String,
	) {
		// TODO: Ton - Discover page: Discover item UI
		self.color = color
		self.icon = icon
		self.backgroundNode = ASDisplayNode()
		self.imageNode = ASImageNode()
		super.init()
		self.backgroundNode.backgroundColor = UIColor(rgb: color)
		self.backgroundNode.cornerRadius = 8
		self.backgroundNode.clipsToBounds = true
		self.imageNode.contentMode = .scaleAspectFit
		self.imageNode.clipsToBounds = true
		self.imageNode.image = UIImage(bundleImageName: icon)?
			.withRenderingMode(.alwaysOriginal)
			.withTintColor(UIColor(rgb: 0xFFFFFF))
		self.addSubnode(self.backgroundNode)
		self.addSubnode(self.imageNode)
	}
	
	override func layout(){
		super.layout()
		self.backgroundNode.frame = self.bounds
		let iconWidth = self.bounds.width * 0.6
		let iconPadding = (self.bounds.width - iconWidth) / 2
		self.imageNode.frame = CGRect(
			x: iconPadding,
			y: iconPadding,
			width: iconWidth,
			height: iconWidth
		)
	}
}
