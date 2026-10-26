#!/system/bin/sh
#
# Copyright (c) 2018 Amazon.com, Inc. or its affiliates.  All rights reserved.
# PROPRIETARY/CONFIDENTIAL.  USE IS SUBJECT TO LICENSE TERMS.
#

# Provide required permission to directories in /tee partition
/system/bin/find /tee -type d -not -perm -700 -exec chmod 700 {} \;
