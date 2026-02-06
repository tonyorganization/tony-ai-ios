import Foundation
import UIKit
import AsyncDisplayKit
import Display
import PhoneNumberFormat

private func removeDuplicatedPlus(_ text: String?) -> String {
    var result = ""
    if let text = text {
        for c in text {
            if c == "+" {
                if result.isEmpty {
                    result += String(c)
                }
            } else {
                result += String(c)
            }
        }
    }
    return result
}

private func removePlus(_ text: String?) -> String {
    var result = ""
    if let text = text {
        for c in text {
            if c != "+" {
                result += String(c)
            }
        }
    }
    return result
}

private func cleanPhoneNumber(_ text: String?) -> String {
    var cleanNumber = ""
    if let text = text {
        for c in text {
            if c == "+" {
                if cleanNumber.isEmpty {
                    cleanNumber += String(c)
                }
            } else if c >= "0" && c <= "9" {
                cleanNumber += String(c)
            }
        }
    }
    return cleanNumber
}

private func cleanPrefix(_ text: String) -> String {
    var result = ""
    var checked = false
    for c in text {
        if c != " " {
            checked = true
        }
        if checked {
            result += String(c)
        }
    }
    return result
}

private func cleanSuffix(_ text: String) -> String {
    var result = ""
    var checked = false
    for c in text.reversed() {
        if c != " " {
            checked = true
        }
        if checked {
            result = String(c) + result
        }
    }
    return result
}

public final class PhoneInputNode: ASDisplayNode, UITextFieldDelegate {
	public let dialingTextNode: TextFieldNode
    public let phoneNumberNode: TextFieldNode
    public let placeholderNode: ImmediateTextNode
	public let separatorNode: ASDisplayNode
    public var previousCountryCodeText = "+"
    public var previousNumberText = ""
    public var enableEditing: Bool = true
    
    public var number: String {
        get {
            return cleanPhoneNumber((self.dialingTextNode.textField.text ?? "") + (self.phoneNumberNode.textField.text ?? ""))
        } set(value) {
            self.updateNumber(value)
        }
    }
    
    public var codeNumberAndFullNumber: (String, String, String) {
        let full = self.number
        return (
            cleanPhoneNumber(self.dialingTextNode.textField.text ?? ""),
            cleanPhoneNumber(self.phoneNumberNode.textField.text ?? ""),
            full
        )
    }
    
    public var countryCodeText: String {
        get {
            return self.dialingTextNode.textField.text ?? ""
        } set(value) {
            if self.dialingTextNode.textField.text != value {
                self.dialingTextNode.textField.text = value
                self.countryCodeTextChanged(self.dialingTextNode.textField)
            }
        }
    }
    
    public var numberText: String {
        get {
            return self.phoneNumberNode.textField.text ?? ""
        } set(value) {
            if self.phoneNumberNode.textField.text != value {
                self.phoneNumberNode.textField.text = value
                self.numberTextChanged(self.phoneNumberNode.textField)
            }
        }
    }
    
    private var countryNameForCode: (Int32, String)?
    
    public var formattedCodeAndNumber: (String, String) {
        return (self.dialingTextNode.textField.text ?? "", self.phoneNumberNode.textField.text ?? "")
    }
    
    public var codeAndNumber: (Int32?, String?, String) {
        get {
            var code: Int32?
            if let text = self.dialingTextNode.textField.text, text.count <= 4, let number = Int(removePlus(text)) {
                code = Int32(number)
                var countryName: String?
                if self.countryNameForCode?.0 == code {
                    countryName = self.countryNameForCode?.1
                }
                return (code, countryName, cleanPhoneNumber(self.phoneNumberNode.textField.text))
            } else if let text = self.dialingTextNode.textField.text {
                return (nil, nil, cleanPhoneNumber(text + (self.phoneNumberNode.textField.text ?? "")))
            } else {
                return (nil, nil, "")
            }
        } set(value) {
            let updatedCountryName = self.countryNameForCode?.0 != value.0 || self.countryNameForCode?.1 != value.1
            if let code = value.0, let name = value.1 {
                self.countryNameForCode = (code, name)
            } else {
                self.countryNameForCode = nil
            }
            self.updateNumber("+" + (value.0 == nil ? "" : "\(value.0!)") + value.2, forceNotifyCountryCodeUpdated: updatedCountryName)
        }
    }
    
    public var countryCodeUpdated: ((String, String?) -> Void)?
    
    public var countryCodeTextUpdated: ((String) -> Void)?
	
    public var numberTextUpdated: ((String) -> Void)?
    
    public var keyPressed: ((Int) -> Void)?
    
    public var returnAction: (() -> Void)?
    
    private let phoneFormatter = InteractivePhoneFormatter()
	
    public var customFormatter: ((String) -> String?)?
    
    public var mask: NSAttributedString? {
        didSet {
            self.updatePlaceholder()
        }
    }
    
    private var didSetupPlaceholder = false
    private func updatePlaceholder() {
		// TODO: Ton - Phone: disable show 00000
        if let mask = self.mask {
            let mutableMask = NSMutableAttributedString(attributedString: mask)
            mutableMask.replaceCharacters(in: NSRange(location: 0, length: mask.string.count), with: mask.string.replacingOccurrences(of: "X", with: "0"))
            if let text = self.phoneNumberNode.textField.text {
                mutableMask.replaceCharacters(in: NSRange(location: 0, length: min(text.count, mask.string.count)), with: text)
            }
            mutableMask.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 0, length: min(self.phoneNumberNode.textField.text?.count ?? 0, mutableMask.string.count)))
            mutableMask.addAttribute(.kern, value: 1.6, range: NSRange(location: 0, length: mask.string.count))
            //self.placeholderNode.attributedText = mutableMask
        } else {
            self.placeholderNode.attributedText = NSAttributedString(string: "")
        }
        if !self.frame.size.width.isZero {
            self.didSetupPlaceholder = true
//            let _ = self.placeholderNode.updateLayout(CGSize(
//				width: self.frame.size.width,
//				height: 20
//				//height: CGFloat.greatestFiniteMagnitude
//			))
        }
    }
    
    private let fontSize: CGFloat
    
    public init(fontSize: CGFloat = 20.0) {
        self.fontSize = fontSize
        
        let font = Font.with(size: fontSize, design: .regular, traits: [.monospacedNumbers])
        
        self.dialingTextNode = TextFieldNode()
        self.dialingTextNode.textField.font = font
        self.dialingTextNode.textField.textAlignment = .center
        self.dialingTextNode.textField.returnKeyType = .next
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.dialingTextNode.textField.keyboardType = .asciiCapableNumberPad
        } else {
            self.dialingTextNode.textField.keyboardType = .numberPad
        }
		self.separatorNode = ASDisplayNode()
		self.separatorNode.backgroundColor = UIColor(rgb: 0x828284)
        self.placeholderNode = ImmediateTextNode()
        
        self.phoneNumberNode = TextFieldNode()
        self.phoneNumberNode.textField.font = font
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.phoneNumberNode.textField.keyboardType = .asciiCapableNumberPad
        } else {
            self.phoneNumberNode.textField.keyboardType = .numberPad
        }
        self.phoneNumberNode.textField.defaultTextAttributes = [NSAttributedString.Key.font: font, NSAttributedString.Key.kern: 1.6]
        super.init()
		self.addSubnode(self.separatorNode)
        self.addSubnode(self.dialingTextNode)

        self.addSubnode(self.placeholderNode)
        self.addSubnode(self.phoneNumberNode)
        
        self.phoneNumberNode.textField.didDeleteBackwardWhileEmpty = { [weak self] in
            self?.dialingTextNode.textField.becomeFirstResponder()
        }
        self.dialingTextNode.textField.addTarget(self, action: #selector(self.countryCodeTextChanged(_:)), for: .editingChanged)
        self.phoneNumberNode.textField.addTarget(self, action: #selector(self.numberTextChanged(_:)), for: .editingChanged)
        self.dialingTextNode.textField.delegate = self
        self.phoneNumberNode.textField.delegate = self
    }
    
    @objc private func countryCodeTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
    
    @objc private func numberTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
        
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if !self.enableEditing {
            return false
        }
        if range.length == 0, string.count > 1 {
            self.updateNumber(cleanPhoneNumber(string), tryRestoringInputPosition: false)
            return false
        }
        
        if string.count == 1, let num = Int(string) {
            self.keyPressed?(num)
        }
        
        return true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.phoneNumberNode.textField {
            self.returnAction?()
        }
        return false
    }
    
    private func updateNumberFromTextFields() {
        let inputText = removeDuplicatedPlus(cleanPhoneNumber(self.dialingTextNode.textField.text) + cleanPhoneNumber(self.phoneNumberNode.textField.text))
        self.updateNumber(inputText)
    }
    
    private func updateNumber(_ inputText: String, tryRestoringInputPosition: Bool = true, forceNotifyCountryCodeUpdated: Bool = false) {
        var (regionPrefix, text) = self.phoneFormatter.updateText(inputText)
        
        if let customFormatter = self.customFormatter, let customRegionPrefix = customFormatter(inputText) {
            regionPrefix = "+\(customRegionPrefix)"
            text = inputText
        }
                
        var realRegionPrefix: String
        var numberText: String
        if let regionPrefix = regionPrefix, !regionPrefix.isEmpty, regionPrefix != "+" {
            realRegionPrefix = cleanSuffix(regionPrefix)
            if !realRegionPrefix.hasPrefix("+") {
                realRegionPrefix = "+" + realRegionPrefix
            }
            if !text.hasPrefix("+") {
                text = "+" + text
            }
            numberText = cleanPrefix(String(text[realRegionPrefix.endIndex...]))
        } else {
            realRegionPrefix = text
            if !realRegionPrefix.hasPrefix("+") {
                realRegionPrefix = "+" + realRegionPrefix
            }
            numberText = ""
        }
        
        if let mask = self.mask {
            numberText = formatPhoneNumberToMask(numberText, mask: mask.string)
        }
        
        var focusOnNumber = false
        if realRegionPrefix != self.dialingTextNode.textField.text {
            self.dialingTextNode.textField.text = realRegionPrefix
        }
        if self.previousCountryCodeText != realRegionPrefix || forceNotifyCountryCodeUpdated {
            self.previousCountryCodeText = realRegionPrefix
            let code = removePlus(realRegionPrefix).trimmingCharacters(in: .whitespaces)
            var countryName: String?
            if self.countryNameForCode?.0 == Int32(code) {
                countryName = self.countryNameForCode?.1
            }
            self.countryCodeUpdated?(code, countryName)
        }
        self.countryCodeTextUpdated?(realRegionPrefix)
        
        if numberText != self.phoneNumberNode.textField.text {
            var restorePosition: Int?
            if let text = self.phoneNumberNode.textField.text, let selectedTextRange = self.phoneNumberNode.textField.selectedTextRange {
                let initialOffset = self.phoneNumberNode.textField.offset(from: self.phoneNumberNode.textField.beginningOfDocument, to: selectedTextRange.start)
                var significantIndex = 0
                for i in 0 ..< min(initialOffset, text.count) {
                    let unicodeScalars = String(text[text.index(text.startIndex, offsetBy: i)]).unicodeScalars
                    if unicodeScalars.count == 1 && CharacterSet.decimalDigits.contains(unicodeScalars[unicodeScalars.startIndex]) {
                        significantIndex += 1
                    }
                }
                var restoreIndex = 0
                for i in 0 ..< numberText.count {
                    if significantIndex <= 0 {
                        break
                    }
                    let unicodeScalars = String(numberText[numberText.index(numberText.startIndex, offsetBy: i)]).unicodeScalars
                    if unicodeScalars.count == 1 && CharacterSet.decimalDigits.contains(unicodeScalars[unicodeScalars.startIndex]) {
                        significantIndex -= 1
                    }
                    restoreIndex += 1
                }
                restorePosition = restoreIndex
            }
            self.phoneNumberNode.textField.text = numberText
            if tryRestoringInputPosition, let restorePosition = restorePosition {
                if let startPosition = self.phoneNumberNode.textField.position(from: self.phoneNumberNode.textField.beginningOfDocument, offset: restorePosition) {
                    let selectionRange = self.phoneNumberNode.textField.textRange(from: startPosition, to: startPosition)
                    self.phoneNumberNode.textField.selectedTextRange = selectionRange
                }
            }
        }
        self.numberTextUpdated?(numberText)
        
        if self.previousNumberText.isEmpty && !numberText.isEmpty {
            focusOnNumber = true
        }
        self.previousNumberText = numberText
        
        if focusOnNumber && !self.phoneNumberNode.textField.isFirstResponder {
            self.phoneNumberNode.textField.becomeFirstResponder()
        }
        
        self.updatePlaceholder()
    }
    
    public override func layout() {
        super.layout()
        
        if !self.didSetupPlaceholder, self.frame.width > 0.0 {
            self.updatePlaceholder()
        }
    }
}
