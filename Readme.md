# Demo of Carvel Tool Suite

![logo](assets/CarvelLogo.png)

The Carvel Tool Suite website [carvel.dev](https://carvel.dev)

## Setting up the development environment

### Prerequirements

## Create the thing application

Generate image with code

```bash
mkdir -p tmp
bin/kbld -f build.docker.gcr.yml -f deployment/config/app.yml --imgpkg-lock-output tmp/images.yml
```

Presentation layout Before the demo:

```bash
bin/kapp deploy -a kc -f https://raw.githubusercontent.com/vmware-tanzu/carvel-kapp-controller/dev-packaging/alpha-releases/v0.18.0-alpha.5.yml
```

### Demo part 1

#### Before starting

Creates the namespace, and the service account needed by `kapp-controller` to install the application

```bash
make setup-demo-1
```

#### Steps of the demo

We are using a Helm application, but we can use ytt or manifest This is a Hello World application that writes to the
logs some text Look at the App Custom Resource As Helen mentioned before we are retrieving the configuration for our
application from a git repository, this is the repository I have checked out in my editor. The App Custom Resource
templates the manifests that are present in the git repository and afterwards deploys

1. Apply the App CR
   `bin/kapp deploy -a demo-1 -f demo/01-simple-app-cr/config/app-cr.git.yml`
1. Check the yaml
   `kubectl get pod -n demo-1-ns`
1. Look at the logs to check the message
   `kubectl logs -n demo-1-ns -lapp.kubernetes.io/instance=simple-app`

END: Lets see how can we build up from this scenario

### Demo part 2

#### Before starting

1. Creates the namespace, and the service account needed by `kapp-controller` to install the application
   ```bash
   make setup-demo-2
   ```
1. Create the bundle

```bash
mkdir -p tmp/bundle/.imgpkg
helm template hello-world-app demo/01-simple-app-cr/hello-world | bin/kbld -f- --imgpkg-lock-output tmp/bundle/.imgpkg/images.yml
bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/demo-hello-world-bundle -f tmp/bundle/ -f demo/01-simple-app-cr/hello-world
```

#### Steps of the demo

1. Operator defines the package and make it available to be installed later
   `bin/kapp deploy -a package-bundle -f demo/02-simple-package-cr/package.bundle.yml`
1. Check the yaml
   `kubectl get package hello-world-helm.1.0.0`
1. Instantiate the application from the package previously defined
   `bin/kapp deploy -a installed-package-bundle -f demo/02-simple-package-cr/installed.package.yml`
1. Check that a pod was created with the updated environment variable
   `kubectl get pod -n demo-2-ns`
1. Look at the logs to check the message
   `kubectl logs -n demo-2-ns -lapp.kubernetes.io/instance=hello-world-1-0-0`

END: Lets see how can we build up from this scenario

### Demo part 3

#### Before starting

1. Creates the namespace, and the service account needed by `kapp-controller` to install the application
   ```bash
   make setup-demo-3
   ```
1. Create the bundles

```bash
mkdir -p tmp/bundle/.imgpkg
helm template hello-world-app demo/01-simple-app-cr/hello-world | bin/kbld -f- --imgpkg-lock-output tmp/bundle/.imgpkg/images.yml
bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/demo-hello-world-bundle -f tmp/bundle/ -f demo/03-package-repository-cr/hello-world-1.1.0
bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/demo-hello-world-bundle -f tmp/bundle/ -f demo/03-package-repository-cr/hello-world-2.0.0
bin/kbld -f demo/03-package-repository-cr/repository-v1 --imgpkg-lock-output tmp/package-repository-bundle/.imgpkg/images.yml 
bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/demo-package-repository:latest -f demo/03-package-repository-cr/repository-v1 -f tmp/package-repository-bundle
```

#### Steps of the demo

I created

1. Check all the installed packages before creating the package repository
   `kubectl get packages`
1. Create the package repository from an OCI Image
   `bin/kapp deploy -a package-repository -f demo/03-package-repository-cr/package-repository.yaml`
1. Check all the available packages
   `kubectl get packages`

#### Automatic update of versions

Talk about creating a package registry

1. Producer would add a new version
   ```bash
   bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/demo-package-repository:latest -f demo/03-package-repository-cr/repository-v2
   ```
1. Check the packages available
   `kubectl get packages`
