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


// TODO: Ton - Ai: AiControllerNode
final class AiInputNode: ASDisplayNode {
	
	private let presentationData: PresentationData

	private let bottomInsetNode: ASDisplayNode

	private let inputBackgroundNode: ASDisplayNode
	private let inputSeparateNode: ASDisplayNode
	private let sendButtonNode: ASImageNode
	private let userInputNode: ASDisplayNode
	private let placeholderNode: ASTextNode
	
	///
	private var initialContainerY: CGFloat = 0
	private var containerLayout: ContainerViewLayout?
	public var onTextApplied: ((String) -> Void)?
	public var onTextTranslated: ((String) -> Void)?
	
	private let context: AccountContext
	private let inputDelegate: InputDelegate
	
	
	//
	private var screenWidth = 0.0
	private var screenHeight = 0.0
	private let padding = 16.0
	private var bottomInsetHeight = 24.0
	private let sendButtonSize = 26.0
	private let maxInputHeight = 200.0
	private let minInputHeight = 40.0
	private let inputTextSize = 18.0
	private let textPaddingTop = 0.0
	private var cacheBottomInsetHeight: CGFloat = 0.0

	init(
		context: AccountContext
	) {

		//
		self.context = context
		self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
		//
		self.inputBackgroundNode = ASDisplayNode()
		self.bottomInsetNode = ASDisplayNode()
		self.inputSeparateNode = ASDisplayNode()
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

		self.inputDelegate = InputDelegate()
		
		super.init()
		let theme =  self.presentationData.theme
		self.backgroundColor = .red
		self.userInputNode.backgroundColor = .blue
		self.bottomInsetNode.backgroundColor = theme.custom.aiInputBackground
		self.addSubnode(self.bottomInsetNode)


		self.inputSeparateNode.backgroundColor = theme.list.itemPlainSeparatorColor
		self.addSubnode(self.inputSeparateNode)
		
		self.inputBackgroundNode.backgroundColor = theme.custom.aiInputBackground
		self.addSubnode(self.inputBackgroundNode)
		
//		self.inputDelegate.onTextChanged = { [weak self] text in
//			guard let strongSelf = self else { return }
//			strongSelf.invalidateIntrinsicContentSizeAndNotify()
//			strongSelf.delayTranstate()
//		}
		
		if let tv = self.userInputNode.view as? UITextView {
			tv.backgroundColor = .clear
			tv.textColor = theme.custom.aiInputTextColor
			tv.textContainer.lineFragmentPadding = 0
			tv.font = Font.regular(inputTextSize)
			tv.delegate = self.inputDelegate
			tv.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
		}
		
		self.addSubnode(self.userInputNode)
		
		
		
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

	@objc private func sendButtonTapped() {
//		print("Translation button tapped")
//		guard let setting = self.translateSettings else {
//			return
//		}
//		let language = setting.code
//		if language.isEmpty {
//			self.alertSelectLanguage()
//		} else {
//			self.fetchTranslation(language: language)
//		}
	}
	
	func setUserInputText(_ text: String?){
//		let s : String = text ?? ""
//		if let tv = self.userInputNode.view as? UITextView {
//			tv.text = s
//			self.invalidateIntrinsicContentSizeAndNotify()
//			if let setting = self.translateSettings {
//				self.fetchTranslation(language: setting.code)
//			} else {
//				let languageCode = self.presentationData.strings.primaryComponent.languageCode
//				self.fetchTranslation(language: languageCode)
//			}
//		}
	}
	
	override func layout() {
		self.inputSeparateNode.frame = CGRect(
			x: 0,
			y: 0,
			width: self.screenWidth,
			height: 1
		)
	}
	func updateLayout(layout: ContainerViewLayout) {

		self.containerLayout = layout
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
		self.invalidateIntrinsicContentSizeAndNotify()
	}
	

	private func invalidateIntrinsicContentSizeAndNotify() {
		guard let tv = self.userInputNode.view as? UITextView else { return }
		let textWidth = self.screenWidth - (self.padding * 2) - self.sendButtonSize - 4
		let targetSize = tv.sizeThatFits(CGSize(
			width: textWidth,
			height: CGFloat.greatestFiniteMagnitude
		))
		var textHeight = max(minInputHeight, targetSize.height)
		let textPaddingTop = 4.0
		textHeight = min(textHeight, maxInputHeight)
		let textY = screenHeight - textHeight
		
		self.frame = CGRect(
			x: 0,
			y: textY - 8 - self.bottomInsetHeight,
			width: screenWidth,
			height: textHeight + self.bottomInsetHeight + 8
		)
		// Constant constraint
		let placeholderSize = self.placeholderNode.measure(CGSize(
			width: screenWidth - (padding * 2) - sendButtonSize - 4,
			height: CGFloat.greatestFiniteMagnitude
		))
		self.placeholderNode.frame = CGRect(
			x: self.padding,
			y: self.padding,
			width: placeholderSize.width,
			height: placeholderSize.height
		)
		self.placeholderNode.isHidden = !tv.text.isEmpty
		//
		

	
		self.sendButtonNode.frame = CGRect(
			x: screenWidth - self.sendButtonSize - self.padding ,
			y: (textHeight - sendButtonSize - floor((minInputHeight - sendButtonSize) / 2.0) + textPaddingTop) ,
			width: self.sendButtonSize,
			height: self.sendButtonSize
		)
		
		self.inputBackgroundNode.frame = CGRect(
			x: 0,
			y: 0,
			width: screenWidth,
			height: textHeight + 8
		)
	
		self.userInputNode.frame = CGRect(
			x: padding,
			y: textPaddingTop - bottomInsetHeight,
			width: textWidth,
			height: textHeight
		)
		self.bottomInsetNode.frame = CGRect(
			x: 0,
			y: self.inputBackgroundNode.frame.maxY,
			width: screenWidth,
			height: self.bottomInsetHeight
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
					return
				}
				self.updateLayout(layout: layout)
			}
		}
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
