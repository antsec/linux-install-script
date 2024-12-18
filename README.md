# Thank you
We are glad to see you are installing our collectors. This script will guide you through the installation as much as possible.

If you have any questions, feel free to contact us through your known channels.

For those who come across this page and don't know what it is for. Visit https://www.antsec.io

# Support
If you are unsure of anything we are here to help. Contact us and we will aid you through the process of installing the collectors.

This installer provides a basic configuration out of the box, which might not suit your needs. Feel free to contact us for further configuration.

Currently this works on Debian based linux systems. Tested platforms are:

* Debian 9
* Debian 10
* Ubuntu 14.04 LTS
* Ubuntu 16.04 LTS
* Ubuntu 18.04 LTS
* Ubuntu 20.04 LTS
* Ubuntu 22.04 LTS

# Components
The AntSec collector for Linux consists of 4 components.

* Event Collector (Audit Beat)
  * Collection of logs from the audit log.
* System collector (Metricbeat)
  * Collection of logs about the performance of the system.
* File Collector (Filebeat)
  * Collection of logs from files or receive logs from syslog which we forward to our central system.
* Network collector (Packetbeat)
  * Collection of logs of the network traffic of the system.

# Requirements
Please make sure the following requirements are available on the system:

* wget
* perl-Digest-SHA (shasum)
* Connection to athena.antsec.nl trough TCP port 7201.
* Certificate for connecting to our systems. The certificate is unique per customer.

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
