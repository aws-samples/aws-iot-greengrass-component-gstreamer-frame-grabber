# AWS IoT Greengrass V2 Component using Docker to run GStreamer to grab frames from an RTSP Stream

Using this project you can setup a docker container that will pull the latest frame from an RTSP source using GStreamer and controlled by AWS IoT Greengrass V2.

This project targets Linux hosts and was developed using Linux and Mac desktop environments. 

## Part 1 - RTSP Stream to Still in a Docker Container

Using Computer Vision models often means acquiring images from RTSP sources. GStreamer provides a flexible and effective means to acquire those sources and render the current frame. As [GStreamer](https://gstreamer.freedesktop.org/) can require a number of libraries and be a bit tricky to work with, using Docker helps to manage these dependencies.

_Prerequisites_:

* [Install Docker](https://docs.docker.com/engine/install/)
* A working installation of [AWS IoT Greengrass v2](https://docs.aws.amazon.com/greengrass/index.html)
* an AWS Account, If you don't have one, see [Set up an AWS account](https://docs.aws.amazon.com/greengrass/v2/developerguide/setting-up.html#set-up-aws-account)
* AWS CLI v2 [installed](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html) with permissions to
    - PUT objects into S3

### Build the Docker image

The `RUN` command of the `Dockerfile` will install all the packages needed. The current build is based on Ubuntu 20.04, but it is certainly possible to create a smaller, more targetted image. 

Note the export of the Time Zone -- the GStreamer install will pause (and fail) if this is not set. 

1. set `TZ` to your [time zone](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

the `CMD` provides the exec style params to the `ENTRYPOINT` -- these can be overridden by the docker invocation. Note the `location` parameter giving the RTSP source and the second `location` parameter giving the Docker-side path for the frame results.

2. customize the `location` for the `rtspsrc` for your source.

_Make sure you have the right source (IP, port, user, password) by using [VLC](https://www.videolan.org/vlc/) *and* with `telnet`, `nc`, or other from the Docker host to ensure the stream can be accessed._

3. (Optional) modify the `location` parameter for the `multifilesink` plugin to set the location of the file that the pipeline will write.

4. Now, build the image:

```bash
docker build --rm -t <name> .
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
docker run -v /tmp:/data --user "$(id -u):$(id -g)" --name=<name> <name>
# adding the -d flag will detach the container's output
#   stop it with docker stop, but get the running name first with docker container ls
#   or force the name when starting the container with the `--name=<name>` option as shown
```

This will start the container, mapping the host's `/tmp` dir to the container's `/data` dir. New files will be created with the current user/group. 

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
ls -l /tmp/frame.jpg
``` 
observe the user, group, timestamp, etc. 

3. Open the file in an image viewer and verify correctness.

_Tip_: on Ubuntu hosts, the command `eog /tmp/frame.jpg` will open a window with the image--it should refresh as the pipeline writes new frames.

_Troubleshooting_

Try executing the GStreamer pipeline interactively.

```bash
# launch the container in interactive mode
docker run -v  /tmp:/data --user "$(id -u):$(id -g)" -it --entrypoint /bin/bash gst
```

_(Errors about not having a name are normal.)_

Execute pipelines manually

```bash
# same command as in the Dockerfile
gst-launch-1.0 rtspsrc location="rtsp://<ip>:<port>/h264?username=<user>&password=<pass>" ! queue ! rtph264depay ! avdec_h264 ! jpegenc ! multifilesink location="/data/frame.jpg"

# capture the stream to a file until Ctrl-C cancels 
gst-launch-1.0 -e rtspsrc location="rtsp://192.168.5.193:554/h264?username=admin&password=123456" ! queue ! rtph264depay ! h264parse ! mp4mux ! filesink location=/data/file.mp4
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

As the GStreamer pipeline will (re)write the frame file 30x/second, using a RAM Disk for these will save power and disk cycles as well as improve overall performance. When inference is added, we can extend the use of this RAM Disk.

* create entry in `/etc/fstab` 

```
tmpfs /tmp/data tmpfs defaults,noatime,nosuid,nodev,noexec,mode=1777,size=32M 0 0
```

creates 32M RAM disk in `/tmp/gst`...  the mapped volume for docker

Mount the RAM Disk with

```bash
sudo mount -a
```

You may need to `chown` the user/group of the created tmp dir **OR** execute subsequent inference with `sudo` **OR** modify the `fstab` entry to set the user/group.

## Part 2. Build the Greengrass Component

AWS IoT Greengrass can manage and run a Docker container. If AWS IoT Greengrass v2 is **NOT** already installed, consult [Getting started with AWS IoT Greengrass V2](https://docs.aws.amazon.com/greengrass/v2/developerguide/getting-started.html)

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
vim ~/GreengrassCore/recipes/$component_name-$component_version.json
```

And enter the following content for the recipe, replacing paste_bucket_name_here with the name of the bucket you created earlier. Also replace component-name, component-version, and containter-name

```json
{
  "RecipeFormatVersion": "2020-01-25",
  "ComponentName": "<component-name>",
  "ComponentVersion": "1.0.0",
  "ComponentDescription": "A component that runs a Docker container from an image in an S3 bucket.",
  "ComponentPublisher": "Amazon",
  "Manifests": [
    {
      "Platform": {
        "os": "linux"
      },
      "Lifecycle": {
        "Install": {
          "Script": "docker load -i {artifacts:path}/<container-name>.tar.gz"
        },
        "Startup": {
          "Script": "docker run --rm -d -v /tmp/data:/data --user \"$(id -u):$(id -g)\" --name=<container-name> <container-name>"
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

**NB-** the above command assumes the RAM disk was set up for `/tmp/data` -- modify it as appropriate for your installation.

Also note that for this recipe, we use the `Startup`/`Shutdown` Events of the `Lifecycle`. This is important when creating a background process. For processes that are not background, use the `Run` event. `Shutdown` will be called as soon as the `Run` command completes or when the core is shutting down.


5. create the GG component with 

```bash
aws greengrassv2 create-component-version \
  --inline-recipe fileb://~/GreengrassCore/recipes/$component_name-$component_version.json
```

## FINISHED: Next steps

You have now created a Greengrass component to run a GStreamer pipeline to a known file in your AWS Account. You can continue to deploy this component to your Greengrass Cores which will start the container running and producing output files (e.g. `/tmp/data/frame.jpg`) on the Greengrass core. These results can be inspected with `eog` or other tools on the Greengrass core.

## Develoment and Troubleshooting considerations 

To fix a failed deployment:

1. Go to Deployments in the console and remove the offending component from the deployment (check both thing and group level). Deploy.  This will remove the component from the target.

2. Delete the component definition in the console

3. Update the artifacts and push to S3

4. Re-Create the component definition (as this will take a hash from the artifacts). (alternatively, it should be possible to create a new version)

5. Add the newly, re-created component to the deployment and deploy.

_It can be very handy to turn off the Rollback feature on failure to see what was captured/expanded_

If you find yourself iterating through the above cycle many times, it may be easier to develop the component locally first and then upload it. See [Create custom AWS IoT Greengrass components](https://docs.aws.amazon.com/greengrass/v2/developerguide/create-components.html) for information about how to work with components locally on the Greengrass core.
