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

public final class PageHolderNode: ASDisplayNode {
	
	private let feature: AiFeature
	private let textNode: ASTextNode
	private let context: AccountContext
	private var presentationData: PresentationData
	
	public init(context: AccountContext,feature: AiFeature ) {
		self.context = context
		self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.feature = feature
		self.textNode = ASTextNode()
		super.init()
		self.automaticallyManagesSubnodes = true
		self.textNode.attributedText = NSAttributedString(
			string: feature.title(strings: self.presentationData.strings),
			font: Font.bold(20),
			textColor: self.presentationData.theme.custom.primaryTextColor
		)
		self.addSubnode(self.textNode)
	}
	
	override public func layout() {
		super.layout()
		if self.bounds.width > 0.0 {
			let bounds = self.bounds
			let textSize = self.textNode.measure(CGSize(
				width: bounds.width,
				height: .greatestFiniteMagnitude
			))
			self.textNode.frame = CGRect(
				x: floor((bounds.width - textSize.width) / 2),
				y: floor((bounds.height - textSize.height) / 2),
				width: textSize.width,
				height: textSize.height
			)
		}
		
	}
}



public final class AiNavBarTitleNode : ASDisplayNode{
	
	private let context: AccountContext
	private var presentationData: PresentationData
	private let iconNode: ASImageNode
	private let titleNode: ASTextNode
	
	public init(context: AccountContext){
		self.context = context
		self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.iconNode = ASImageNode()
		self.titleNode = ASTextNode()
		super.init()
		let theme = self.presentationData.theme
		self.iconNode.image = UIImage(named: "Ton/IconAi")
		self.titleNode.attributedText = NSAttributedString(
			string: "AI Tony",
			font: Font.bold(20),
			textColor: theme.custom.navBarTitleColor
		)
		self.addSubnode(self.iconNode)
		self.addSubnode(self.titleNode)
	}
	
	public func containerLayoutUpdated(
		_ layout: ContainerViewLayout,
		navigationBarHeight: CGFloat,
		actualNavigationBarHeight: CGFloat,
		transition: ContainedViewLayoutTransition
	){
		let iconSize = 24.0
		let viewHeight = self.bounds.height
		let iconMargin = 8.0
		let titleTextSize = self.titleNode.measure(CGSize(
			width: self.bounds.width,
			height: .greatestFiniteMagnitude
		))
		let centerWidth = iconSize + iconMargin + titleTextSize.width
		let centerX = floor((self.bounds.width - centerWidth) / 2)
		self.iconNode.frame = CGRect(
			x: centerX,
			y: floor((viewHeight - iconSize) / 2),
			width: iconSize,
			height: iconSize
		)
		self.titleNode.frame = CGRect(
			x: centerX + iconSize + iconMargin,
			y: floor((viewHeight - titleTextSize.height) / 2),
			width: titleTextSize.width,
			height: titleTextSize.height
		)
	}
}

public class AiMenuButton : ASDisplayNode {
	
	private let context: AccountContext
	private var presentationData: PresentationData
	private let feature: AiFeature
	private var selected: Bool = false
	

	private let iconContainer: ASDisplayNode
	private let iconNode: ASImageNode
	
	private let activeIconContainer: ASDisplayNode
	private let activeIconNode: ASImageNode
	
	private let titleNode: ASTextNode
	private var onTap : ((AiFeature) -> Void)?
	
	public init(
		context: AccountContext,
		feature: AiFeature,
		selected: Bool = false
	){
		self.context = context
		self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.feature = feature
		self.selected = selected
		self.activeIconContainer = ASDisplayNode()
		self.activeIconNode = ASImageNode()
		self.iconContainer = ASDisplayNode()
		self.iconNode = ASImageNode()
		self.titleNode = ASTextNode()
		super.init()
		
		let theme = self.presentationData.theme
		let image = UIImage(named: self.feature.iconName)
	
		
		//
		self.iconContainer.cornerRadius = 8
		self.iconContainer.clipsToBounds = true
		self.iconContainer.backgroundColor = theme.custom.unselectButton2
		
		self.addSubnode(self.iconContainer)
		
		//
		self.iconNode.contentMode = .scaleAspectFit
		self.iconNode.clipsToBounds = true
		self.iconNode.image = generateTintedImage(
			image: image,
			color: theme.custom.accentColor
		)
		self.iconContainer.addSubnode(self.iconNode)
		
		//
		self.activeIconContainer.cornerRadius = 8
		self.activeIconContainer.clipsToBounds = true
		self.activeIconContainer.backgroundColor = theme.custom.accentColor
		self.addSubnode(self.activeIconContainer)
		
		//
		self.activeIconNode.contentMode = .scaleAspectFit
		self.activeIconNode.clipsToBounds = true
		self.activeIconNode.image = generateTintedImage(
			image: image,
			color: .black
		)
		self.activeIconContainer.addSubnode(self.activeIconNode)
		
		//
		self.titleNode.attributedText =  NSAttributedString(
			string: feature.title(strings: self.presentationData.strings),
			font: Font.regular(10),
			textColor: theme.custom.primaryTextColor
		)
		self.addSubnode(self.titleNode)
		
		//
	
		
		if self.selected {
			self.activeIconContainer.alpha = 1.0
			self.iconContainer.alpha = 0.0
		} else {
			self.activeIconContainer.alpha = 0.0
			self.iconContainer.alpha = 1.0
		}
		

	}

	override public func layout() {
		super.layout()
		let viewWidth = self.bounds.width
		let viewHeight = self.bounds.height
		let iconBackgroundWidth = 40.0
		let iconWidth = iconBackgroundWidth * 0.7
		let iconPadding = (iconBackgroundWidth - iconWidth) / 2
		let iconAndTitleMargin = 4.0
		let titleTextSize = self.titleNode.measure(CGSize(
			width: viewWidth,
			height: .greatestFiniteMagnitude
		))
		let contentHeight = iconBackgroundWidth + iconAndTitleMargin + titleTextSize.height
		
		let iconBackgroundX =  floor((viewWidth - iconBackgroundWidth) / 2);
		let contentY = floor((viewHeight - contentHeight) / 2)
		let iconContainerFrame = CGRect(
			x: iconBackgroundX,
			y: contentY,
			width: iconBackgroundWidth,
			height: iconBackgroundWidth
		)
		self.activeIconContainer.frame = iconContainerFrame
		self.iconContainer.frame = iconContainerFrame
		
		
		let iconFrame = CGRect(
			x: iconPadding,
			y: iconPadding,
			width: iconWidth,
			height: iconWidth
		)
		self.activeIconNode.frame = iconFrame
		self.iconNode.frame = iconFrame
		
		self.titleNode.frame = CGRect(
			x: floor((viewWidth - titleTextSize.width) / 2),
			y: contentY + iconBackgroundWidth + iconAndTitleMargin,
			width: titleTextSize.width,
			height: titleTextSize.height
		)
	}
	
	public func updateSelect(_ selected : Bool){
		if self.selected != selected {
			self.selected = selected
			if selected {
				self.setStateSelected()
			} else {
				self.setStateUnselect()
			}
		}
	}
	

	// Action tap
	public func setActionTap(onTap : ((AiFeature) -> Void)?){
		self.onTap = onTap
		self.view.addGestureRecognizer(UITapGestureRecognizer(
			target: self,
			action: #selector(self.onButtonPress)
		))
	}
	
	@objc private func onButtonPress() {
		self.onTap?(self.feature)
	}
	
	// Action hightlight
	public func setActionHightlighTap(onTap : ((AiFeature) -> Void)?){
		self.onTap = onTap
		self.view.addGestureRecognizer(UITapGestureRecognizer(
			target: self,
			action: #selector(self.onButtonHightlighPress)
		))
	}
	
	
	@objc private func onButtonHightlighPress() {
		self.setStateSelected()
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.21) {
			self.setStateUnselect()
			self.onButtonPress()
		}
	}
	
	private func setStateSelected() {
		let transition: ContainedViewLayoutTransition = .animated(
			duration: 0.2,
			curve: .linear
		)
		transition.updateAlpha(node: self.activeIconContainer, alpha:  1.0)
		transition.updateAlpha(node: self.iconContainer, alpha:  0.0)

	}
	
	private func setStateUnselect() {
		let transition: ContainedViewLayoutTransition = .animated(
			duration: 0.2,
			curve: .linear
		)
		transition.updateAlpha(node: self.activeIconContainer, alpha:  0.0)
		transition.updateAlpha(node: self.iconContainer, alpha:  1.0)
	}
	
}


public class AiMenuTabBar : ASDisplayNode{
	
	public let features: [AiFeature] = [
		AiFeature.summarize,
		AiFeature.translation,
		AiFeature.grammar,
		AiFeature.formal,
		AiFeature.friend
	]
	
	
	private let context: AccountContext
	private var presentationData: PresentationData
	private var currrentFeature: AiFeature?
	private var tabNodes: [AiMenuButton] = []
	private let tabScrollNode: ASScrollNode
	private let tabWidth : CGFloat
	public var onTabChanged : ((AiFeature, Int)->Void)?

	public init(context: AccountContext,tabWidth : CGFloat){
		self.context = context
		self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
		self.tabWidth = tabWidth
		self.tabScrollNode = ASScrollNode()
		
		super.init()
		self.tabScrollNode.view.showsHorizontalScrollIndicator = false
		self.tabScrollNode.view.alwaysBounceHorizontal = true
		self.tabScrollNode.view.alwaysBounceVertical = false
		self.tabScrollNode.view.bounces = true
		self.addSubnode(self.tabScrollNode)
		for feature in self.features {
			let tab = AiMenuButton(context: self.context, feature: feature)
			tab.setActionTap(onTap: { feature in
				self.onTabSelected(feature)
			})
			
			
			self.tabNodes.append(tab)
			self.tabScrollNode.addSubnode(tab)
		}
		
		
	}
	
	override public func layout() {
		super.layout()
		if self.bounds.height > 0.0 {
			let bounds = self.bounds
			
			
			self.tabScrollNode.frame = CGRect(
				x : 0,
				y: 0,
				width: CGFloat(self.tabNodes.count) * self.tabWidth + self.tabWidth,
				height: bounds.height
			)
			
			for (index, tab) in self.tabNodes.enumerated() {
				tab.frame = CGRect(
					x: CGFloat(index) * tabWidth,
					y: 0,
					width: self.tabWidth,
					height: bounds.height
				)
				
			}
		}
	}
	
	public func select(_ feature: AiFeature?) {
		if let index = self.features.firstIndex(where: { $0.id == feature?.id }) {
			self.selectByIndex(index)
		} else{
			self.selectByIndex(-1)
		}
	}
	
	public func selectByIndex(_ index: Int) {
		var selectFeature : AiFeature?
		if index >= 0 && index < self.features.count {
			selectFeature = self.features[index]
		}
		if self.currrentFeature?.id == selectFeature?.id {
			return
		}
		if let f = self.currrentFeature  {
			if let preIndex = self.features.firstIndex(where: { $0.id == f.id }) {
				self.tabNodes[preIndex].updateSelect(false)
			}
		}
		if selectFeature != nil  {
			self.tabNodes[index].updateSelect(true)
		}
		self.currrentFeature = selectFeature
	}
	
	private func onTabSelected(_ feature: AiFeature) {
		if let index = self.features.firstIndex(where: { $0.id == feature.id }) {
			self.selectByIndex(index)
			self.onTabChanged?(feature,index)
		}
	}
}

