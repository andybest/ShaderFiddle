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

#import "ABAudioManager.h"
#import "ABEventList.h"

@implementation ABAudioManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (id)init
{
    if ((self = [super init])) {
        [self setupFFT];
    }
    return self;
}

- (void)dealloc
{
    free(A.realp);
    free(A.imagp);
    vDSP_destroy_fftsetup(fftSetup);
}

- (void)setupFFT
{
    int numSamples = 512;
    vDSP_Length log2n = log2f(numSamples);
    fftSetup = vDSP_create_fftsetup(log2n, FFT_RADIX2);
    int nOver2 = numSamples / 2;
    A.realp = (float *)malloc(nOver2 * sizeof(float));
    A.imagp = (float *)malloc(nOver2 * sizeof(float));
}

- (void)startAudio
{
    if (!_audioManager) {
        self.audioManager = [Novocaine audioManager];
    }

    __weak typeof(self) weakSelf = self;
    [_audioManager setInputBlock:^(float *newAudio, UInt32 numSamples, UInt32 numChannels) {
        
        float samples[512];
        float amplitudes[512];
        
        for(int i=0; i < numSamples; i++)
        {
            int sampleIdx = i * 2;
            
            float leftSamp = newAudio[sampleIdx];
            float rightSamp = newAudio[sampleIdx + 1];
            
            // Sum the stereo channels for the FFT
            float outputSamp = (leftSamp + rightSamp) * 0.5;
            samples[i] = outputSamp;
        }
        
        [weakSelf doFFT:samples amplitudes:amplitudes numSamples:512];
        
        // Sum FFT bins.
        float summed[16];
        
        for(int i=0; i < 16; i++)
            summed[i] = 0.0;
        
        for(int i=0; i < 256; i++)
        {
            int summedBin = (int)floor(i / 16.0);
            summed[summedBin] += amplitudes[i];
        }
        
        NSMutableArray *amps = [NSMutableArray array];
        for(int i=0; i < numSamples / 2; i++)
        {
            [amps addObject:@(amplitudes[i])];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            [center postNotificationName:kABFFTUpdatedEvent
                                  object:nil
                                userInfo:@{@"amplitudes": amps}];
        });
    }];
}

- (void)doFFT:(float[])samples amplitudes:(float[])amp numSamples:(int)numSamples
{
    vDSP_Length log2n = log2f(numSamples);

    //Convert float array of reals samples to COMPLEX_SPLIT array A
    vDSP_ctoz((COMPLEX *)samples, 2, &A, 1, numSamples / 2);

    //Perform FFT using fftSetup and A
    //Results are returned in A
    vDSP_fft_zrip(fftSetup, &A, 1, log2n, FFT_FORWARD);

    //Convert COMPLEX_SPLIT A result to float array to be returned

    vDSP_zvmags(&A, 1, amp, 1, numSamples); // get amplitude squared
    vvsqrtf(amp, amp, &numSamples);         // get amplitude
    amp[0] = amp[0] / 2.;

    float fNumSamples = numSamples;
    vDSP_vsdiv(amp, 1, &fNumSamples, amp, 1, numSamples); // /numSamples
}

@end
