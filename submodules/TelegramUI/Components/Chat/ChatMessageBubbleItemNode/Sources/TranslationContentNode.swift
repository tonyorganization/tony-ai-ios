import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TextFormat
import UrlEscaping
import TelegramUniversalVideoContent
import TextSelectionNode
import Emoji
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import AccountContext
import YuvConversion
import AnimationCache
import LottieAnimationCache
import MultiAnimationRenderer
import EmojiTextAttachmentView
import TextNodeWithEntities
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ShimmeringLinkNode
import ChatMessageItemCommon
import TextLoadingEffect
import ChatControllerInteraction
import InteractiveTextComponent
import RadialStatusNode

// TODO: Ton - Translate: TranslationContentNode
public class TranslationContentNode: ChatMessageBubbleContentNode {
	
	private let buttonNode: HighlightTrackingButtonNode
	private let buttonBackgroundNode: ASDisplayNode
	private let buttonTextNode: TextNode
	private let buttonIconNode: ASImageNode
	
	private let translatedBackgroundNode: ASDisplayNode
	private let translatedTextNode: InteractiveTextNodeWithEntities
	
	private let progressNode: RadialStatusNode
	private var constrainedSize: CGSize = CGSize.zero
	private var layoutConstants: ChatMessageItemLayoutConstants?
	private var translatedText: String = ""
	private var isShowTranslate: Bool = true
	private var isTranslating: Bool = false
	private var textSelectionNode: TextSelectionNode?
	
	
	
	required public init() {
		self.buttonBackgroundNode = ASDisplayNode()
		self.buttonNode = HighlightTrackingButtonNode()
		self.buttonTextNode = TextNode()
		
		self.translatedBackgroundNode = ASDisplayNode()
		self.translatedTextNode = InteractiveTextNodeWithEntities()
		
		self.progressNode = RadialStatusNode(backgroundNodeColor: .clear)
		self.buttonIconNode = ASImageNode()
		super.init()
		
		self.addSubnode(self.buttonNode)
		
		// Translate button
		self.buttonBackgroundNode.isUserInteractionEnabled = false
#if targetEnvironment(simulator)
		self.buttonBackgroundNode.backgroundColor = UIColor(rgb: 0xAED581)
#else
		self.buttonBackgroundNode.backgroundColor = .clear
#endif
		self.buttonNode.addSubnode(self.buttonBackgroundNode)
		
		self.buttonTextNode.isUserInteractionEnabled = false
		self.buttonTextNode.contentMode = .topLeft
		self.buttonTextNode.contentsScale = UIScreenScale
		self.buttonNode.addSubnode(self.buttonTextNode)
		self.buttonNode.isAccessibilityElement = false
		self.buttonNode.addTarget(self, action: #selector(self.startTranslate), forControlEvents: .touchUpInside)
		
		
		self.buttonIconNode.contentMode = .scaleAspectFit
		self.buttonIconNode.isUserInteractionEnabled = false
		self.buttonIconNode.image = UIImage(named: "Ton/IconTranslate")?
			.withRenderingMode(.alwaysOriginal)
			.withTintColor(UIColor(rgb: 0x8b8f95))
		self.buttonNode.addSubnode(self.buttonIconNode)
		
#if targetEnvironment(simulator)
		self.translatedBackgroundNode.backgroundColor = UIColor(rgb: 0xCE93D8)
#else
		self.translatedBackgroundNode.backgroundColor = .clear
#endif
		self.addSubnode(self.translatedBackgroundNode)
		
		
		let textNode = self.translatedTextNode.textNode
		textNode.isUserInteractionEnabled = true
		textNode.contentMode = .topLeft
		textNode.contentsScale = UIScreenScale
		textNode.displaysAsynchronously = true
		
		self.addSubnode(self.translatedTextNode.textNode)
		self.setUpTextSelectionNode()
		//self.progressNode.foregroundNodeColor = UIColor(rgb: 0x1976D2)
		self.addSubnode(self.progressNode)
	}
	
	required public init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
		//let localPoint = self.buttonNode.convert(point, from: self)
		if self.buttonNode.bounds.contains(point) {
			//self.onButtonPress()
			return ChatMessageBubbleContentTapAction(content: .ignore)
		}
		return ChatMessageBubbleContentTapAction(content: .none)
	}
	
	override public func asyncLayoutContent() -> (
		_ item: ChatMessageBubbleContentItem,
		_ layoutConstants: ChatMessageItemLayoutConstants,
		_ preparePosition: ChatMessageBubblePreparePosition,
		_ messageSelection: Bool?,
		_ constrainedSize: CGSize,
		_ avatarInset: CGFloat
	) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
		
		let buttonTextMeasure = TextNode.asyncLayout(self.buttonTextNode)
		let translatedTextMeasure = InteractiveTextNodeWithEntities.asyncLayout(self.translatedTextNode)
		let translateBottomMargin : CGFloat = 10
		var buttonText = "Translate"
		return { item, layoutConstants, _, _, _, _ in
			self.item = item
			// TODO: Ton - Translate: get exist translate content
			if  !item.message.attributes.isEmpty {
				//print("Translate - item attributes: \(item.message.attributes.count)")
				if let translatedAttribute = item.message.attributes.first(where: {
					$0 is TranslateTextMessageAttribute
				}) as? TranslateTextMessageAttribute {
					let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
					let languageCode = presentationData.strings.primaryComponent.languageCode
					
					if translatedAttribute.lang == languageCode {
						self.translatedText = translatedAttribute.text
						self.isShowTranslate = translatedAttribute.isShow
						if  self.translatedText.isEmpty {
							buttonText = self.isTranslating ? "Translating...": "Translate"
						} else {
							buttonText = self.isShowTranslate ? "Hide Translation": "Translate"
						}
					}
				}
			}
			
			let contentProperties = ChatMessageBubbleContentProperties(
				hidesSimpleAuthorHeader: false,
				headerSpacing: 0.0,
				hidesBackground: .never,
				forceFullCorners: false,
				forceAlignment: .none,
			)
			
			return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
				
				self.constrainedSize = constrainedSize
				self.layoutConstants = layoutConstants
				let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
				let messageTheme = item.presentationData.theme.theme.chat.message.incoming
				
				// TODO: Ton - Translate: Translate button
				let buttonInsets : UIEdgeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 10.0, right: 4.0)
				let (buttonLayout, buttonApply) = buttonTextMeasure(TextNodeLayoutArguments(
					attributedString: NSAttributedString(
						string: buttonText,
						font: Font.bold(12),
						textColor: UIColor(rgb: 0x8b8f95)
					),
					maximumNumberOfLines: 1,
					truncationType: .end,
					constrainedSize: CGSize(
						width: min(CGFloat.greatestFiniteMagnitude, constrainedSize.width - horizontalInset),
						height: constrainedSize.height
					),
					insets: buttonInsets,
				))
				
				var buttonFrame = CGRect(
					origin: CGPoint(x: -buttonInsets.left, y: -buttonInsets.top),
					size: buttonLayout.size,
				)
				var buttonFrameWithoutInsets = CGRect(
					origin: CGPoint(
						x: buttonFrame.origin.x + buttonInsets.left,
						y: buttonFrame.origin.y + buttonInsets.top,
					),
					size: CGSize(
						width: buttonFrame.width - buttonInsets.left - buttonInsets.right,
						height: buttonFrame.height - buttonInsets.top - buttonInsets.bottom,
					)
				)
				buttonFrame = buttonFrame.offsetBy(
					dx: layoutConstants.text.bubbleInsets.left,
					dy: 0
				)
				buttonFrameWithoutInsets = buttonFrameWithoutInsets.offsetBy(
					dx: layoutConstants.text.bubbleInsets.left,
					dy: 0
				)
				
				// TODO: Ton - Translate: Translate text
				let textWillShow : String
				let textLines : Int
				let textColor: UIColor
				if !self.translatedText.isEmpty && self.isShowTranslate {
					textWillShow = self.translatedText
					textLines = 300
					textColor = messageTheme.primaryTextColor
				}else{
					textWillShow = ""
					textLines = 1
					textColor = .clear
				}
				let (textLayout, textApply) = translatedTextMeasure(InteractiveTextNodeLayoutArguments(
					attributedString: NSAttributedString(
						string: textWillShow,
						font: item.presentationData.messageFont,
						textColor: textColor
					),
					backgroundColor: nil,
					maximumNumberOfLines: textLines,
					truncationType: .end,
					constrainedSize: CGSize(
						width: constrainedSize.width - (horizontalInset * 2),
						height: CGFloat.greatestFiniteMagnitude
					),
					alignment: .natural,
					cutout: nil,
					insets: UIEdgeInsets.zero,
					lineColor: messageTheme.accentControlColor
				))
				
				let iconSize : CGFloat = 14
				// TODO: Ton - Translate: Node width
				let suggestedBoundingWidth: CGFloat
				if !self.translatedText.isEmpty && self.isShowTranslate {
					suggestedBoundingWidth = textLayout.size.width + (horizontalInset * 2) + iconSize
				}else{
					suggestedBoundingWidth = buttonFrameWithoutInsets.width + iconSize
				}
				return (suggestedBoundingWidth, { boundingWidth in
					// TODO: Ton - Translate: update node height
					var boundingSize: CGSize = buttonFrameWithoutInsets.size
					boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
					boundingSize.height += layoutConstants.text.bubbleInsets.top + layoutConstants.text.bubbleInsets.bottom
					
					if !self.translatedText.isEmpty && self.isShowTranslate {
						boundingSize.height += (textLayout.size.height + translateBottomMargin)
					}
					return (boundingSize, { [weak self] animation, synchronousLoads, _ in
						guard let strongSelf = self else {	return }
						
						// TODO: Ton - Translate: apply translate button layout
						let _ = buttonApply()
						
						let clickableAreaSize = CGSize(
							width: buttonFrame.width + iconSize + 4,
							height: buttonFrame.height
						)
						let clickableAreaFrame =  CGRect(
							origin: buttonFrame.origin,
							size: clickableAreaSize
						)
						
						strongSelf.buttonNode.frame = clickableAreaFrame
						strongSelf.buttonBackgroundNode.frame = CGRect(origin: .zero, size: clickableAreaSize)
						strongSelf.buttonTextNode.frame = CGRect(origin: .zero, size: buttonFrame.size)
						
						if !strongSelf.translatedText.isEmpty && strongSelf.isShowTranslate {
//							// TODO: Ton - Translate: init translate text layout
							let textFrame = CGRect(
								origin: buttonFrame.bottomLeft,
								size: textLayout.size
							)
							
							
							strongSelf.translatedBackgroundNode.frame = textFrame
							strongSelf.translatedTextNode.textNode.frame = textFrame
							strongSelf.buttonIconNode.frame = .zero
							
						} else {
							
							strongSelf.translatedBackgroundNode.frame = .zero
							strongSelf.translatedTextNode.textNode.frame = .zero
							strongSelf.buttonIconNode.frame = CGRect(
								origin: strongSelf.buttonTextNode.frame.topRight,
								size: CGSize(width: iconSize, height: iconSize)
							)
							
						}
						let _ = textApply(InteractiveTextNodeWithEntities.Arguments(
							context: item.context,
							cache: item.controllerInteraction.presentationContext.animationCache,
							renderer: item.controllerInteraction.presentationContext.animationRenderer,
							placeholderColor: messageTheme.mediaPlaceholderColor,
							attemptSynchronous: synchronousLoads,
							textColor: messageTheme.primaryTextColor,
							spoilerEffectColor: messageTheme.secondaryTextColor,
							applyArguments: InteractiveTextNode.ApplyArguments(
								animation: animation,
								spoilerTextColor: messageTheme.primaryTextColor,
								spoilerEffectColor: messageTheme.secondaryTextColor,
								areContentAnimationsEnabled: item.context.sharedContext.energyUsageSettings.loopEmoji,
								spoilerExpandRect: nil,
								crossfadeContents: {
									sourceView in
									//[weak strongSelf] sourceView in
									
									//										guard let strongSelf else {
									//											return
									//										}
									//										if let textNodeContainer = strongSelf.translatedTextNode.textNode.view.superview {
									//											sourceView.frame = CGRect(origin: strongSelf.translatedTextNode.textNode.frame.origin, size: sourceView.bounds.size)
									//											textNodeContainer.addSubview(sourceView)
									//
									//											sourceView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak sourceView] _ in
									//												sourceView?.removeFromSuperview()
									//											})
									//											strongSelf.translatedTextNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
									//										}
								}
							)
						))
						
					})
					
					
				})
			})
		}
	}
	
	override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
		self.buttonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
		self.translatedTextNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
	}
	
	override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
		self.animateInsertion(currentTimestamp, duration: duration)
	}
	
	override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
		self.buttonNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
		self.translatedTextNode.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
	}
	
	// TODO: Ton - Translate: on translate button click
	@objc private func startTranslate() {
		guard let item = self.item else { return }
		let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
		let languageCode = presentationData.strings.primaryComponent.languageCode
		if !self.translatedText.isEmpty {
			let isShow = !self.isShowTranslate
			self.isShowTranslate = isShow
			self.translatedText = ""
			self.saveTranslatedText(
				text: self.translatedText,
				languageCode: languageCode,
				isShow: isShow,
				completed: {
				
					
				}
			)
			
			return
		}
		self.startTranslateAnim()
		let originalText = item.message.text
		print("Translate button pressed for: \(originalText)")
		self.isTranslating = true
		if let item = self.item {
			item.controllerInteraction.requestMessageUpdate(item.message.id, false)
		}
		
		let _ = (item.context.sharedContext.postTranslateText(text: originalText, language: languageCode) |> deliverOnMainQueue)
			.start(next: { [weak self] s in
				let translatedText = s ?? ""
				print("Translated: \(translatedText)")
				guard let strongSelf = self else {	return }
				strongSelf.stopTranslateAnim()
				strongSelf.translatedText = translatedText
				strongSelf.isTranslating = false
				//#if targetEnvironment(simulator)
				//				item.controllerInteraction.requestMessageUpdate(item.message.id, true)
				//#else
				// Save translation only real device
				strongSelf.saveTranslatedText(
					text: translatedText,
					languageCode: languageCode,
					isShow: true,
					completed: {
						
					}
				)
				//#endif
			})
		
	}
	
	// TODO: Ton - Translate: save translated text
	func saveTranslatedText(
		text: String,
		languageCode: String,
		isShow: Bool,
		completed: @escaping (() -> Void)
	)  {
		guard let item = self.item else { return }
		let message = item.message;
		let postbox = item.context.account.postbox
		let messageId = message.id
		Queue.mainQueue().async {
			let _ = postbox.transaction { transaction in
				transaction.updateMessage(messageId) { currentMessage in
					var updatedAttributes = currentMessage.attributes
					updatedAttributes.removeAll { $0 is TranslateTextMessageAttribute }
					updatedAttributes.append(
						TranslateTextMessageAttribute(
							isShow: isShow,
							lang: languageCode,
							text: self.translatedText
						)
					)
					let updateMessage = StoreMessage(
						id: currentMessage.id,
						customStableId: nil,
						globallyUniqueId: currentMessage.globallyUniqueId,
						groupingKey: currentMessage.groupingKey,
						threadId: currentMessage.threadId,
						timestamp: currentMessage.timestamp,
						flags: StoreMessageFlags(currentMessage.flags),
						tags: currentMessage.tags,
						globalTags: currentMessage.globalTags,
						localTags: currentMessage.localTags,
						forwardInfo: nil,
						authorId: currentMessage.author?.id,
						text: currentMessage.text,
						attributes: updatedAttributes,
						media: currentMessage.media
					)
					print("Translate - item attributes updated: \(updatedAttributes.count)")
					return PostboxUpdateMessage.update(
						updateMessage.withUpdatedAttributes(updatedAttributes)
					)
				}
			}.start(completed: completed)
		}
	}
	
	func startTranslateAnim() {
		let fade = CABasicAnimation(keyPath: "opacity")
		fade.fromValue = 0.0
		fade.toValue = 1.0
		fade.duration = 0.8
		fade.autoreverses = true
		fade.repeatCount = .infinity
		fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
		self.buttonTextNode.layer.add(fade, forKey: "fade")
	}
	
	func stopTranslateAnim(){
		self.buttonTextNode.layer.removeAnimation(forKey: "fade")
	}
	
	// TODO: Ton - Translate: Text selection
	private var displayContentsUnderSpoilers: (value: Bool, location: CGPoint?) = (false, nil)
	private var expandedBlockIds: Set<Int> = Set()
	private var appliedExpandedBlockIds: Set<Int>?
	private var textSelectionState: Promise<ChatControllerSubject.MessageOptionsInfo.SelectionState>?
	
	private func setUpTextSelectionNode(){
		self.translatedTextNode.textNode.requestToggleBlockCollapsed = { [weak self] blockId in
			guard let self, let item = self.item else {
				return
			}
			if self.expandedBlockIds.contains(blockId) {
				self.expandedBlockIds.remove(blockId)
			} else {
				self.expandedBlockIds.insert(blockId)
			}
			item.controllerInteraction.requestMessageUpdate(item.message.id, false)
		}
		self.translatedTextNode.textNode.requestDisplayContentsUnderSpoilers = { [weak self] location in
			guard let self else {
				return
			}
			
			cancelParentGestures(view: self.view)
			
			var mappedLocation: CGPoint?
			if let location {
				mappedLocation = self.translatedTextNode.textNode.layer.convert(location, to: self.layer)
			}
			self.updateDisplayContentsUnderSpoilers(value: true, at: mappedLocation)
		}
		self.translatedTextNode.textNode.canHandleTapAtPoint = { [weak self] point in
			guard let self else {
				return false
			}
			let localPoint = self.translatedTextNode.textNode.view.convert(point, to: self.view)
			let action = self.tapActionAtPoint(localPoint, gesture: .tap, isEstimating: true)
			if case .none = action.content {
				return true
			} else {
				return false
			}
		}
	}
	
	override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
		if !value {
			if let textSelectionNode = self.textSelectionNode {
				self.textSelectionNode = nil
				textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
				textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
					textSelectionNode?.highlightAreaNode.removeFromSupernode()
					textSelectionNode?.removeFromSupernode()
				})
			}
		}
	}
	
	override public func updateIsExtractedToContextPreview(_ value: Bool) {
		if value {
			if self.textSelectionNode == nil, let item = self.item, let rootNode = item.controllerInteraction.chatControllerNode() {
				let selectionColor: UIColor
				let knobColor: UIColor
				if item.message.effectivelyIncoming(item.context.account.peerId) {
					selectionColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionColor
					knobColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionKnobColor
				} else {
					selectionColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionColor
					knobColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionKnobColor
				}
				
				let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: selectionColor, knob: knobColor, isDark: item.presentationData.theme.theme.overallDarkAppearance), strings: item.presentationData.strings, textNode: self.translatedTextNode.textNode, updateIsActive: { [weak self] value in
					self?.updateIsTextSelectionActive?(value)
				}, present: { [weak self] c, a in
					guard let self, let item = self.item else {
						return
					}
					
					if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .reply = info {
						item.controllerInteraction.presentControllerInCurrent(c, a)
					} else {
						item.controllerInteraction.presentGlobalOverlayController(c, a)
					}
				}, rootNode: { [weak rootNode] in
					return rootNode
				}, performAction: { [weak self] text, action in
					guard let strongSelf = self, let item = strongSelf.item else {
						return
					}
					item.controllerInteraction.performTextSelectionAction(item.message, true, text, action)
				})
				textSelectionNode.updateRange = { [weak self] selectionRange in
					guard let strongSelf = self else {
						return
					}
					if !strongSelf.displayContentsUnderSpoilers.value, let textLayout = strongSelf.translatedTextNode.textNode.cachedLayout, textLayout.segments.contains(where: { !$0.spoilers.isEmpty }), let selectionRange {
						for segment in textLayout.segments {
							for (spoilerRange, _) in segment.spoilers {
								if let intersection = selectionRange.intersection(spoilerRange), intersection.length > 0 {
									strongSelf.updateDisplayContentsUnderSpoilers(value: true, at: nil)
									return
								}
							}
						}
					}
					if let textSelectionState = strongSelf.textSelectionState {
						textSelectionState.set(.single(strongSelf.getSelectionState(range: selectionRange)))
					}
				}
				
				let enableCopy = (!item.associatedData.isCopyProtectionEnabled && !item.message.isCopyProtected()) || item.message.id.peerId.isVerificationCodes
				textSelectionNode.enableCopy = enableCopy
				
				var enableQuote = !item.message.text.isEmpty
				var enableOtherActions = true
				if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .reply = info {
					enableOtherActions = false
				} else if item.controllerInteraction.canSetupReply(item.message) == .reply {
					//enableOtherActions = false
				}
				
				if !item.controllerInteraction.canSendMessages() && !enableCopy {
					enableQuote = false
				}
				if item.message.id.peerId.namespace == Namespaces.Peer.SecretChat || item.message.id.peerId.isVerificationCodes {
					enableQuote = false
				}
				if item.message.containsSecretMedia {
					enableQuote = false
				}
				if item.associatedData.translateToLanguage != nil {
					enableQuote = false
				}
				
				textSelectionNode.enableQuote = enableQuote
				textSelectionNode.enableTranslate = enableOtherActions
				textSelectionNode.enableShare = enableOtherActions && enableCopy
				textSelectionNode.menuSkipCoordnateConversion = !enableOtherActions
				self.textSelectionNode = textSelectionNode
				self.addSubnode(textSelectionNode)
				self.insertSubnode(textSelectionNode.highlightAreaNode, belowSubnode: self.translatedTextNode.textNode)
				textSelectionNode.frame = self.translatedTextNode.textNode.frame
				textSelectionNode.highlightAreaNode.frame = self.translatedTextNode.textNode.frame
			}
		} else {
			if let textSelectionNode = self.textSelectionNode {
				self.textSelectionNode = nil
				self.updateIsTextSelectionActive?(false)
				textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
				textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
					textSelectionNode?.highlightAreaNode.removeFromSupernode()
					textSelectionNode?.removeFromSupernode()
				})
			}
			
			if self.displayContentsUnderSpoilers.value {
				self.updateDisplayContentsUnderSpoilers(value: false, at: nil)
			}
		}
	}
	
	private func updateDisplayContentsUnderSpoilers(value: Bool, at location: CGPoint?) {
		if self.displayContentsUnderSpoilers.value == value {
			return
		}
		self.displayContentsUnderSpoilers = (value, location)
		if let item = self.item {
			item.controllerInteraction.requestMessageUpdate(item.message.id, false)
		}
	}
	
	public func beginTextSelection(range: NSRange?, displayMenu: Bool = true) {
		guard let textSelectionNode = self.textSelectionNode else {
			return
		}
		guard let string = self.translatedTextNode.textNode.cachedLayout?.attributedString else {
			return
		}
		let nsString = string.string as NSString
		let range = range ?? NSRange(location: 0, length: nsString.length)
		textSelectionNode.setSelection(range: range, displayMenu: displayMenu)
	}
	
	public func cancelTextSelection() {
		guard let textSelectionNode = self.textSelectionNode else {
			return
		}
		textSelectionNode.cancelSelection()
	}
	
	private func getSelectionState(range: NSRange?) -> ChatControllerSubject.MessageOptionsInfo.SelectionState {
		var quote: ChatControllerSubject.MessageOptionsInfo.Quote?
		if let item = self.item, let range, let selection = self.getCurrentTextSelection(customRange: range) {
			quote = ChatControllerSubject.MessageOptionsInfo.Quote(messageId: item.message.id, text: selection.text, offset: selection.offset)
		}
		return ChatControllerSubject.MessageOptionsInfo.SelectionState(canQuote: true, quote: quote)
	}
	
	public func getCurrentTextSelection(customRange: NSRange? = nil) -> (text: String, entities: [MessageTextEntity], offset: Int)? {
		guard let textSelectionNode = self.textSelectionNode else {
			return nil
		}
		guard let range = customRange ?? textSelectionNode.getSelection() else {
			return nil
		}
		guard let item = self.item else {
			return nil
		}
		guard let string = self.translatedTextNode.attributedString else {
			return nil
		}
		
		let nsString = string.string as NSString
		let substring = nsString.substring(with: range)
		let offset = range.location
		
		var entities: [MessageTextEntity] = []
		if let textEntitiesAttribute = item.message.textEntitiesAttribute {
			entities = messageTextEntitiesInRange(entities: textEntitiesAttribute.entities, range: range, onlyQuoteable: true)
		}
		
		return (substring, entities, offset)
	}
	
	
}
