import Foundation
import TelegramCore
import TelegramUIPreferences
import UIKit
// TODO: Ton - Theme: color resources - theme 
public class CustomTheme {
	public let isDark: Bool
	public let accentColor: UIColor
	public let accent2Color: UIColor
	public let aiButtonColor: UIColor
	public let aiButtonDisabledColor: UIColor
	public let aiInputBackground: UIColor
	public let aiInputTextColor: UIColor
	public let aiInputHolderColor: UIColor
	public let aiTranslatedColor: UIColor

	public let backgroundColor: UIColor
	public let blurredBackgroundColor: UIColor
	public let buttonTextColor: UIColor
	public let chatDateHeaderTextColor: UIColor
	public let defaultBlock: UIColor
	public let dimColor: UIColor
	
	public let incomingBubble: [UIColor]
	public let incomingSecondaryText: UIColor
	public let incomingText: UIColor
	public let inputBackground: UIColor

	public let itemHighlightColor: UIColor
	public let linkTextColor: UIColor
	public let modalBackground: UIColor

	public let navBarColor: UIColor
	public let navBarButtonIconColor: UIColor
	public let navBarButtonTextColor: UIColor
	public let navBarTitleColor: UIColor

	public let outgoingBubble: [UIColor]
	public let outgoingSecondaryText: UIColor
	public let outgoingText: UIColor

	public let primaryTextColor: UIColor
	public let secondaryTextColor: UIColor
	
	public let selectedButton: UIColor
	public let unselectButton: UIColor
	public let unselectButton2: UIColor
	public let selectedButtonText: UIColor
	public let unselectButtonText: UIColor
	
	public init(
		isDark: Bool,
		accentColor: UIColor,
		accent2Color: UIColor,
		aiButtonColor: UIColor,
		aiButtonDisabledColor: UIColor,
		aiInputBackground: UIColor,
		aiInputTextColor: UIColor,
		aiInputHolderColor: UIColor,
		aiTranslatedColor: UIColor,

		backgroundColor: UIColor,
		blurredBackgroundColor: UIColor,
		buttonTextColor: UIColor,
		chatDateHeaderTextColor: UIColor,
		defaultBlock: UIColor,
		dimColor: UIColor,

		incomingBubble: [UIColor],
		incomingSecondaryText: UIColor,
		incomingText: UIColor,
		inputBackground: UIColor,
		itemHighlightColor: UIColor,

		linkTextColor: UIColor,
		modalBackground: UIColor,

		navBarColor: UIColor,
		navBarButtonIconColor: UIColor,
		navBarButtonTextColor: UIColor,
		navBarTitleColor: UIColor,

		outgoingBubble: [UIColor],
		outgoingSecondaryText: UIColor,
		outgoingText: UIColor,

		primaryTextColor: UIColor,
		secondaryTextColor: UIColor,
		
		selectedButton: UIColor,
		unselectButton: UIColor,
		unselectButton2: UIColor,
		selectedButtonText: UIColor,
		unselectButtonText: UIColor
	) {
		self.isDark = isDark
		self.accentColor = accentColor
		self.accent2Color = accentColor
		self.aiButtonColor = aiButtonColor
		self.aiButtonDisabledColor = aiButtonDisabledColor
		self.aiInputBackground = aiInputBackground
		self.aiInputTextColor = aiInputTextColor
		self.aiInputHolderColor = aiInputHolderColor
		self.aiTranslatedColor = aiTranslatedColor

		self.backgroundColor = backgroundColor
		self.blurredBackgroundColor = blurredBackgroundColor

		self.buttonTextColor = buttonTextColor
		self.chatDateHeaderTextColor = chatDateHeaderTextColor

		self.defaultBlock = defaultBlock
		self.dimColor = dimColor

		self.incomingBubble = incomingBubble
		self.incomingSecondaryText = incomingSecondaryText
		self.incomingText = incomingText
		self.inputBackground = inputBackground

		self.itemHighlightColor = itemHighlightColor
		self.linkTextColor = linkTextColor
		self.modalBackground = modalBackground

		self.navBarColor = navBarColor
		self.navBarButtonIconColor = navBarButtonIconColor
		self.navBarButtonTextColor = navBarButtonTextColor
		self.navBarTitleColor = navBarTitleColor

		self.outgoingBubble = outgoingBubble
		self.outgoingSecondaryText = outgoingSecondaryText
		self.outgoingText = outgoingText

		self.primaryTextColor = primaryTextColor
		self.secondaryTextColor = secondaryTextColor
		
		self.selectedButton = selectedButton
		self.unselectButton = unselectButton
		self.unselectButton2 = unselectButton2
		self.selectedButtonText = selectedButtonText
		self.unselectButtonText = unselectButtonText
	}
}

public class CustomDimen {
	
	public var buttonHeight: CGFloat {
		return 50.0
	}
	public var borderWidth: CGFloat {
		return 1.6
	}
	public var buttonRadius: CGFloat {
		return 25.0
	}
	public var inputHeight: CGFloat {
		return 50.0
	}
	public var inputWidth: CGFloat {
		return 1.6
	}
	public var inputRadius: CGFloat {
		return 25.0
	}
	public var searchTextHeight: CGFloat {
		return 40.0
	}
	
	public init(){
	
	}

}
