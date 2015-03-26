#!/bin/sh

bundle install --without api

bundle exec rake check:yaml:build_spec

bundle exec rake ios:clean:all
bundle exec rake android:clean

bundle exec rake utest || exit $?

envchain my_app bundle exec rake android:build
envchain my_app bundle exec rake android:build_sandbox
