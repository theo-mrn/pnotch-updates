# MediaRemoteAdapter

Vendored from [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) at tag `v0.7.7`
(BSD 3-Clause, see `LICENSE`). Only the framework sources are kept; the test client and build scripts are not.

Since macOS 15.4, reading the system "Now Playing" information through the private MediaRemote framework
is reserved to Apple-entitled processes. The adapter works around it by being loaded into `/usr/bin/perl`,
which is entitled: PNotch runs `PNotch/MediaControllers/mediaremote-adapter.pl` with this framework and
reads the now playing state it streams as JSON lines.

The Xcode target `MediaRemoteAdapter` builds this folder; the app embeds the result without linking it.
