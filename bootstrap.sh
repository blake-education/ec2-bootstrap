#!/bin/bash

set -e

BOOTSTRAP_HOME=https://raw.github.com/blake-education/ec2-bootstrap/master

runurl () {
  curl $BOOTSTRAP_HOME/scripts/$1 | /bin/bash -e
}


runurl apt
runurl install_essentials
runurl install_ruby_build
runurl install_ruby
runurl install_git
runurl install_puppet

