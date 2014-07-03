//
//  ABAudioManager.h
//  ShaderFiddle
//
//  Created by Andy Best on 02/07/2014.
//  Copyright (c) 2014 Andy Best. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Novocaine.h>
#import <Accelerate/Accelerate.h>

@interface ABAudioManager : NSObject {
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;
}

+ (instancetype)sharedInstance;
- (void)startAudio;

@property (atomic, assign) BOOL audioRunning;
@property (nonatomic, strong) Novocaine *audioManager;

@end
