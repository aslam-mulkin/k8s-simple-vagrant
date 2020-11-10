#!/usr/bin/env bash

#deploy metric-server v0.4
kubectl apply -f /vagrant/components.yaml
#verify with kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

#deploy dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.4/aio/deploy/recommended.yaml

# Make the dashboard a NodePort ganti ini
#kubectl patch svc -n kubernetes-dashboard kubernetes-dashboard  -p '{"spec": {"type": "NodePort", "ports": [{"nodePort": 8443, "port": 443}] }}'
kubectl patch svc -n kubernetes-dashboard kubernetes-dashboard  -p '{"spec": {"type": "NodePort"}}'

#Create admin user for dashboard
#kubectl apply -f /vagrant/k8s-dashboard-admin.yml
kubectl apply -f /vagrant/dashboard-admin.yml

# Get IP of first master
dashboard_port=$(kubectl -n kubernetes-dashboard get svc kubernetes-dashboard --no-headers -o custom-columns=PORT:.spec.ports.*.nodePort)
master_ip=$(kubectl get nodes -l node-role.kubernetes.io/master= --no-headers -o custom-columns=IP:.status.addresses.*.address | cut -f1 -d, | head -1)

# Get access token
token=$(kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}') | grep ^token: | awk '{print $2}')

export dashboard_url="https://${master_ip}:${dashboard_port}"

# Print Dashboard address
echo
echo "Dashboard is available at: ${dashboard_url}"

# Print token
echo
echo "Access token: ${token}"
echo
