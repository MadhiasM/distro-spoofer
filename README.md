# distro-spoofer

This tool can spoof the linux distro to fool tools like Microsoft InTune into thinking you are running Ubuntu 24.04 instead of Zorin OS 17.3
Replace os-release.orig with the one of your distro that can be found in /etc/os-release.
Replace os-release.spoof with the one you want to use to spoof your machinet to.
Run as sudo.
After the defined time it will revert back to the original state.
