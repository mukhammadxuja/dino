osascript -e 'tell application "Music" to set song repeat to off'
sleep 1
perl mediaremote-adapter/mediaremote-adapter.pl /System/Library/PrivateFrameworks/MediaRemote.framework get | grep -i repeatMode

osascript -e 'tell application "Music" to set song repeat to one'
sleep 1
perl mediaremote-adapter/mediaremote-adapter.pl /System/Library/PrivateFrameworks/MediaRemote.framework get | grep -i repeatMode

osascript -e 'tell application "Music" to set song repeat to all'
sleep 1
perl mediaremote-adapter/mediaremote-adapter.pl /System/Library/PrivateFrameworks/MediaRemote.framework get | grep -i repeatMode
