//
//  STTweetTextView.h
//  STTweetTextView
//
//  Created by Giuseppe Nucifora on 10/10/14.
//  Copyright (c) 2015 Giuseppe Nucifora. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, STTweetHotWord) {
    STTweetHandle = 0,
    STTweetHashtag,
    STTweetLink,
    STTweetText
};


@interface STTweetTextView : UILabel

@property (nonatomic, strong) NSArray *validProtocols;
@property (nonatomic, assign) BOOL leftToRight;
@property (nonatomic, assign) BOOL textSelectable;
@property (nonatomic, strong) UIColor *selectionColor;
@property (nonatomic, copy) void (^detectionBlock)(STTweetHotWord hotWord, NSString *string, NSString *protocol, NSRange range);
@property (nonatomic, copy) void (^textViewDidChangeBlock)(STTweetTextView *textView, UITextView *_textView, BOOL isDeleting);
@property (nonatomic, copy) void (^textViewDidBegindEditingBlock)(STTweetTextView *textView, UITextView *_textView);
@property (nonatomic) NSInteger maxHashtags;
@property (nonatomic) BOOL blockInsert;

- (void)setAttributes:(NSDictionary *)attributes;
- (void)setAttributes:(NSDictionary *)attributes hotWord:(STTweetHotWord)hotWord;

- (NSDictionary *)attributes;
- (NSDictionary *)attributesForHotWord:(STTweetHotWord)hotWord;

- (CGSize)suggestedFrameSizeToFitEntireStringConstrainedToWidth:(CGFloat)width;

- (NSArray*) hotWordsForType:(STTweetHotWord) hotWord;


@end
