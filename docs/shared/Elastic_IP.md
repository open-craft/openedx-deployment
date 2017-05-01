Elastic IP
==========

An Elastic IP makes it possible to perform updates or replace servers without downtime.  When a new server is ready, you
can simply switch the Elastic IP to point to the new server.

Create
------

To create an Elastic IP and assign it to the new EC2 instance:

* Go to the EC2 dashboard
* Under `Network & Security`, click the `Elastic IPs` link.
* Click `Allocate New Address`, select `EC2`, and click `Yes, Allocate`.
* Select the new Elastic IP from the list, and click `Actions -> Associate Address`.
* Select your EC2 instance from the dropdown and click `Associate`.

Your EC2 instance can now be reached through the Elastic IP.

Update
------

To reassociate an existing Elastic IP with a new EC2 instance:

* Go to the EC2 dashboard
* Under `Network & Security`, click the `Elastic IPs` link.
* Select the desired Elastic IP from the list, and click `Actions -> Associate Address`.
* Select your EC2 instance from the dropdown.
* Enable the "Reassociate" checkbox.
* Click `Associate`.
