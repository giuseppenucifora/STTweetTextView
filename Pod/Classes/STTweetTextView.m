//
//  STTweetTextView.m
//  STTweetTextView
//
//  Created by Giuseppe Nucifora on 10/10/14.
//  Copyright (c) 2015 Giuseppe Nucifora. All rights reserved.
//

#import "STTweetTextView.h"

#define STURLRegex @"(?i)\\b((?:[a-z][\\w-]+:(?:/{1,3}|[a-z0-9%])|www\\d{0,3}[.]|[a-z0-9.\\-]+[.][a-z]{2,4}/)(?:[^\\s()<>]+|\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\))+(?:\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\)|[^\\s`!()\\[\\]{};:'\".,<>?«»“”‘’]))"

@interface STTweetTextView () <UITextViewDelegate>

@property (nonatomic, strong) NSRegularExpression *urlRegex;

@property (strong) NSTextStorage *textStorage;
@property (strong) NSLayoutManager *layoutManager;
@property (strong) NSTextContainer *textContainer;

@property (nonatomic, strong) NSString *cleanText;
@property (nonatomic, copy) NSAttributedString *cleanAttributedText;

@property (strong) NSMutableArray *rangesOfHotWords;

@property (nonatomic, strong) NSDictionary *attributesText;
@property (nonatomic, strong) NSDictionary *attributesHandle;
@property (nonatomic, strong) NSDictionary *attributesHashtag;
@property (nonatomic, strong) NSDictionary *attributesLink;

@property (strong) UITextView *textView;
@property (nonatomic) BOOL isDeleting;

@end

@implementation STTweetTextView {
    BOOL _isTouchesMoved;
    NSRange _selectableRange;
    NSInteger _firstCharIndex;
    CGPoint _firstTouchLocation;
}

#pragma mark - Lifecycle

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self setupLabel];
        [self setupTextView];
        [self setupURLRegularExpression];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    
    self = [super initWithCoder:coder];
    if (self) {
        [self setupLabel];
        [self setupTextView];
        [self setupURLRegularExpression];
    }
    
    return self;
}


- (void)setupTextView {
    
    _textStorage   = [NSTextStorage new];
    _layoutManager = [NSLayoutManager new];
    _textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(self.frame.size.width, CGFLOAT_MAX)];
    
    [_layoutManager addTextContainer:_textContainer];
    [_textStorage addLayoutManager:_layoutManager];
    
    _textView = [[UITextView alloc] initWithFrame:self.bounds textContainer:_textContainer];
    _textView.delegate                          = self;
    _textView.autoresizingMask                  = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _textView.backgroundColor                   = [UIColor clearColor];
    _textView.textContainer.lineFragmentPadding = 0;
    _textView.textContainerInset                = UIEdgeInsetsZero;
    _textView.userInteractionEnabled            = YES;
    UIToolbar* numberToolbar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
    numberToolbar.barStyle = UIBarStyleDefault;
    numberToolbar.items = @[[[UIBarButtonItem alloc]initWithTitle:NSLocalizedString(@"Cancel",@"") style:UIBarButtonItemStylePlain target:self action:@selector(cancel)],
                            [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                            [[UIBarButtonItem alloc]initWithTitle:NSLocalizedString(@"Close",@"") style:UIBarButtonItemStyleDone target:self action:@selector(done)]];
    [numberToolbar sizeToFit];
    _textView.inputAccessoryView = numberToolbar;
    [_textView setScrollEnabled:NO];
    [self addSubview:_textView];
}

- (void)setupURLRegularExpression {
    
    NSError *regexError = nil;
    self.urlRegex = [NSRegularExpression regularExpressionWithPattern:STURLRegex options:0 error:&regexError];
}

-(void) cancel {
    [_textView resignFirstResponder];
    [_textView setText:nil];
}

-(void) done {
    [_textView resignFirstResponder];
}

#pragma mark - Responder

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return (action == @selector(copy:));
}

- (void)copy:(id)sender {
    [[UIPasteboard generalPasteboard] setString:[_cleanText substringWithRange:_selectableRange]];
    
    @try {
        [_textStorage removeAttribute:NSBackgroundColorAttributeName range:_selectableRange];
    } @catch (NSException *exception) {
        NSLog(@"%@", exception);
    }
}

#pragma mark - Setup

- (void)setupLabel {
    
    // Set the basic properties
    [self setBackgroundColor:[UIColor clearColor]];
    [self setClipsToBounds:NO];
    [self setUserInteractionEnabled:YES];
    [self setNumberOfLines:0];
    
    _leftToRight = YES;
    _textSelectable = YES;
    _selectionColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    
    _attributesText = @{NSForegroundColorAttributeName: self.textColor, NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:14.0]};
    _attributesHandle = @{NSForegroundColorAttributeName: [UIColor redColor], NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:14.0]};
    _attributesHashtag = @{NSForegroundColorAttributeName: [[UIColor alloc] initWithWhite:170.0/255.0 alpha:1.0], NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:14.0]};
    _attributesLink = @{NSForegroundColorAttributeName: [[UIColor alloc] initWithRed:129.0/255.0 green:171.0/255.0 blue:193.0/255.0 alpha:1.0], NSFontAttributeName: [UIFont fontWithName:@"HelveticaNeue" size:14.0]};
    
    self.validProtocols = @[@"http", @"https"];
}

#pragma mark - Printing and calculating text

- (void)determineHotWords {
    // Need a text
    if (_cleanText == nil)
        return;
    
    NSMutableString *tmpText = [[NSMutableString alloc] initWithString:_cleanText];
    
    // Support RTL
    if (!_leftToRight) {
        tmpText = [[NSMutableString alloc] init];
        [tmpText appendString:@"\u200F"];
        [tmpText appendString:_cleanText];
    }
    
    // Define a character set for hot characters (@ handle, # hashtag)
    NSString *hotCharacters = @"@#";
    NSCharacterSet *hotCharactersSet = [NSCharacterSet characterSetWithCharactersInString:hotCharacters];
    
    // Define a character set for the complete world (determine the end of the hot word)
    NSMutableCharacterSet *validCharactersSet = [NSMutableCharacterSet alphanumericCharacterSet];
    [validCharactersSet removeCharactersInString:@"!@#$%^&*()-={[]}|;:',<>.?/"];
    [validCharactersSet addCharactersInString:@"_"];
    
    _rangesOfHotWords = [[NSMutableArray alloc] init];
    
    while ([tmpText rangeOfCharacterFromSet:hotCharactersSet].location < tmpText.length) {
        NSRange range = [tmpText rangeOfCharacterFromSet:hotCharactersSet];
        
        STTweetHotWord hotWord;
        
        switch ([tmpText characterAtIndex:range.location]) {
            case '@':
                hotWord = STTweetHandle;
                break;
            case '#':
                hotWord = STTweetHashtag;
                break;
            default:
                hotWord = STTweetText;
                break;
        }
        
        [tmpText replaceCharactersInRange:range withString:@"%"];
        // If the hot character is not preceded by a alphanumeric characater, ie email (sebastien@world.com)
        if (range.location > 0 && [validCharactersSet characterIsMember:[tmpText characterAtIndex:range.location - 1]])
            continue;
        
        // Determine the length of the hot word
        int length = (int)range.length;
        
        while (range.location + length < tmpText.length) {
            BOOL charIsMember = [validCharactersSet characterIsMember:[tmpText characterAtIndex:range.location + length]];
            
            if (charIsMember)
                length++;
            else
                break;
        }
        
        // Register the hot word and its range
        if (length > 1)
            [_rangesOfHotWords addObject:@{@"hotWord": @(hotWord), @"range": [NSValue valueWithRange:NSMakeRange(range.location, length)]}];
    }
    
    [self determineLinks];
    [self updateText];
}

- (void)determineLinks {
    NSMutableString *tmpText = [[NSMutableString alloc] initWithString:_cleanText];
    
    [self.urlRegex enumerateMatchesInString:tmpText options:0 range:NSMakeRange(0, tmpText.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        NSString *protocol     = @"http";
        NSString *link         = [tmpText substringWithRange:result.range];
        NSRange  protocolRange = [link rangeOfString:@":"];
        if (protocolRange.location != NSNotFound) {
            protocol = [link substringToIndex:protocolRange.location];
        }
        
        if ([_validProtocols containsObject:protocol.lowercaseString]) {
            [_rangesOfHotWords addObject:@{ @"hotWord"  : @(STTweetLink),
                                            @"protocol" : protocol,
                                            @"range"    : [NSValue valueWithRange:result.range]
                                            }];
        }
    }];
}

- (void)updateText {
    [_textStorage beginEditing];
    
    NSAttributedString *attributedString = _cleanAttributedText ?: [[NSMutableAttributedString alloc] initWithString:_cleanText];
    [_textStorage setAttributedString:attributedString];
    [_textStorage setAttributes:_attributesText range:NSMakeRange(0, attributedString.length)];
    
    for (NSDictionary *dictionary in _rangesOfHotWords)  {
        NSRange range = [dictionary[@"range"] rangeValue];
        STTweetHotWord hotWord = (STTweetHotWord)[dictionary[@"hotWord"] intValue];
        [_textStorage setAttributes:[self attributesForHotWord:hotWord] range:range];
    }
    
    [_textStorage endEditing];
}

#pragma mark - Public methods

- (CGSize)suggestedFrameSizeToFitEntireStringConstrainedToWidth:(CGFloat)width {
    if (_cleanText == nil)
        return CGSizeZero;
    
    return [_textView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
}

- (CGSize) intrinsicContentSize {
    CGSize size = [self suggestedFrameSizeToFitEntireStringConstrainedToWidth:CGRectGetWidth(self.frame)];
    return CGSizeMake(size.width, size.height + 1);
}

#pragma mark - Private methods

- (NSArray *)hotWordsList {
    return _rangesOfHotWords;
}

#pragma mark - Setters

- (void)setBounds:(CGRect)bounds {
    [super setBounds:bounds];
    [self invalidateIntrinsicContentSize];
}

- (void)setText:(NSString *)text {
    [super setText:@""];
    _cleanText = text;
    _selectableRange = NSMakeRange(NSNotFound, 0);
    [self determineHotWords];
    [self invalidateIntrinsicContentSize];
}

- (void)setValidProtocols:(NSArray *)validProtocols {
    _validProtocols = validProtocols;
    [self determineHotWords];
}

- (void)setAttributes:(NSDictionary *)attributes {
    if (!attributes[NSFontAttributeName]) {
        NSMutableDictionary *copy = [attributes mutableCopy];
        copy[NSFontAttributeName] = self.font;
        attributes = [NSDictionary dictionaryWithDictionary:copy];
    }
    
    if (!attributes[NSForegroundColorAttributeName]) {
        NSMutableDictionary *copy = [attributes mutableCopy];
        copy[NSForegroundColorAttributeName] = self.textColor;
        attributes = [NSDictionary dictionaryWithDictionary:copy];
    }
    
    _attributesText = attributes;
    
    [self determineHotWords];
}

- (void)setAttributes:(NSDictionary *)attributes hotWord:(STTweetHotWord)hotWord {
    if (!attributes[NSFontAttributeName]) {
        NSMutableDictionary *copy = [attributes mutableCopy];
        copy[NSFontAttributeName] = self.font;
        attributes = [NSDictionary dictionaryWithDictionary:copy];
    }
    
    if (!attributes[NSForegroundColorAttributeName]) {
        NSMutableDictionary *copy = [attributes mutableCopy];
        copy[NSForegroundColorAttributeName] = self.textColor;
        attributes = [NSDictionary dictionaryWithDictionary:copy];
    }
    
    switch (hotWord)  {
        case STTweetHandle:
            _attributesHandle = attributes;
            break;
        case STTweetHashtag:
            _attributesHashtag = attributes;
            break;
        case STTweetLink:
            _attributesLink = attributes;
            break;
        case STTweetText:
            _attributesText = attributes;
            break;
        default:
            break;
    }
    
    [self determineHotWords];
}

- (void)setLeftToRight:(BOOL)leftToRight {
    _leftToRight = leftToRight;
    
    [self determineHotWords];
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
    [super setTextAlignment:textAlignment];
    _textView.textAlignment = textAlignment;
}

- (void)setDetectionBlock:(void (^)(STTweetHotWord, NSString *, NSString *, NSRange))detectionBlock {
    if (detectionBlock) {
        _detectionBlock = [detectionBlock copy];
        self.userInteractionEnabled = YES;
    } else {
        _detectionBlock = nil;
        self.userInteractionEnabled = NO;
    }
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    _cleanAttributedText = [attributedText copy];
    self.text = _cleanAttributedText.string;
}

#pragma mark - Getters

- (NSString *)text {
    return _cleanText;
}

- (NSDictionary *)attributes {
    return _attributesText;
}

- (NSDictionary *)attributesForHotWord:(STTweetHotWord)hotWord {
    switch (hotWord) {
        case STTweetHandle:
            return _attributesHandle;
            
        case STTweetHashtag:
            return _attributesHashtag;
            
        case STTweetLink:
            return _attributesLink;
        case STTweetText:
            return _attributesText;
        default:
            break;
    }
    return nil;
}

- (BOOL)isLeftToRight {
    return _leftToRight;
}

- (NSArray*) hotWordsForType:(STTweetHotWord) hotWord {
    
    NSMutableArray *responseArray = [[NSMutableArray alloc] init];
    
    for (NSDictionary* objectDict in _rangesOfHotWords) {
        
        if ([[objectDict objectForKey:@"hotWord"] integerValue] == hotWord) {
            NSRange range = [[objectDict objectForKey:@"range"] rangeValue];
            
            NSString *symbol;
            switch (hotWord) {
                case STTweetHashtag:
                    symbol = @"#";
                    break;
                case STTweetHandle:
                default:
                    symbol = @"@";
                    break;
            }
            
            [responseArray addObject:[[_textView.text substringWithRange:range] stringByReplacingOccurrencesOfString:symbol withString:@""]];
        }
    }
    return responseArray;
}

#pragma mark - Retrieve word after touch event

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (![_textView isFirstResponder]) {
        [_textView becomeFirstResponder];
    }
    
}

- (NSInteger)charIndexAtLocation:(CGPoint)touchLocation {
    NSUInteger glyphIndex = [_layoutManager glyphIndexForPoint:touchLocation inTextContainer:_textView.textContainer];
    CGRect boundingRect = [_layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1) inTextContainer:_textView.textContainer];
    
    if (CGRectContainsPoint(boundingRect, touchLocation))
        return [_layoutManager characterIndexForGlyphAtIndex:glyphIndex];
    else
        return NSNotFound;
}

- (id)getTouchedHotword:(NSSet *)touches {
    NSInteger charIndex = [self charIndexAtLocation:[[touches anyObject] locationInView:_textView]];
    
    if (charIndex != NSNotFound) {
        for (id obj in _rangesOfHotWords) {
            NSRange range = [[obj objectForKey:@"range"] rangeValue];
            
            if (charIndex >= range.location && charIndex < range.location + range.length) {
                return obj;
            }
        }
    }
    
    return nil;
}


- (void)textViewDidChange:(UITextView *)textView {
    if ((_blockInsert && _isDeleting) || !_blockInsert || _isDeleting) {
        [self setText:textView.text];
        if (_textViewDidChangeBlock) {
            _textViewDidChangeBlock(self,_textView,_isDeleting);
        }
    }
    else {
        [self setText:_cleanText];
    }
}

- (void) textViewDidBeginEditing:(UITextView *)textView {
    
    if (self.textViewDidBegindEditingBlock) {
        self.textViewDidBegindEditingBlock(self,_textView);
    }
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    const char * _char = [text cStringUsingEncoding:NSUTF8StringEncoding];
    int isBackSpace = strcmp(_char, "\b");
    
    _isDeleting = NO;
    
    if (isBackSpace == -8) {
        // is backspace
        _isDeleting = YES;
    }
    
    
    
    return YES;
}

@end
