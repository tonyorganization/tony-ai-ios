import Foundation
import UIKit
import AsyncDisplayKit

open class ASImageNode: ASDisplayNode {
    public var image: UIImage? {
        didSet {
            if self.isNodeLoaded {
                if let image = self.image {
                    let capInsets = image.capInsets
                    if capInsets.left.isZero && capInsets.top.isZero && capInsets.right.isZero && capInsets.bottom.isZero {
                        self.contentsScale = image.scale
                        self.contents = image.cgImage
                    } else {
                        ASDisplayNodeSetResizableContents(self.layer, image)
                    }
                } else {
                    self.contents = nil
                }
                if self.image?.size != oldValue?.size {
                    self.invalidateCalculatedLayout()
                }
            }
        }
    }
    
    public var customTintColor: UIColor? {
        didSet {
            self.layer.layerTintColor = self.customTintColor?.cgColor
        }
    }

    public var displayWithoutProcessing: Bool = true

    override public init() {
        super.init()
    }
    
    override open func didLoad() {
        super.didLoad()
        
        if let image = self.image {
            let capInsets = image.capInsets
            if capInsets.left.isZero && capInsets.top.isZero {
                self.contentsScale = image.scale
                self.contents = image.cgImage
            } else {
                ASDisplayNodeSetResizableContents(self.layer, image)
            }
        }
        self.layer.layerTintColor = self.customTintColor?.cgColor
    }
    
    override public func calculateSizeThatFits(_ contrainedSize: CGSize) -> CGSize {
        return self.image?.size ?? CGSize()
    }
}

//public final class ASBackgroundImageNode : ASImageNode {
public final class ASBackgroundImageNode : ASDisplayNode {
	override public init() {
		super.init()

	}
	
	override public func didLoad() {
//		if self.image == nil {
//			self.image = UIImage(named: "Ton/Background1")
//		}
	
		super.didLoad()
	}
	
	public func fill(parent: ASDisplayNode) {
		if self.supernode == nil{
			parent.insertSubnode(self, at: 0)
		}
		self.frame = parent.bounds
	}
	
	public func fillParent(color: UIColor) {
		self.backgroundColor = color
		if let parent = self.supernode {
			self.frame = parent.bounds
		}

	}
	
}
