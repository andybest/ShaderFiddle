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

#import <Cocoa/Cocoa.h>
#import "ABShader.h"

typedef struct {
    GLfloat x, y;
} Vector2;

typedef struct {
    GLfloat x, y, z, w;
} Vector4;

typedef struct {
    GLfloat r, g, b, a;
} Colour;

@protocol ABDisplayViewDelegate <NSObject>
@required
- (void)dispatchErrors:(NSArray *)errors;
@end

@interface ABDisplayView : NSOpenGLView <ABShaderDelegate> {
    CVDisplayLinkRef displayLink;

    double deltaTime;
    float viewWidth;
    float viewHeight;

    GLuint shaderProgram;
    BOOL fftTextureCreated;
    GLuint fftTextureId;

    NSTimeInterval lastFrameTime;
}

@property (nonatomic, strong) NSString *fragShader;
@property (nonatomic, strong) ABShader *shader;
@property (nonatomic, strong) NSDate *startDate;
@property (weak) id<ABDisplayViewDelegate> delegate;
@property (nonatomic, strong) NSTextField *fpsView;

@property (nonatomic, strong) NSArray *fftData;

- (CVReturn)getFrameForTime:(const CVTimeStamp *)outputTime;
- (void)runShader:(NSString *)shaderSource;

@end
