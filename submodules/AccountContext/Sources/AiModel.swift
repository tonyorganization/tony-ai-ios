import TelegramCore
import Foundation

public final class LanguageItemInfo {
	
	public let code : String
	public let name : String
	public let nativeName : String
	
	public init(
		code: String,
		name: String,
		nativeName: String,
	) {
		self.code = code
		self.name = name
		self.nativeName = nativeName
	}
	
}
public final class OutgoingTranslateSetting:  Codable, Equatable {
	
	public let code: String
	public let name: String
	
	
	public static var defaultSettings: OutgoingTranslateSetting {
		return OutgoingTranslateSetting(code: "en", name: "English")
	}
	
	public init(code: String, name: String) {
		self.code = code
		self.name = name
	}
	
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: StringCodingKey.self)
		if let languageCode = try container.decodeIfPresent(String.self, forKey: "languageCode") {
			self.code = languageCode
		} else {
			self.code = "en"
		}
		if let languageName = try container.decodeIfPresent(String.self, forKey: "languageName") {
			self.name = languageName
		} else {
			self.name = "English"
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: StringCodingKey.self)
		try container.encode(self.code, forKey: "languageCode")
		try container.encode(self.name, forKey: "languageName")
	}
	
	public static func ==(lhs: OutgoingTranslateSetting, rhs: OutgoingTranslateSetting) -> Bool {
		return lhs.code == rhs.code
	}
}
