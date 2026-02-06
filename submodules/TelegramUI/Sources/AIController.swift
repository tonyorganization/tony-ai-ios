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

final class AiController: ViewController {
	
	private let userInputText: String?
	private let translatedText: String?
	private let context: AccountContext
	private var presentationData: PresentationData

	private var aiNode: AiControllerNode {
		return self.displayNode as! AiControllerNode
	}
	
	
	
	public var onTextApplied: ((String) -> Void)?
	private var listDisposable: Disposable?
	public var onTextTranslated: ((String) -> Void)?
	let fetchLanguages : Signal<[LanguageItemInfo]?, NoError>
	
	
	public init(
		context: AccountContext,
		userInputText: String? = nil,
		translatedText: String? = nil
	) {
		self.context = context
		self.userInputText = userInputText
		self.translatedText = translatedText
		self.presentationData = (context.sharedContext.currentPresentationData.with { $0 })
		self.fetchLanguages = context.sharedContext.fetchLanguages()
		super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
		self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
		// TODO: Ton - AI: sync saved selected language
		self.listDisposable = combineLatest(
			queue: .mainQueue(),
			self.fetchLanguages,
			context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId)),
			context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.outgoingTranstate]),
		).start(next: { [weak self] languageList, peer, sharedData in
			let current = sharedData.entries[SharedDataKeys.outgoingTranstate]?.get(OutgoingTranslateSetting.self)
			guard let strongSelf = self else { return }
			if current != nil {
				strongSelf.aiNode.updateSelectedLanguage(current)
			} else if let languages = languageList {
				let languageCode = strongSelf.presentationData.strings.primaryComponent.languageCode
				if let match = languages.first(where: { $0.code == languageCode }) {
					let defaultSetting = OutgoingTranslateSetting(code: match.code, name: match.name)
					strongSelf.aiNode.updateSelectedLanguage(defaultSetting)
				}
			}
		})
	}
	
	required public init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func loadDisplayNode() {
		self.displayNode = AiControllerNode(
			context: self.context,
			controller: self,
			fetchLanguages : fetchLanguages
		)
		self.displayNodeDidLoad()
		
	}
	
	override public func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		let node = self.aiNode

		node.setUserInputText(self.userInputText)
		node.setTranslatedText(self.translatedText)
		node.onTextApplied = { text in
			self.onTextApplied?(text)
		}
		node.onTextTranslated = { text in
			self.onTextTranslated?(text)
		}
		DispatchQueue.main.async {
			node.animateIn()
			
		}
		//Auto-focus the text view after the present animation completes
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
			node.focusInputTextNode()
		}
		
		
		
		self.syncCurrentTranslationSetting()
		NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardFrameChanged(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
		
		
		
	}
	
	override public func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.listDisposable?.dispose()
		NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
	}
	
	override func containerLayoutUpdated(
		_ layout: ContainerViewLayout,
		transition: ContainedViewLayoutTransition
	) {
		(self.displayNode as? AiControllerNode)?
			.updateLayout(layout: layout, transition: transition)
	}
	
	// TODO: Ton - get translation settings
	private func syncCurrentTranslationSetting(){
		//		let _ = (context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
		//				 |> take(1)
		//				 |> deliverOnMainQueue).start(next: {  [weak self] sharedData in
		//
		//			let settings : TranslationSettings
		//
		//			if let strongSelf = self {
		//				if let current = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) {
		//					strongSelf.translationSettings = current
		//				} else {
		//					strongSelf.translationSettings = TranslationSettings.defaultSettings
		//				}
		//			}
		//
		//		})
		
	}
	
	@objc private func keyboardFrameChanged(_ notification: Notification) {
		guard let userInfo = notification.userInfo, let node = self.displayNode as? AiControllerNode, let view = self.view else {
			return
		}
		let endFrameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue
		let endFrame = endFrameValue?.cgRectValue ?? .zero
		// convert keyboard frame to this view's coordinate space
		let endFrameInView = view.convert(endFrame, from: nil)
		let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
		let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue ?? UIView.AnimationCurve.easeInOut.rawValue
		let curve = UIView.AnimationCurve(rawValue: curveRaw) ?? .easeInOut
		// compute visible keyboard height
		let keyboardHeight = max(0.0, view.bounds.height - endFrameInView.origin.y)
		node.setKeyboardHeight(CGFloat(keyboardHeight), duration: duration, curve: curve)
	}
	
	
}


// TODO: Ton - Ai: AiControllerNode
final class AiControllerNode: ASDisplayNode {
	
	private let presentationData: PresentationData
	private let dimNode: ASDisplayNode
	private let modalContentNode: ASDisplayNode
	private let bottomInsetNode: ASDisplayNode
	
	// Header
	private let modalNavBarNode: ASDisplayNode
	private let backNode: ASImageNode
	private let applyNode: ASTextNode
	private let titleIconNode: ASImageNode
	private let titleTextNode: ASTextNode
	
	// Body
	private let modalBodyNode: ASDisplayNode
	
	// Tool buttons
	private let toolContainer: ASDisplayNode
	
	// Tool buttons - transtate button
	private let translateButton: ASDisplayNode
	private let translateImage: ASImageNode
	private let translateIcon: ASImageNode
	private let translateText: ASTextNode
	
	// Tool buttons - writing button
	private let writingButton: ASDisplayNode
	private let writingIcon: ASImageNode
	private let writingText: ASTextNode
	private let commingText: ASTextNode
	
	
	
	// language selector
	private let languageContainer: ASDisplayNode
	private let languageIcon: ASImageNode
	private let languageText: ASTextNode
	private let languageArrow: ASImageNode
	private let progressNode : ASImageNode
	private let dividerNode: ASDisplayNode
	private let translatedTextNode: ASTextNode
	
	// footer
	
	private let inputBackgroundNode: ASDisplayNode
	private let inputSeparateNode: ASDisplayNode
	private let sendButtonNode: ASImageNode
	private let userInputNode: ASDisplayNode
	private let placeholderNode: ASTextNode
	
	///
	private let controller: AiController
	private var panGesture: UIPanGestureRecognizer?
	private var initialContainerY: CGFloat = 0
	private var containerLayout: ContainerViewLayout?
	public var onTextApplied: ((String) -> Void)?
	public var onTextTranslated: ((String) -> Void)?

	private let context: AccountContext
	var translateSettings : OutgoingTranslateSetting?
	private let inputDelegate: InputDelegate
	
	
	//
	private var screenWidth = 0.0
	private var screenHeight = 0.0
	private var modalY = 0.0
	private var modalHeight = 500.0
	private let headerHeight = 56.0
	private let padding = 16.0
	private var bottomInsetHeight = 24.0
	private let langButtonHeight = 40.0
	private let langIconSize = 24.0
	private let arrowSize = 16.0
	private let toolHeight = 40.0
	private let toolIconPadding = 6.0
	private let toolIconSize = 24.0
	private let aiIconSize = 24.0
	private let aiIconMargin = 8.0
	private let sendButtonSize = 26.0
	private let maxInputHeight = 200.0
	private let minInputHeight = 40.0
	private let inputTextSize = 18.0
	private let textPaddingTop = 0.0
	private var cacheBottomInsetHeight: CGFloat = 0.0
	let fetchLanguages : Signal<[LanguageItemInfo]?, NoError>
	
	
	init(
		context: AccountContext,
		controller: AiController,
		fetchLanguages : Signal<[LanguageItemInfo]?, NoError>
	) {
		self.fetchLanguages = fetchLanguages
		self.context = context
		self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.controller = controller
		
		self.dimNode = ASDisplayNode()
		self.modalContentNode = ASDisplayNode()
		self.bottomInsetNode = ASDisplayNode()
		
		// Header content
		self.modalNavBarNode = ASDisplayNode()
		self.backNode = ASImageNode()
		
		self.titleIconNode = ASImageNode()
		self.titleTextNode = ASTextNode()
		self.applyNode = ASTextNode()
		
		// Body content
		self.modalBodyNode = ASDisplayNode()
		self.toolContainer = ASDisplayNode()
		
		// Translate button
		self.translateButton = ASDisplayNode()
		self.translateImage = ASImageNode()
		self.translateIcon = ASImageNode()
		self.translateText = ASTextNode()
		
		// Translate button
		self.writingButton = ASDisplayNode()
		self.writingIcon = ASImageNode()
		self.writingText = ASTextNode()
		self.commingText = ASTextNode()
		
		// language
		self.languageContainer = ASDisplayNode()
		self.languageIcon = ASImageNode()
		self.languageText = ASTextNode()
		self.languageArrow = ASImageNode()
		self.progressNode = ASImageNode()
		
		self.dividerNode = ASDisplayNode()
		self.translatedTextNode = ASTextNode()
		// footer
		self.inputSeparateNode = ASDisplayNode()
		self.inputBackgroundNode = ASDisplayNode()
		
		self.sendButtonNode = ASImageNode()
		self.placeholderNode = ASTextNode()
		self.userInputNode = ASDisplayNode(viewBlock: {
			let tv = UITextView()
			tv.isScrollEnabled = true
			tv.textContainerInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 12.0, right: 0)
			tv.isEditable = true
			tv.keyboardType = .default
			tv.returnKeyType = .default
			tv.autocorrectionType = .no
			tv.alwaysBounceVertical = false
			tv.text = ""
			return tv
		})
		
		// keep a reference to the input delegate so it isn't deallocated
		self.inputDelegate = InputDelegate()
		
		super.init()
		let theme =  self.presentationData.theme
		// Start hidden (offscreen) and dim invisible so animateIn can animate them into view
		self.dimNode.alpha = 0.0
		// move container down offscreen by screen height initially so animateIn can slide it up
		let screenH = UIScreen.main.bounds.height
		self.modalContentNode.layer.setAffineTransform(CGAffineTransform(translationX: 0, y: screenH))
		
		// Dimmed background setup
		self.dimNode.backgroundColor = theme.custom.dimColor
		self.dimNode.view.addGestureRecognizer(
			UITapGestureRecognizer(
				target: self,
				action: #selector(self.dissmissPressed)
			)
		)
		self.addSubnode(self.dimNode)
		
		// Container setup
		self.modalContentNode.backgroundColor = theme.custom.modalBackground
		self.modalContentNode.cornerRadius = 16
		self.modalContentNode.layer.maskedCorners = [
			.layerMinXMinYCorner,
			.layerMaxXMinYCorner
		]
		self.modalContentNode.clipsToBounds = true
		//		self.panGesture = UIPanGestureRecognizer(
		//			target: self,
		//			action: #selector(self.handlePan(_:))
		//		)
		//		self.modalContentNode.view.addGestureRecognizer(self.panGesture!)
		self.addSubnode(self.modalContentNode)
		
		self.bottomInsetNode.backgroundColor = theme.custom.aiInputBackground
		self.modalContentNode.addSubnode(self.bottomInsetNode)
		
		
		// Header -------------------------------------------------
		// Header content setup
		
		self.modalContentNode.addSubnode(self.modalNavBarNode)
		// Button back
		self.backNode.contentMode = .center
		
		self.backNode.image = generateTintedImage(
			image: UIImage(bundleImageName: "Ton/IconArrowLeft"),
			color: theme.custom.navBarButtonIconColor,
			backgroundColor: nil
		)
		self.backNode.tintColor = theme.custom.navBarButtonIconColor
		self.backNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dissmissPressed)))
		self.modalNavBarNode.addSubnode(self.backNode)
		
		// Button apply
		self.applyNode.displaysAsynchronously = false
		self.applyNode.attributedText = NSAttributedString(
			string: self.presentationData.strings.Theme_Context_Apply,
			font: Font.regular(15),
			textColor: theme.custom.navBarButtonTextColor
		)
		let applyTap = UITapGestureRecognizer(target: self, action: #selector(self.applyTapped))
		self.applyNode.view.addGestureRecognizer(applyTap)
		self.modalNavBarNode.addSubnode(self.applyNode)
		// Title text
		self.titleIconNode.image = UIImage(named: "Ton/IconAi")
		
		
		self.titleTextNode.attributedText = NSAttributedString(
			string: "AI Tony",
			font: Font.bold(20),
			textColor: theme.custom.navBarTitleColor
		)
		
		self.modalNavBarNode.addSubnode(self.titleIconNode)
		self.modalNavBarNode.addSubnode(self.titleTextNode)
		//----------------------------------------------------------
		
		// Body -------------------------------------------------
		// Body content setup
		
		self.modalContentNode.addSubnode(self.modalBodyNode)
		
		// Tool buttons container
		self.modalContentNode.addSubnode(self.toolContainer)
		
		//  Tool buttons container - Translate Button
		let isDark = theme.overallDarkAppearance
		if isDark {
			self.translateButton.borderColor = UIColor(rgb: 0x7C99D6).cgColor
			self.translateButton.borderWidth = 1.0
			self.translateButton.backgroundColor = theme.custom.modalBackground
			self.translateIcon.image = generateTintedImage(
				image: UIImage(named: "Ton/IconTranslate2"),
				color: theme.custom.accent2Color
			)
			self.translateText.attributedText = NSAttributedString(
				string: "Translation",
				font: Font.medium(14),
				textColor: theme.custom.primaryTextColor
			)
		}else{
			self.translateButton.backgroundColor = theme.custom.accent2Color
			self.translateImage.image = UIImage(named: "Ton/ButtonAi")
			self.translateIcon.image = generateTintedImage(
				image: UIImage(named: "Ton/IconTranslate2"),
				color: .white
			)
			self.translateText.attributedText = NSAttributedString(
				string: "Translation",
				font: Font.medium(14),
				textColor: .white
			)
		}
		
	
		self.translateButton.view.addGestureRecognizer(UITapGestureRecognizer(
			target: self,
			action: #selector(self.translationTabTapped)
		))
		self.toolContainer.addSubnode(self.translateButton)
		
		self.translateImage.contentMode = .scaleToFill
		self.translateButton.addSubnode(self.translateImage)
		
		self.translateIcon.contentMode = .scaleAspectFit
		self.translateButton.addSubnode(self.translateIcon)
		
	
		self.translateButton.addSubnode(self.translateText)
		
		
		//  Tool buttons container - Writing Button
		self.writingButton.clipsToBounds = true
		self.writingButton.backgroundColor = theme.custom.aiButtonDisabledColor
		self.writingButton.borderColor = UIColor(rgb: 0xBDCBEA).cgColor
		self.writingButton.borderWidth = 1.0
		self.writingButton.view.addGestureRecognizer(UITapGestureRecognizer(
			target: self,
			action: #selector(self.writingTapped)
		))
		self.toolContainer.addSubnode(self.writingButton)
		
		self.writingIcon.contentMode = .scaleAspectFit
		self.writingIcon.image = UIImage(named: "Ton/IconWriting")?
			.withRenderingMode(.alwaysTemplate)
			.withTintColor(UIColor(rgb: 0x5f6e90))
		self.writingButton.addSubnode(self.writingIcon)
		
		self.writingText.attributedText = NSAttributedString(
			string: "Writing Assistant",
			font: Font.medium(14),
			textColor: UIColor(rgb: 0x878991)
		)
		self.writingButton.addSubnode(self.writingText)
		
		self.commingText.attributedText = NSAttributedString(
			string: "Comming soon",
			font: Font.regular(10),
			textColor: UIColor(rgb: 0x752229)
		)
		self.writingButton.addSubnode(self.commingText)
		
		// Language selected container -------------------------------------------
		self.modalContentNode.addSubnode(self.languageContainer)
		
		self.languageIcon.image = UIImage(named: "Ton/IconTranslate2")
		self.languageContainer.addSubnode(self.languageIcon)
		self.languageContainer.view.addGestureRecognizer(UITapGestureRecognizer(
			target: self,
			action: #selector(self.languageTapped)
		))
		self.languageText.attributedText = NSAttributedString(
			string: "Choose language",
			font: Font.semibold(14),
			textColor: theme.custom.accent2Color
		)
		self.languageContainer.addSubnode(self.languageText)
		
		self.languageArrow.image = UIImage(named: "Ton/IconDropdown")
		self.languageArrow.contentMode = .scaleAspectFit
		self.languageContainer.addSubnode(self.languageArrow)
		self.languageContainer.addSubnode(self.progressNode)
		
		
		// Translated Text --------------------------------------------
		self.dividerNode.backgroundColor = theme.list.itemPlainSeparatorColor
		self.modalContentNode.addSubnode(self.dividerNode)
		
		self.translatedTextNode.attributedText = NSAttributedString(
			string: "...",
			font: Font.regular(inputTextSize),
			textColor: theme.custom.aiTranslatedColor
		)
		self.modalContentNode.addSubnode(self.translatedTextNode)
		
		
		// Footer --------------------------------------------
		
		self.inputSeparateNode.backgroundColor = theme.list.itemPlainSeparatorColor
		self.modalContentNode.addSubnode(self.inputSeparateNode)
		
		self.inputBackgroundNode.backgroundColor = theme.custom.aiInputBackground
		self.modalContentNode.addSubnode(self.inputBackgroundNode)
		
		self.inputDelegate.onTextChanged = { [weak self] text in
			guard let strongSelf = self else { return }
			strongSelf.invalidateIntrinsicContentSizeAndNotify()
			strongSelf.delayTranstate()
		}
		
		if let tv = self.userInputNode.view as? UITextView {
			tv.backgroundColor = .clear
			tv.textColor = theme.custom.aiInputTextColor
			tv.textContainer.lineFragmentPadding = 0
			tv.font = Font.regular(inputTextSize)
			tv.delegate = self.inputDelegate
			tv.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
		}
		
		self.modalContentNode.addSubnode(self.userInputNode)
		
		
		
		self.placeholderNode.displaysAsynchronously = false
		self.placeholderNode.isUserInteractionEnabled = false
		self.placeholderNode.attributedText = NSAttributedString(
			string: presentationData.strings.Conversation_InputTextPlaceholder,
			font: Font.regular(inputTextSize),
			textColor: theme.custom.aiInputHolderColor
		)
		self.inputBackgroundNode.addSubnode(self.placeholderNode)
		
		self.sendButtonNode.image = UIImage(named: "Ton/IconArrowUp")?.withRenderingMode(.alwaysTemplate)
		self.sendButtonNode.contentMode = .scaleAspectFit
		self.sendButtonNode.view.addGestureRecognizer(UITapGestureRecognizer(
			target: self,
			action: #selector(self.sendButtonTapped)
		))
		self.inputBackgroundNode.addSubnode(self.sendButtonNode)
	}
	
	@objc private func dissmissPressed() {
		if currentKeyboardHeight > 0.0 {
			self.dismissAnimated()
		} else {
			self.dismissAnimated()
		}
		
	}
	
	deinit {
		self.pendingFetchWorkItem?.cancel()
	}
	
	@objc private func applyTapped() {
		print("Apply button tapped")
		let translatedText = self.translatedTextNode.attributedText?.string ?? ""
		self.dismissAnimated()
		if !translatedText.isEmpty && translatedText != "..." {
			self.onTextApplied?(translatedText)
		}
	}
	
	@objc private func translationTabTapped() {
		print("Translation tab tapped")
	}
	
	@objc private func sendButtonTapped() {
		print("Translation button tapped")
		guard let setting = self.translateSettings else {
			return
		}
		let language = setting.code
		if language.isEmpty {
			self.alertSelectLanguage()
		} else {
			self.fetchTranslation(language: language)
		}
	}
	
	private var pendingFetchWorkItem: DispatchWorkItem?
	
	private func delayTranstate() {
		
		self.pendingFetchWorkItem?.cancel()
		let work = DispatchWorkItem { [weak self] in
			guard let strongSelf = self else { return }
			guard let setting = strongSelf.translateSettings else { return }
			let language = setting.code
			if !language.isEmpty {
				strongSelf.fetchTranslation(language: language)
			}
		}
		self.pendingFetchWorkItem = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
		
		
	}
	
	private func fetchTranslation(language: String){
		let currentText = (self.userInputNode.view as? UITextView)?.text ?? ""
		let trimText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
		if trimText.isEmpty {
			//self.view.endEditing(true)
			return
		}
		self.showProgress()
		let task = context.sharedContext.postTranslateText(text: trimText, language: language)
		let _ = (task |> deliverOnMainQueue)
			.start(next: { [weak self] s in
				let translatedText = s ?? ""
				print("Translated: \(translatedText)")
				
				guard let strongSelf = self else {	return }
				strongSelf.hideProgress()
				strongSelf.setTranslatedText(translatedText)
				strongSelf.onTextTranslated?(translatedText)
			})
	}
	
	func alertSelectLanguage(){
		let alertController =  self.context.sharedContext.simpleTextAlert(
			text: "Please select translate language."
		)
		self.controller.present(alertController, in: .window(.root))
	}
	
	@objc private func writingTapped() {
		let alertController =  self.context.sharedContext.simpleTextAlert(
			text: "Coming soon"
		)
		self.controller.present(alertController, in: .window(.root))
	}
	
	@objc private func languageTapped() {
		let ctl = LanguagesController(
			context: self.context,
			fetchLanguages: self.fetchLanguages
		)
		ctl.languageSelectionChanged = { [weak self] language in
			if let strongSelf = self {
				strongSelf.updateSelectedLanguage(language)
				strongSelf.sendButtonTapped()
			}
		}
		self.controller.present(
			ctl,
			in: .window(.root)
		)
	}
	
	func updateSelectedLanguage(_ settings: OutgoingTranslateSetting?){
		self.translateSettings = settings
		//let languageY = toolContainerY + toolHeight + 16
		let langButtonHeight = 40.0
		let langIconSize = 24.0
		let arrowSize = 16.0
		
		let langTextMeasure = TextNode.asyncLayout(self.languageText)
		self.languageText.attributedText = NSAttributedString(
			string: settings?.name ?? "Choose language",
			font: Font.semibold(14),
			textColor: self.presentationData.theme.custom.accent2Color
		)
		let (langTextLayout, langTextApply) = langTextMeasure(TextNodeLayoutArguments(
			attributedString: self.languageText.attributedText!,
			maximumNumberOfLines: 0,
			truncationType: .start,
			constrainedSize: CGSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
		))
		let _ = langTextApply()
		self.languageText.frame = CGRect(
			x: langIconSize + 6,
			y: floor((langButtonHeight - langTextLayout.size.height) / 2.0),
			width: langTextLayout.size.width,
			height: langTextLayout.size.height
		)
		
		self.languageArrow.frame = CGRect(
			x: self.languageText.frame.maxX + 6,
			y: floor((langButtonHeight - arrowSize) / 2.0),
			width: arrowSize,
			height: arrowSize
		)
	}
	
	func setUserInputText(_ text: String?){
		let s : String = text ?? ""
		if let tv = self.userInputNode.view as? UITextView {
			tv.text = s
			self.invalidateIntrinsicContentSizeAndNotify()
			if let setting = self.translateSettings {
				self.fetchTranslation(language: setting.code)
			} else {
				let languageCode = self.presentationData.strings.primaryComponent.languageCode
				self.fetchTranslation(language: languageCode)
			}
		}
	}
	
	func setTranslatedText(_ text: String?){
		if(screenWidth > 0){
			let s = text ?? ""
			self.translatedTextNode.attributedText = NSAttributedString(
				string: s.isEmpty ? "..." : s,
				font: Font.regular(inputTextSize),
				textColor: presentationData.theme.custom.aiTranslatedColor
			)
			let frame = self.translatedTextNode.frame
			let textSize = self.translatedTextNode.measure(CGSize(
				width: screenWidth - (padding * 2),
				height: .greatestFiniteMagnitude
			))
			
			self.translatedTextNode.frame = CGRect(
				x: frame.origin.x,
				y: frame.origin.y,
				width:  textSize.width,
				height: modalHeight - headerHeight  + maxInputHeight + padding
			)
		}
		
	}
	
	public func animateIn() {
		DispatchQueue.main.async {
			// guard against repeated animations
			if self.dimNode.alpha >= 0.99 {
				return
			}
			// ensure starting state: offscreen and dimmed
			let startOffset = max(CGFloat(self.modalHeight), UIScreen.main.bounds.height)
			self.modalContentNode.layer.setAffineTransform(CGAffineTransform(translationX: 0, y: startOffset))
			self.dimNode.alpha = 0.0
			// slide up with decelerate curve
			UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut, .allowUserInteraction], animations: {
				self.modalContentNode.layer.setAffineTransform(.identity)
				self.dimNode.alpha = 1.0
			}, completion: nil)
		}
	}
	
	private func dismissAnimated() {
		DispatchQueue.main.async {
			let endOffset = max(CGFloat(self.modalHeight), UIScreen.main.bounds.height)
			UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: {
				self.modalContentNode.layer.setAffineTransform(CGAffineTransform(translationX: 0, y: endOffset))
				self.dimNode.alpha = 0.0
			}, completion: { _ in
				self.controller.dismiss(animated: false)
			})
		}
	}
	

	
	// TODO: Ton - AI: Modal layout
	func updateLayout(
		layout: ContainerViewLayout,
		transition: ContainedViewLayoutTransition
	) {
		
		
		self.containerLayout = layout
		self.dimNode.frame = CGRect(origin: .zero, size: layout.size)
		
		self.screenWidth = layout.size.width
		self.screenHeight = layout.size.height
		
		let inputHeight = layout.inputHeight ?? 0.0
		self.currentKeyboardHeight = inputHeight
		self.cacheBottomInsetHeight = layout.intrinsicInsets.bottom
	
		
		// Bottom inset
		let keyboardShown = inputHeight > 0.0
		if keyboardShown {
			self.bottomInsetHeight = 0
		} else {
			self.bottomInsetHeight = self.cacheBottomInsetHeight
		}
		
		
		
		if(self.currentKeyboardHeight > 0.0){
			self.modalY = layout.safeInsets.top
			self.modalHeight = screenHeight - self.currentKeyboardHeight - layout.safeInsets.top
			transition.updateFrame(node: self.modalContentNode, frame: CGRect(
				x: 0,
				y: modalY,
				width: screenWidth,
				height: modalHeight
			))
		}else{
			self.modalY = layout.safeInsets.top
			self.modalHeight = screenHeight - self.currentKeyboardHeight - layout.safeInsets.top
			transition.updateFrame(node: self.modalContentNode, frame: CGRect(
				x: 0,
				y: modalY,
				width: screenWidth,
				height: modalHeight
			))
		}
		
		
		
		// Header content layout
		transition.updateFrame(node: self.modalNavBarNode, frame: CGRect(
			x: 0,
			y: 0,
			width: screenWidth,
			height: headerHeight
		))
		self.backNode.frame = CGRect(x: padding, y: 14, width: 28, height: 28)
		
		// Apply button
		let applyTextMeasure = TextNode.asyncLayout(self.applyNode)
		let (applyTextLayout, applyTextApply) = applyTextMeasure(TextNodeLayoutArguments(
			attributedString: self.applyNode.attributedText!,
			maximumNumberOfLines: 0,
			truncationType: .end,
			constrainedSize: CGSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
		))
		let _ = applyTextApply()
		// Measure and center vertically inside header
		let applySize = applyTextLayout.size
		transition.updateFrame(node: self.applyNode, frame: CGRect(
			x: screenWidth - applySize.width - padding,
			y: floor((headerHeight - applySize.height) / 2.0),
			width: applySize.width,
			height: applySize.height
		))
		
		// Header title
		let titleTextMeasure = TextNode.asyncLayout(self.titleTextNode)
		let (titleTextLayout, titleTextApply) = titleTextMeasure(TextNodeLayoutArguments(
			attributedString: self.titleTextNode.attributedText,
			maximumNumberOfLines: 1,
			truncationType: .end,
			constrainedSize: CGSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
		))
		let _ = titleTextApply()
		
		
		
		let titleTextSize = titleTextLayout.size
		let titleX = floor((screenWidth - aiIconSize - titleTextSize.width - aiIconMargin) / 2.0)
		transition.updateFrame(node: self.titleIconNode, frame: CGRect(
			x: titleX,
			y: floor((headerHeight - aiIconSize) / 2.0),
			width: aiIconSize,
			height: aiIconSize
		))
		transition.updateFrame(node: self.titleTextNode, frame: CGRect(
			x: titleX + aiIconSize + aiIconMargin,
			y: floor((headerHeight - titleTextSize.height) / 2.0),
			width: titleTextSize.width,
			height: titleTextSize.height
		))
		
		
		
		// Body content layout -----------
		transition.updateFrame(node: self.modalBodyNode, frame: CGRect(
			x: 0,
			y: headerHeight,
			width: screenWidth,
			height: modalHeight - headerHeight
		))
		
		
		// Tool buttons container layout
		let toolContainerY: CGFloat = headerHeight + 12
		
		let toolIconY = floor((toolHeight - toolIconSize) / 2.0)
		let buttonRadius = toolHeight/2
		
		self.toolContainer.frame = CGRect(
			x: padding,
			y: toolContainerY,
			width: screenWidth - padding * 2,
			height: toolHeight
		)
		
		// Translate button layout
		
		let translateTextMeasure = TextNode.asyncLayout(self.translateText)
		let (translateTextLayout, translateTextApply) = translateTextMeasure(TextNodeLayoutArguments(
			attributedString: self.translateText.attributedText!,
			maximumNumberOfLines: 0,
			truncationType: .start,
			constrainedSize: CGSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
		))
		let _ = translateTextApply()
		let transtateButtonWidth = padding + toolIconSize + toolIconPadding + translateTextLayout.size.width + padding
		self.translateButton.cornerRadius = buttonRadius
		self.translateButton.frame = CGRect(
			x: 0,
			y: 0,
			width: transtateButtonWidth,
			height: toolHeight
		)
		self.translateImage.frame = CGRect(
			x: 0,
			y: 0,
			width: transtateButtonWidth,
			height: toolHeight
		)
		self.translateIcon.frame = CGRect(
			x: padding,
			y: toolIconY,
			width: toolIconSize,
			height: toolIconSize
		)
		self.translateText.frame = CGRect(
			x: padding + toolIconSize + toolIconPadding,
			y: floor((toolHeight - translateTextLayout.size.height) / 2.0),
			width: translateTextLayout.size.width,
			height: translateTextLayout.size.height
		)
		
		// Writing button layout
		let writingTextMeasure = TextNode.asyncLayout(self.writingText)
		let (writingTextLayout, writingTextApply) = writingTextMeasure(TextNodeLayoutArguments(
			attributedString: self.writingText.attributedText!,
			maximumNumberOfLines: 0,
			truncationType: .start,
			constrainedSize: CGSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
		))
		let _ = writingTextApply()
		
		let comingTextMeasure = TextNode.asyncLayout(self.commingText)
		let (comingTextLayout, comingTextApply) = comingTextMeasure(TextNodeLayoutArguments(
			attributedString: self.commingText.attributedText!,
			maximumNumberOfLines: 0,
			truncationType: .start,
			constrainedSize: CGSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
		))
		let _ = comingTextApply()
		
		let writingButtonWidth = padding + toolIconSize + toolIconPadding + writingTextLayout.size.width + padding
		self.writingButton.cornerRadius = buttonRadius
		self.writingButton.frame = CGRect(
			x: self.translateButton.frame.maxX + 4,
			y: 0,
			width: writingButtonWidth,
			height: toolHeight
		)
		self.writingIcon.frame = CGRect(
			x: padding,
			y: toolIconY,
			width: toolIconSize,
			height: toolIconSize
		)
		let writingTextX = padding + toolIconSize + toolIconPadding
		let writingTextHeight = writingTextLayout.size.height + comingTextLayout.size.height
		self.writingText.frame = CGRect(
			x: writingTextX,
			y: floor((toolHeight - writingTextHeight) / 2.0),
			width: writingTextLayout.size.width,
			height: writingTextLayout.size.height
		)
		self.commingText.frame = CGRect(
			x: writingTextX,
			y: self.writingText.frame.maxY,
			width: comingTextLayout.size.width,
			height: comingTextLayout.size.height
		)
		
		// Language select button
		let languageY = toolContainerY + toolHeight + 16
		
		self.languageContainer.frame = CGRect(
			x: padding,
			y: languageY,
			width: screenWidth - padding,
			height: langButtonHeight
		)
		self.languageIcon.frame = CGRect(
			x: 0,
			y: floor((langButtonHeight - langIconSize) / 2.0),
			width: langIconSize,
			height: langIconSize
		)
		let langTextMeasure = TextNode.asyncLayout(self.languageText)
		let (langTextLayout, langTextApply) = langTextMeasure(TextNodeLayoutArguments(
			attributedString: self.languageText.attributedText!,
			maximumNumberOfLines: 0,
			truncationType: .start,
			constrainedSize: CGSize(
				width: CGFloat.greatestFiniteMagnitude,
				height: CGFloat.greatestFiniteMagnitude
			)
		))
		let _ = langTextApply()
		self.languageText.frame = CGRect(
			x: self.languageIcon.frame.maxX + 6,
			y: floor((langButtonHeight - langTextLayout.size.height) / 2.0),
			width: langTextLayout.size.width,
			height: langTextLayout.size.height
		)
		
		self.languageArrow.frame = CGRect(
			x: self.languageText.frame.maxX + 6,
			y: floor((langButtonHeight - arrowSize) / 2.0),
			width: arrowSize,
			height: arrowSize
		)
		
		// divider
		let dividerY = languageY + 40 + 12
		self.dividerNode.frame = CGRect(x: padding, y: dividerY, width: screenWidth - padding * 2, height: 1)
		self.translatedTextNode.frame = CGRect(
			x: padding,
			y: dividerY + 20,
			width: screenWidth - padding * 2,
			height: 22
		)
		
		
		// Footer layout -----------
		self.invalidateIntrinsicContentSizeAndNotify()
	}
	
	@objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
		let view = self.view
		
		let translation = gesture.translation(in: view)
		let velocity = gesture.velocity(in: view)
		
		switch gesture.state {
			
		case .began:
			self.initialContainerY = self.modalContentNode.frame.minY
			
		case .changed:
			if translation.y > 0 {
				self.modalContentNode.frame.origin.y =
				self.initialContainerY + translation.y
			}
			
		case .ended, .cancelled:
			let shouldDismiss =
			translation.y > 120 || velocity.y > 1200
			
			if shouldDismiss {
				self.dismissAnimated()
			} else {
				self.snapBack()
			}
			
		default:
			break
		}
	}
	
	private func snapBack() {
		guard let layout = self.containerLayout else { return }
		
		let targetFrame = CGRect(
			x: 0,
			y: layout.size.height - modalHeight,
			width: layout.size.width,
			height: modalHeight
		)
		
		let transition = ContainedViewLayoutTransition.animated(
			duration: 0.25,
			curve: .spring
		)
		
		transition.updateFrame(
			node: self.modalContentNode,
			frame: targetFrame
		)
	}

	private func invalidateIntrinsicContentSizeAndNotify() {
		guard let tv = self.userInputNode.view as? UITextView else { return }
		let textWidth = screenWidth - (padding * 2) - sendButtonSize - 4
		
		// Constant constraint
		let placeholderSize = self.placeholderNode.measure(CGSize(
			width: screenWidth - (padding * 2) - sendButtonSize - 4,
			height: CGFloat.greatestFiniteMagnitude
		))
		self.placeholderNode.frame = CGRect(
			x: padding,
			y: padding,
			width: placeholderSize.width,
			height: placeholderSize.height
		)
		self.placeholderNode.isHidden = !tv.text.isEmpty
		//
		
	
		let targetSize = tv.sizeThatFits(CGSize(
			width: textWidth,
			height: CGFloat.greatestFiniteMagnitude
		))
		var textHeight = max(minInputHeight, targetSize.height)
		let textPaddingTop = 4.0
		textHeight = min(textHeight, maxInputHeight)
		let textY = modalHeight - textHeight
		self.sendButtonNode.frame = CGRect(
			x: screenWidth - self.sendButtonSize - self.padding ,
			y: (textHeight - sendButtonSize - floor((minInputHeight - sendButtonSize) / 2.0) + textPaddingTop) ,
			width: sendButtonSize,
			height: sendButtonSize
		)
		self.inputSeparateNode.frame = CGRect(
			x: 0,
			y: textY - 9 - bottomInsetHeight,
			width: screenWidth,
			height: 1
		)
		self.inputBackgroundNode.frame = CGRect(
			x: 0,
			y: textY - 8 - bottomInsetHeight,
			width: screenWidth,
			height: textHeight + 8
		)
		self.userInputNode.frame = CGRect(
			x: padding,
			y: textY + textPaddingTop  - bottomInsetHeight,
			width: textWidth,
			height: textHeight
		)
//		self.bottomInsetNode.frame = CGRect(
//			x: 0,
//			y: textY - textPaddingTop - bottomInsetHeight + textHeight + 8,
//			width: screenWidth,
//			height: self.bottomInsetHeight + 8
//		)
		let bottomY = self.inputBackgroundNode.frame.maxY
		self.bottomInsetNode.frame = CGRect(
			x: 0,
			y: bottomY,
			width: screenWidth,
			height: self.screenHeight - bottomY
		)
	}
	
	public func focusInputTextNode() {
		DispatchQueue.main.async {
			(self.userInputNode.view as? UITextView)?.becomeFirstResponder()
		}
	}
	
	public func resignFirstResponderIfNeeded() {
		(self.userInputNode.view as? UITextView)?.resignFirstResponder()
	}
	
	private var currentKeyboardHeight: CGFloat = 0.0
	
	func setKeyboardHeight(_ height: CGFloat, duration: Double, curve: UIView.AnimationCurve) {
		// store new value
		
		if height != self.currentKeyboardHeight {
			self.currentKeyboardHeight = height
			let keyboardShown = height > 0.0
			if keyboardShown {
				self.bottomInsetHeight = 0
			} else {
				self.bottomInsetHeight = self.cacheBottomInsetHeight
			}
			DispatchQueue.main.async {
				guard let layout = self.containerLayout else {
					// if no layout yet, just apply a transform fallback
					//let transform = CGAffineTransform(translationX: 0, y: -height)
					//self.modalContentNode.layer.setAffineTransform(transform)
					return
				}
				let transition = ContainedViewLayoutTransition.animated(duration: duration, curve: .linear)
				self.updateLayout(layout: layout, transition: transition)
			}
		}
	}
	
	private func showProgress(){
		let progressSize = 20.0
		if self.progressNode.image == nil {
			self.progressNode.image = generateIndefiniteActivityIndicatorImage(
				color: self.presentationData.theme.custom.accent2Color,
				diameter: progressSize,
				lineWidth: 2.0 + UIScreenPixel
			)
			
			let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
			rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
			rotationAnimation.duration = 1.0
			rotationAnimation.fromValue = NSNumber(value: Float(0.0))
			rotationAnimation.toValue = NSNumber(value: Float.pi * 2.0)
			rotationAnimation.repeatCount = Float.infinity
			rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
			rotationAnimation.beginTime = 1.0
			self.progressNode.layer.add(rotationAnimation, forKey: "progressRotation")
			
		}
		self.progressNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
		let parentSize = self.languageContainer.frame.size
		self.progressNode.frame = CGRect(
			x: parentSize.width - progressSize - self.padding,
			y: floor((parentSize.height - progressSize) / 2.0),
			width: progressSize,
			height: progressSize
		)
	}
	
	private func hideProgress(){
		self.progressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
			//[weak progressNode, weak self] _ in
			
		})
	}
	
	private class InputDelegate: NSObject, UITextViewDelegate {
		
		var onTextChanged: ((String) -> Void)?
		
		func textViewDidChange(_ textView: UITextView) {
			self.onTextChanged?(textView.text ?? "")
		}
		
		func textView(
			_ textView: UITextView,
			shouldChangeTextIn range: NSRange,
			replacementText text: String
		) -> Bool {
			// handle send on newline if you want:
			// if text == "\n" { owner?.send(); return false }
			return true
		}
	}
	
	
}
