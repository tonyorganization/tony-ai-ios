import AccountContext
import AnimatedStickerNode
import AsyncDisplayKit
import AuthorizationUtils
import CountrySelectionUI
import Display
import Foundation
import ManagedAnimationNode
import PhoneInputNode
import Postbox
import QrCode
import SolidRoundedButtonNode
import SwiftSignalKit
import TelegramAnimatedStickerNode
import TelegramCore
import TelegramPresentationData
import UIKit

private final class PhoneAndCountryNode: ASDisplayNode {
	let strings: PresentationStrings
	let theme: PresentationTheme
	
	let countryBackground: ASDisplayNode
	let countryButton: ASButtonNode
	let countryArrow: ASImageNode
	
	let phoneBackground: ASDisplayNode
	let phoneInputNode: PhoneInputNode
	
	var selectCountryCode: (() -> Void)?
	var checkPhone: (() -> Void)?
	var hasNumberUpdated: ((Bool) -> Void)?
	var keyPressed: ((Int) -> Void)?
	
	var preferredCountryIdForCode: [String: String] = [:]
	
	let inputHeight : CGFloat
	
	var hasCountry = false
	
	let presentationData : PresentationData
	
	init(presentationData: PresentationData) {
		self.presentationData = presentationData
		self.strings = presentationData.strings
		self.theme = presentationData.theme
		
		self.countryBackground = ASDisplayNode()
		self.countryButton = ASButtonNode()
		self.countryArrow = ASImageNode()
		
		self.phoneBackground = ASImageNode()
		self.phoneInputNode = PhoneInputNode()
		self.inputHeight = presentationData.dimen.inputHeight
		super.init()
		
		// TODO: Ton - Phone Auth: country button background
		self.countryBackground.backgroundColor = theme.custom.inputBackground
		self.countryBackground.cornerRadius = self.inputHeight / 2
		self.countryBackground.clipsToBounds = true
		self.addSubnode(self.countryBackground)
		// TODO: Ton - Phone Auth: country button
		self.countryButton.displaysAsynchronously = false
		self.countryButton.titleNode.maximumNumberOfLines = 1
		self.countryButton.titleNode.truncationMode = .byTruncatingTail
		self.countryButton.contentHorizontalAlignment = .left
		
		
		self.countryButton.addTarget(
			self,
			action: #selector(self.countryPressed),
			forControlEvents: .touchUpInside
		)
		
		self.addSubnode(self.countryButton)
		
		self.countryArrow.image = generateTintedImage(
			image: UIImage(bundleImageName: "Item List/DisclosureArrow"),
			color: theme.list.itemPrimaryTextColor
		)
		self.countryButton.addSubnode(self.countryArrow)
		
		// TODO: Ton - Phone Auth: phone input
		self.phoneBackground.backgroundColor = theme.custom.inputBackground
		self.phoneBackground.cornerRadius = self.inputHeight / 2
		self.phoneBackground.clipsToBounds = true
		self.phoneBackground.borderColor = self.theme.custom.accentColor.cgColor
		self.phoneBackground.borderWidth = 1.4
		self.addSubnode(self.phoneBackground)
		
		self.addSubnode(self.phoneInputNode)
		
		let dialingTextNode = self.phoneInputNode.dialingTextNode
		let dialingTextField = dialingTextNode.textField
		dialingTextField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
		dialingTextField.textColor = theme.list.itemPrimaryTextColor
		dialingTextField.tintColor = theme.list.itemAccentColor
		dialingTextField.tintColor = theme.list.itemAccentColor
		dialingTextField.disableAutomaticKeyboardHandling = [.forward]
		dialingTextNode.accessibilityHint =	strings.Login_VoiceOver_PhoneCountryCode
		
		let phoneNumberNode = self.phoneInputNode.phoneNumberNode
		let phoneNumberField = phoneNumberNode.textField
		phoneNumberField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
		phoneNumberField.textColor = theme.list.itemPrimaryTextColor
		phoneNumberField.tintColor = theme.list.itemAccentColor
		phoneNumberField.tintColor = theme.list.itemAccentColor
		phoneNumberField.disableAutomaticKeyboardHandling = [.forward]
		phoneNumberNode.accessibilityHint = strings.Login_VoiceOver_PhoneNumber
		
		
		self.phoneInputNode.numberTextUpdated = { [weak self] number in
			if let strongSelf = self {
				let _ = strongSelf.processNumberChange(
					number: strongSelf.phoneInputNode.number
				)
				
				let isServiceNumber = strongSelf.phoneInputNode.number
					.hasPrefix("+999")
				if strongSelf.hasCountry || isServiceNumber {
					strongSelf.hasNumberUpdated?(
						!strongSelf.phoneInputNode.codeAndNumber.2.isEmpty
						|| isServiceNumber
					)
				} else {
					strongSelf.hasNumberUpdated?(false)
				}
			}
		}
		
		self.phoneInputNode.countryCodeUpdated = { [weak self] code, name in
			if let strongSelf = self {
				if let name = name {
					strongSelf.preferredCountryIdForCode[code] = name
				}
				
				if strongSelf.processNumberChange(number: strongSelf.phoneInputNode.number) {
				} else if let code = Int(code), let name = name,
						  let countryName = countryCodeAndIdToName[
							CountryCodeAndId(code: code, id: name)
						  ]
				{
					let flagString = emojiFlagForISOCountryCode(name)
					var localizedName: String =
					AuthorizationSequenceCountrySelectionController
						.lookupCountryNameById(
							name,
							strings: strongSelf.strings
						) ?? countryName
					if name == "FT" {
						localizedName =
						strongSelf.strings.Login_AnonymousNumbers
					}
					strongSelf.updateContryButton(
						flag: flagString,
						countryName: localizedName
					)
					strongSelf.hasCountry = true
					
					if strongSelf.phoneInputNode.mask == nil {
						strongSelf.phoneInputNode.phoneNumberNode.textField
							.attributedPlaceholder = NSAttributedString(
								string: strongSelf.strings.Login_PhonePlaceholder,
								font: Font.regular(20.0),
								textColor: strongSelf.theme.list.itemPlaceholderTextColor
							)
					}
				} else if let code = Int(code),
						  let (countryId, countryName) = countryCodeToIdAndName[code]
				{
					let flagString = emojiFlagForISOCountryCode(countryId)
					var localizedName: String =
					AuthorizationSequenceCountrySelectionController
						.lookupCountryNameById(
							countryId,
							strings: strongSelf.strings
						) ?? countryName
					if countryId == "FT" {
						localizedName =
						strongSelf.strings.Login_AnonymousNumbers
					}
					
					strongSelf.updateContryButton(
						flag: flagString,
						countryName: localizedName
					)
					strongSelf.hasCountry = true
					
					if strongSelf.phoneInputNode.mask == nil {
						strongSelf.phoneInputNode.phoneNumberNode.textField
							.attributedPlaceholder = NSAttributedString(
								string: strongSelf.strings.Login_PhonePlaceholder,
								font: Font.regular(20.0),
								textColor: strongSelf.theme.list.itemPlaceholderTextColor
							)
					}
				} else {
					strongSelf.hasCountry = false
					strongSelf.updateContryButton(
						flag: strongSelf.strings.Login_SelectCountry,
						countryName: ""
					)
					strongSelf.phoneInputNode.mask = nil
					strongSelf.phoneInputNode.phoneNumberNode.textField
						.attributedPlaceholder = NSAttributedString(
							string: strongSelf.strings.Login_PhonePlaceholder,
							font: Font.regular(20.0),
							textColor: strongSelf.theme.list.itemPlaceholderTextColor
						)
				}
				
				strongSelf.countryButton.accessibilityLabel =
				strongSelf.countryButton.attributedTitle(for: .normal)?
					.string ?? ""
				strongSelf.countryButton.accessibilityTraits = [.button]
				
				if strongSelf.hasCountry {
					strongSelf.hasNumberUpdated?(
						!strongSelf.phoneInputNode.codeAndNumber.2.isEmpty
					)
				} else {
					strongSelf.hasNumberUpdated?(false)
				}
			}
		}
		
		
		self.phoneInputNode.customFormatter = { number in
			if let (_, code) =
				AuthorizationSequenceCountrySelectionController
				.lookupCountryIdByNumber(number, preferredCountries: [:])
			{
				return code.code
			} else {
				return nil
			}
		}
		
		self.phoneInputNode.number = "+1"
		self.phoneInputNode.returnAction = { [weak self] in
			self?.checkPhone?()
		}
		
		self.phoneInputNode.keyPressed = { [weak self] num in
			self?.keyPressed?(num)
		}
	}
	
	func updateContryButton(flag: String, countryName: String) {
		self.countryButton.setTitle(
			"\(flag)   \(countryName)",
			with: Font.semibold(20.0),
			with: self.theme.list.itemPrimaryTextColor,
			for: []
		)
	}
	func processNumberChange(number: String) -> Bool {
		if let (country, _) =
			AuthorizationSequenceCountrySelectionController
			.lookupCountryIdByNumber(
				number,
				preferredCountries: self.preferredCountryIdForCode
			)
		{
			let flagString = emojiFlagForISOCountryCode(country.id)
			var localizedName: String =
			AuthorizationSequenceCountrySelectionController
				.lookupCountryNameById(country.id, strings: self.strings)
			?? country.name
			if country.id == "FT" {
				localizedName = self.strings.Login_AnonymousNumbers
			}
			self.updateContryButton(
				flag: flagString,
				countryName: localizedName
			)
			self.hasCountry = true
			
			let maskFont = Font.with(
				size: 20.0,
				design: .regular,
				traits: [.monospacedNumbers]
			)
			if let mask =
				AuthorizationSequenceCountrySelectionController
				.lookupPatternByNumber(
					number,
					preferredCountries: self.preferredCountryIdForCode
				).flatMap({
					NSAttributedString(
						string: $0,
						font: maskFont,
						textColor: self.theme.list.itemPlaceholderTextColor
					)
				})
			{
				self.phoneInputNode.phoneNumberNode.textField
					.attributedPlaceholder = nil
				self.phoneInputNode.mask = mask
			} else {
				self.phoneInputNode.mask = nil
				self.phoneInputNode.phoneNumberNode.textField
					.attributedPlaceholder = NSAttributedString(
						string: strings.Login_PhonePlaceholder,
						font: Font.regular(20.0),
						textColor: self.theme.list.itemPlaceholderTextColor
					)
			}
			return true
		} else {
			return false
		}
	}
	
	@objc func countryPressed() {
		self.selectCountryCode?()
	}
	
	override func layout() {
		super.layout()
		// TODO: Ton - Phone: Country and phone layout
		let size = self.bounds.size
		let screenWidth = size.width
		let layoutInset: CGFloat = 24.0
		let inputInset: CGFloat = 24.0
		let buttonWidth = screenWidth - (layoutInset * 2)
		let buttonSize = CGSize(
			width: buttonWidth,
			height: self.inputHeight
		)
		let buttonFrame = CGRect(
			origin: CGPoint(x: layoutInset, y: 0.0),
			size: buttonSize
		)
		self.countryButton.frame = buttonFrame
		self.countryButton.contentEdgeInsets = UIEdgeInsets(
			top: 0.0,
			left: inputInset,
			bottom: 0.0,
			right: 0.0
		)
		self.countryBackground.frame = buttonFrame
		let arrowSize = self.inputHeight * 0.6
		self.countryArrow.frame = CGRect(
			origin: CGPoint(
				x: buttonWidth - 16.0 - layoutInset,
				y: floor((self.inputHeight - arrowSize) / 2.0)
			),
			size: CGSize(
				width: arrowSize,
				height: arrowSize
			)
		)
		
		let phoneInputFrame = CGRect(
			origin: buttonFrame.origin.offsetBy(dx: 0, dy: self.inputHeight + 12),
			size: buttonSize
		);
		self.phoneBackground.frame = phoneInputFrame
		self.phoneInputNode.frame = phoneInputFrame
		
		let phoneCodeWidth =  buttonWidth * 0.20
		let dialingFrame = CGRect(
			origin: CGPoint(
				x: layoutInset,
				y: floor((self.inputHeight - 20) / 2.0)
			),
			size: CGSize(
				width: phoneCodeWidth,
				height: 20.0
			)
		)
		self.phoneInputNode.dialingTextNode.frame = dialingFrame
		self.phoneInputNode.dialingTextNode.backgroundColor = .clear
		self.phoneInputNode.separatorNode.frame = CGRect(
			origin: CGPoint(
				x: dialingFrame.maxX,
				y: floor((self.inputHeight - 20) / 2.0)
			),
			size: CGSize(
				width: 2,
				height: 20
			)
		)
		let numberFrame = CGRect(
			origin: CGPoint(
				x: dialingFrame.maxX + 2 + inputInset,
				y: floor((self.inputHeight - 20) / 2.0)
			),
			size: CGSize(
				width: buttonWidth - phoneCodeWidth - inputInset,
				height: 20.0
			)
		)
		self.phoneInputNode.phoneNumberNode.frame = numberFrame
		self.phoneInputNode.placeholderNode.frame = numberFrame
	}
	
}

private final class ContactSyncNode: ASDisplayNode {
	private let titleNode: ImmediateTextNode
	let switchNode: SwitchNode
	
	init(theme: PresentationTheme, strings: PresentationStrings) {
		self.titleNode = ImmediateTextNode()
		self.titleNode.maximumNumberOfLines = 1
		self.titleNode.attributedText = NSAttributedString(
			string: strings.Privacy_ContactsSync,
			font: Font.regular(17.0),
			textColor: theme.list.itemPrimaryTextColor
		)
		self.switchNode = SwitchNode()
		self.switchNode.frameColor = theme.list.itemSwitchColors.frameColor
		self.switchNode.contentColor = theme.list.itemSwitchColors.contentColor
		self.switchNode.handleColor = theme.list.itemSwitchColors.handleColor
		self.switchNode.isOn = true
		
		super.init()
		
		self.addSubnode(self.titleNode)
		self.addSubnode(self.switchNode)
	}
	
	func updateLayout(width: CGFloat) -> CGSize {
		var switchSize = CGSize(width: 51.0, height: 31.0)
		if let switchView = self.switchNode.view as? UISwitch {
			if self.switchNode.bounds.size.width.isZero {
				switchView.sizeToFit()
			}
			switchSize = switchView.bounds.size
		}
		
		let inset: CGFloat = 24.0
		let titleSize = self.titleNode.updateLayout(
			CGSize(
				width: width - switchSize.width - inset * 2.0 - 8.0,
				height: .greatestFiniteMagnitude
			)
		)
		let height: CGFloat = 40.0
		self.titleNode.frame = CGRect(
			origin: CGPoint(
				x: inset,
				y: floor((height - titleSize.height) / 2.0)
			),
			size: titleSize
		)
		self.switchNode.frame = CGRect(
			origin: CGPoint(
				x: width - inset - switchSize.width,
				y: floor((height - switchSize.height) / 2.0)
			),
			size: switchSize
		)
		return CGSize(width: width, height: height)
	}
}

final class AuthorizationSequencePhoneEntryControllerNode: ASDisplayNode {
	
	// TODO: Ton - Background: adapt
	private let backgroundImage = ASBackgroundImageNode()
	
	private let sharedContext: SharedAccountContext
	private var account: UnauthorizedAccount?
	private let strings: PresentationStrings
	private let theme: PresentationTheme
	private let hasOtherAccounts: Bool
	
	private let animationNode: AnimatedStickerNode
	private let managedAnimationNode: ManagedPhoneAnimationNode
	private let titleNode: ASTextNode
	private let titleActivateAreaNode: AccessibilityAreaNode
	private let noticeNode: ASTextNode
	private let noticeActivateAreaNode: AccessibilityAreaNode
	private let phoneAndCountryNode: PhoneAndCountryNode
	private let contactSyncNode: ContactSyncNode
	private let proceedNode: SolidRoundedButtonNode
	
	private var qrNode: ASImageNode?
	private let exportTokenDisposable = MetaDisposable()
	private let tokenEventsDisposable = MetaDisposable()
	var accountUpdated: ((UnauthorizedAccount) -> Void)?
	
	private let phoneImageNode: ASImageNode
	private let buttonImageNode: ASImageNode
	private let debugAction: () -> Void
	
	var currentNumber: String {
		return self.phoneAndCountryNode.phoneInputNode.number
	}
	
	var codeAndNumber: (Int32?, String?, String) {
		get {
			return self.phoneAndCountryNode.phoneInputNode.codeAndNumber
		}
		set(value) {
			self.phoneAndCountryNode.phoneInputNode.codeAndNumber = value
		}
	}
	
	var formattedCodeAndNumber: (String, String) {
		return self.phoneAndCountryNode.phoneInputNode.formattedCodeAndNumber
	}
	
	var syncContacts: Bool {
		if self.hasOtherAccounts {
			return self.contactSyncNode.switchNode.isOn
		} else {
			return true
		}
	}
	
	var selectCountryCode: (() -> Void)?
	var checkPhone: (() -> Void)?
	
	var inProgress: Bool = false {
		didSet {
			self.phoneAndCountryNode.phoneInputNode.enableEditing = !self
				.inProgress
			self.phoneAndCountryNode.phoneInputNode.alpha =
			self.inProgress ? 0.6 : 1.0
			self.phoneAndCountryNode.countryButton.isEnabled = !self.inProgress
			
			if self.inProgress != oldValue {
				if self.inProgress {
					self.proceedNode.transitionToProgress()
				} else {
					self.proceedNode.transitionFromProgress()
				}
			}
		}
	}
	
	var codeNode: ASDisplayNode {
		return self.phoneAndCountryNode.phoneInputNode.dialingTextNode
	}
	
	var numberNode: ASDisplayNode {
		return self.phoneAndCountryNode.phoneInputNode.phoneNumberNode
	}
	
	var buttonNode: ASDisplayNode {
		return self.proceedNode
	}
	let presentationData : PresentationData
	init(
		sharedContext: SharedAccountContext,
		account: UnauthorizedAccount?,
		presentationData : PresentationData,
		debugAction: @escaping () -> Void,
		hasOtherAccounts: Bool
	) {
		
		// TODO: Ton - Phone verify: edit UI
		self.sharedContext = sharedContext
		self.account = account
		self.presentationData = presentationData
		self.strings = presentationData.strings
		self.theme =  presentationData.theme
		self.debugAction = debugAction
		self.hasOtherAccounts = hasOtherAccounts
		
		self.animationNode = DefaultAnimatedStickerNodeImpl()
		self.animationNode.setup(
			source: AnimatedStickerNodeLocalFileSource(name: "IntroPhone"),
			width: 256,
			height: 256,
			playbackMode: .once,
			mode: .direct(cachePathPrefix: nil)
		)
		
		self.phoneImageNode = ASImageNode()
		self.phoneImageNode.image = UIImage(named: "Ton/PhoneFlat")
		self.phoneImageNode.contentMode = .scaleAspectFit
		self.phoneImageNode.displaysAsynchronously = false
		self.phoneImageNode.isLayerBacked = true
		
		self.buttonImageNode = ASImageNode()
		self.buttonImageNode.image = generateTintedImage(
			image: UIImage(bundleImageName: "Ton/IconArrowRight"),
			color: .black
		)
		self.buttonImageNode.contentMode = .scaleAspectFit
		
		self.managedAnimationNode = ManagedPhoneAnimationNode()
		self.managedAnimationNode.isHidden = true
		
		self.titleNode = ASTextNode()
		self.titleNode.isUserInteractionEnabled = true
		self.titleNode.displaysAsynchronously = false
		self.titleNode.attributedText = NSAttributedString(
			string: account == nil
			? strings.Login_NewNumber : strings.Login_PhoneTitle,
			font: Font.light(17.0),
			textColor: theme.custom.accentColor
		)
		self.titleNode.insets = UIEdgeInsets(
			top: 12.0,
			left: 0.0,
			bottom: 4.0,
			right: 0.0
		)
		self.titleActivateAreaNode = AccessibilityAreaNode()
		self.titleActivateAreaNode.accessibilityTraits = .staticText
		
		self.noticeNode = ASTextNode()
		self.noticeNode.maximumNumberOfLines = 0
		self.noticeNode.isUserInteractionEnabled = true
		self.noticeNode.displaysAsynchronously = false
		self.noticeNode.lineSpacing = 0.1
		self.noticeNode.insets = UIEdgeInsets(
			top: 4.0,
			left: 0.0,
			bottom: 12.0,
			right: 0.0
		)
		self.noticeActivateAreaNode = AccessibilityAreaNode()
		self.noticeActivateAreaNode.accessibilityTraits = .staticText
		
		self.noticeNode.attributedText = NSAttributedString(
			string: account == nil
			? strings.ChangePhoneNumberNumber_Help
			: strings.Login_PhoneAndCountryHelp,
			font: Font.regular(17.0),
			textColor: theme.list.itemPrimaryTextColor.withAlphaComponent(0.5),
			paragraphAlignment: .center
		)
		
		self.contactSyncNode = ContactSyncNode(theme: theme, strings: strings)
		
		self.phoneAndCountryNode = PhoneAndCountryNode(presentationData: presentationData)
		
		self.proceedNode = SolidRoundedButtonNode(
			title: self.strings.Login_Continue,
			theme: SolidRoundedButtonTheme(theme: self.theme),
			height: self.presentationData.dimen.buttonHeight,
			cornerRadius: self.presentationData.dimen.buttonRadius
		)
		self.proceedNode.progressType = .embedded
		self.proceedNode.isEnabled = false
		
		super.init()
		
		self.setViewBlock({
			return UITracingLayerView()
		})
		
		self.backgroundColor = theme.list.plainBackgroundColor
		// TODO: Ton - Background: adapt
		self.addSubnode(self.backgroundImage)
		self.addSubnode(self.backgroundImage)
		self.addSubnode(self.phoneImageNode)
		self.addSubnode(self.titleNode)
		self.addSubnode(self.noticeNode)
		self.addSubnode(self.titleActivateAreaNode)
		self.addSubnode(self.noticeActivateAreaNode)
		self.addSubnode(self.phoneAndCountryNode)
		self.addSubnode(self.contactSyncNode)
		self.addSubnode(self.proceedNode)
		self.proceedNode.addSubnode(self.buttonImageNode)
		//self.addSubnode(self.animationNode)
		//self.addSubnode(self.managedAnimationNode)
		self.contactSyncNode.isHidden = true
		
		self.phoneAndCountryNode.selectCountryCode = { [weak self] in
			self?.selectCountryCode?()
		}
		self.phoneAndCountryNode.checkPhone = { [weak self] in
			self?.checkPhone?()
		}
		self.phoneAndCountryNode.hasNumberUpdated = { [weak self] hasNumber in
			self?.proceedNode.isEnabled = hasNumber
		}
		self.phoneAndCountryNode.keyPressed = { [weak self] num in
			if let strongSelf = self, !strongSelf.managedAnimationNode.isHidden
			{
				strongSelf.managedAnimationNode.animate(num: num)
			}
		}
		
		if let account = account {
			self.tokenEventsDisposable.set(
				(account.updateLoginTokenEvents
				 |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
					 self?.refreshQrToken()
				 })
			)
		}
		
		self.proceedNode.pressed = { [weak self] in
			self?.checkPhone?()
		}
		
		self.animationNode.completed = { [weak self] _ in
			self?.animationNode.removeFromSupernode()
			self?.managedAnimationNode.isHidden = false
		}
	}
	
	deinit {
		self.exportTokenDisposable.dispose()
		self.tokenEventsDisposable.dispose()
	}
	
	override func didLoad() {
		super.didLoad()
		
		self.titleNode.view.addGestureRecognizer(
			UITapGestureRecognizer(
				target: self,
				action: #selector(self.debugTap(_:))
			)
		)
#if DEBUG
		self.noticeNode.view.addGestureRecognizer(
			UITapGestureRecognizer(
				target: self,
				action: #selector(self.debugQrTap(_:))
			)
		)
#endif
	}
	
	private var animationSnapshotView: UIView?
	private var textSnapshotView: UIView?
	private var forcedButtonFrame: CGRect?
	
	func willAnimateIn(
		buttonFrame: CGRect,
		buttonTitle: String,
		animationSnapshot: UIView,
		textSnapshot: UIView
	) {
		
		self.proceedNode.frame = buttonFrame
		
		self.proceedNode.isEnabled = true
		self.proceedNode.title = buttonTitle
		
		self.animationSnapshotView = animationSnapshot
		self.view.insertSubview(animationSnapshot, at: 0)
		
		self.textSnapshotView = textSnapshot
		self.view.insertSubview(textSnapshot, at: 0)
		
		let nodes: [ASDisplayNode] = [
			self.phoneImageNode,
			self.titleNode,
			self.noticeNode,
			self.phoneAndCountryNode,
			self.contactSyncNode,
		]
		
		for node in nodes {
			node.alpha = 0.0
		}
	}
	
	func animateIn(
		buttonFrame: CGRect,
		buttonTitle: String,
		animationSnapshot: UIView,
		textSnapshot: UIView
	) {
		self.proceedNode.animateTitle(to: self.strings.Login_Continue)
		
		self.animationSnapshotView?.layer.animateAlpha(
			from: 1.0,
			to: 0.0,
			duration: 0.2,
			removeOnCompletion: false,
			completion: { [weak self] _ in
				self?.animationSnapshotView?.removeFromSuperview()
				self?.animationSnapshotView = nil
			}
		)
		self.animationSnapshotView?.layer.animatePosition(
			from: CGPoint(),
			to: CGPoint(x: 0.0, y: -100.0),
			duration: 0.3,
			timingFunction: kCAMediaTimingFunctionSpring,
			removeOnCompletion: false,
			additive: true
		)
		self.animationSnapshotView?.layer.animateScale(
			from: 1.0,
			to: 0.3,
			duration: 0.4
		)
		
		self.textSnapshotView?.layer.animateAlpha(
			from: 1.0,
			to: 0.0,
			duration: 0.2,
			removeOnCompletion: false,
			completion: { [weak self] _ in
				self?.textSnapshotView?.removeFromSuperview()
				self?.textSnapshotView = nil
			}
		)
		self.textSnapshotView?.layer.animatePosition(
			from: CGPoint(),
			to: CGPoint(x: 0.0, y: -140.0),
			duration: 0.3,
			timingFunction: kCAMediaTimingFunctionSpring,
			removeOnCompletion: false,
			additive: true
		)
		
		let nodes: [ASDisplayNode] = [
			self.animationNode,
			self.titleNode,
			self.noticeNode,
			self.phoneAndCountryNode,
			self.contactSyncNode,
		]
		
		self.animationNode.layer.animateScale(from: 0.3, to: 1.0, duration: 0.3)
		
		for node in nodes {
			node.alpha = 1.0
			node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
		}
	}
	
	func updateCountryCode() {
		self.phoneAndCountryNode.phoneInputNode.codeAndNumber =
		self.codeAndNumber
		let _ = self.phoneAndCountryNode.processNumberChange(
			number: self.phoneAndCountryNode.phoneInputNode.number
		)
	}
	
	func containerLayoutUpdated(
		_ layout: ContainerViewLayout,
		navigationBarHeight: CGFloat,
		transition: ContainedViewLayoutTransition
	) {
		
		// TODO: Ton - Background: adapt
		self.backgroundImage.fillParent(color: theme.list.plainBackgroundColor)
		
		var insets = layout.insets(options: [])
		insets.top = layout.statusBarHeight ?? 16.0
		if let inputHeight = layout.inputHeight, !inputHeight.isZero {
			insets.bottom = max(inputHeight, insets.bottom)
		}
		
		let titleInset: CGFloat = layout.size.width > 320.0 ? 24.0 : 16.0
		let additionalBottomInset: CGFloat = layout.size.height * 0.20
		// TODO: Ton - Phone verify: UI update
		
		self.titleNode.attributedText = NSAttributedString(
			string: strings.Login_PhoneTitle,
			font: Font.bold(20.0),
			textColor: self.theme.custom.accentColor
		)
	
		self.titleActivateAreaNode.accessibilityLabel =
		self.titleNode.attributedText?.string ?? ""
		
		let inset: CGFloat = 24.0
		let maximumWidth: CGFloat = min(430.0, layout.size.width)
		
		let animationSize = CGSize(width: 100.0, height: 100.0)
		let titleSize = self.titleNode.measure(
			CGSize(
				width: maximumWidth,
				height: CGFloat.greatestFiniteMagnitude
			)
		)
		
		let noticeInset: CGFloat = self.account == nil ? 32.0 : 0.0
		
		let noticeSize = self.noticeNode.measure(
			CGSize(
				width: min(274.0 + noticeInset, maximumWidth - 28.0),
				height: CGFloat.greatestFiniteMagnitude
			)
		)
		
		let proceedHeight = self.proceedNode.updateLayout(
			width: maximumWidth - inset * 2.0,
			transition: transition
		)
		let proceedSize = CGSize(
			width: maximumWidth - inset * 2.0,
			height: proceedHeight
		)
		//		let proceedHeight = self.proceedNode.updateLayout(
		//			width: proceedSize.width,
		//			transition: transition
		//		)
		//		let proceedSize = CGSize(
		//			width: proceedSize.width,
		//			height: proceedHeight
		//		)
		var items: [AuthorizationLayoutItem] = [
			AuthorizationLayoutItem(
				node: self.phoneImageNode,
				size: CGSize(width: 100.0, height: 100.0),
				spacingBefore: AuthorizationLayoutItemSpacing(
					weight: titleInset,
					maxValue: titleInset
				),
				spacingAfter: AuthorizationLayoutItemSpacing(
					weight: 0.0,
					maxValue: 0.0
				)
			),
			
			AuthorizationLayoutItem(
				node: self.titleNode,
				size: CGSize(
					width: titleSize.width,
					height: titleSize.height
				),
				spacingBefore: AuthorizationLayoutItemSpacing(
					weight: 18.0,
					maxValue: 18.0,
				),
				spacingAfter: AuthorizationLayoutItemSpacing(
					weight: 0.0,
					maxValue: 0.0
				)
			),
			
			AuthorizationLayoutItem(
				node: self.noticeNode,
				size: CGSize(
					width: noticeSize.width,
					height: noticeSize.height
				),
				spacingBefore: AuthorizationLayoutItemSpacing(
					weight: 18.0,
					maxValue: 18.0,
				),
				spacingAfter: AuthorizationLayoutItemSpacing(
					weight: 0.0,
					maxValue: 0.0
				)
			),
			
			AuthorizationLayoutItem(
				node: self.phoneAndCountryNode,
				size: CGSize(width: maximumWidth, height: 124.0),
				spacingBefore: AuthorizationLayoutItemSpacing(
					weight: 28.0,
					maxValue: 28.0
				),
				spacingAfter: AuthorizationLayoutItemSpacing(
					weight: 0.0,
					maxValue: 0.0
				)
			),
		]
		
		if layout.size.width > 320.0 {
			items.insert(
				AuthorizationLayoutItem(
					node: self.animationNode,
					size: animationSize,
					spacingBefore: AuthorizationLayoutItemSpacing(
						weight: 10.0,
						maxValue: 10.0
					),
					spacingAfter: AuthorizationLayoutItemSpacing(
						weight: 0.0,
						maxValue: 0.0
					)
				),
				at: 0
			)
			self.proceedNode.isHidden = false
			self.animationNode.isHidden = false
			self.animationNode.visibility = true
		} else {
			insets.top = navigationBarHeight
			self.proceedNode.isHidden = true
			self.animationNode.isHidden = true
			self.managedAnimationNode.isHidden = true
		}
		
		let contactSyncSize = self.contactSyncNode.updateLayout(
			width: maximumWidth
		)
		if self.hasOtherAccounts {
			self.contactSyncNode.isHidden = false
			items.append(
				AuthorizationLayoutItem(
					node: self.contactSyncNode,
					size: contactSyncSize,
					spacingBefore: AuthorizationLayoutItemSpacing(
						weight: 0.0,
						maxValue: 0.0
					),
					spacingAfter: AuthorizationLayoutItemSpacing(
						weight: 0.0,
						maxValue: 0.0
					)
				)
			)
		} else {
			self.contactSyncNode.isHidden = true
		}
		
		let buttonFrame: CGRect
		if let forcedButtonFrame = self.forcedButtonFrame,
		   (layout.inputHeight ?? 0.0).isZero
		{
			buttonFrame = forcedButtonFrame
		} else {
			// TODO: Ton - Phone verify: Edit continue button position
			buttonFrame = CGRect(
				origin: CGPoint(
					x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0),
					y: layout.size.height - insets.bottom - proceedSize.height - inset
				),
				size: proceedSize,
			)
			
			//			let iconSize = CGSize(width: 20.0, height: 20.0)
			//			buttonFrame = CGRect(
			//				origin: CGPoint(
			//					x: layout.size.width - proceedSize.width - inset,
			//					y: layout.size.height - insets.bottom - proceedSize.height
			//					- inset
			//				),
			//				size: proceedSize,
			//			)
			//			self.buttonImageNode.frame = CGRect(
			//				x: floorToScreenPixels(
			//					(buttonFrame.width - iconSize.width) / 2.0
			//				),
			//				y: floorToScreenPixels(
			//					(buttonFrame.height - iconSize.height) / 2.0
			//				),
			//				width: iconSize.width,
			//				height: iconSize.height
			//			)
		}
		
		transition.updateFrame(node: self.proceedNode, frame: buttonFrame)
		
		self.animationNode.updateLayout(size: animationSize)
		
		let _ = layoutAuthorizationItems(
			bounds: CGRect(
				origin: CGPoint(x: 0.0, y: insets.top),
				size: CGSize(
					width: layout.size.width,
					height: layout.size.height - insets.top - insets.bottom - additionalBottomInset
				)
			),
			items: items,
			transition: transition,
			failIfDoesNotFit: false
		)

		transition.updateFrame(
			node: self.managedAnimationNode,
			frame: self.animationNode.frame
		)
		
		self.titleActivateAreaNode.frame = self.titleNode.frame
		self.noticeActivateAreaNode.accessibilityLabel =
		self.noticeNode.attributedText?.string ?? ""
		self.noticeActivateAreaNode.frame = self.noticeNode.frame
	}
	
	func activateInput() {
		self.phoneAndCountryNode.phoneInputNode.phoneNumberNode.textField
			.becomeFirstResponder()
	}
	
	func animateError() {
		self.phoneAndCountryNode.phoneInputNode.dialingTextNode.layer
			.addShakeAnimation()
		self.phoneAndCountryNode.phoneInputNode.phoneNumberNode.layer
			.addShakeAnimation()
	}
	
	private var debugTapCounter: (Double, Int) = (0.0, 0)
	@objc private func debugTap(_ recognizer: UITapGestureRecognizer) {
		if case .ended = recognizer.state {
			let timestamp = CACurrentMediaTime()
			if self.debugTapCounter.0 < timestamp - 0.4 {
				self.debugTapCounter.0 = timestamp
				self.debugTapCounter.1 = 0
			}
			
			if self.debugTapCounter.0 >= timestamp - 0.4 {
				self.debugTapCounter.0 = timestamp
				self.debugTapCounter.1 += 1
			}
			
			if self.debugTapCounter.1 >= 10 {
				self.debugTapCounter.1 = 0
				
				self.debugAction()
			}
		}
	}
	
	@objc private func debugQrTap(_ recognizer: UITapGestureRecognizer) {
		if self.qrNode == nil {
			let qrNode = ASImageNode()
			qrNode.frame = CGRect(
				origin: CGPoint(x: 16.0, y: 64.0 + 16.0),
				size: CGSize(width: 200.0, height: 200.0)
			)
			self.qrNode = qrNode
			self.addSubnode(qrNode)
			
			self.refreshQrToken()
		}
	}
	
	private func refreshQrToken() {
		guard let account = self.account else {
			return
		}
		let sharedContext = self.sharedContext
		let tokenSignal =
		sharedContext.activeAccountContexts
		|> castError(ExportAuthTransferTokenError.self)
		|> take(1)
		|> mapToSignal {
			activeAccountsAndInfo -> Signal<
				ExportAuthTransferTokenResult, ExportAuthTransferTokenError
			> in
			let (_, activeAccounts, _) = activeAccountsAndInfo
			let activeProductionUserIds = activeAccounts.map({
				$0.1.account
			}).filter({ !$0.testingEnvironment }).map({ $0.peerId.id })
			let activeTestingUserIds = activeAccounts.map({ $0.1.account })
				.filter({ $0.testingEnvironment }).map({ $0.peerId.id })
			
			let allProductionUserIds = activeProductionUserIds
			let allTestingUserIds = activeTestingUserIds
			
			return TelegramEngineUnauthorized(account: account).auth
				.exportAuthTransferToken(
					accountManager: sharedContext.accountManager,
					otherAccountUserIds: account.testingEnvironment
					? allTestingUserIds : allProductionUserIds,
					syncContacts: true
				)
		}
		
		self.exportTokenDisposable.set(
			(tokenSignal
			 |> deliverOnMainQueue).startStrict(next: { [weak self] result in
				 guard let strongSelf = self else {
					 return
				 }
				 switch result {
				 case .displayToken(let token):
					 var tokenString = token.value.base64EncodedString()
					 //print("export token \(tokenString)")
					 tokenString = tokenString.replacingOccurrences(
						of: "+",
						with: "-"
					 )
					 tokenString = tokenString.replacingOccurrences(
						of: "/",
						with: "_"
					 )
					 let urlString = "tg://login?token=\(tokenString)"
					 let _ =
					 (qrCode(
						string: urlString,
						color: .black,
						backgroundColor: .white,
						icon: .none
					 )
					  |> deliverOnMainQueue).startStandalone(next: {
						 _,
						 generate in
						 guard let strongSelf = self else {
							 return
						 }
						 
						 let context = generate(
							TransformImageArguments(
								corners: ImageCorners(),
								imageSize: CGSize(
									width: 200.0,
									height: 200.0
								),
								boundingSize: CGSize(
									width: 200.0,
									height: 200.0
								),
								intrinsicInsets: UIEdgeInsets()
							)
						 )
						 if let image = context?.generateImage() {
							 strongSelf.qrNode?.image = image
						 }
					 })
					 
					 let timestamp = Int32(Date().timeIntervalSince1970)
					 let timeout = max(5, token.validUntil - timestamp)
					 strongSelf.exportTokenDisposable.set(
						(Signal<Never, NoError>.complete()
						 |> delay(Double(timeout), queue: .mainQueue()))
						.startStrict(completed: {
							guard let strongSelf = self else {
								return
							}
							strongSelf.refreshQrToken()
						})
					 )
				 case .changeAccountAndRetry(let account):
					 strongSelf.exportTokenDisposable.set(nil)
					 strongSelf.account = account
					 strongSelf.accountUpdated?(account)
					 strongSelf.tokenEventsDisposable.set(
						(account.updateLoginTokenEvents
						 |> deliverOnMainQueue).startStrict(next: { _ in
							 self?.refreshQrToken()
						 })
					 )
					 strongSelf.refreshQrToken()
				 case .loggedIn, .passwordRequested:
					 strongSelf.exportTokenDisposable.set(nil)
				 }
			 })
		)
	}
}

final class PhoneConfirmationController: ViewController {
	private var controllerNode: Node {
		return self.displayNode as! Node
	}
	
	private let theme: PresentationTheme
	private let strings: PresentationStrings
	private let code: String
	private let number: String
	private weak var sourceController:
	AuthorizationSequencePhoneEntryController?
	
	var inProgress: Bool = false {
		didSet {
			if self.inProgress != oldValue {
				if self.inProgress {
					self.controllerNode.proceedNode.transitionToProgress()
				} else {
					self.controllerNode.proceedNode.transitionFromProgress()
				}
			}
		}
	}
	
	var proceed: () -> Void = {}
	
	class Node: ASDisplayNode {
		private let theme: PresentationTheme
		private let strings: PresentationStrings
		
		private let code: String
		private let number: String
		
		private let dimNode: ASDisplayNode
		private let backgroundNode: ASDisplayNode
		
		private let codeSourceNode: ImmediateTextNode
		private let phoneSourceNode: ImmediateTextNode
		
		private let codeTargetNode: ImmediateTextNode
		private let phoneTargetNode: ImmediateTextNode
		private let measureTargetNode: ImmediateTextNode
		
		private let textNode: ImmediateTextNode
		private let textActivateAreaNode: AccessibilityAreaNode
		
		private let cancelButton: HighlightableButtonNode
		fileprivate let proceedNode: SolidRoundedButtonNode
		
		var proceed: () -> Void = {}
		var cancel: () -> Void = {}
		
		private var validLayout: ContainerViewLayout?
		let presentationData : PresentationData
		init(
			presentationData: PresentationData,
			code: String,
			number: String
		) {
			self.presentationData = presentationData
			self.theme = presentationData.theme
			self.strings = presentationData.strings
			
			self.code = code
			self.number = number
			
			self.dimNode = ASDisplayNode()
			self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
			
			self.backgroundNode = ASDisplayNode()
			self.backgroundNode.backgroundColor =
			theme.list.itemBlocksBackgroundColor
			self.backgroundNode.cornerRadius = 24.0
			
			self.textNode = ImmediateTextNode()
			self.textNode.displaysAsynchronously = false
			self.textNode.attributedText = NSAttributedString(
				string: strings.Login_PhoneNumberConfirmation,
				font: Font.regular(17.0),
				textColor: theme.list.itemPrimaryTextColor
			)
			self.textNode.textAlignment = .center
			
			self.textActivateAreaNode = AccessibilityAreaNode()
			self.textActivateAreaNode.accessibilityTraits = .staticText
			
			self.cancelButton = HighlightableButtonNode()
			self.cancelButton.setTitle(
				strings.Login_Edit,
				with: Font.regular(19.0),
				with: theme.list.itemAccentColor,
				for: .normal
			)
			self.cancelButton.accessibilityTraits = [.button]
			self.cancelButton.accessibilityLabel = strings.Login_Edit
			
			self.proceedNode = SolidRoundedButtonNode(
				title: strings.Login_Continue,
				theme: SolidRoundedButtonTheme(theme: theme),
				height: self.presentationData.dimen.buttonHeight,
				cornerRadius: self.presentationData.dimen.buttonRadius
			)
			
			self.proceedNode.progressType = .embedded
			
			let font = Font.with(
				size: 20.0,
				design: .regular,
				traits: [.monospacedNumbers]
			)
			let largeFont = Font.with(
				size: 34.0,
				design: .regular,
				weight: .bold,
				traits: [.monospacedNumbers]
			)
			
			self.codeSourceNode = ImmediateTextNode()
			self.codeSourceNode.alpha = 0.0
			self.codeSourceNode.displaysAsynchronously = false
			self.codeSourceNode.attributedText = NSAttributedString(
				string: code,
				font: font,
				textColor: theme.list.itemPrimaryTextColor
			)
			
			self.phoneSourceNode = ImmediateTextNode()
			self.phoneSourceNode.alpha = 0.0
			self.phoneSourceNode.displaysAsynchronously = false
			
			let sourceString = NSMutableAttributedString(
				string: number,
				font: font,
				textColor: theme.list.itemPrimaryTextColor
			)
			sourceString.addAttribute(
				NSAttributedString.Key.kern,
				value: 1.6,
				range: NSRange(location: 0, length: sourceString.length)
			)
			self.phoneSourceNode.attributedText = sourceString
			
			self.codeTargetNode = ImmediateTextNode()
			self.codeTargetNode.displaysAsynchronously = false
			self.codeTargetNode.attributedText = NSAttributedString(
				string: code,
				font: largeFont,
				textColor: theme.list.itemPrimaryTextColor
			)
			
			self.phoneTargetNode = ImmediateTextNode()
			self.phoneTargetNode.displaysAsynchronously = false
			
			self.measureTargetNode = ImmediateTextNode()
			self.measureTargetNode.displaysAsynchronously = false
			self.measureTargetNode.maximumNumberOfLines = 1
			
			let targetString = NSMutableAttributedString(
				string: number,
				font: largeFont,
				textColor: theme.list.itemPrimaryTextColor
			)
			targetString.addAttribute(
				NSAttributedString.Key.kern,
				value: 1.6,
				range: NSRange(location: 0, length: targetString.length)
			)
			self.phoneTargetNode.attributedText = targetString
			
			super.init()
			
			self.clipsToBounds = false
			
			self.addSubnode(self.dimNode)
			self.addSubnode(self.backgroundNode)
			
			self.addSubnode(self.codeSourceNode)
			self.addSubnode(self.phoneSourceNode)
			
			self.addSubnode(self.codeTargetNode)
			self.addSubnode(self.phoneTargetNode)
			
			self.addSubnode(self.textNode)
			self.addSubnode(self.textActivateAreaNode)
			
			self.addSubnode(self.cancelButton)
			self.addSubnode(self.proceedNode)
			
			self.cancelButton.addTarget(
				self,
				action: #selector(self.cancelPressed),
				forControlEvents: .touchUpInside
			)
			self.proceedNode.pressed = { [weak self] in
				self?.proceed()
			}
		}
		
		override func didLoad() {
			super.didLoad()
			
			self.dimNode.view.addGestureRecognizer(
				UITapGestureRecognizer(
					target: self,
					action: #selector(self.dimTapped)
				)
			)
		}
		
		@objc private func dimTapped() {
			self.cancelPressed()
		}
		
		@objc private func cancelPressed() {
			self.dimNode.isUserInteractionEnabled = false
			self.cancel()
		}
		
		func animateIn(
			codeNode: ASDisplayNode,
			numberNode: ASDisplayNode,
			buttonNode: ASDisplayNode
		) {
			guard let layout = self.validLayout else {
				return
			}
			let codeFrame = codeNode.convert(codeNode.bounds, to: nil)
			let numberFrame = numberNode.convert(numberNode.bounds, to: nil)
			let buttonFrame = buttonNode.convert(buttonNode.bounds, to: nil)
			
			codeNode.isHidden = true
			numberNode.isHidden = true
			buttonNode.isHidden = true
			
			self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
			
			let duration: Double = 0.25
			
			let codeSize = self.codeSourceNode.updateLayout(layout.size)
			self.codeSourceNode.frame = CGRect(
				origin: CGPoint(
					x: codeFrame.midX - codeSize.width / 2.0,
					y: codeFrame.midY - codeSize.height / 2.0
				),
				size: codeSize
			)
			
			let numberSize = self.phoneSourceNode.updateLayout(layout.size)
			self.phoneSourceNode.frame = CGRect(
				origin: CGPoint(
					x: numberFrame.minX,
					y: numberFrame.midY - numberSize.height / 2.0
				),
				size: numberSize
			)
			
			let targetScale = codeSize.height / self.codeTargetNode.frame.height
			let sourceScale = self.codeTargetNode.frame.height / codeSize.height
			
			self.codeSourceNode.layer.animateScale(
				from: 1.0,
				to: sourceScale,
				duration: duration
			)
			self.codeSourceNode.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: duration
			)
			self.codeSourceNode.layer.animatePosition(
				from: self.codeSourceNode.position,
				to: self.codeTargetNode.position,
				duration: duration
			)
			
			self.phoneSourceNode.layer.animateScale(
				from: 1.0,
				to: sourceScale,
				duration: duration
			)
			self.phoneSourceNode.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: duration
			)
			self.phoneSourceNode.layer.animatePosition(
				from: self.phoneSourceNode.position,
				to: self.phoneTargetNode.position,
				duration: duration
			)
			
			self.codeTargetNode.layer.animateScale(
				from: targetScale,
				to: 1.0,
				duration: duration
			)
			self.codeTargetNode.layer.animateAlpha(
				from: 0.0,
				to: 1.0,
				duration: duration
			)
			self.codeTargetNode.layer.animatePosition(
				from: self.codeSourceNode.position,
				to: self.codeTargetNode.position,
				duration: duration
			)
			
			self.phoneTargetNode.layer.animateScale(
				from: targetScale,
				to: 1.0,
				duration: duration
			)
			self.phoneTargetNode.layer.animateAlpha(
				from: 0.0,
				to: 1.0,
				duration: duration
			)
			self.phoneTargetNode.layer.animatePosition(
				from: self.phoneSourceNode.position,
				to: self.phoneTargetNode.position,
				duration: duration
			)
			
			self.backgroundNode.layer.animateAlpha(
				from: 0.0,
				to: 1.0,
				duration: 0.1
			)
			
			self.backgroundNode.layer.animateFrame(
				from: CGRect(
					origin: CGPoint(
						x: self.backgroundNode.frame.origin.x + 6.0,
						y: codeFrame.minY
					),
					size: CGSize(
						width: self.backgroundNode.frame.width - 12.0,
						height: buttonFrame.maxY + 18.0 - codeFrame.minY
					)
				),
				to: self.backgroundNode.frame,
				duration: duration
			)
			
			self.textNode.layer.animateAlpha(
				from: 0.0,
				to: 1.0,
				duration: duration
			)
			self.textNode.layer.animateScale(
				from: 0.5,
				to: 1.0,
				duration: duration
			)
			self.textNode.layer.animatePosition(
				from: CGPoint(x: -100.0, y: -45.0),
				to: CGPoint(),
				duration: duration,
				additive: true
			)
			
			self.cancelButton.layer.animateAlpha(
				from: 0.0,
				to: 1.0,
				duration: duration
			)
			self.cancelButton.layer.animateScale(
				from: 0.5,
				to: 1.0,
				duration: duration
			)
			self.cancelButton.layer.animatePosition(
				from: CGPoint(x: -100.0, y: -70.0),
				to: CGPoint(),
				duration: duration,
				additive: true
			)
			
			self.proceedNode.layer.animatePosition(
				from: buttonFrame.center,
				to: self.proceedNode.position,
				duration: duration
			)
		}
		
		func animateOut(
			codeNode: ASDisplayNode,
			numberNode: ASDisplayNode,
			buttonNode: ASDisplayNode,
			completion: @escaping () -> Void
		) {
			let codeFrame = codeNode.convert(codeNode.bounds, to: nil)
			let numberFrame = numberNode.convert(numberNode.bounds, to: nil)
			let buttonFrame = buttonNode.convert(buttonNode.bounds, to: nil)
			
			self.dimNode.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: 0.2,
				removeOnCompletion: false
			)
			
			let duration: Double = 0.25
			
			let codeSize = self.codeSourceNode.updateLayout(self.frame.size)
			self.codeSourceNode.frame = CGRect(
				origin: CGPoint(
					x: codeFrame.midX - codeSize.width / 2.0,
					y: codeFrame.midY - codeSize.height / 2.0
				),
				size: codeSize
			)
			
			let numberSize = self.phoneSourceNode.updateLayout(self.frame.size)
			self.phoneSourceNode.frame = CGRect(
				origin: CGPoint(
					x: numberFrame.minX,
					y: numberFrame.midY - numberSize.height / 2.0
				),
				size: numberSize
			)
			
			let targetScale = codeSize.height / self.codeTargetNode.frame.height
			let sourceScale = self.codeTargetNode.frame.height / codeSize.height
			
			self.codeSourceNode.layer.animateScale(
				from: sourceScale,
				to: 1.0,
				duration: duration
			)
			self.codeSourceNode.layer.animateAlpha(
				from: 0.0,
				to: 1.0,
				duration: duration
			)
			self.codeSourceNode.layer.animatePosition(
				from: self.codeTargetNode.position,
				to: self.codeSourceNode.position,
				duration: duration
			)
			
			self.phoneSourceNode.layer.animateScale(
				from: sourceScale,
				to: 1.0,
				duration: duration
			)
			self.phoneSourceNode.layer.animateAlpha(
				from: 0.0,
				to: 1.0,
				duration: duration
			)
			self.phoneSourceNode.layer.animatePosition(
				from: self.phoneTargetNode.position,
				to: self.phoneSourceNode.position,
				duration: duration
			)
			
			self.codeTargetNode.layer.animateScale(
				from: 1.0,
				to: targetScale,
				duration: duration
			)
			self.codeTargetNode.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: duration,
				removeOnCompletion: false
			)
			self.codeTargetNode.layer.animatePosition(
				from: self.codeTargetNode.position,
				to: self.codeSourceNode.position,
				duration: duration
			)
			
			Queue.mainQueue().after(0.2) {
				codeNode.isHidden = false
				numberNode.isHidden = false
				buttonNode.isHidden = false
			}
			
			self.phoneTargetNode.layer.animateScale(
				from: 1.0,
				to: targetScale,
				duration: duration
			)
			self.phoneTargetNode.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: duration,
				removeOnCompletion: false,
				completion: { _ in
					completion()
				}
			)
			self.phoneTargetNode.layer.animatePosition(
				from: self.phoneTargetNode.position,
				to: self.phoneSourceNode.position,
				duration: duration
			)
			
			self.backgroundNode.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: 0.2,
				delay: 0.1,
				removeOnCompletion: false
			)
			self.backgroundNode.layer.animateFrame(
				from: self.backgroundNode.frame,
				to: CGRect(
					origin: CGPoint(
						x: self.backgroundNode.frame.origin.x + 6.0,
						y: codeFrame.minY
					),
					size: CGSize(
						width: self.backgroundNode.frame.width - 12.0,
						height: buttonFrame.maxY + 18.0 - codeFrame.minY
					)
				),
				duration: duration
			)
			
			self.textNode.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: 0.2,
				removeOnCompletion: false
			)
			self.textNode.layer.animateScale(
				from: 1.0,
				to: 0.5,
				duration: duration,
				removeOnCompletion: false
			)
			self.textNode.layer.animatePosition(
				from: CGPoint(),
				to: CGPoint(x: -100.0, y: -45.0),
				duration: duration,
				removeOnCompletion: false,
				additive: true
			)
			
			self.cancelButton.layer.animateAlpha(
				from: 1.0,
				to: 0.0,
				duration: 0.2,
				removeOnCompletion: false
			)
			self.cancelButton.layer.animateScale(
				from: 1.0,
				to: 0.5,
				duration: duration,
				removeOnCompletion: false
			)
			self.cancelButton.layer.animatePosition(
				from: CGPoint(),
				to: CGPoint(x: -100.0, y: -70.0),
				duration: duration,
				removeOnCompletion: false,
				additive: true
			)
			
			self.proceedNode.layer.animatePosition(
				from: self.proceedNode.position,
				to: buttonFrame.center,
				duration: duration,
				removeOnCompletion: false
			)
		}
		
		func containerLayoutUpdated(
			_ layout: ContainerViewLayout,
			transition: ContainedViewLayoutTransition
		) {
			let hadLayout = self.validLayout != nil
			self.validLayout = layout
			
			let sideInset: CGFloat = 8.0
			let innerInset: CGFloat = 18.0
			
			let maximumWidth: CGFloat = min(430.0, layout.size.width)
			
			transition.updateFrame(
				node: self.dimNode,
				frame: CGRect(
					origin: CGPoint(x: -layout.size.width, y: 0.0),
					size: CGSize(
						width: layout.size.width * 3.0,
						height: layout.size.height
					)
				)
			)
			
			let backgroundSize = CGSize(
				width: maximumWidth - sideInset * 2.0,
				height: 243.0
			)
			
			let originY: CGFloat
			if case .regular = layout.metrics.widthClass {
				originY = floorToScreenPixels(
					(layout.size.height - backgroundSize.height) / 2.0
				)
			} else {
				let hasOnScreenNavigation =
				layout.deviceMetrics.onScreenNavigationHeight(
					inLandscape: false,
					systemOnScreenNavigationHeight: nil
				) != nil
				if hasOnScreenNavigation || layout.deviceMetrics.hasTopNotch
					|| layout.deviceMetrics.hasDynamicIsland
				{
					originY = layout.size.height - backgroundSize.height - 260.0
				} else {
					originY = floorToScreenPixels(
						(layout.size.height - backgroundSize.height) / 2.0
					)
				}
			}
			
			let backgroundFrame = CGRect(
				origin: CGPoint(
					x: floorToScreenPixels(
						(layout.size.width - backgroundSize.width) / 2.0
					),
					y: originY
				),
				size: backgroundSize
			)
			transition.updateFrame(
				node: self.backgroundNode,
				frame: backgroundFrame
			)
			
			let maxWidth = layout.size.width - 20.0
			if !hadLayout {
				var fontSize = 34.0
				if layout.size.width < 375.0 {
					fontSize = 30.0
				}
				
				self.measureTargetNode.attributedText = NSAttributedString(
					string: self.code + " " + self.number,
					font: Font.with(
						size: fontSize,
						design: .regular,
						weight: .bold,
						traits: [.monospacedNumbers]
					),
					textColor: self.theme.list.itemPrimaryTextColor
				)
				let measuredSize = self.measureTargetNode.updateLayout(
					CGSize(width: 1000.0, height: .greatestFiniteMagnitude)
				)
				if measuredSize.width > maxWidth {
					fontSize = floor(0.8 * fontSize)
				}
				
				let largeFont = Font.with(
					size: fontSize,
					design: .regular,
					weight: .bold,
					traits: [.monospacedNumbers]
				)
				
				self.codeTargetNode.attributedText = NSAttributedString(
					string: self.code,
					font: largeFont,
					textColor: self.theme.list.itemPrimaryTextColor
				)
				let targetString = NSMutableAttributedString(
					string: self.number,
					font: largeFont,
					textColor: self.theme.list.itemPrimaryTextColor
				)
				targetString.addAttribute(
					NSAttributedString.Key.kern,
					value: 1.6,
					range: NSRange(location: 0, length: targetString.length)
				)
				self.phoneTargetNode.attributedText = targetString
			}
			
			let spacing: CGFloat = 10.0
			
			let codeSize = self.codeTargetNode.updateLayout(
				CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
			)
			let numberSize = self.phoneTargetNode.updateLayout(
				CGSize(
					width: maxWidth - codeSize.width - spacing,
					height: .greatestFiniteMagnitude
				)
			)
			
			let totalWidth = codeSize.width + numberSize.width + spacing
			
			let codeFrame = CGRect(
				origin: CGPoint(
					x: floorToScreenPixels(
						(backgroundSize.width - totalWidth) / 2.0
					),
					y: 30.0
				),
				size: codeSize
			)
			transition.updateFrame(
				node: self.codeTargetNode,
				frame: codeFrame.offsetBy(
					dx: backgroundFrame.minX,
					dy: backgroundFrame.minY
				)
			)
			
			let numberFrame = CGRect(
				origin: CGPoint(x: codeFrame.maxX + spacing, y: 30.0),
				size: numberSize
			)
			transition.updateFrame(
				node: self.phoneTargetNode,
				frame: numberFrame.offsetBy(
					dx: backgroundFrame.minX,
					dy: backgroundFrame.minY
				)
			)
			
			let textSize = self.textNode.updateLayout(backgroundSize)
			transition.updateFrame(
				node: self.textNode,
				frame: CGRect(
					origin: CGPoint(
						x: floorToScreenPixels(
							(backgroundSize.width - textSize.width) / 2.0
						),
						y: 88.0
					),
					size: textSize
				).offsetBy(dx: backgroundFrame.minX, dy: backgroundFrame.minY)
			)
			self.textActivateAreaNode.frame = self.textNode.frame
			self.textActivateAreaNode.accessibilityLabel =
			"\(self.code) \(self.number). \(self.strings.Login_PhoneNumberConfirmation)"
			
			let proceedWidth = backgroundSize.width - 16.0 * 2.0
			let proceedHeight = self.proceedNode.updateLayout(
				width: proceedWidth,
				transition: transition
			)
			transition.updateFrame(
				node: self.proceedNode,
				frame: CGRect(
					origin: CGPoint(
						x: innerInset,
						y: backgroundSize.height - proceedHeight - innerInset
					),
					size: CGSize(width: proceedWidth, height: proceedHeight)
				).offsetBy(dx: backgroundFrame.minX, dy: backgroundFrame.minY)
			)
			
			let cancelSize = self.cancelButton.measure(layout.size)
			transition.updateFrame(
				node: self.cancelButton,
				frame: CGRect(
					origin: CGPoint(
						x: floorToScreenPixels(
							(backgroundSize.width - cancelSize.width) / 2.0
						),
						y: backgroundSize.height - proceedHeight - innerInset
						- cancelSize.height - 25.0
					),
					size: cancelSize
				).offsetBy(dx: backgroundFrame.minX, dy: backgroundFrame.minY)
			)
		}
	}
	let presentationData: PresentationData
	public init(
		presentationData: PresentationData,
		code: String,
		number: String,
		sourceController: AuthorizationSequencePhoneEntryController
	) {
		self.presentationData = presentationData
		self.theme = presentationData.theme
		self.strings = presentationData.strings
		self.code = code
		self.number = number
		self.sourceController = sourceController
		
		super.init(navigationBarPresentationData: nil)
		
		self.blocksBackgroundWhenInOverlay = true
		
		self.statusBar.statusBarStyle = .Ignore
	}
	
	required public init(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	private var isDismissed = false
	override public func loadDisplayNode() {
		self.displayNode = Node(
			presentationData: self.presentationData,
			code: self.code,
			number: self.number
		)
		self.displayNodeDidLoad()
		
		self.controllerNode.proceed = { [weak self] in
			self?.proceed()
		}
		self.controllerNode.cancel = { [weak self] in
			if let strongSelf = self,
			   let sourceController = strongSelf.sourceController
			{
				strongSelf.controllerNode.animateOut(
					codeNode: sourceController.codeNode,
					numberNode: sourceController.numberNode,
					buttonNode: sourceController.buttonNode,
					completion: { [weak self] in
						self?.dismiss()
					}
				)
			}
		}
	}
	
	func dismissAnimated() {
		self.controllerNode.cancel()
	}
	
	func transitionOut() {
		self.controllerNode.cancel()
		
		let transition = ContainedViewLayoutTransition.animated(
			duration: 0.5,
			curve: .spring
		)
		transition.updatePosition(
			layer: self.view.layer,
			position: CGPoint(
				x: self.view.center.x - self.view.frame.width,
				y: self.view.center.y
			)
		)
	}
	
	private var didPlayAppearanceAnimation = false
	override public func viewDidAppear(_ animated: Bool) {
		if !self.didPlayAppearanceAnimation {
			self.didPlayAppearanceAnimation = true
			if let sourceController = self.sourceController {
				self.controllerNode.animateIn(
					codeNode: sourceController.codeNode,
					numberNode: sourceController.numberNode,
					buttonNode: sourceController.buttonNode
				)
			}
		}
	}
	
	override public func containerLayoutUpdated(
		_ layout: ContainerViewLayout,
		transition: ContainedViewLayoutTransition
	) {
		super.containerLayoutUpdated(layout, transition: transition)
		
		self.controllerNode.containerLayoutUpdated(
			layout,
			transition: transition
		)
	}
}

private final class PhoneKeyNode: ASDisplayNode {
	private let imageNode: ASImageNode
	private var highlightedNode: ASImageNode?
	
	private let image: UIImage?
	private let highlightedImage: UIImage?
	
	init(offset: CGPoint, image: UIImage?, highlightedImage: UIImage?) {
		self.image = image
		self.highlightedImage = highlightedImage
		
		self.imageNode = ASImageNode()
		self.imageNode.displaysAsynchronously = false
		self.imageNode.image = image
		
		super.init()
		
		self.clipsToBounds = true
		
		if let imageSize = self.imageNode.image?.size {
			self.imageNode.frame = CGRect(
				origin: CGPoint(x: -offset.x, y: -offset.y),
				size: imageSize
			)
		}
		
		self.addSubnode(self.imageNode)
	}
	
	func animatePress() {
		guard self.highlightedNode == nil else {
			return
		}
		
		let highlightedNode = ASImageNode()
		highlightedNode.displaysAsynchronously = false
		highlightedNode.image = self.highlightedImage
		highlightedNode.frame = self.imageNode.frame
		self.addSubnode(highlightedNode)
		self.highlightedNode = highlightedNode
		
		highlightedNode.layer.animateAlpha(
			from: 1.0,
			to: 0.0,
			duration: 0.16,
			removeOnCompletion: false,
			completion: { [weak self] _ in
				self?.highlightedNode?.removeFromSupernode()
				self?.highlightedNode = nil
			}
		)
		
		let values: [NSNumber] = [0.75, 0.5, 0.75, 1.0]
		self.layer.animateKeyframes(
			values: values,
			duration: 0.16,
			keyPath: "transform.scale"
		)
	}
}

private final class ManagedPhoneAnimationNode: ManagedAnimationNode {
	private var timer: SwiftSignalKit.Timer?
	
	private let plateNode: ASDisplayNode
	private var nodes: [PhoneKeyNode]
	
	init() {
		self.plateNode = ASDisplayNode()
		self.plateNode.backgroundColor = UIColor(rgb: 0xc30023)
		self.plateNode.frame = CGRect(
			x: 27.0,
			y: 38.0,
			width: 46.0,
			height: 32.0
		)
		
		let image = UIImage(bundleImageName: "Settings/Keypad")
		let highlightedImage = generateTintedImage(
			image: image,
			color: UIColor(rgb: 0x000000, alpha: 0.4)
		)
		
		var nodes: [PhoneKeyNode] = []
		for i in 0..<9 {
			let offset: CGPoint
			switch i {
			case 1:
				offset = CGPoint(x: 15.0, y: 0.0)
			case 2:
				offset = CGPoint(x: 30.0, y: 0.0)
			case 3:
				offset = CGPoint(x: 0.0, y: 10.0)
			case 4:
				offset = CGPoint(x: 15.0, y: 10.0)
			case 5:
				offset = CGPoint(x: 30.0, y: 10.0)
			case 6:
				offset = CGPoint(x: 0.0, y: 21.0)
			case 7:
				offset = CGPoint(x: 15.0, y: 21.0)
			case 8:
				offset = CGPoint(x: 30.0, y: 21.0)
			default:
				offset = CGPoint(x: 0.0, y: 0.0)
			}
			let node = PhoneKeyNode(
				offset: offset,
				image: image,
				highlightedImage: highlightedImage
			)
			node.frame = CGRect(
				origin: offset.offsetBy(dx: 28.0, dy: 38.0),
				size: CGSize(width: 15.0, height: 10.0)
			)
			nodes.append(node)
		}
		self.nodes = nodes
		
		super.init(size: CGSize(width: 100.0, height: 100.0))
		
		self.trackTo(
			item: ManagedAnimationItem(
				source: .local("IntroPhone"),
				frames: .range(startFrame: 0, endFrame: 0),
				duration: 0.001
			)
		)
		
		self.addSubnode(self.plateNode)
		
		for node in nodes {
			self.addSubnode(node)
		}
	}
	
	func animate(num: Int) {
		guard num != 0 else {
			return
		}
		let index = max(0, min(self.nodes.count - 1, num - 1))
		self.nodes[index].animatePress()
	}
}
