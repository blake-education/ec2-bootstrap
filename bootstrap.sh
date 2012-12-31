#!/bin/bash

set -ex

HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"
cd $HERE


BOOTSTRAP_HOME=https://raw.github.com/blake-education/ec2-bootstrap/master
S3_ROOT=http://s3.amazonaws.com/ops.blakedev.com/bootstrap
WORKDIR=$HOME/bootstrap


mkdir -p $WORKDIR/vendor
cd $WORKDIR


export PATH=/usr/local/bin:$PATH
mkdir -p /usr/local/bin

( cd /usr/local/bin
  curl -s -LO $BOOTSTRAP_HOME/vendor/jq
  curl -s -LO $BOOTSTRAP_HOME/vendor/s3curl.pl

  chmod 0755 jq
  chmod 0755 s3curl.pl
)

apt-get install libdigest-hmac-perl


ROLE=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/)
CREDENTIALS=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE)
S3_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r .AccessKeyId)
S3_SECRET_KEY=$(echo $CREDENTIALS | jq -r .SecretAccessKey)
S3_TOKEN=$(echo $CREDENTIALS | jq -r .Token)

cat <<EODOTFILE > ~/.s3curl
%awsSecretAccessKeys = (
  iam => {
      id => '$S3_ACCESS_KEY_ID',
      key => '$S3_SECRET_KEY',
  }
);
EODOTFILE

chmod 0600 ~/.s3curl

dl () {
  s3curl.pl --id iam -- -H "x-amz-security-token: $S3_TOKEN" -f -s $S3_ROOT/$1
}

runurl () {
  echo
  echo running url $1 >> /var/log/blake-bootstrap.log
  echo
  dl $1 | /bin/bash -ex >> /var/log/blake-bootstrap.log 2>&1
}


runurl apt
runurl install_essentials
runurl install_ruby_build
runurl install_ruby
runurl install_ruby_essentials
runurl install_git
runurl install_blake_cloud

BC=/var/lib/blake-cloud/blake_cloud.sh
dl files/blake_cloud.sh > $BC
chmod 0700 $BC


GET_INSTANCE_NAME=/usr/local/bin/get_instance_name
dl files/get_instance_name > $GET_INSTANCE_NAME
chmod 0700 $GET_INSTANCE_NAME
