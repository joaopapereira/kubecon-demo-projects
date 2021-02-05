# Demo of Carvel Tool Suite

## Setting up the development environment
### Prerequirements
- Go >=1.13
- Make
- vendir installed from carvel.dev

## During development
### Setup local environment
We rely on multiple tools from the Carvel Tool Suite and this repository contains
configuration needed to download these tools.
In order to do this we use `vendir` to retrieve the binaries as well as some configurations????

:construction: Talk a little bit about the advantage of vendir


### Create configuration for application

The configuration for the application can be found in the folder `config`

Interesting files:
- `schema.yml`: definition of the types that the data values can have
                Schemas serve as defaults in case no values are provided
                `#@schema/nullable` annotation defines the next element as nullable, so it can be provided or not in the data values
- `helpers.star`: Starlark file with helper functions definition used in `crds.yml` and `projects.yml`

Lets create a file with the following data values configuration

```yaml
#@ load("@ytt:overlay", "overlay")
#@data/values
---
projects:
  #@overlay/append
  - name: "first-project"
    namespace: "default"
  #@overlay/append
  - name: "second-project"
    namespace: "other-namespace"
  #@overlay/append
  - name: "third-project"
    namespace: "default"
    description: "some very nice project"
```

This is for tests purposes to ensure that when we provide the expected information
the configuration is generated correctly.

To test out our configuration we use the following command

`bin/ytt -f deployment/config -f tmp/data.yml --enable-experiment-schema`

Explanation of the arguments:
- `-f config`: folder where `ytt` will retrieve the configuration
- `-f tmp/values.yml`: file with the above information
- `--enable-experiment-schema`: Enable the Schema feature(we still haven't made schemas a default behavior of `ytt`)


### Create application images

To create the OCI Images needed for our application we use `kbld`

`bin/kbld -f build.docker.yml -f deployment/config/app.yml --imgpkg-lock-output tmp/images.yml`

Explanation of the arguments:
- `-f build.docker.yml`: configuration file for kbld to build current source
  `build.pack.yml` can also be used if we want to build source using `pack`
- `-f config/app.yml`: file that contains the deployment information. This is important because `kbld` will only
  build images that are used.
- `--imgpkg-lock-output tmp/images.yml`: This is not mandatory, but creates an image lock file that will
  be used on our next step to create a bundle using `imgpkg`

## Packaging

This section will describe how might a developer prepare an application to be distributed
### Creation of bundles

Using `imgpkg` the developer can create a bundle with all the needed OCI images with the software
as well as the configuration that will be needed to use the software.

In this case we need to package the image that we just built plus our `config` folder.

This is done by executing the following commands
1. Create the bundle structure
    `mkdir -p bundle/.imgpkg && cp tmp/images.yml bundle/.imgpkg/images.yml`
2. Run `imgpkg`
   
    `bin/imgpkg push -b localhost:5000/projects-bundle:v1 -f bundle -f deployment`
   
    Explanation of the arguments:
    - `-b localhost:5000/projects-bundle:v1`: Repository where our bundle will be uploaded to
    - `-f bundle -f deployment`: there 2 folders contain the deployment files as well as the bundle configuration

### Copy to a public registry

After this is done we will copy our artifacts to a public registry to allow the application consumers to
get our application

This is done by executing the following command
`bin/imgpkg copy -b localhost:5000/projects-bundle:v1 --to-repo k8slt/projects-bundle`

Explanation of the arguments:
- `-b localhost:5000/projects-bundle:v1`: Copy from our local repository
- `--to-repo k8slt/projects-bundle`: repository where all the images will be stored

Output
```
copy | exporting 2 images...
copy | will export localhost:5000/projects-app@sha256:c46eb0c974a21b4cb3e7508125bc7fa7aabf7f4dc9d6321a083df5330192c656
copy | will export localhost:5000/projects-bundle@sha256:e19829cc0bd2e8713bfb5abbe899aac0f87c5d60639ed22b589b16d550f0174c
copy | exported 2 images
copy | importing 2 images...
copy | importing localhost:5000/projects-bundle@sha256:e19829cc0bd2e8713bfb5abbe899aac0f87c5d60639ed22b589b16d550f0174c -> index.docker.io/k8slt/projects-bundle@sha256:e19829cc0bd2e8713bfb5abbe899aac0f87c5d60639ed22b589b16d550f0174c...
copy | importing localhost:5000/projects-app@sha256:c46eb0c974a21b4cb3e7508125bc7fa7aabf7f4dc9d6321a083df5330192c656 -> index.docker.io/k8slt/projects-bundle@sha256:c46eb0c974a21b4cb3e7508125bc7fa7aabf7f4dc9d6321a083df5330192c656...
copy | imported 2 images
Succeeded
```

Interesting things to note:
- All the images are copied to the same repository
- The copy is done using the SHA
- `imgpkg` ensures that SHA will never change

## Deployment

For the consumers of the application the developer will have to provide the image repository and,
the SHA of the bundle in the above case it will be `k8slt/projects-bundle@sha256:e19829cc0bd2e8713bfb5abbe899aac0f87c5d60639ed22b589b16d550f0174c`

### Prerequirements for the installation
Since everything was package using Carvel Tool the consumer will have to download `imgpkg` and for this particular
application will also need `vendir` to manage other dependencies

### Transfer to local registry

This step is optional but usually recommend.

This is done by executing the following command
`bin/imgpkg copy -b k8slt/projects-bundle@sha256:45f3926bca9fc42adb650fef2a41250d77841dde49afc8adc7c0c633b3d5f27a --to-repo localhost:5000/projects-bundle-to-deploy`

Explanation of the arguments:
- `-b k8slt/projects-bundle@sha256:45f3926bca9fc42adb650fef2a41250d77841dde49afc8adc7c0c633b3d5f27a`: Exact version of the software we want to run
- `--to-repo localhost:5000/projects-bundle-to-deploy`: local repository

### Prepare customization of the configuration

What steps need to be done to customize and prepare to deploy the application
1. Retrieve the configuration for the app
   This is done by executing the following command
   `bin/imgpkg pull -b localhost:5000/projects-bundle-to-deploy@sha256:e19829cc0bd2e8713bfb5abbe899aac0f87c5d60639ed22b589b16d550f0174c -o tmp/projects-bundle`
   Explanation of the arguments:
   - `-b localhost:5000/projects-bundle-to-deploy@sha256:e19829cc0bd2e8713bfb5abbe899aac0f87c5d60639ed22b589b16d550f0174c`: Exact version of the software we want to run
   - `-o tmp/projects-bundle`: location where the bundle configuration will be downloaded too

2. Retrieve the overlay's that are needed to adapt this installation

    We need to add the following configuration to vendir.yml
    ```yaml
      - path: local_configuration
        contents:
          - path: .
            git:
              url: https://github.com/joaopapereira/webinar-demo-projects
              ref: origin/local_configuration
    ```
   Execute `./prepare-env.sh` to retrieve the needed binaries and configuration

`bin/ytt -f config -f local_configuration/local_config --enable-experiment-schema`

### Deploy

This is done by executing the following command
`bin/ytt -f config -f local_configuration --enable-experiment-schema | bin/kbld -f- -f .imgpkg/images.yml | bin/kapp deploy -a team-1-projects-app -f-`

Explanation of the arguments:
- `-b k8slt/projects-bundle@sha256:e19829cc0bd2e8713bfb5abbe899aac0f87c5d60639ed22b589b16d550f0174c`: Exact version of the software we want to run
- `--to-repo localhost:5000/projects-bundle-to-deploy`: local repository
