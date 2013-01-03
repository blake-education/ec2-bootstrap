#!/bin/bash

# put everything in a subshell so we can log the output
(
set -ex

date

# HOME was cleaned from the environment
export HOME=/root
export PATH=/usr/local/bin:$PATH

env


HERE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"
cd $HERE


BOOTSTRAP_HOME=https://raw.github.com/blake-education/ec2-bootstrap/master
S3_ROOT=http://s3.amazonaws.com/ops.blakedev.com/bootstrap
WORKDIR=$HOME/bootstrap


mkdir -p $WORKDIR/vendor
cd $WORKDIR


mkdir -p /usr/local/bin

( cd /usr/local/bin
  curl -s -LO $BOOTSTRAP_HOME/vendor/jq
  curl -s -LO $BOOTSTRAP_HOME/vendor/s3curl.pl

  chmod 0755 jq
  chmod 0755 s3curl.pl
)


apt-get -y install libdigest-hmac-perl python-setuptools

easy_install https://github.com/blake-education/aws-cfn-bootstrap/archive/master.tar.gz


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




CREDENTIAL_FILE=$HOME/.cfn-credentials

cat <<EOCREDENTIALS > $CREDENTIAL_FILE
AWSAccessKeyId=$S3_ACCESS_KEY_ID
AWSSecretKey=$S3_SECRET_KEY
SecurityToken=$S3_TOKEN
EOCREDENTIALS

chmod 0600 $CREDENTIAL_FILE


function error_exit {
  cfn-signal -e 1 -r "$1" "$CFN_WAITHANDLE"
  exit 1
}


# init cfn
cfn-init --region "$CFN_REGION" \
         -s "$CFN_STACK" \
         -r "$CFN_RESOURCE_ID" \
         --credential-file "$CREDENTIAL_FILE" || error_exit 'Failed to run cfn-init'



dl () {
  s3curl.pl --id iam -- -H "x-amz-security-token: $S3_TOKEN" -f -s $S3_ROOT/$1
}

runurl () {
  echo
  echo running url $1
  echo
  dl $1 | /bin/bash -ex
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


cfn-signal -e 0 -r 'Server configuration' "$CFN_WAITHANDLE"

) 2>&1 | tee --append /var/log/blake-bootstrap.log
