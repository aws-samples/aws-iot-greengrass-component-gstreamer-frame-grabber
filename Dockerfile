# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

FROM ubuntu:20.04
ENV TZ=<your timezone, e.g. America/Los_Angeles>
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get -y update && apt-get install -y \
    libgstreamer1.0-0  \
	gstreamer1.0-plugins-base \
	gstreamer1.0-plugins-good \
	gstreamer1.0-plugins-bad \
	gstreamer1.0-plugins-ugly \
	gstreamer1.0-libav \
	gstreamer1.0-doc \
	gstreamer1.0-tools \
	gstreamer1.0-x \
	gstreamer1.0-alsa \
	gstreamer1.0-gl \
	gstreamer1.0-gtk3 \
	gstreamer1.0-qt5 \
	gstreamer1.0-pulseaudio \
	&& apt-get clean && apt-get autoremove && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["gst-inspect-1.0"] 
CMD [ "fakesrc", "!", "fakesink" ]
# CMD ["rtspsrc", "location=\"rtsp://<ip>:<port>/h264?username=<user>&password=<pass>\"", "!", "queue", "!", "rtph264depay", "!", "avdec_h264", "!", "jpegenc", "!", "multifilesink", "location=\"/data/frame.jpg\""]
# CMD ["fakesrc", "num-buffers=10", "!", "multifilesink", "location=\"/data/frame.jpg\""]
# CMD ["multifilesrc", "location=/frames/seq_%06d.jpg", "index=1", "loop=true", "caps=\"image/jpg,framerate=\\(fraction\\)12/1\"", "!", "multifilesink", "location=\"/data/frame.jpg\""]
