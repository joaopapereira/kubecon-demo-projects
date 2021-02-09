define CONFIG_PROJECTS_DEMO
  - path: local_configuration
    contents:
      - path: .
        git:
          url: https://github.com/joaopapereira/webinar-demo-projects
          ref: origin/local_configuration
endef
export CONFIG_PROJECTS_DEMO

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

run-demo: get-carvel
	bin/kbld -f build.docker.gcr.yml -f deployment/config/app.yml --imgpkg-lock-output tmp/images.yml
	mkdir -p bundle/.imgpkg && cp tmp/images.yml bundle/.imgpkg/images.yml
	mkdir tmp
	bin/imgpkg push -b k8slt/projects-bundle:v1 -f bundle -f deployment --lock-output tmp/bundle.lock.yml
	bin/imgpkg copy --lock tmp/bundle.lock.yml --to-repo localhost:5000/projects-bundle-to-deploy
	bin/imgpkg pull --lock tmp/bundle.lock.yml -o tmp/projects-bundle
	echo "$$CONFIG_PROJECTS_DEMO" >>tmp/projects-bundle/vendir.yml
	cat tmp/projects-bundle/vendir.yml
	cd tmp/projects-bundle && bash prepare-env.sh
	cd tmp/projects-bundle && bin/ytt -f config -f local_configuration --enable-experiment-schema | bin/kbld -f- -f .imgpkg/images.yml | bin/kapp deploy -a team-1-projects-app -f- -y

port-forward:
	echo "Application running in http://localhost:51130"
	kubectl port-forward -n team-1 deployment/projects-app 51130:8080
