#!/bin/bash
helm pull oci://harbor.158.160.142.165.nip.io/library/frontend --version 0.1.0 
helm pull oci://harbor.158.160.142.165.nip.io/library/hipster-shop --version 0.1.0 
tar -xzvf frontend-0.1.0.tgz
tar -xzvf hipster-shop-0.1.0.tgz


