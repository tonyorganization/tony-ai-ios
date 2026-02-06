import Foundation
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
//import PhoneNumberFormat

public extension EnginePeer {
    var compactDisplayTitle: String {
        switch self {
        case let .user(user):
            if let firstName = user.firstName, !firstName.isEmpty {
                return firstName
            } else if let lastName = user.lastName, !lastName.isEmpty {
                return lastName
            } else if let _ = user.phone {
                return "" //formatPhoneNumber("+\(phone)")
            } else {
                return "Deleted Account"
            }
        case let .legacyGroup(group):
            return group.title
        case let .channel(channel):
            return channel.title
        case .secretChat:
            return ""
        }
    }

    func displayTitle(strings: PresentationStrings, displayOrder: PresentationPersonNameOrder) -> String {
		let appName : String
		if Bundle.main.bundleIdentifier == "io.toncorp.tonmessenger" {
			// Dev
			appName = "Tongram Dev"
		}else{
			// Prod
			appName = "Tongram"
		}
        switch self {
        case let .user(user):
            if user.id.isReplies {
                return strings.DialogList_Replies
            }
            if let firstName = user.firstName, !firstName.isEmpty {
                if let lastName = user.lastName, !lastName.isEmpty {
                    switch displayOrder {
                    case .firstLast:
                        return "\(firstName) \(lastName)"
                    case .lastFirst:
                        return "\(lastName) \(firstName)"
                    }
                } else {
					// TODO: Ton - ChatList: modify Telegram text in chat list, Telegram id: user.id.toInt64() = 777000
					if(firstName == "Telegram"){
						return appName
					}
                    return firstName
                }
            } else if let lastName = user.lastName, !lastName.isEmpty {
				// TODO: Ton - ChatList: modify Telegram text in chat list
				if(lastName == "Telegram"){
					return appName
				}
                return lastName
            } else if let _ = user.phone {
                return "" //formatPhoneNumber("+\(phone)")
            } else {
                return strings.User_DeletedAccount
            }
        case let .legacyGroup(group):
            return group.title
        case let .channel(channel):
			// TODO: Ton - ChatList: modify Telegram Tip text in chat list, Telegram Tip: channel.id.toInt64() = 9814559261
			var title = channel.title
			if let range = title.range(of: "Telegram") {
				 title.replaceSubrange(range, with: "Tongram")
			}
            return title
        case .secretChat:
            return ""
        }
    }
}

public extension EnginePeer.IndexName {
    func isLessThan(other: EnginePeer.IndexName, ordering: PresentationPersonNameOrder) -> ComparisonResult {
        switch self {
        case let .title(lhsTitle, _):
            let rhsString: String
            switch other {
            case let .title(title, _):
                rhsString = title
            case let .personName(first, last, _, _):
                switch ordering {
                case .firstLast:
                    if first.isEmpty {
                        rhsString = last
                    } else {
                        rhsString = first + last
                    }
                case .lastFirst:
                    if last.isEmpty {
                        rhsString = first
                    } else {
                        rhsString = last + first
                    }
                }
            }
            return lhsTitle.caseInsensitiveCompare(rhsString)
        case let .personName(lhsFirst, lhsLast, _, _):
            let lhsString: String
            switch ordering {
            case .firstLast:
                if lhsFirst.isEmpty {
                    lhsString = lhsLast
                } else {
                    lhsString = lhsFirst + lhsLast
                }
            case .lastFirst:
                if lhsLast.isEmpty {
                    lhsString = lhsFirst
                } else {
                    lhsString = lhsLast + lhsFirst
                }
            }
            let rhsString: String
            switch other {
            case let .title(title, _):
                rhsString = title
            case let .personName(first, last, _, _):
                switch ordering {
                case .firstLast:
                    if first.isEmpty {
                        rhsString = last
                    } else {
                        rhsString = first + last
                    }
                case .lastFirst:
                    if last.isEmpty {
                        rhsString = first
                    } else {
                        rhsString = last + first
                    }
                }
            }
            return lhsString.caseInsensitiveCompare(rhsString)
        }
    }
}
