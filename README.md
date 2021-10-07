# AWS IoT Greengrass V2 Component using Docker to run GStreamer to grab frames from an RTSP Stream

Using this project you can setup a docker container that will pull the latest frame from an RTSP source using GStreamer and controlled by AWS IoT Greengrass V2.

This project targets Linux hosts and was developed using Linux and Mac desktop environments. 

**_NOTE_**: The architecture (x86, amd64, armv7l, x86_64, etc.) of the built container must match the target device.  That is, if your target is Raspberry Pi (armv7l), then you must either build the image on an armv7l OR cross-compile. For the purposes of **_this project_**, cross-compiling is out of scope and the reader is advised to build on the target architecture. 

Likewise the base image for the container must match. For that reason, alternate `Dockerfiles` are provided for some common platforms. 

**Check your development host and target device architecture**

```bash
uname -a

# output for a Raspberry Pi 4:
#Linux raspberrypi 5.10.63-v7l+ #1457 SMP Tue Sep 28 11:26:14 BST 2021 armv7l GNU/Linux

# x86 Mac
#Darwin 3c22fbe3d4e9.ant.amazon.com 20.6.0 Darwin Kernel Version 20.6.0: Mon Aug 30 06:12:21 PDT 2021; root:xnu-7195.141.6~3/RELEASE_X86_64 x86_64

# i7 Ubuntu
#Linux dev 5.11.0-37-generic #41~20.04.2-Ubuntu SMP Fri Sep 24 09:06:38 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux

# grab just the machine architecture with
uname -m
```

**Select one of the provided `Dockerfiles` for common platforms or modify as needed**

| platform | Dockerfile | |
| --- | --- | --- |
| x86_64 | `Dockerfile` | use as is below |
| Raspberry Pi (`armv7l`) | `Dockerfile.rpi` | `mv Dockerfile Dockerfile.x86_64; mv Dockerfile.rpi Dockerfile` |

Before proceeding, inspect and verify the Dockerfile contents and filename to agree with the commands in this document.

## Part 1 - RTSP Stream to Still in a Docker Container

Using Computer Vision models often means acquiring images from RTSP sources. GStreamer provides a flexible and effective means to acquire those sources and render the current frame. As [GStreamer](https://gstreamer.freedesktop.org/) can require a number of libraries and be a bit tricky to work with, using Docker helps to manage these dependencies.

_Note:_ This section will build a Docker image and wrap it in a Greengrass V2 component. Docker images are specific to the OS and instruction architecture of the host. It can be convenient to build the image on one machine and deploy it to multiple others. However, the OS and architecture needs to be consistent. To avoid any issues, these instructions will build the image on the same system as the target for deployment. Advanced users can adapt this sequence to their needs.

_Prerequisites_:

* [Install Docker](https://docs.docker.com/engine/install/)
* A working installation of [AWS IoT Greengrass v2](https://docs.aws.amazon.com/greengrass/index.html)
* an AWS Account, If you don't have one, see [Set up an AWS account](https://docs.aws.amazon.com/greengrass/v2/developerguide/setting-up.html#set-up-aws-account)
* AWS CLI v2 [installed](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) with permissions to
    - PUT objects into S3

### Build the Docker image

The `RUN` command of the `Dockerfile` will install all the packages needed. The current build is based on Ubuntu 20.04, but it is certainly possible to create a smaller, more targetted image. 

**Open the Dockerfile in your editor**, make the following changes.

Note the export of the Time Zone -- the GStreamer install will pause (and fail) if this is not set. 

1. set `TZ` to your [time zone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

the `CMD` provides the exec style params to the `ENTRYPOINT` -- these can be overridden by the docker invocation. Note the `location` parameter giving the RTSP source and the second `location` parameter giving the Docker-side path for the frame results.

2. customize the `location` for the `rtspsrc` for your source.

_Make sure you have the right source (IP, port, user, password) by using [VLC](https://www.videolan.org/vlc/) *and* with `telnet`, `nc`, or other from the Docker host to ensure the stream can be accessed._

**No RTSP Source?**

You can use a series of numbered files and the `multifilesrc` or the `fakesrc` plugins. A convenient collection of numbered images can be found at the [Mall Crowd Counting Dataset](http://personal.ie.cuhk.edu.hk/~ccloy/downloads_mall_dataset.html).

In the Dockerfile, two alternate pipelines are given for the `multifilesrc` and the `fakesrc` options. Uncomment them (and comment the `rtspsrc` CMD) to use those. Alternatively, you can provide an alternate pipeline on the command line when invoking Docker.

3. (Optional) modify the `location` parameter for the `multifilesink` plugin to set the location of the file that the pipeline will write.

4. **Save the Dockerfile**.
5. Now, build the image:

```bash
docker build --rm -t <name> .
# example
# docker build --rm -t gst .
```

The `--rm` switch will remove any previous builds (which you may accumulate if you change the `CMD` parameters or other settings). However, orphaned images can still accumulate. 

**List Images**
List images with

```bash
docker images
```

**Prune unused images**
```bash
docker system prune
```

### Test the Docker Image

1. Start the docker container with

```bash
# create the mount point for the volume
mkdir -p /tmp/data

docker run -v /tmp/data:/data --name=<name> <name>
# adding the -d flag will detach the container's output
#   stop it with docker stop, but get the running name first with docker container ls
#   or force the name when starting the container with the `--name=<name>` option as shown
# Since we made /tmp/data world writable, we don't need to map the docker user, 
#   but could add back with `--user "$(id -u):$(id -g)"` on command line
```

This will start the container, mapping the host's `/tmp/data` dir to the container's `/data` dir. New files will be created with the current user/group. 

**Normal output**
```
Progress: (open) Retrieving server options
Progress: (open) Retrieving media info
Progress: (request) SETUP stream 0
Progress: (request) SETUP stream 1
Progress: (open) Opened Stream
Setting pipeline to PLAYING ...
New clock: GstSystemClock
Progress: (request) Sending PLAY request
Progress: (request) Sending PLAY request
Progress: (request) Sent PLAY request
Redistribute latency...
```

2. Check the output with

```bash
# modify as needed if you changed the output location
ls -l /tmp/data/frame.jpg
``` 
observe the user, group, timestamp, etc. 

3. Open the file in an image viewer and verify correctness.

_Tip_: If using a headed Ubuntu host (not Cloud9), the command `eog /tmp/data/frame.jpg` will open a window with the image--it should refresh as the pipeline writes new frames.

_Troubleshooting_

Try executing the GStreamer pipeline interactively.

```bash
mkdir -p /tmp/data
# launch the container in interactive mode
docker run -v /tmp/data:/data -it --entrypoint /bin/bash gst
```

_(Errors about not having a name are normal.)_

Execute pipelines manually

```bash
# extract current frame from a stream until Ctrl-C cancels 
gst-launch-1.0 rtspsrc location="rtsp://<ip>:<port>/h264?username=<user>&password=<pass>" ! queue ! rtph264depay ! avdec_h264 ! jpegenc ! multifilesink location="/data/frame.jpg"

# capture the stream to a file until Ctrl-C cancels 
gst-launch-1.0 rtspsrc location="rtsp:/<ip>:<port>/h264?username=admin&password=123456" ! queue ! rtph264depay ! h264parse ! mp4mux ! filesink location=/data/file.mp4
# change the IP number as needed for your RTSP source
```

Seeing errors about plugins missing or misconfigured?
```bash
# no rtspsrc? 
gst-inspect-1.0 rtspsrc
```

No available RTSP source to test with?
Try changing the `rtspsrc location=...` to `filesrc` and a local file

Compose additional pipelines, consulting the [GStreamer Plugin Reference](https://gstreamer.freedesktop.org/documentation/plugins_doc.html?gi-language=c)

### (Optional) Step 3. Use a RAM disk for the images

As the GStreamer pipeline will (re)write the frame file 30x/second, using a RAM Disk for these will save power and disk cycles as well as improve overall performance. When inference is added, we can extend the use of this RAM Disk. This step may be important for traditional linux systems or other systems where you wish to avoid repeated disk writes. That is, this is **not necessary for Cloud 9** hosts, but may be helpful for embedded systems where the 'disk' is an SD card with finite lifetime writes.

* create entry in `/etc/fstab` 

```
tmpfs /tmp/data tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=32M 0 0
```

creates 32M RAM disk in `/tmp/data`...  the mapped volume for docker

Mount the RAM Disk with

```bash
sudo mount -a
```

You may need to `chown` the user/group of the created tmp dir **OR** execute subsequent inference with `sudo` **OR** modify the `fstab` entry to set the user/group.

## Part 2. Build the Greengrass Component

AWS IoT Greengrass can manage and run a Docker container. If AWS IoT Greengrass v2 is **NOT** already installed, consult [Getting started with AWS IoT Greengrass V2](https://docs.aws.amazon.com/greengrass/v2/developerguide/getting-started.html). **Note** If you are using the same system for both development (creating the image and component) as well as the target (where the Greengrass core and this component will run), ensure that side effects of development and testing are not left over prior to deploying the component. Specifically, check filesystem mounts and directories that may have been created above.  The installation recipe below will **_create_** a directory in `/tmp` (configurable). It is important that this directory creation be performed by the installation script so that the correct user/group owner is set for this directory.  Use `sudo rm -rf /tmp/data` or other command if needed to remove any development-time setup.

1. archive the docker image 

```bash
# keeping a local copy of artifacts is generally helpful
mkdir -p ~/GreengrassCore && cd $_

export component_name=<name for your component>
export component_version=<version number>
# example
# export component_name=com.example.gst-grabber
# export component_version=1.0.0

# use the name of your docker container created in Part 1
mkdir -p ~/GreengrassCore/artifacts/$component_name/$component_version

export container_name=<name of your container>
# example
# export container_name=gst
docker save $container_name > ~/GreengrassCore/artifacts/$component_name/$component_version/$container_name.tar
```

2. (Optional) remove the original image and reload

```bash
docker image ls $container_name
# check the output

docker rmi -f $container_name

# recheck images
docker image ls $container_name
# should be empty set

docker load -i ~/GreengrassCore/artifacts/$component_name/$component_version/$container_name.tar

# and the container should now be in the list
docker image ls
```

3. upload the image to S3

```bash
# compress the file first, gzip, xz, and bzip are supporteed by Docker for load
gzip ~/GreengrassCore/artifacts/$component_name/$component_version/$container_name.tar

export bucket_name=<where you want to host your artifacts>
# for example
# export region='us-west-2'
# export acct_num=$(aws sts get-caller-identity --query "Account" --output text)
# export bucket_name=greengrass-component-artifacts-$acct_num-$region

# create the bucket if needed
aws s3 mb s3://$bucket_name

# and copy the artifacts to S3
aws s3 sync ~/GreengrassCore/ s3://$bucket_name/
```

4. create the recipe for the component

```bash
mkdir -p ~/GreengrassCore/recipes/
touch ~/GreengrassCore/recipes/$component_name-$component_version.json

# paste these values
echo $component_name " " $component_version " " $bucket_name

# edit using IDE or other editor
# for example: vim
# vim ~/GreengrassCore/recipes/$component_name-$component_version.json
```

And enter the following content for the recipe, replacing paste_bucket_name_here with the name of the bucket you created earlier. Also replace component-name, component-version, and container-name

```json
{
  "RecipeFormatVersion": "2020-01-25",
  "ComponentName": "<component-name>",
  "ComponentVersion": "<component-version>",
  "ComponentDescription": "A component that runs a Docker container from an image in an S3 bucket.",
  "ComponentPublisher": "Amazon",
  "ComponentConfiguration": {
      "DefaultConfiguration": {
          "mounts": "-v /tmp/data:/data",
          "entrypoint": "gst-launch-1.0",
          "command": "fakesrc ! multifilesink location=\"/data/frame.jpg\""
      }
  },
  "Manifests": [
    {
      "Platform": {
        "os": "linux",
        "architecture": "<arch_of_machine_building_the_image>"
      },
      "Lifecycle": {
        "Install": {
          "Script": "mkdir -p /tmp/data; docker load -i {artifacts:path}/<container-name>.tar.gz"
        },
        "Startup": {
          "Script": "docker run --user=$(id -u):$(id -g) --rm -d {configuration:/mounts} --name=<container-name> --entrypoint {configuration:/entrypoint} gst {configuration:/command}"
        },
        "Shutdown": {
          "Script": "docker stop <container-name>"
        }
      },
      "Artifacts": [
        {
          "URI": "s3://<paste_bucket_name_here>/artifacts/<component-name>/<component-version>/<container-name>.tar.gz"
        }
      ]
    }
  ]
}
```

Consult the [AWS IoT Greengrass component recipe reference](https://docs.aws.amazon.com/greengrass/v2/developerguide/component-recipe-reference.html) for more information about the properties of the recipe file, including how to set `<arch_of_machine_building_the_image>`, which **MUST** match the target architecture as well.

Retrieve the target device's architecture with

```bash
uname -m
```

For `x86_64`, set the `architecture` property in the recipe file to `amd64`.

**NB-** the above command assumes the RAM disk was set up for `/tmp/data` -- modify it as appropriate for your installation in the `mounts` property. Also note that the directory is created in the Install Lifecycle for the component recipe. Adjust as needed for your environment.  This will ensure the directory exists and the docker user has write permissions. 

You can also set the `command` configuration property for other GStreamer pipelines. For example,

```json
"command": "gst-launch-1.0 -e rtspsrc location=\"rtsp://192.168.5.193:554/h264?username=admin&password=123456\" ! queue ! rtph264depay ! h264parse ! mp4mux ! filesink location=/data/file.mp4"
```

will set GStreamer to read the rtsp stream from `192.168.5.193` with username `admin` and password `123456`.

The configuration property `entrypoint` can be overridden for debugging purposes. Setting this to `echo` or `gst-inspect-1.0` can be helpful.

In this recipe, we use the `Startup`/`Shutdown` Events of the `Lifecycle`. This is important when creating a background process. For processes that are not background, use the `Run` event. `Shutdown` will be called as soon as the `Run` command completes or when the core is shutting down.


5. create the GG component with 

```bash
aws greengrassv2 create-component-version \
  --inline-recipe fileb://~/GreengrassCore/recipes/$component_name-$component_version.json
```

**An Error** of `not authorized to perform: null` usually indicates an error in the JSON for the recipe. Validate the JSON with a tool like `jq`.

```bash
cat ~/GreengrassCore/recipes/$component_name-$component_version.json | jq
```

## FINISHED: Next steps

You have now created a Greengrass component to run a GStreamer pipeline to a known file in your AWS Account. You can continue to deploy this component to your Greengrass Cores which will start the container running and producing output files (e.g. `/tmp/data/frame.jpg`) on the Greengrass core. These results can be inspected with `eog` or other tools on the Greengrass core.

You can also customize the application of the component by overriding the configuration as described above.
## Develoment and Troubleshooting considerations 

To fix a failed deployment:

1. Go to Deployments in the console and remove the offending component from the deployment (check both thing and group level). Deploy.  This will remove the component from the target.

2. Delete the component definition in the console

3. Update the artifacts and push to S3

4. Re-Create the component definition (as this will take a hash from the artifacts). (alternatively, it should be possible to create a new version)

5. Add the newly, re-created component to the deployment and deploy.

_It can be very handy to turn off the Rollback feature on failure to see what was captured/expanded_

If you find yourself iterating through the above cycle many times, it may be easier to develop the component locally first and then upload it. See [Create custom AWS IoT Greengrass components](https://docs.aws.amazon.com/greengrass/v2/developerguide/create-components.html) for information about how to work with components locally on the Greengrass core.
