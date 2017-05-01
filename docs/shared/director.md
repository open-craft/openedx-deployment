Director Setup
==============

The `director` instance is used to run ansible playbooks in the
[`edx/configuration`](https://github.com/edx/configuration) repo.

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
pip install -r pre-requirements.txt
pip install -r requirements.txt
```

This will install `ansible` among other depencencies.
