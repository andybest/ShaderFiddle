//
//    Copyright (c) 2014, Andy Best
//
//    Permission to use, copy, modify, and/or distribute this software for any
//    purpose with or without fee is hereby granted, provided that the above
//    copyright notice and this permission notice appear in all copies.
//
//    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//    WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//    MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
//    ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//    WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//    ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
//    OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
//

#import "ABDisplayWindowController.h"

@interface ABDisplayWindowController ()

@end

@implementation ABDisplayWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    _openGLView.delegate = self;

    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)runShader:(NSString *)shaderSource
{
    [_openGLView runShader:shaderSource];
}

- (void)dispatchErrors:(NSArray *)errors
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:kABShaderHasErrorsEvent object:self userInfo:@{ @"errors" : errors }];
}

@end
