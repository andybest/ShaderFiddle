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
#import <aubio/aubio.h>

@interface ABAudioManager : NSObject {
    FFTSetup fftSetup;
    COMPLEX_SPLIT A;

    aubio_onset_t *o;
    fvec_t *onset;
    smpl_t is_onset;
}

+ (instancetype)sharedInstance;
- (void)startAudio;

@property (atomic, assign) BOOL audioRunning;
@property (nonatomic, strong) Novocaine *audioManager;

@end
