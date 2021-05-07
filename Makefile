define CONFIG_PROJECTS_DEMO
  - path: local_configuration
    contents:
      - path: .
        git:
          url: https://github.com/joaopapereira/webinar-demo-projects
          ref: origin/local_configuration
endef
export CONFIG_PROJECTS_DEMO

define DEMOX_SETUP
apiVersion: v1
kind: Namespace
metadata:
  name: demo-X-ns
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-X-sa
  namespace: demo-X-ns
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: demo-X-deployment-role
  namespace: demo-X-ns
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["get", "list", "create", "update"]
- apiGroups: [""]
  resources: ["services", "serviceaccounts", "pods"]
  verbs: ["create", "get", "list", "update"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "get", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: demo-X-sa-role-binding
  namespace: demo-X-ns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: demo-X-deployment-role
subjects:
- kind: ServiceAccount
  name: demo-X-sa
  namespace: demo-X-ns
endef

.EXPORT_ALL_VARIABLES:
DEMO1_SETUP =${subst demo-X,demo-1,$(DEMOX_SETUP)}
DEMO2_SETUP =${subst demo-X,demo-2,$(DEMOX_SETUP)}
DEMO3_SETUP =${subst demo-X,demo-3,$(DEMOX_SETUP)}

get-carvel:
	@echo "+---------------------------------------+"
	@echo "| Using vendir to download carvel tools |"
	@echo "+---------------------------------------+"
	vendir sync

	@echo "+----------------------+"
	@echo "| copy tools to ./bin/ |"
	@echo "+----------------------+"
	cp bin/github.com/vmware-tanzu/carvel-imgpkg/imgpkg-darwin-amd64 bin/imgpkg
	chmod u+x bin/imgpkg
	cp bin/github.com/vmware-tanzu/carvel-kapp/kapp-darwin-amd64 bin/kapp
	chmod u+x bin/kapp
	cp bin/github.com/vmware-tanzu/carvel-kbld/kbld-darwin-amd64 bin/kbld
	chmod u+x bin/kbld
	cp bin/github.com/vmware-tanzu/carvel-ytt/ytt-darwin-amd64 bin/ytt
	chmod u+x bin/ytt

run-demo: get-carvel setup-demo-1 setup-demo-2 setup-demo-3 create-app-image install-kapp-controller
	@make demo
demo: .*
	@make demo-1
	@echo "Press Enter to continue"
	@read
	@make demo-2

demo-1: setup-demo-1
	@echo "+========================================+"
	@echo "|               Demo Part 1              |"
	@echo "+========================================+"
	@echo "Instantiate an application using App Custom Resource"
	@bin/kapp deploy -a demo-1 -f demo/01-simple-app-cr/config/app-cr.yml -y
	@echo "Check the yaml from the resource after applying to the cluster"
	@kubectl get app -n demo-1-ns -o yaml
	@echo "Press Enter to continue"
	@read
	@echo "Check the logs to ensure the application is running have the correct version"
	@kubectl logs -n demo-1-ns -lapp.kubernetes.io/instance=simple-app

demo-2: setup-demo-2
	@echo "+========================================+"
	@echo "|               Demo Part 2              |"
	@echo "+========================================+"
	@echo "Operator defines the package and make it available to be installed later"
	@bin/kapp deploy -a package-bundle -f demo/02-simple-package-cr/package.bundle.yml -y
	@echo "Check the yaml from the Package Custom Resource after applying to the cluster"
	@kubectl get package hello-world-helm.1.0.0 -o yaml
	@echo "Press Enter to continue"
	@read
	@echo "Instantiate the application from the package previously defined"
	@bin/kapp deploy -a installed-package-bundle -f demo/02-simple-package-cr/installed.package.yml -y
	@echo "Check the yaml from the InstalledPackage Custom Resource after applying to the cluster"
	@kubectl get installedpackage -n demo-2-ns -o yaml
	@echo "Press Enter to continue"
	@read
	@echo "Check that a pod was created with the updated environment variable"
	@kubectl get pod -n demo-2-ns -o yaml
	@echo "Press Enter to continue"
	@read
	@echo "Check the logs to ensure the application is running have the correct version and overlay"
	@kubectl logs -n demo-2-ns -lapp.kubernetes.io/instance=hello-world-1-0-0
	@echo "Press Enter to continue"
	@read

port-forward:
	echo "Application running in http://localhost:51130"
	kubectl port-forward -n team-1 deployment/projects-app 51130:8080

setup-demo-1:
	@echo "Create the namespace and service account for demo 1"
	@echo "$$DEMO1_SETUP" | bin/kapp deploy -a demo-1-setup -f- -y

setup-demo-2:
	@echo "Create the namespace and service account for demo 2"
	@echo "$$DEMO2_SETUP" | bin/kapp deploy -a demo-2-setup -f- -y

setup-demo-3:
	@echo "Create the namespace and service account for demo 3"
	@echo "$$DEMO3_SETUP" | bin/kapp deploy -a demo-3-setup -f- -y
	@echo "Create a bundle with Helm Chart and pointing to the Application OCI Image"
	@mkdir -p tmp/bundle/.imgpkg
	@helm template hello-world-app demo/01-simple-app-cr/hello-world | bin/kbld -f- --imgpkg-lock-output tmp/bundle/.imgpkg/images.yml
	@bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/demo-hello-world-bundle -f tmp/bundle/ -f demo/01-simple-app-cr/hello-world
	@echo "Create the repository v1"
	@bin/imgpkg push -b gcr.io/cf-k8s-lifecycle-tooling-klt/demo-package-repository:latest -f demo/03-package-repository-cr/repository-v1


install-kapp-controller:
	@echo "Install alpha version of kapp-controller"
	@bin/kapp deploy -a kc -f https://raw.githubusercontent.com/vmware-tanzu/carvel-kapp-controller/dev-packaging/alpha-releases/v0.18.0-alpha.5.yml

create-app-image:
	@echo "Creating application image and pushing it to gcr"
	@mkdir -p tmp
	@bin/kbld -f build.docker.gcr.yml -f deployment/config/app.yml --imgpkg-lock-output tmp/images.yml
