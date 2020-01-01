#!/usr/bin/env python3

from kubernetes import client, config

config.load_kube_config(config_file='admin.conf')

v1 = client.CoreV1Api()
podList = v1.list_pod_for_all_namespaces()
for i in podList.items:
    print("%s\t%s\t%s" % (i.status.pod_ip, i.metadata.namespace, i.metadata.name))
