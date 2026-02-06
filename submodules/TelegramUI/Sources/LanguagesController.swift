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
import SearchBarNode


// TODO: Ton - LanguageList : ViewController
final class LanguagesController : ViewController {
	public static var selectedLanguage = OutgoingTranslateSetting.defaultSettings
	
	public static let itemHeight : CGFloat = 54.0
	
	private let context: AccountContext
	private var presentationData: PresentationData
	private var presentationDataDisposable: Disposable?
	public var languageSelectionChanged: ((OutgoingTranslateSetting) -> Void)?
	private var languagesNode: LanguagesControllerNode {
		return self.displayNode as! LanguagesControllerNode
	}
	
	private var allLanguages: [LanguageItemInfo] = []
	
	private var listDisposable: Disposable?
	let fetchLanguages : Signal<[LanguageItemInfo]?, NoError>
	
	public init(context: AccountContext,fetchLanguages : Signal<[LanguageItemInfo]?, NoError>) {
		self.context = context
		self.fetchLanguages = fetchLanguages
		self.presentationData = (context.sharedContext.currentPresentationData.with { $0 })
		
		super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
		
		self.tabBarItemContextActionType = .always
		self.navigationPresentation = .modal
		self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
		
		self.updateThemeAndStrings()
		
		self.scrollToTop = { [weak self] in
			print("\(self?.debugDescription ?? "nil")")
		}
		self.presentationDataDisposable = (context.sharedContext.presentationData
										   |> deliverOnMainQueue).start(next: { [weak self] presentationData in
			if let strongSelf = self {
				let previousTheme = strongSelf.presentationData.theme
				let previousStrings = strongSelf.presentationData.strings
				
				strongSelf.presentationData = presentationData
				
				if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
					strongSelf.updateThemeAndStrings()
				}
			}
		}).strict()
	}
	
	required public init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override public func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		let node = self.languagesNode
		DispatchQueue.main.async {
			node.animateIn()
		}
	}
	
	override public func loadDisplayNode() {
		self.displayNode = LanguagesControllerNode(context: self.context)
		self.displayNodeDidLoad()
		
		// wire search callback
		self.languagesNode.onSearchTextChanged = { [weak self] text in
			guard let strongSelf = self else { return }
			let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
			if trimmed.isEmpty {
				strongSelf.applyLanguages(strongSelf.allLanguages)
			} else {
				let lower = trimmed.lowercased()
				let filtered = strongSelf.allLanguages.filter { info in
					return info.name.lowercased().contains(lower) || info.nativeName.lowercased().contains(lower) || info.code.lowercased().contains(lower)
				}
				strongSelf.applyLanguages(filtered)
			}
		}
		
		self.listDisposable = combineLatest(
			queue: .mainQueue(),
			self.fetchLanguages,
			context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
			context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.outgoingTranstate]),
		).start(next: { [weak self] languageList, peer, sharedData in
			guard let strongSelf = self else {
				return
			}
			guard let languages = languageList else {
				return
			}
			// store full list
			strongSelf.allLanguages = languages
			
			// TODO: Ton - LanguageList: get selected language
			if let current = sharedData.entries[SharedDataKeys.outgoingTranstate]?.get(OutgoingTranslateSetting.self) {
				LanguagesController.selectedLanguage = current
			}
			// apply items (initial)
			strongSelf.applyLanguages(languages)
		})
	}
	
	deinit {
		self.listDisposable?.dispose()
		self.presentationDataDisposable?.dispose()
	}
	
	private func updateThemeAndStrings() {
		let theme = self.presentationData.theme
		
		self.statusBar.statusBarStyle = theme.rootController.statusBarStyle.style
		if let navBar = self.navigationBar{
			navBar.updatePresentationData(
				NavigationBarPresentationData(presentationData: self.presentationData)
			)
			navBar.hideSeparator()
		}
		
		
		
		
		// TODO: Ton - Background: adapt
		//self.navigationBar?.syncBackground()
		self.displayNode.backgroundColor = theme.list.plainBackgroundColor
		self.title = "Choose Language"
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.closePressed))
	}
	
	@objc private func closePressed() {
		if let nav = self.navigationController, nav.viewControllers.first != self {
			self.navigationController?.popViewController(animated: true)
		} else {
			dismiss(animated: true, completion: nil)
		}
	}
	
	func onLanguageItemClick(item: LanguageItem)  {
		// update selection state and only update the two affected rows (previous + new)
		let theme = (self.context.sharedContext.currentPresentationData.with { $0 }).theme
		let previousCode = LanguagesController.selectedLanguage.code
		let newCode = item.info.code
		if previousCode == newCode {
			return
		}
		LanguagesController.selectedLanguage = OutgoingTranslateSetting(
			code: item.info.code,
			name: item.info.name
		)
		
		
		var updateItems: [ListViewUpdateItem] = []
		if  let prevIndex = self.languagesNode.localizationInfos.firstIndex(where: { $0.code == previousCode }) {
			let info = self.languagesNode.localizationInfos[prevIndex]
			let updatedPrev = LanguageItem(info: info, theme: theme, selected: false, action: { [weak self] item in
				self?.onLanguageItemClick(item: item)
			})
			updateItems.append(ListViewUpdateItem(
				index: prevIndex,
				previousIndex: prevIndex,
				item: updatedPrev,
				directionHint: nil
			))
		}
		if let newIndex = self.languagesNode.localizationInfos.firstIndex(where: { $0.code == newCode }) {
			let info = self.languagesNode.localizationInfos[newIndex]
			let updatedNew = LanguageItem(info: info, theme: theme, selected: true, action: { [weak self] item in
				self?.onLanguageItemClick(item: item)
			})
			updateItems.append(ListViewUpdateItem(
				index: newIndex,
				previousIndex: newIndex,
				item: updatedNew,
				directionHint: nil,
			))
		}
		
		
		if !updateItems.isEmpty {
			Queue.mainQueue().async {
				self.languagesNode.listView.transaction(
					deleteIndices: [],
					insertIndicesAndItems: [],
					updateIndicesAndItems: updateItems,
					options: [.Synchronous, .LowLatency],
					scrollToItem: nil,
					stationaryItemRange: nil,
					updateOpaqueState: nil,
					completion: { _ in }
				)
			}
			Queue.mainQueue().after(0.3) {
				self.dismiss(animated: true)
			}
		}
		
		let _ = self.context.sharedContext.accountManager.transaction { transaction -> Void in
			transaction.updateSharedData(SharedDataKeys.outgoingTranstate, { entry in
				return SharedPreferencesEntry(LanguagesController.selectedLanguage)
			})
		}.start()
		
		self.languageSelectionChanged?(LanguagesController.selectedLanguage)
	}
	
	override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
		super.containerLayoutUpdated(layout, transition: transition)
		self.languagesNode.containerLayoutUpdated(
			layout,
			navigationBarHeight: self.cleanNavigationHeight,
			actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY,
			transition: transition
		)
	}
	
	private func applyLanguages(_ languages: [LanguageItemInfo]) {
		let theme = (self.context.sharedContext.currentPresentationData.with { $0 }).theme
		let prevCount = self.languagesNode.localizationInfos.count
		// set new infos before transaction so node has authoritative list
		self.languagesNode.localizationInfos = languages
		let insertItems = languages.enumerated().map { index, info in
			ListViewInsertItem(
				index: index,
				previousIndex: nil,
				item: LanguageItem(info: info, theme: theme, selected: LanguagesController.selectedLanguage.code == info.code, action: { item in
					self.onLanguageItemClick(item: item)
				}),
				directionHint: nil
			)
		}
		let deleteItems: [ListViewDeleteItem] = prevCount > 0 ? Array(0..<prevCount).map { index in
			return ListViewDeleteItem(index: index,  directionHint: nil)
		} : []
		self.languagesNode.listView.transaction(
			deleteIndices: deleteItems,
			insertIndicesAndItems: insertItems,
			updateIndicesAndItems: [],
			options: [.Synchronous, .LowLatency],
			scrollToItem: nil,
			stationaryItemRange: nil,
			updateOpaqueState: nil,
			completion: { _ in }
		)
	}
}



final class LanguagesControllerNode: ASDisplayNode {
	private let context: AccountContext
	
	public let listView: ListView
	private var listInsets : UIEdgeInsets = UIEdgeInsets()
	var localizationInfos: [LanguageItemInfo] = []
	private let searchBar: SearchBarNode
	private let searchHeight: CGFloat
	private let presentationData: PresentationData
	public var onSearchTextChanged: ((String) -> Void)?
	init(context: AccountContext) {
		self.context = context
		let presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.presentationData = presentationData
		self.searchHeight = presentationData.dimen.searchTextHeight
		self.listView = ListView()
		self.searchBar = SearchBarNode(
			theme: SearchBarNodeTheme(
				theme: presentationData.theme,
				hasSeparator: false
			),
			strings: presentationData.strings,
			fieldStyle: .modern,
			displayBackground: false
		)
		
		super.init()
		
		
		self.searchBar.hasCancelButton = false
		self.searchBar.placeholderString = NSAttributedString(
			string: presentationData.strings.Common_Search,
			font: Font.regular(17.0),
			textColor:presentationData.theme.rootController.navigationSearchBar.inputPlaceholderTextColor
		)
		self.searchBar.textUpdated = { [weak self] text, _ in
			self?.onSearchTextChanged?(text)
		}
		self.addSubnode(self.searchBar)
		
		// Start hidden (offscreen) and dim invisible so animateIn can animate them into view
		self.listView.alpha = 0.0
		self.addSubnode(self.listView)
		
		// move container down offscreen by modalHeight initially
		self.layer.setAffineTransform(CGAffineTransform(translationX: 0, y: 670))
	}
	
	override func layout(){
		super.layout()
	}
	
	
	public func animateIn() {
		DispatchQueue.main.async {
			// guard against repeated animations
			if self.listView.alpha >= 0.99  {
				return
			}
			self.listView.alpha = 0.0
			// animate container transform to identity and dim to full alpha
			UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.8, options: [.allowUserInteraction, .curveEaseOut], animations: {
				self.layer.setAffineTransform(.identity)
				self.listView.alpha = 1.0
			}, completion: nil)
		}
	}
	
	func containerLayoutUpdated(
		_ layout: ContainerViewLayout,
		navigationBarHeight: CGFloat,
		actualNavigationBarHeight: CGFloat,
		transition: ContainedViewLayoutTransition
	) {
		//let topInset = actualNavigationBarHeight
		let searchTop: CGFloat = actualNavigationBarHeight + 12.0
		let searchSide: CGFloat = 4.0
		let searchFrame = CGRect(
			x: searchSide,
			y: searchTop,
			width: layout.size.width - searchSide * 2.0,
			height: self.searchHeight
		)
		transition.updateFrame(
			node: self.searchBar,
			frame: searchFrame
		)
		self.searchBar.updateLayout(
			boundingSize: searchFrame.size,
			leftInset: 4.0,
			rightInset: 4.0,
			transition: transition
		)
		
		self.listInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 100, right: 0.0)
		let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
		let listSize = CGSize(
			width: layout.size.width,
			height: layout.size.height - actualNavigationBarHeight - (self.searchHeight + 12.0)
		)
		self.listView.transaction(
			deleteIndices: [],
			insertIndicesAndItems: [],
			updateIndicesAndItems: [],
			options: [.Synchronous, .LowLatency],
			scrollToItem: nil,
			updateSizeAndInsets: ListViewUpdateSizeAndInsets(
				size: listSize,
				insets: self.listInsets,
				headerInsets: UIEdgeInsets(),
				scrollIndicatorInsets:self.listInsets,
				duration: duration,
				curve: curve
			),
			stationaryItemRange: nil,
			updateOpaqueState: nil,
			completion: { _ in }
		)
		
		// Ensure the underlying scroll view dismisses the keyboard on drag
		if #available(iOS 11.0, *) {
			self.listView.scroller.contentInsetAdjustmentBehavior = .never
		}
		self.listView.scroller.keyboardDismissMode = .onDrag
		
		self.listView.frame = CGRect(
			x: 0,
			y: searchTop + self.searchHeight + 4.0,
			width: listSize.width,
			height: listSize.height
		)
	}
}


final class LanguageItem: ListViewItem {
	let info: LanguageItemInfo
	
	let action: ((LanguageItem) -> Void)?
	var selectable: Bool {
		return true
	}
	var approximateHeight: CGFloat {
		return LanguagesController.itemHeight
	}
	var headerAccessoryItem: ListViewAccessoryItem? {
		return nil
	}
	private let theme : PresentationTheme
	var selected: Bool = false
	
	init(
		info: LanguageItemInfo,
		theme : PresentationTheme,
		selected: Bool = false,
		action: ((LanguageItem) -> Void)?
	) {
		self.info = info
		self.selected = selected
		self.action = action
		self.theme = theme
	}
	
	func selected(listView: ListView) {
		listView.clearHighlightAnimated(true)
		self.action?(self)
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
			let node = LanguageItemNode(theme: self.theme, item: self)
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
			if let node = node() as? LanguageItemNode {
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

final class LanguageItemNode: ListViewItemNode {
	
	private let item : LanguageItem
	private let theme : PresentationTheme
	private var selectedCode: String = ""
	private let titleNode : ASTextNode
	private let subtitleNode : ASTextNode
	private let checkNode : ASImageNode
	private let borderNode : ASDisplayNode
	private let highlightNode : ASDisplayNode
	
	init(theme: PresentationTheme, item: LanguageItem) {
		self.theme = theme
		self.item = item
		
		self.highlightNode = ASDisplayNode()
		self.checkNode = ASImageNode()
		self.borderNode = ASDisplayNode()
		self.titleNode = ASTextNode()
		self.subtitleNode = ASTextNode()
		super.init(layerBacked: false, dynamicBounce: false)
		
		self.highlightNode.backgroundColor = theme.list.itemHighlightedBackgroundColor
		self.highlightNode.alpha = 0.0
		self.highlightNode.isLayerBacked = true
		self.addSubnode(self.highlightNode)
		
		self.checkNode.image = UIImage(named: "Ton/IconCheckFlat")?.withRenderingMode(.alwaysTemplate)
		self.checkNode.contentMode = .scaleAspectFit
		
		
		self.checkNode.isUserInteractionEnabled = false
		self.addSubnode(self.checkNode)
		
		self.borderNode.clipsToBounds = true
		
		self.borderNode.borderWidth = 1.6
		self.borderNode.isUserInteractionEnabled = false
		self.addSubnode(self.borderNode)
		
		let info = self.item.info
		let paragraph = NSMutableParagraphStyle()
		paragraph.alignment = .left
		paragraph.baseWritingDirection = .leftToRight
		
		self.titleNode.isUserInteractionEnabled = false
		self.titleNode.attributedText = NSAttributedString(
			string: info.nativeName,
			font: Font.medium(16),
			textColor: theme.custom.primaryTextColor,
		)
		self.titleNode.textAlignment = paragraph.alignment
		self.addSubnode(self.titleNode)
		
		self.subtitleNode.isUserInteractionEnabled = false
		self.subtitleNode.attributedText = NSAttributedString(
			string: info.nativeName,
			font: Font.regular(14),
			textColor: theme.custom.secondaryTextColor,
			
		)
		self.subtitleNode.textAlignment = paragraph.alignment
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
			
			let contentWidth = max(360, params.width)
			
			let layout = ListViewItemNodeLayout(
				contentSize: CGSize(width: contentWidth, height: LanguagesController.itemHeight),
				insets: .zero
			)
			return (layout, {
				
				let paddingLeft = 24.0
				
				self.highlightNode.frame = CGRect(
					x: 0,
					y: 0,
					width: contentWidth,
					height: LanguagesController.itemHeight
				)
				let iconSize = 24.0
				let checkFrame = CGRect(
					x: paddingLeft,
					y: floor((LanguagesController.itemHeight - iconSize) / 2.0),
					width: iconSize,
					height: iconSize
				)
				if self.item.info.code == LanguagesController.selectedLanguage.code {
					self.checkNode.alpha = 1.0
					if self.theme.overallDarkAppearance{
						self.borderNode.borderColor = self.theme.list.itemPrimaryTextColor.cgColor
					} else {
						self.borderNode.borderColor = UIColor(rgb: 0x2BA71D).cgColor
					}
				} else {
					self.checkNode.alpha = 0.0
					self.borderNode.borderColor = self.theme.list.itemPrimaryTextColor.cgColor
				}
				self.borderNode.cornerRadius = iconSize / 2
				self.borderNode.frame = checkFrame
				self.checkNode.frame = checkFrame
				
				
				// Text
				let titleTextSize = self.titleNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
				let subTextSize = self.subtitleNode.measure(CGSize(width: contentWidth, height: .greatestFiniteMagnitude))
				let textHeight = titleTextSize.height + subTextSize.height
				let textLeft = paddingLeft + iconSize + 16
				let textWidth = contentWidth - paddingLeft - textLeft
				
				self.titleNode.frame = CGRect(
					x: textLeft,
					y: floor((LanguagesController.itemHeight - textHeight) / 2.0),
					width: textWidth,
					height: titleTextSize.height
				)
				self.subtitleNode.frame = CGRect(
					x: textLeft,
					y: self.titleNode.frame.maxY,
					width: textWidth,
					height: subTextSize.height
				)
			})
		}
	}
	
	
	func updateSelected(_ selected: Bool){
		
		if selected {
			self.checkNode.alpha = 1.0
			if self.theme.overallDarkAppearance{
				self.borderNode.borderColor = theme.list.itemPrimaryTextColor.cgColor
			} else {
				self.borderNode.borderColor = UIColor(rgb: 0x2BA71D).cgColor
			}
		} else {
			self.checkNode.alpha = 0.0
			self.borderNode.borderColor = theme.list.itemPrimaryTextColor.cgColor
		}
		
	}
}
