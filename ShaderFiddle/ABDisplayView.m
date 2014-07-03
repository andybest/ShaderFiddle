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

#import "ABDisplayView.h"
#import "ABShader.h"
#import "ABEventList.h"

#import <OpenGL/glu.h>

typedef struct
    {
    Vector4 position;
    Vector2 uv;
} Vertex;

@implementation ABDisplayView {
    GLuint vertexArrayObject;
    GLuint vertexBuffer;
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        [self prepareOpenGL];
    }
    return self;
}

- (void)awakeFromNib
{
    self.startDate = [NSDate date];

    self.fpsView = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 50)];
    _fpsView.textColor = [NSColor redColor];
    [self.superview addSubview:_fpsView];

    fftTextureCreated = NO;

    NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
        NSOpenGLPFAColorSize, 24,
        NSOpenGLPFAAlphaSize, 8,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFANoRecovery,
        0};

    NSOpenGLPixelFormat *pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    [self setPixelFormat:pf];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(fftUpdated:)
                   name:kABFFTUpdatedEvent
                 object:nil];
}

- (void)dealloc
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self
                      name:kABFFTUpdatedEvent
                    object:nil];

    CVDisplayLinkStop(displayLink);
    CVDisplayLinkRelease(displayLink);
}

- (void)reshape
{
    NSSize size = [self frame].size;
    BOOL setCtx = [NSOpenGLContext currentContext] != self.openGLContext;

    [self.openGLContext update];

    if (setCtx)
        [self.openGLContext makeCurrentContext];

    glViewport(0, 0, (GLint)size.width, (GLint)size.height);

    if (setCtx)
        [NSOpenGLContext clearCurrentContext];
}

- (void)prepareOpenGL
{
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval];

    // Create a display link capable of being used with all active displays
    CVDisplayLinkCreateWithActiveCGDisplays(&displayLink);

    // Set the renderer output callback function
    CVDisplayLinkSetOutputCallback(displayLink, &MyDisplayLinkCallback, (__bridge void *)self);

    // Set the display link for the current renderer
    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(displayLink, cglContext, cglPixelFormat);

    // Activate the display link
    CVDisplayLinkStart(displayLink);
}

- (void)loadBufferData
{
    Vertex vertexData[4] = {
        {.position = {.x = -1.0, .y = -1.0, .z = 0.0, .w = 1.0}, .uv = {.x = 0.0, .y = 0.0}},
        {.position = {.x = -1.0, .y = 1.0, .z = 0.0, .w = 1.0}, .uv = {.x = 0.0, .y = 1.0}},
        {.position = {.x = 1.0, .y = 1.0, .z = 0.0, .w = 1.0}, .uv = {.x = 1.0, .y = 1.0}},
        {.position = {.x = 1.0, .y = -1.0, .z = 0.0, .w = 1.0}, .uv = {.x = 1.0, .y = 0.0}}};

    glGenVertexArrays(1, &vertexArrayObject);
    glBindVertexArray(vertexArrayObject);

    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, 4 * sizeof(Vertex), vertexData, GL_STATIC_DRAW);

    GLuint positionAttribute = (GLuint)[_shader.attributes[@"position"] unsignedIntegerValue];

    glEnableVertexAttribArray((GLuint)positionAttribute);
    glVertexAttribPointer((GLuint)positionAttribute, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex), (const GLvoid *)offsetof(Vertex, position));
}

- (void)updateUniforms
{
    /* Time */
    GLuint timeUnif = (GLuint)[_shader.uniforms[@"iGlobalTime"] unsignedIntegerValue];
    NSTimeInterval elapsedTime = [[NSDate date] timeIntervalSinceDate:_startDate];
    glUniform1f(timeUnif, (float)elapsedTime);

    /* Date */
    NSDate *date = [NSDate date];
    NSUInteger componentFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
    NSDateComponents *components = [[NSCalendar currentCalendar] components:componentFlags fromDate:date];
    NSInteger timeSeconds = [components hour] * 60 * 60 + [components minute] * 60 + [components second];
    Vector4 iDate = {.x = [components year], .y = [components month], .z = [components day], .w = timeSeconds};
    GLuint dateUnif = (GLuint)[_shader.uniforms[@"iDate"] unsignedIntegerValue];
    glUniform4fv(dateUnif, 1, (const GLfloat *)&iDate);

    /* Resolution */
    Vector2 r = {.x = (float)self.frame.size.width, .y = (float)self.frame.size.height};
    GLuint resolutionUnif = (GLuint)[_shader.uniforms[@"iResolution"] unsignedIntegerValue];
    glUniform2fv(resolutionUnif, 1, (const GLfloat *)&r);

    /* FFT */
    [self generateFFTTexture];
}

- (void)drawFrameForTime:(CVTimeStamp)time
{
    NSDate *date = [NSDate date];
    NSTimeInterval thisFrameTime = [date timeIntervalSince1970];

    NSTimeInterval timePassed = thisFrameTime - lastFrameTime;
    float fps = 1.0 / timePassed;
    [_fpsView setStringValue:[NSString stringWithFormat:@"FPS: %f", fps]];

    NSOpenGLContext *currentContext = [self openGLContext];
    [currentContext makeCurrentContext];

    // must lock GL context because display link is threaded
    CGLLockContext((CGLContextObj)[currentContext CGLContextObj]);

    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);

    [_shader use];

    [self updateUniforms];

    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);

    [currentContext flushBuffer];

    CGLUnlockContext((CGLContextObj)[currentContext CGLContextObj]);
}

- (void)runShader:(NSString *)shaderSource
{
    [self.openGLContext makeCurrentContext];
    @try {
        NSArray *attrs = @[ @"position" ];
        NSArray *unifs = @[ @"iResolution", @"iGlobalTime", @"iMouse", @"iDate", @"iFFT", @"iOnset", @"iGroupedFFT" ];

        self.shader = [[ABShader alloc] init];
        _shader.delegate = self;
        [_shader loadShaderWithFragmentSource:shaderSource attributes:attrs uniforms:unifs];

        [self loadBufferData];
    }
    @catch (NSException *e)
    {
        NSLog(@"%@", [e description]);
    }
}

- (void)dispatchErrors:(NSArray *)errors
{
    if (_delegate) {
        [_delegate dispatchErrors:errors];
    }
}

- (void)fftUpdated:(NSNotification *)notification
{
    NSArray *summed = notification.userInfo[@"summed"];

    @synchronized(self.fftData)
    {
        self.fftData = notification.userInfo[@"amplitudes"];
    }

    float grouped[16];
    for (int i = 0; i < 16; i++) {
        grouped[i] = [summed[i] floatValue];
    }
}

- (void)generateFFTTexture
{
    @synchronized(self.fftData)
    {
        if (!_fftData)
            return;

        if (!fftTextureCreated) {
            // Create one OpenGL texture
            glGenTextures(1, &fftTextureId);
            NSLog(@"Texture id: %i", fftTextureId);
            fftTextureCreated = YES;
        }

        float texData[256][4];
        for (int x = 0; x < 256; x++) {
            for (int y = 0; y < 1; y++) {
                texData[x + (y * 256)][0] = [_fftData[x] floatValue];
                texData[x + (y * 256)][1] = ((char)(x ^ y)) / 255.0;
                texData[x + (y * 256)][2] = ((char)(x ^ y)) / 255.0;
                texData[x + (y * 256)][3] = 255;
            }
        }

        glActiveTexture(GL_TEXTURE0);
        // "Bind" the newly created texture : all future texture functions will modify this texture
        glBindTexture(GL_TEXTURE_2D, fftTextureId);

        // Give the image to OpenGL
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 256, 1, 0, GL_RGBA, GL_FLOAT, texData);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glUniform1i((GLint)[_shader.uniforms[@"iFFT"] integerValue], 0);

        CGLUnlockContext(self.openGLContext.CGLContextObj);

        self.fftData = nil;
    }
}

#pragma mark -
#pragma mark Display Link

static CVReturn MyDisplayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *now,
                                      const CVTimeStamp *outputTime, CVOptionFlags flagsIn,
                                      CVOptionFlags *flagsOut, void *displayLinkContext)
{
    // go back to Obj-C for easy access to instance variables
    CVReturn result = [(__bridge ABDisplayView *)displayLinkContext getFrameForTime:outputTime];
    return result;
}

- (CVReturn)getFrameForTime:(const CVTimeStamp *)outputTime
{
    // deltaTime is unused in this bare bones demo, but here's how to calculate it using display link info
    deltaTime = 1.0 / (outputTime->rateScalar * (double)outputTime->videoTimeScale / (double)outputTime->videoRefreshPeriod);

    [self drawFrameForTime:*outputTime];

    return kCVReturnSuccess;
}

@end
