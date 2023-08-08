#import "MicrophoneStream.h"


@implementation MicrophoneStream {
    AudioQueueRef _queue;
    AudioQueueBufferRef _buffer;
    AVAudioSessionCategory _category;
    AVAudioSessionMode _mode;
}

void inputCallback(
        void *inUserData,
        AudioQueueRef inAQ,
        AudioQueueBufferRef inBuffer,
        const AudioTimeStamp *inStartTime,
        UInt32 inNumberPacketDescriptions,
        const AudioStreamPacketDescription *inPacketDescs) {
    [(__bridge MicrophoneStream *) inUserData processInputBuffer:inBuffer queue:inAQ];
}


RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(init:(NSDictionary *) options) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    _category = [session category];
    _mode = [session mode];

    UInt32 bufferSize = options[@"bufferSize"] == nil ? 4096 : [options[@"bufferSize"] unsignedIntegerValue];

    AudioStreamBasicDescription description;
    description.mReserved = 0;
    description.mSampleRate = options[@"sampleRate"] == nil ? 44100 : [options[@"sampleRate"] doubleValue];
    description.mBitsPerChannel = options[@"bitsPerSample"] == nil ? 16 : [options[@"bitsPerSample"] unsignedIntegerValue];
    description.mChannelsPerFrame = options[@"audioChannels"] == nil ? 1 : [options[@"audioChannels"] unsignedIntegerValue];
    description.mFramesPerPacket = options[@"framesPerPacket"] == nil ? 1 : [options[@"framesPerPacket"] unsignedIntegerValue];
    description.mBytesPerFrame = options[@"bytesPerFrame"] == nil ? 2 : [options[@"bytesPerFrame"] unsignedIntegerValue];
    description.mBytesPerPacket = options[@"bytesPerPacket"] == nil ? 2 : [options[@"bytesPerPacket"] unsignedIntegerValue];
    description.mFormatID = kAudioFormatLinearPCM;
    description.mFormatFlags = kAudioFormatFlagIsSignedInteger;

    AudioQueueNewInput(&description, inputCallback, (__bridge void *) self, NULL, NULL, 0, &_queue);
    AudioQueueAllocateBuffer(_queue, (UInt32) (bufferSize * 2), &_buffer);
    AudioQueueEnqueueBuffer(_queue, _buffer, 0, NULL);
}

RCT_EXPORT_METHOD(start) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
                   error:nil];
    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                               error:nil];
    AudioQueueStart(_queue, NULL);
}

RCT_EXPORT_METHOD(pause) {
    AudioQueuePause(_queue);
    AudioQueueFlush(_queue);
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:_category
                   error:nil];
    [session setMode:_mode
               error:nil];
}

RCT_EXPORT_METHOD(stop) {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:_category
                   error:nil];
    [session setMode:_mode
               error:nil];
    AudioQueueStop(_queue, YES);
}

- (void)processInputBuffer:(AudioQueueBufferRef)inBuffer queue:(AudioQueueRef)queue {
    SInt16 *audioData = inBuffer->mAudioData;
    UInt32 count = inBuffer->mAudioDataByteSize / sizeof(SInt16);

    NSMutableArray *array  = [NSMutableArray arrayWithCapacity:count];

    for (int i = 0; i < count; ++i)
        // Changes by Miðeind: Removed u-law conversion
        [array addObject:[NSNumber numberWithInteger:audioData[i]]];

    [self sendEventWithName:@"audioData" body:array];
    AudioQueueEnqueueBuffer(queue, inBuffer, 0, NULL);
}

- (NSArray<NSString *> *)supportedEvents {
    return @[@"audioData"];
}

- (void)dealloc {
    AudioQueueStop(_queue, YES);
}

@end
