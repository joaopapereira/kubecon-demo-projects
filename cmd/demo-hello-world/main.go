// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: Apache-2.0

package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)
func main() {
	msg := os.Getenv("VERSION") + ":" + os.Getenv("MESSAGE")
	fmt.Printf("The message being printed is: %s\n\n", msg)
	http.HandleFunc("/", func(w http.ResponseWriter, request *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(msg))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
