#!/bin/bash

service supervisor start &&\
sleep 10 &&\
supervisorctl status &&\
/bin/bash -l $*
