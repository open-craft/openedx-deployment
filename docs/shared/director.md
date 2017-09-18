Director Setup
==============

The `director` instance is used to run ansible playbooks in the
[`edx/configuration`](https://github.com/edx/configuration) repo.

When we [deploy an instance or an upgrade](../openstack-openedx/aws-deployment.md), we don't SSH directly into the server.
Instead, we SSH to the `director`, and from `director` we SSH to the server we're deploying.
This is done for security (the server only accepts SSH connections from `director`) and to offer us a stable environment with the right versions.

Requirements
------------

Bootstrap the director instance by installing these packages:

```bash
# Install git, pip, and build libraries
sudo apt-get install git python-pip python-dev build-essential libssl-dev libffi-dev

# Install mysql client and dev packages
sudo apt-get install libmysqlclient-dev mysql-client
```

Set up python virtualenv:

```bash
sudo pip install virtualenv virtualenvwrapper
mkdir ~/virtualenvs
echo "export WORKON_HOME=~/virtualenvs" >> ~/.bashrc
echo "source /usr/local/bin/virtualenvwrapper.sh" >> ~/.bashrc
echo "export PIP_VIRTUALENV_BASE=~/virtualenvs" >> ~/.bashrc
source ~/.bashrc
```

Create and activate a python virtualenv to install the configuration dependencies:

```bash
mkvirtualenv edx-configuration
```

If you've already created the virtualenv in a previous step, then you can activate it using:

```bash
workon edx-configuration
```

Clone [`edx/configuration`](https://github.com/edx/configuration) repo, and install its python dependencies:

```bash
git clone https://github.com/edx/configuration.git
cd configuration
make requirements
```

This will install `ansible` among other depencencies.


Upgrading `director`
--------------------

A new openedx release can include a newer version of `ansible` or other Python packages. Because ansible playbooks are to be run from `director`, we must update the packages in `director`'s virtualenv. To do so:

```bash
workon edx-configuration
cd configuration
make requirements
```
