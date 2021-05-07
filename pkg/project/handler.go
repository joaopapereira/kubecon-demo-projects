// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: Apache-2.0

package project

import (
	"fmt"
	"net/http"

	"github.com/joaopapereira/kubecon-demo-projects/pkg/clientset/v1alpha1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/util/json"
)

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hi there, I love %s!", r.URL.Path[1:])
}

type httpProject struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

func HttpHandler(client v1alpha1.ProjectInterface) func(w http.ResponseWriter, r *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		projects, err := client.List(metav1.ListOptions{})
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("error: %s", err)))
		}

		var allProjects []httpProject
		for _, project := range projects.Items {
			allProjects = append(allProjects, httpProject{
				Name:        project.Spec.Name,
				Description: project.Spec.Description,
			})
		}

		data, err := json.Marshal(allProjects)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("error: %s", err)))
		}

		w.WriteHeader(http.StatusOK)
		w.Write(data)
	}
}
