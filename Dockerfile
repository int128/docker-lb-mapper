from centos:centos7

run yum install -y docker
volume /containers
add provision.sh /
cmd /provision.sh
