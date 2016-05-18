//
//  ImojiSDKUI
//
//  Created by Jeff Wang
//  Copyright (C) 2015 Imoji
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import <Masonry/Masonry.h>
#import <YYImage/YYAnimatedImageView.h>
#import "IMKeyboardCollectionViewCell.h"

@implementation IMKeyboardCollectionViewCell {

}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.placeholderView.contentMode = UIViewContentModeScaleAspectFit;

        [self.placeholderView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.width.and.height.equalTo(@62.0f);
        }];

        [self.imojiView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.center.equalTo(self);
            make.width.and.height.equalTo(@74.0f);
        }];
    }

    return self;
}

//- (void)loadImojiImage:(UIImage *)imojiImage animated:(BOOL)animated {
//    if (!self.imojiView) {
//        self.imojiView = [YYAnimatedImageView new];
//
//        [self addSubview:self.imojiView];
//        [self.imojiView mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.center.equalTo(self);
//            make.width.and.height.equalTo(self).multipliedBy(.85f);
//        }];
//    }
//
//    [super loadImojiImage:imojiImage animated:animated];
//}

- (void)setupPlaceholderImageWithPosition:(NSUInteger)position {
    [super setupPlaceholderImageWithPosition:position];
    self.placeholderView.contentMode = UIViewContentModeScaleAspectFit;
}

@end
