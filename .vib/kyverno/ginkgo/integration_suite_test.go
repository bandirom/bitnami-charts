// Copyright Broadcom, Inc. All Rights Reserved.
// SPDX-License-Identifier: APACHE-2.0

package integration

import (
	"context"
	b64 "encoding/base64"
	"flag"
	"fmt"
	"math/rand"
	"os"
	"testing"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	cv1 "k8s.io/client-go/kubernetes/typed/core/v1"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"

	// For client auth plugins

	_ "k8s.io/client-go/plugin/pkg/client/auth"
)

const APP_NAME = "kyverno"

var kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
var namespace = flag.String("namespace", "", "namespace where the resources are deployed")

func clusterConfigOrDie() *rest.Config {
	var config *rest.Config
	var err error

	if *kubeconfig != "" {
		config, err = clientcmd.BuildConfigFromFlags("", *kubeconfig)
	} else {
		config, err = rest.InClusterConfig()
	}
	if err != nil {
		panic(err.Error())
	}

	return config
}

func createTestingPodOrDie(ctx context.Context, c cv1.PodsGetter) *v1.Pod {
	// Provided pull secrets
	pullSecrets := []v1.LocalObjectReference{
		{Name: "cp-pullsecret-0"},
		{Name: "cp-pullsecret-1"},
		{Name: "cp-pullsecret-2"},
		{Name: "cp-pullsecret-3"},
	}

	scriptContent, _ := os.ReadFile("./scripts/kyverno-env-check.sh")
	securityContext := &v1.SecurityContext{
		Privileged:               &[]bool{false}[0],
		AllowPrivilegeEscalation: &[]bool{false}[0],
		RunAsNonRoot:             &[]bool{true}[0],
		Capabilities: &v1.Capabilities{
			Drop: []v1.Capability{"ALL"},
		},
		SeccompProfile: &v1.SeccompProfile{
			Type: "RuntimeDefault",
		},
	}

	podData := &v1.Pod{
		ObjectMeta: metav1.ObjectMeta{
			Namespace: *namespace,
			Name:      "vib-sample-" + fmt.Sprint(rand.Intn(100)),
			Labels: map[string]string{
				"app": "vib-sample",
			},
		},
		Spec: v1.PodSpec{
			ImagePullSecrets: pullSecrets,
			Containers: []v1.Container{
				{
					Name:       "vib-sample",
					Image:      "registry.app-catalog.vmware.com/eam/prd/containers/verified/common/minideb-bookworm/os-shell:latest",
					WorkingDir: "/tmp",
					Command: []string{
						"/bin/bash", "-c", "printenv SCRIPT | base64 -d | bash && sleep infinity"},
					Env: []v1.EnvVar{
						{
							Name:  "SCRIPT",
							Value: fmt.Sprint(b64.StdEncoding.EncodeToString([]byte(scriptContent))),
						},
					},
					SecurityContext: securityContext,
				},
			},
		},
	}
	result, err := c.Pods(*namespace).Create(ctx, podData, metav1.CreateOptions{})
	if err != nil {
		panic(fmt.Sprintf("There was an error creating the Pod: %s", err))
	}
	return result
}

func CheckRequirements() {
	if *namespace == "" {
		panic(fmt.Sprintf("The namespace where %s is deployed must be provided. Use the '--namespace' flag", APP_NAME))
	}
}

func TestIntegration(t *testing.T) {
	RegisterFailHandler(Fail)
	RunSpecs(t, fmt.Sprintf("%s Integration Tests", APP_NAME))
}
