// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/joaopapereira/kubecon-demo-projects/pkg/api/types/v1alpha1"
	clientV1alpha1 "github.com/joaopapereira/kubecon-demo-projects/pkg/clientset/v1alpha1"
	"github.com/joaopapereira/kubecon-demo-projects/pkg/project"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes/scheme"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

var kubeconfig string

func init() {
	flag.StringVar(&kubeconfig, "kubeconfig", "", "path to Kubernetes config file")
	flag.Parse()
}

func main() {
	var clusterConfig *rest.Config
	var err error

	if os.Getenv("LOCAL_START") != "" {
		clusterConfig, err = retrieveLocalConfiguration()
		if err != nil {
			log.Fatalf("unable to retrieve local configuration: %s", err.Error())
		}
	} else {
		clusterConfig, err = retrieveClusterConfiguration()
		if err != nil {
			log.Fatalf("unable to retrieve cluster configuration: %s", err.Error())
		}
	}

	err = v1alpha1.AddToScheme(scheme.Scheme)
	if err != nil {
		panic(fmt.Sprintf("unable to add scheme: %s", err))
	}

	clientSet, err := clientV1alpha1.NewForConfig(clusterConfig)
	if err != nil {
		panic(err)
	}

	ns, found := os.LookupEnv("TEAM_NAME")
	if !found {
		ns = "default"
	}

	projects, err := clientSet.Projects(ns).List(metav1.ListOptions{})
	if err != nil {
		panic(err)
	}

	fmt.Printf("projects found: %+v\n", projects)
	handler := project.HttpHandler(clientSet.Projects(ns))
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func retrieveLocalConfiguration() (*rest.Config, error) {
	var kubeconfig *string
	if home := homeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()
	// use the current context in kubeconfig
	clusterConfig, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		panic(err.Error())
	}
	return clusterConfig, err
}

func retrieveClusterConfiguration() (*rest.Config, error) {
	clusterConfig, err := rest.InClusterConfig()
	if err != nil {
		log.Fatalf("could not get kubernetes in-cluster config: %s", err.Error())
	}
	return clusterConfig, err
}
func homeDir() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	return os.Getenv("USERPROFILE") // windows
}
