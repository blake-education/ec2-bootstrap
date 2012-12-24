#!/bin/bash

set -e

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"
cd $HERE


BOOTSTRAP_HOME=https://raw.github.com/blake-education/ec2-bootstrap/master
S3_ROOT=ops.blakedev.com/bootstrap
WORKDIR=$HOME/bootstrap


mkdir $WORKDIR
cd $WORKDIR

JQ=./vendor/jq
S3CURL=./vendor/s3curl.pl

curl -O $BOOTSTRAP_HOME/vendor/jq
chmod 0755 $JQ

curl -O $BOOTSTRAP_HOME/vendor/s3curl.pl
chmod 0755 $S3CURL


ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
CREDENTIALS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE)
S3_ACCESS_KEY_ID=$(echo $CREDENTIALS | $JQ -r .AwsAccessKey)
S3_SECRET_KEY=$(echo $CREDENTIALS | $JQ -r .SecretAccessKey)
S3_TOKEN=$(echo $CREDENTIALS | $JQ -r .Token)

runurl () {
  $S3CURL --id $S3_ACCESS_KEY_ID --key $S3_SECRET_KEY -- -H "x-amz-security-token: $S3_TOKEN" $S3_ROOT/$1 | /bin/bash -e
}

runurl apt
runurl install_essentials
runurl install_ruby_build
runurl install_ruby
runurl install_git
runurl install_blake_cloud
