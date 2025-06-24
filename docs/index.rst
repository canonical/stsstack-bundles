STSStack-Bundles Documentation
==============================

STSStack-Bundles is a set of bundles that leverage Juju bundle overlays to allow generating complex deployments from a number of options using a single command. These bundles are designed for use with the Juju OpenStack provider.

The top level directory contains a set of modules, each of which has a generate-bundle.sh script which you can use to create a deployment from a number of options.

NOTE: see generate-bundle.sh --help for option info about using that particular module.

Basic usage:

 * give your deployment a name with (--name)
 * create a Juju model using the given name or use existing one
 * add one or more feature overlays depending on what you need (see --list-overlays)
 * resources are stored under a named directory so as to be able to avoid collisions and replay later (--replay)
 * immediate deploy (--run) or save for later


.. toctree::
   :hidden:
   :maxdepth: 2

   Users </user-docs/index>
   Contributors </contrib-docs/index>

In this documentation
---------------------

.. grid:: 1 1 2 2

   .. grid-item-card:: User Docs
      :link: /user-docs/index
      :link-type: doc

      **For users and operators** - how to use and operator STSStack-Bundles.

   .. grid-item-card:: Contributor Docs
      :link: /contrib-docs/index
      :link-type: doc

      **For contributors** - how to contribute to STSStack-Bundles.

