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

### Using vendir

- download binaries
- download configurations from git in a gitops style
- keep code in sync from a different source
- download other blobs or something


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

`bin/kbld -f build.docker.hub.yml -f deployment/config/app.yml --imgpkg-lock-output tmp/images.yml`

Explanation of the arguments:
- `-f build.docker.hub.yml`: configuration file for kbld to build current source
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
   
    `bin/imgpkg push -b k8slt/projects-bundle:v1 -f bundle -f deployment`
    `bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/projects-bundle:v1 -f bundle -f deployment`
   
    Explanation of the arguments:
    - `-b k8slt/projects-bundle:v1`: Repository where our bundle will be uploaded to
    - `-f bundle -f deployment`: there 2 folders contain the deployment files as well as the bundle configuration

## Deployment

For the consumers of the application the developer will have to provide the image repository and,
the SHA of the bundle in the above case it will be `k8slt/projects-bundle@sha256:77c7e2dd9293499a2a1f11fbba5cd57f36e11281c5fc6fd10d316b8824df70d7`

### Prerequirements for the installation
Since everything was package using Carvel Tool the consumer will have to download `imgpkg` and for this particular
application will also need `vendir` to manage other dependencies

### Transfer to local registry

This step is optional but usually recommend.

This is done by executing the following command
`bin/imgpkg copy -b k8slt/projects-bundle@sha256:77c7e2dd9293499a2a1f11fbba5cd57f36e11281c5fc6fd10d316b8824df70d7 --to-repo localhost:5000/projects-bundle-to-deploy`
`bin/imgpkg copy -b gcr.io/cf-k8s-lifecycle-tooling-klt/projects-bundle@sha256:77c7e2dd9293499a2a1f11fbba5cd57f36e11281c5fc6fd10d316b8824df70d7 --to-repo localhost:5000/projects-bundle-to-deploy`

Explanation of the arguments:
- `-b k8slt/projects-bundle@sha256:77c7e2dd9293499a2a1f11fbba5cd57f36e11281c5fc6fd10d316b8824df70d7`: Exact version of the software we want to run
- `--to-repo localhost:5000/projects-bundle-to-deploy`: local repository

Interesting things to note:
- All the images are copied to the same repository
- The copy is done using the SHA
- `imgpkg` ensures that SHA will never change

### Prepare customization of the configuration

What steps need to be done to customize and prepare to deploy the application
1. Retrieve the configuration for the app
   This is done by executing the following command
   `bin/imgpkg pull -b localhost:5000/projects-bundle-to-deploy@sha256:77c7e2dd9293499a2a1f11fbba5cd57f36e11281c5fc6fd10d316b8824df70d7 -o tmp/projects-bundle`
   Explanation of the arguments:
   - `-b localhost:5000/projects-bundle-to-deploy@sha256:77c7e2dd9293499a2a1f11fbba5cd57f36e11281c5fc6fd10d316b8824df70d7`: Exact version of the software we want to run
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
   Execute `bash ./prepare-env.sh` to retrieve the needed binaries and configuration

`bin/ytt -f config -f local_configuration/local_config --enable-experiment-schema`

### Deploy

This is done by executing the following command
`bin/ytt -f config -f local_configuration --enable-experiment-schema | bin/kbld -f- -f .imgpkg/images.yml | bin/kapp deploy -a team-1-projects-app -f- -y`

Above command steps:
1. Uses `ytt` to merge the application configuration with the local configuration
   
   Explanation of the arguments:
   - `-f config`: Application configured created by the application developer
   - `-f local_configuration`: Overrides creates by the deployer to configure application
    
2. Uses `kbld` to  update the OCI image location in the customized deployment configuration

   Explanation of the arguments:
    - `-f-`: Read from standard in as a file
    - `-f .imgpkg/images.yml`: Images Lock file with the translation information
    
3. Uses kapp to deploy the application

   Explanation of the arguments:
    - `-a team-1-projects-app`: Name of the deployment
    - `-f-`: Reads deployment manifest from standard in as a file

To check what is installed executing the following command
`bin/kapp inspect -a team-1-projects-app`
