# Scheduino

Minimalistic OS for the Arduino Uno. (WIP)

It is planned to feature preemptive multithreading and userspace ressource dirvers, allowing all the user processes to access the ressources in a safe, non-colliding, way. This obviously assumes the processes aren't malicious and do not try and access memory-mapped ressources directly, since there is no MMU on this platform.

The processes will most probably have to be spawned at compile-time, in order to acomodate for the limited ressources of the platform, and because there would not be need for runtime allocation of processes.

Very simple means of inter-process comunication such as pipes should get implemented in the future as well.