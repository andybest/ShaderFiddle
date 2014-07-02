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

#import "ABDocument.h"
#import "ABEventList.h"
#import "ABShader.h"

@implementation ABBackgroundView
- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    [[NSColor lightGrayColor] setFill];
    NSRectFill(dirtyRect);
}
@end

@implementation ABDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"ABDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];

    // Initial config options
    [_aceView setDelegate:self];
    [_aceView setTheme:ACEThemeSolarizedDark];
    [_aceView setMode:ACEModeGLSL];

    self.undoManager = _aceView.undoManager;
    NSLog(@"%@", _aceView.undoManager);

    if (_documentFileWrapper != nil) {
        NSFileWrapper *shaderWrapper =
            [_documentFileWrapper fileWrappers][@"shader.glsl"];

        if (shaderWrapper) {
            NSData *shaderData = [shaderWrapper regularFileContents];
            if (shaderData) {
                NSString *shaderString =
                    [[NSString alloc] initWithData:shaderData
                                          encoding:NSUTF8StringEncoding];
                _aceView.string = shaderString;
            }
        }
    }

    self.displayWindowController = [[ABDisplayWindowController alloc]
        initWithWindowNibName:@"ABDisplayWindowController"];
    [_displayWindowController showWindow:_displayWindowController.window];

    if ([self displayName] == nil) {
        _displayWindowController.window.title = @"Viewer (Untitled)";
    } else {
        _displayWindowController.window.title =
            [NSString stringWithFormat:@"Viewer (%@)", [self displayName]];
    }

    // Watch for error events posted by the display
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(displayErrors:)
                   name:kABShaderHasErrorsEvent
                 object:_displayWindowController];

    _errorTableView.delegate = self;
    _errorTableView.dataSource = self;

    [[ABAudioManager sharedInstance] startAudio];
}

+ (BOOL)autosavesInPlace
{
    return YES;
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    NSData *data = [[_aceView string] dataUsingEncoding:NSUTF8StringEncoding];
    return data;
}

- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError
{
    NSString *code =
        [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    _aceView.string = code;

    return YES;
}

- (NSFileWrapper *)fileWrapperOfType:(NSString *)typeName
                               error:(NSError *__autoreleasing *)outError
{
    if (_documentFileWrapper == nil) {
        self.documentFileWrapper =
            [[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil];
    }

    NSDictionary *fileWrappers = _documentFileWrapper.fileWrappers;

    NSFileWrapper *shaderWrapper = fileWrappers[@"shader.glsl"];

    if (shaderWrapper != nil) {
        [_documentFileWrapper removeFileWrapper:shaderWrapper];
    }

    [_documentFileWrapper
        addRegularFileWithContents:[[_aceView string]
                                       dataUsingEncoding:NSUTF8StringEncoding]
                 preferredFilename:@"shader.glsl"];

    return _documentFileWrapper;
}

- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper
                     ofType:(NSString *)typeName
                      error:(NSError *__autoreleasing *)outError
{
    NSFileWrapper *shaderWrapper = [fileWrapper fileWrappers][@"shader.glsl"];

    if (!shaderWrapper && outError) {
        *outError = [NSError errorWithDomain:@"ABShaderFiddleFileErrorDomain"
                                        code:1
                                    userInfo:nil];
        return NO;
    }

    NSData *shaderData = [shaderWrapper regularFileContents];
    if (!shaderData)
        return NO;

    self.documentFileWrapper = fileWrapper;

    return YES;
}

- (void)setDisplayName:(NSString *)displayNameOrNil
{
    [super setDisplayName:displayNameOrNil];

    if (displayNameOrNil == nil) {
        _displayWindowController.window.title = @"Viewer (Untitled)";
    } else {
        _displayWindowController.window.title =
            [NSString stringWithFormat:@"Viewer (%@)", displayNameOrNil];
    }
}

#pragma mark - Events

- (IBAction)didTapToolbarRunButton:(id)sender
{
    // Empty the errors from the error table. They will be repopulated after the
    // shader has compiled.
    self.errors = @[];
    [_errorTableView reloadData];

    [_displayWindowController runShader:_aceView.string];
}

- (void)displayErrors:(NSNotification *)notification
{
    if (notification.userInfo) {
        NSArray *errors = (NSArray *)notification.userInfo[@"errors"];

        self.errors = errors;
        [_errorTableView reloadData];
    }
}

#pragma mark - ACEViewDelegate

- (void)textDidChange:(NSNotification *)notification
{
}

#pragma mark - NSTableViewDelegate / NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return _errors.count;
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row
{
    ABShaderError *error = _errors[row];

    if ([tableColumn.identifier
            isEqualToString:kABTableColumnIdentifierLineNum]) {
        return @(error.lineNumber);
    }

    if ([tableColumn.identifier
            isEqualToString:kABTableColumnIdentifierErrorType]) {
        return (error.type == kABShaderErrorTypeError) ? @"Error" : @"Warning";
    }

    if ([tableColumn.identifier
            isEqualToString:kABTableColumnIdentifierErrorMessage]) {
        return error.message;
    }

    return nil;
}

@end
