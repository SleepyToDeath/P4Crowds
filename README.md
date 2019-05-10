# P4Crowds
This is an attempt to move anonymity networks to programmable hardware. 
In this project, I'm implementing Crowds with p4. It currently only aims
for p4c simulator and mininet.

# Setup
Run `vagrant up` at root dir. It should start up a vagrant VM with necessary environment.
You may encounter some subtle problems like lacking dependencies. It varies slightly
for everyone, so fix it yourself.

Then run `vagrant ssh` to log into the VM. The project is located at `/vagrant`.
In that dir, first `make run` to start the network and data planes. Then start
another ssh session to run `control_plane.py` with python2. Then it should be
working.

For the system to be fully functional, set up a network of jondos, web servers and clients.
All jondos and servers' routing information need to be hardcoded in the control plane.
Any client can send a packet with jondo header to any switch. Then the switches will
function similarly as is described in the Crowds paper.
