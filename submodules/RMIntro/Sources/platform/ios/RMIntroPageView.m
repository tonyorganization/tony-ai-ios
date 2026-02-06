//
//  RMIntroPageView.m
//  IntroOpenGL
//
//  Created by Ilya Rimchikov on 05.12.13.
//  Copyright (c) 2013 Ilya Rimchikov. All rights reserved.
//

#import "RMIntroPageView.h"

@implementation RMIntroPageView

#define IPAD ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
// TODO: Ton - Intro: Page view
- (id)initWithFrame:(CGRect)frame headline:(NSString*)headline description:(NSString*)description titleColor:(UIColor *)titleColor descriptionColor:(UIColor *)descriptionColor accentColor:(UIColor *)accentColor
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        
        //self.backgroundColor=[UIColor redColor];
        self.opaque=YES;
        _headline=headline;
	
        UILabel *headlineLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, frame.size.width, 64+8)];
        headlineLabel.font = [UIFont boldSystemFontOfSize:35.0]; //[UIFont fontWithName:@"HelveticaNeue-Light" size:IPAD ? 96/2 : 36];
		headlineLabel.text = [NSString stringWithFormat:@"%@", _headline];;
        headlineLabel.textColor = titleColor;
        headlineLabel.textAlignment = NSTextAlignmentCenter;
        headlineLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        _headerLabel = headlineLabel;
      
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.lineSpacing = IPAD ? 4 : 3;
        style.lineBreakMode = NSLineBreakByWordWrapping;
        style.alignment = NSTextAlignmentCenter;
        

        NSMutableArray *boldRanges = [[NSMutableArray alloc] init];
        
        NSMutableString *cleanText = [[NSMutableString alloc] initWithString:description];
        while (true)
        {
            NSRange startRange = [cleanText rangeOfString:@"**"];
            if (startRange.location == NSNotFound)
                break;
            
            [cleanText deleteCharactersInRange:startRange];
            
            NSRange endRange = [cleanText rangeOfString:@"**"];
            if (endRange.location == NSNotFound)
                break;
            
            [cleanText deleteCharactersInRange:endRange];
            
            [boldRanges addObject:[NSValue valueWithRange:NSMakeRange(startRange.location, endRange.location - startRange.location)]];
        }
        
        _description = [[NSMutableAttributedString alloc]initWithString:cleanText];
        NSDictionary *boldAttributes = [
			NSDictionary dictionaryWithObjectsAndKeys: [UIFont boldSystemFontOfSize:IPAD ? 22 : 17.0],
			NSFontAttributeName,
			nil
		];
        for (NSValue *nRange in boldRanges)
        {
            [_description addAttributes:boldAttributes range:[nRange rangeValue]];
			[_description addAttribute:NSForegroundColorAttributeName
								 value: accentColor
								 range:[nRange rangeValue]];
        }
        
		// TODO: Ton - Intro: add color for bold text **..**
        [_description addAttribute:NSParagraphStyleAttributeName
                             value:style
                             range:NSMakeRange(0, _description.length)];
   
        
        UILabel *descriptionLabel = [[UILabel alloc]initWithFrame:CGRectMake(8, 36 + (IPAD ? 22 : 0), frame.size.width - 16, 120+8+5)];
        descriptionLabel.font = [UIFont systemFontOfSize:IPAD ? 22 : 16.0];
		descriptionLabel.textColor = descriptionColor;
        descriptionLabel.attributedText = _description;
        descriptionLabel.numberOfLines=0;
        descriptionLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        [self addSubview:descriptionLabel];
        _descriptionLabel = descriptionLabel;
        
        [self addSubview:headlineLabel];
		//[self addSubview:imageView];
        
    }
    return self;
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
