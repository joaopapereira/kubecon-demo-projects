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

run-demo:
	bin/kbld -f build.docker.yml -f deployment/config/app.yml --imgpkg-lock-output tmp/images.yml
	mkdir -p bundle/.imgpkg && cp tmp/images.yml bundle/.imgpkg/images.yml
	bin/imgpkg push -b k8slt/projects-bundle:v1 -f bundle -f deployment --lock-output tmp/bundle.lock.yml
	bin/imgpkg copy --lock tmp/bundle.lock.yml --to-repo localhost:5000/projects-bundle-to-deploy
	bin/imgpkg pull --lock tmp/bundle.lock.yml -o tmp/projects-bundle

run-deploy:
	cd tmp/projects-bundle && bash prepare-env.sh
	cd tmp/projects-bundle && bin/ytt -f config -f local_configuration --enable-experiment-schema | bin/kbld -f- -f .imgpkg/images.yml | bin/kapp deploy -a team-1-projects-app -f- -y

port-forward:
	kubectl port-forward -n team-1 deployment/projects-app :8080
