generate-bundle.sh
==================

The `generate-bundle.sh` script is used to create a bundle, and optionally deploy it, of a Charmed OpenStack, Kubernetes, or Ceph deployment.

Usage
-----

Run the script from the project root:

.. code::

    ./generate-bundle.sh

This will generate the necessary files for deployment in the `b` directory.

Options
-------

You can pass additional options to customise the build process. For example:

.. code::

    ./generate-bundle.sh --keystone-ha --num-compute 2 --run

Prerequisites
-------------

Make sure you have all required dependencies installed before running the script.
