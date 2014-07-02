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

#import "ABShader.h"
#import "ABEventList.h"

#define kFailedToCompileShaderException @"Failed to compile shader"

@implementation ABShaderError
@end

@implementation ABShader {
    GLuint shaderProgram;

    GLint positionUniform;
    GLint colourAttribute;
    GLint positionAttribute;
}

- (id)init
{
    if ((self = [super init])) {
        self.errors = [NSMutableArray array];
        _isCompiled = NO;
    }
    return self;
}

- (void)dealloc
{
    glDeleteProgram(shaderProgram);
}

- (void)loadShaderWithFragmentSource:(NSString *)fragmentSource
                          attributes:(NSArray *)attrs
                            uniforms:(NSArray *)unifs
{
    GLuint vertexShader;
    GLuint fragmentShader;

    NSString *vertexSource = [NSString
        stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"shader"
                                                                 ofType:@"vsh"]
                        encoding:NSASCIIStringEncoding
                           error:nil];

    if (!vertexSource)
        [NSException raise:kFailedToCompileShaderException
                    format:@"Could not find vertex shader"];

    NSString *combinedFragmentSource = [NSString
        stringWithFormat:@"%@%@", [self generateShaderHeader], fragmentSource];

    vertexShader =
        [self compileShaderOfType:GL_VERTEX_SHADER shaderSource:vertexSource];
    fragmentShader = [self compileShaderOfType:GL_FRAGMENT_SHADER
                                  shaderSource:combinedFragmentSource];

    if (0 != vertexShader && 0 != fragmentShader) {
        shaderProgram = glCreateProgram();

        glAttachShader(shaderProgram, vertexShader);
        glAttachShader(shaderProgram, fragmentShader);

        glBindFragDataLocation(shaderProgram, 0, "fragColor");

        [self linkProgram:shaderProgram];

        // Get attribute locations
        self.attributes = [NSMutableDictionary dictionary];

        for (NSString *attributeName in attrs) {
            GLint attr = glGetAttribLocation(
                shaderProgram,
                [attributeName cStringUsingEncoding:NSASCIIStringEncoding]);
            if (attr < 0) {
                [NSException raise:kFailedToCompileShaderException
                            format:@"Shader did not contain the '%@' attribute.",
                                   attributeName];
            }
            _attributes[attributeName] = @(attr);
        }

        // Get uniform locations
        self.uniforms = [NSMutableDictionary dictionary];

        for (NSString *unifName in unifs) {
            GLint unif = glGetUniformLocation(
                shaderProgram, [unifName cStringUsingEncoding:NSASCIIStringEncoding]);
            _uniforms[unifName] = @(unif);
            if (unif < 0) {
                NSLog(@"unable to find uniform %@", unifName);
            }
        }

        glDeleteShader(vertexShader);
        glDeleteShader(fragmentShader);
    } else {
        [NSException raise:kFailedToCompileShaderException
                    format:@"Shader compilation failed."];
    }
}

- (GLuint)compileShaderOfType:(GLenum)type
                 shaderSource:(NSString *)shaderSource
{
    if ([shaderSource length] == 0) {
        [NSException raise:kFailedToCompileShaderException
                    format:@"Shader code is empty"];
    }

    GLuint shader;
    const GLchar *source =
        (GLchar *)[shaderSource cStringUsingEncoding:NSUTF8StringEncoding];

    shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    GLint logLength;

    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = malloc((size_t)logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        NSString *errors =
            [[NSString alloc] initWithCString:log encoding:NSUTF8StringEncoding];
        [self parseErrors:errors];
        free(log);
    }

    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (0 == status) {
        glDeleteShader(shader);
        [NSException raise:kFailedToCompileShaderException
                    format:@"Shader compilation failed"];
    }

    return shader;
}

- (void)linkProgram:(GLuint)program
{
    glLinkProgram(program);

    GLint logLength;

    glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = malloc((size_t)logLength);
        glGetProgramInfoLog(program, logLength, &logLength, log);
        NSString *errors =
            [[NSString alloc] initWithCString:log encoding:NSUTF8StringEncoding];
        [self parseErrors:errors];
        free(log);
    }

    GLint status;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (0 == status) {
        [NSException raise:kFailedToCompileShaderException
                    format:@"Failed to link shader program"];
    }

    _isCompiled = YES;
}

- (void)parseErrors:(NSString *)errors
{
    NSInteger headerLength = [[[self generateShaderHeader]
        componentsSeparatedByCharactersInSet:[NSCharacterSet
                                                     newlineCharacterSet]] count];

    NSString *cleanedErrors =
        [errors stringByTrimmingCharactersInSet:
                    [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *splitErrors =
        [cleanedErrors componentsSeparatedByCharactersInSet:
                           [NSCharacterSet newlineCharacterSet]];

    for (NSString *e in splitErrors) {
        NSArray *components = [e componentsSeparatedByString:@":"];

        ABShaderErrorType type;
        if ([components[0] isEqualToString:@"ERROR"]) {
            type = kABShaderErrorTypeError;
        } else {
            type = kABShaderErrorTypeWarning;
        }

        NSString *message =
            [components[3] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
        NSInteger lineNum = [components[2] integerValue] - headerLength + 1;

        if ([components count] > 4) {
            message = [message stringByAppendingString:components[4]];
        }

        ABShaderError *error = [[ABShaderError alloc] init];
        error.message = message;
        error.lineNumber = lineNum;
        error.type = type;

        [_errors addObject:error];
    }

    [self dispatchErrors];
}

- (void)dispatchErrors
{
    dispatch_async(dispatch_get_main_queue(), ^{
      if (_delegate) {
        [_delegate dispatchErrors:_errors];
      }
    });
}

- (void)printErrors
{
    for (ABShaderError *error in _errors) {
        NSLog(@"%@ on line %li: %@",
              (error.type == kABShaderErrorTypeError) ? @"Error" : @"Warning",
              (long)error.lineNumber, error.message);
    }
}

- (void)use
{
    if (_isCompiled) {
        glUseProgram(shaderProgram);
    }
}

- (NSString *)generateShaderHeader
{
    NSMutableString *header =
        [NSMutableString stringWithString:@"#version 150\n"];

    // Fragment color
    [header appendString:@"out vec4 fragColor;\n"];

    // Uniforms
    [header appendString:@"uniform float iGlobalTime;\n"];
    [header appendString:@"uniform vec2 iResolution;\n"];
    [header appendString:@"uniform vec4 iDate;\n"];
    [header appendString:@"uniform vec4 iMouse;\n"];
    [header appendString:@"uniform sampler2D iFFT;\n"];

    return header;
}

@end
