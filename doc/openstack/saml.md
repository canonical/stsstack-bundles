# Post-deployment instructions

The setup provided by the keystone-saml overlay makes use of the https://samltest.id service which is a mock service 
for testing SAML authentication.

Once the deployment has been completed (all keystone units are in ready state), please run through the following script:

```shell script
./tools/enable_samltestid.sh
```