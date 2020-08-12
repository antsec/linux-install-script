# Thank you
We are glad to see you are installing our collectors. This script will guide you through the installation as much as possible.

If you have any questions, feel free to contact us through your known channels.

For those who come across this page and don't know what it is for. Visit https://www.antsec.io

# Support
If you are unsure of anything we are here to help. Contact us and we will aid you through the process of installing the collectors.

This installer provides a basic configuration out of the box, which might not suit your needs. Feel free to contact us for further configuration.

# Installation
- Either clone the repository or download the zip file and upload the files of the repository to the designated server
- Extract the contents with 

```unzip linux-install-script-master.zip```

- Enter the directory with 

```cd linux-install-script-master```

- Place the received certificates in the certificates folder. The structure will look like this:

  - as-install-collectors&#46;sh
  - certificates/

    - antsec.cacerts
    - certificate.crt
    - certificate.key

- Run the command either interactively or semi-silent by using any of the following commands

```
#Install interactively
sudo bash ./as-install-collectors.sh -i

#Review the silent parameters
sudo bash ./as-install-collectors.sh -h
```

- Follow the instructions on the screen to complete the installation

# Responsible Disclosure
If you come across any (possible) vulnerabilities or have any security considerations, please contact us at security@antsec.io
