#import "MediaControlBridge.h"

#import <Foundation/Foundation.h>
#import <dlfcn.h>

typedef void (*MRGetPlayingFunction)(dispatch_queue_t, void (^)(BOOL));
typedef Boolean (*MRSendCommandFunction)(NSInteger, CFDictionaryRef);

static MRGetPlayingFunction getPlayingFunction;
static MRSendCommandFunction sendCommandFunction;

static void VTLoadMediaRemote(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote";
        void *handle = dlopen(path, RTLD_NOW | RTLD_LOCAL);
        if (handle == NULL) {
            return;
        }

        getPlayingFunction = (MRGetPlayingFunction)dlsym(
            handle,
            "MRMediaRemoteGetNowPlayingApplicationIsPlaying"
        );
        sendCommandFunction = (MRSendCommandFunction)dlsym(
            handle,
            "MRMediaRemoteSendCommand"
        );
    });
}

bool VTMediaPlaybackIsPlaying(double timeoutSeconds, bool *known) {
    VTLoadMediaRemote();
    if (known != NULL) {
        *known = false;
    }
    if (getPlayingFunction == NULL) {
        return false;
    }

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL callbackReceived = NO;
    __block BOOL isPlaying = NO;
    getPlayingFunction(
        dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0),
        ^(BOOL value) {
            isPlaying = value;
            callbackReceived = YES;
            dispatch_semaphore_signal(semaphore);
        }
    );

    int64_t nanoseconds = (int64_t)(timeoutSeconds * NSEC_PER_SEC);
    if (dispatch_semaphore_wait(
        semaphore,
        dispatch_time(DISPATCH_TIME_NOW, nanoseconds)
    ) != 0) {
        return false;
    }

    if (known != NULL) {
        *known = callbackReceived;
    }
    return callbackReceived && isPlaying;
}

bool VTMediaPlaybackSendPause(void) {
    VTLoadMediaRemote();
    return sendCommandFunction != NULL && sendCommandFunction(1, NULL);
}

bool VTMediaPlaybackSendPlay(void) {
    VTLoadMediaRemote();
    return sendCommandFunction != NULL && sendCommandFunction(0, NULL);
}
