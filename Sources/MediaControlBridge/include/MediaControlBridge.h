#ifndef MEDIA_CONTROL_BRIDGE_H
#define MEDIA_CONTROL_BRIDGE_H

#include <stdbool.h>

bool VTMediaPlaybackIsPlaying(double timeoutSeconds, bool *known);
bool VTMediaPlaybackSendPause(void);
bool VTMediaPlaybackSendPlay(void);

#endif
