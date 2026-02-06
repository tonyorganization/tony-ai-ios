import UIKit
import TelegramPresentationData
import Foundation

public enum AiFeature: CaseIterable {
	case history
	case summarize
	case translation
	case grammar
	case formal
	case friend
	
	public func title(strings : PresentationStrings) -> String {
		switch self {
		case .history:
			return "History"
		case .summarize:
			return "Summarize"
		case .translation:
			return "Translation"
		case .grammar:
			return "Fix Grammar"
		case .formal:
			return "Make Formal"
		case .friend:
			return "Make Friend"
		}
		
	}
	
	var id: Int {
		switch self {
		case .history:
			return 0
		case .summarize:
			return 1
		case .translation:
			return 2
		case .grammar:
			return 3
		case .formal:
			return 4
		case .friend:
			return 5
			
		}
	}
	
	var iconName: String {
		switch self {
		case .history:
			return "Ton/IconInfoFlat"
		case .summarize:
			return "Ton/IconInfoFlat"
		case .translation:
			return "Ton/IconTranslate2"
		case .grammar:
			return "Ton/IconWriting"
		case .formal:
			return "Ton/IconInfoFlat"
		case .friend:
			return "Ton/IconInfoFlat"
			
		}
	}
	
	var image: UIImage? {
		UIImage(named: iconName)
	}
}
