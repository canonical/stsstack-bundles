=================================
Keycloak guide + Keystone-OpenIDC
=================================

1) Install Keycloak
===================

In a model with keystone Yoga deployed:

.. code-block:: console

  juju deploy ubuntu --series jammy

Ssh to the unit upon deployment completion

Access `[1]`_, download the zip and install the appropriate open JDK version and unzip, for example:

.. code-block:: console

  sudo apt install -y openjdk-21-jre unzip

  wget https://github.com/keycloak/keycloak/releases/download/26.2.5/keycloak-26.2.5.zip

  unzip keycloak-26.2.5.zip

  cd keycloak-26.2.5

Generate a self-signed certificate:

.. code-block:: console

  openssl req -newkey rsa:2048 -nodes \
    -keyout keycloak-server.key.pem -x509 -days 3650 -out keycloak-server.crt.pem

Responses:

.. code-block:: console

  Country Name (2 letter code) []: AU
  State or Province Name (full name) []: Some-State
  Locality Name (eg, city) []: Denver
  Organization Name (eg, company) []: Internet Widgits Pty Ltd
  Organizational Unit Name (eg, section) []: Canonical
  Common Name (eg, fully qualified host name) []: <Your_VM_IP> 10.149.138.19
  Email Address []: ubuntu@canonical.com

Start keycloak for the first time:

.. code-block:: console

  ./bin/kc.sh start-dev --https-port=8081 --https-certificate-file=keycloak-server.crt.pem --https-certificate-key-file=keycloak-server.key.pem

Use ``sshuttle`` and access the Keycloak VM IP (10.149.138.19 in this example): ``https://<VM_IP>:8081``

It will hit an error saying local access is necessary

Abort the **kc.sh** process and re-run as:

.. code-block:: console

  bin/kc.sh bootstrap-admin user --username tmpadm

Once it finishes, on a ``screen``/``tmux``/``byobu``, re-run:

.. code-block:: console

  ./bin/kc.sh start-dev --https-port=8081 --https-certificate-file=keycloak-server.crt.pem --https-certificate-key-file=keycloak-server.key.pem

Login as ``tmpadm``, click the side-bar and proceed to:

* Manage realms > create new realm > Realm name: ``myrealm`` > Create

* Users > Create new user > username: ``jdoe`` > Create

* ``jdoe`` user > Credentials > Set password > Temporary=Off

* Clients > Create client > Client ID: ``openstack``

  * Client authentication: ``On``, Standard flow: ``True``, Implicit flow: ``True``

  * Root URL = Home URL = Web Origins = Valid post logout redirect URIs = ``http://<keystone>:5000/v3``

  * Valid redirect URIs = ``http://<keystone>:5000/v3/auth/OS-FEDERATION/websso/openid``
  * (Obs: if the IDP supports multiple values for "Valid redirect URIs" (Keycloak does) then it is good to also include ``http://<keystone>:5000/v3/redirect_uri`` because it solves the upgrade issue later)
  * Create client

* openstack client > Credentials > Copy client secret (``3DuWbK41tAbIdGHyaNigykQNbhxVUABm``)

2) Install keycloak cert in Keystone
====================================

Ssh to keystone unit as root

Copy ``keycloak-server.crt.pem`` contents from keycloak VM to ``/usr/share/ca-certificates/keycloak.crt`` in keystone unit

Run ``dpkg-reconfigure ca-certificates``, choose ``ask``, select ``keycloak.crt``

Test ``curl https://10.149.138.19:8081/realms/myrealm/.well-known/openid-configuration``

3) Install ``keystone-openidc`` charm
=====================================

a) If using yoga/stable rev 5:
------------------------------

Bundle overlay:

.. code-block:: yaml

  applications:
    keystone-openidc:
      charm: keystone-openidc
      channel: yoga/stable
      revision: 5
      options:
        debug: true
        oidc-client-id: openstack
        oidc-client-secret: 3DuWbK41tAbIdGHyaNigykQNbhxVUABm
        oidc-provider-metadata-url: https://10.149.138.19:8081/realms/myrealm/.well-known/openid-configuration
        user-facing-name: keycloak
  relations:
    - ["keystone-openidc", "keystone"]
    - ["keystone-openidc", "openstack-dashboard"]
    - ["keystone:websso-trusted-dashboard", "openstack-dashboard:websso-trusted-dashboard"]

b) If deploying any charm revision newer than rev 5 directly:
-------------------------------------------------------------

* Include in the options section::

    idp_id: openid

* Refer to section **(6)** to apply the SSL workaround if necessary

4) Configure keystone IDP
=========================

commands:

.. code-block:: console

  openstack domain create federated_domain
  openstack group create federated_users --domain federated_domain
  GROUP_ID=$(openstack group show federated_users --domain federated_domain |grep -v domain_id|grep id|awk '{print $4}')
  openstack role add --group ${GROUP_ID} --domain federated_domain member
  DOMAIN_ID=$(openstack domain show federated_domain |grep id |awk '{print $4}')
  openstack project create --domain ${DOMAIN_ID} project1_federated
  PROJECT_ID=$(openstack project show --domain federated_domain -f value -c id project1_federated )
  openstack role add --project ${PROJECT_ID} --group ${GROUP_ID} member
  openstack quota set --instances -1 --cores -1 --gigabytes -1 --ram -1 --server-groups -1 --ports -1 --secgroup-rules -1 --volumes -1 --snapshot -1 --ram -1 ${PROJECT_ID}

  cat > rules.json << EOF
  [{
      "local": [
          {
              "user": {
                  "name": "{0}"
              },
              "group": {
                  "domain": {
                      "id": "${DOMAIN_ID}"
                  },
                  "name": "federated_users"
              },
              "projects": [
              {
                  "name": "project1_federated",
                  "roles": [
                      {
                          "name": "member"
                      }
                  ]
              }
              ]
           }
      ],
      "remote": [
          {
              "type": "HTTP_OIDC_EMAIL"
          }
      ]
  }]
  EOF

  openstack mapping create --rules rules.json openid_mapping
  openstack identity provider create --remote-id https://<keycloak_VM_IP>:8081/realms/myrealm openid
  openstack federation protocol create openid --mapping openid_mapping --identity-provider openid

5) Workaround for non-keycloak IDP
==================================

If you are **NOT** using keycloak **AND** using yoga/stable rev 5, you may need to edit ``/var/lib/juju/agents/unit-keystone-openidc-0/charm/templates/apache-openidc-location.conf`` in keystone unit and replace the first settings with (more specifically ``OIDCSSLValidateServer`` and ``OIDCResponseType``):

.. code-block:: console

  OIDCClaimPrefix "OIDC-"
  OIDCResponseType "id_token token"
  #OIDCResponseType "id_token"
  OIDCScope "openid email profile"
  OIDCSSLValidateServer Off

Flip ``juju config keystone-openidc debug`` to force a config update.

6) Workaround for SSL issue on ``rev > 5``
==========================================

You may see the following message when deploying ``rev > 5`` directly or upgrading from ``rev == 5`` despite having installed the self-signed SSL and configured oidc-provider-metadata-url in the bundle when using ``rev > 5``:

.. code-block:: console

  required keys: oidc-oauth-introspection-endpoint

To hack yourself away from this issue you may want to edit ``/var/lib/juju/agents/unit-keystone-openidc-0/charm/./src/charm.py`` line 155 and change ``verify=False``.


7) Workaround for missing config file when deploying ``rev > 5`` directly
=========================================================================

If you deployed ``keystone-openidc`` ``rev > 5`` directly with all configs correctly set, you may find yourself in a situation where the charm is active/idle but did not create the ``/etc/apache2/openidc/apache-openidc-location.conf`` file. To force the creation of the file you can flip ``juju config keystone-openidc debug`` forcing the charm to write it.

8) Access dashboard at Horizon IP
=================================

Choose ``keycloak``, login with username ``jdoe``.

9) Upgrading from yoga/stable ``rev 5``
=======================================

Upon upgrading the charm from ``rev 5`` you will see the following charm status message:

.. code-block:: console

  required keys: idp_id

Upgrading doesn't cause immediately downtime until the charm is able to update the apache2 config file. It will not do so until the new configs are set, such as below:

.. code-block:: console

  juju config keystone-openidc idp_id=openid

However, the redirect URI changed upon upgrading the charm, requiring an update in keycloak, where "Valid redirect URIs" was ``http://<keystone>:5000/v3/auth/OS-FEDERATION/websso/openid``, now should be ``http://<keystone>:5000/v3/redirect_uri``.

To upgrade smoothly, the IDP must be configured with **BOTH** Redirect URIs if the IDP supports multiple values (like a list of values). You may have already included both URIs if you followed this guide so there may be nothing to do here.

Finally, the value of ``OIDCResponseType "id_token token"`` changed to ``OIDCResponseType "id_token"``, however I noticed no detrimental impact when using keycloak, but it may affect other IDPs.

Sources:

_`[1]` https://www.keycloak.org/getting-started/getting-started-zip

[2] https://medium.com/@buffetbenjamin/keycloak-essentials-openid-connect-c7fa87d3129d

[3] https://medium.com/keycloak/running-keycloak-with-tls-self-signed-certificate-d8da3e10c544

[4] https://www.keycloak.org/server/bootstrap-admin-recovery
