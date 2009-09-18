Panda
=====

Panda is an open source solution for video uploading, encoding and streaming.

**** THIS IS THE MUTANT PANDA FORK ****
we forked panda in order to make it a general asset manager, rather than video only.
we'll focus on the "dm" branch, as our target is to use it without any could services.
the REST api will see minimal changes, mainly to facilitate non-video assets.



Please see [pandastream.com](http://pandastream.com/) for an introduction and lots of documentation.

Information beyond this point is aimed at people who want to contribute to panda and / or understand how it works.

How does Panda work?
====================

1. Video is uploaded to panda
2. Panda checks the video's metadata, uploads the raw file to S3 and adds it to the encoding queue
3. The encoder application picks the encoding job off the queue when it's free and encodes the video to all possible formats
4. Panda sends a callback to your web application notifying you the video has been encoded
5. You use the appropriate S3 url of the encoding to embed the video

Installation and setup
======================

There are two options for running Panda. You can either the use the prebuild AMI which includes all of the software required to run Panda. Or if you wish run it locally on own your own server, you can follow the [local installation guide](http://pandastream.com/docs/local_installation).
