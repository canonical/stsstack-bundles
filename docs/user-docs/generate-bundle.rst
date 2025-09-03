generate-bundle.sh
==================

The `generate-bundle.sh` script is used to create a production-ready bundle of the application. It automates the process of packaging source files and dependencies into a single distributable file.

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

    ./generate-bundle.sh --minify --sourcemaps

Prerequisites
-------------

Make sure you have all required dependencies installed before running the script.
